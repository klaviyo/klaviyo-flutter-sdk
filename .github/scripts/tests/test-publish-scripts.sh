#!/usr/bin/env bash
#
# Offline tests for the example app publish scripts. Fakes `curl` (Play API)
# and `altool` (TestFlight) so the upload-conflict retry paths can be exercised
# without store credentials.
#
# shellcheck disable=SC2016
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

pass() { echo "ok   - $1"; }
# expect_failure <name> <message regex> <command...>: the command must exit non-zero AND say why.
# A bare "it failed" proves nothing: a missing tool or a crash would pass it.
expect_failure() {
  local name="$1" pattern="$2"; shift 2
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ]; then
    fail "$name (exited 0)"
  elif grep -qE -- "$pattern" <<<"$out"; then
    pass "$name"
  else
    fail "$name (failed, but not with /$pattern/: $(head -c 160 <<<"$out" | tr '\n' ' '))"
  fi
}
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$name"; else fail "$name (expected '$expected', got '$actual')"; fi
}

# ---------------------------------------------------------------- fake curl
# Behaviour is driven by files in $FAKE_PLAY:
#   highest      versionCode reported by the bundles listing
#   conflicts    number of bundle uploads to reject as "already used"
#   commit_conflicts  number of edit commits to reject as "already used"
#   calls        log of "METHOD path" lines
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
method=GET out=/dev/null url="" data=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -o) out="$2"; shift 2 ;;
    -w|-H) shift 2 ;;
    --connect-timeout) echo "$method connect=$2" >> "$FAKE_PLAY/timeouts"; shift 2 ;;
    --max-time) echo "$method max=$2" >> "$FAKE_PLAY/timeouts"; shift 2 ;;
    -d|--data-binary) data="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
echo "$method $url" >> "$FAKE_PLAY/full_calls"
path="${url#*applications/*/}"
echo "$method $path" >> "$FAKE_PLAY/calls"
if [[ "$url" == *internalappsharing* ]]; then
  printf '%s' '{"downloadUrl":"https://play.google.com/apps/internaltest/abc123"}' > "$out"
  printf '200'
  exit 0
fi
read_n() { cat "$FAKE_PLAY/$1" 2>/dev/null || echo 0; }
dec() { echo $(( $(read_n "$1") - 1 )) > "$FAKE_PLAY/$1"; }
code=200 body='{}'
case "$method $path" in
  "POST edits") body='{"id":"edit1"}' ;;
  "GET edits/edit1/bundles") body="{\"bundles\":[{\"versionCode\":$(read_n highest)},{\"versionCode\":2}]}" ;;
  "GET edits/edit1/apks") body='{"apks":[{"versionCode":1}]}' ;;
  "DELETE edits/edit1") code=204 body='' ;;
  "POST edits/edit1/bundles?uploadType=media")
    if [ "$(read_n conflicts)" -gt 0 ]; then
      dec conflicts
      # A competing deploy took the code; the floor moves past it.
      echo $(( $(read_n highest) + 1 )) > "$FAKE_PLAY/highest"
      case "$(cat "$FAKE_PLAY/conflict_shape" 2>/dev/null || echo classic)" in
        http409)
          code=409 body='{"error":{"code":409,"message":"Request conflicts with current state","status":"CONFLICT"}}' ;;
        concurrent)
          code=400 body='{"error":{"message":"Concurrent uploads for app com.example"}}' ;;
        editDeleted)
          code=400 body='{"error":{"message":"This edit has been deleted","reason":"editDeleted"}}' ;;
        apkUpgrade)
          code=400 body='{"error":{"message":"apkUpgradeVersionConflict"}}' ;;
        *)
          code=403 body='{"error":{"code":403,"message":"APK specifies a version code that has already been used.","status":"PERMISSION_DENIED"}}' ;;
      esac
    else
      body="{\"versionCode\":$(cat "$FAKE_PLAY/built_code")}"
    fi ;;
  "PUT edits/edit1/tracks/internal") printf '%s' "$data" > "$FAKE_PLAY/track_body" ;;
  "POST edits/edit1:commit")
    if [ "$(read_n commit_conflicts)" -gt 0 ]; then
      dec commit_conflicts
      echo $(( $(read_n highest) + 1 )) > "$FAKE_PLAY/highest"
      code=400 body='{"error":{"message":"Version code 9 has already been used."}}'
    fi ;;
  *) code=500 body="{\"error\":\"unexpected $method $path\"}" ;;
esac
printf '%s' "$body" > "$out"
printf '%s' "$code"
FAKE
chmod +x "$WORK/bin/curl"

run_play() {
  FAKE_PLAY="$WORK/play" PATH="$WORK/bin:$PATH" PACKAGE_NAME=com.example PLAY_ACCESS_TOKEN=fake \
    PLAY_API_ROOT=https://play.test AAB_PATH="$WORK/app.aab" NOTES_FILE="$WORK/notes.txt" \
    GITHUB_ENV="$WORK/play/github_env" \
    "$SCRIPTS/play-publish.sh" deploy -- bash -c 'echo "$VERSION_CODE" > "$FAKE_PLAY/built_code"; echo "$VERSION_CODE" >> "$FAKE_PLAY/builds"'
}

reset_play() {
  rm -rf "$WORK/play"; mkdir -p "$WORK/play"
  echo aab > "$WORK/app.aab"
  echo "Klaviyo Flutter SDK 1.2.3" > "$WORK/notes.txt"
  echo "$1" > "$WORK/play/highest"
}

# Play: clean upload uses highest+1.
reset_play 41
out="$(run_play 2>/dev/null)"
check "play: first attempt uses highest+1" 42 "$out"
check "play: built once" 42 "$(paste -sd, "$WORK/play/builds")"
check "play: exports VERSION_CODE" "VERSION_CODE=42" "$(cat "$WORK/play/github_env")"
check "play: release notes attached" "Klaviyo Flutter SDK 1.2.3" "$(jq -r '.releases[0].releaseNotes[0].text' "$WORK/play/track_body")"
check "play: completed release" "completed" "$(jq -r '.releases[0].status' "$WORK/play/track_body")"

# Play: every call is bounded; only the bundle upload gets the long limit.
check "play: every API call sets a connect timeout" "$(wc -l < "$WORK/play/calls" | tr -d ' ')" "$(grep -c 'connect=15$' "$WORK/play/timeouts" | tr -d ' ')"
check "play: every API call sets a total timeout" "$(wc -l < "$WORK/play/calls" | tr -d ' ')" "$(grep -c ' max=' "$WORK/play/timeouts" | tr -d ' ')"
check "play: only the bundle upload gets the upload limit" "1" "$(grep -c 'max=600$' "$WORK/play/timeouts" | tr -d ' ')"
check "play: ordinary calls get the API limit" "$(( $(wc -l < "$WORK/play/calls" | tr -d ' ') - 1 ))" "$(grep -c 'max=60$' "$WORK/play/timeouts" | tr -d ' ')"
reset_play 41
out="$(PLAY_CONNECT_TIMEOUT=3 PLAY_API_TIMEOUT=7 PLAY_UPLOAD_TIMEOUT=9 run_play 2>/dev/null)"
check "play: timeouts can be overridden from the environment" "3 7 9" "$(grep -c 'connect=3$' "$WORK/play/timeouts" >/dev/null && echo 3) $(grep -q 'max=7$' "$WORK/play/timeouts" && echo 7) $(grep -q 'max=9$' "$WORK/play/timeouts" && echo 9)"

# Play: a gcloud that never answers is cut off and named, not waited on.
mkdir -p "$WORK/hang-bin"
printf '#!/bin/sh\nsleep 30\n' > "$WORK/hang-bin/gcloud"
chmod +x "$WORK/hang-bin/gcloud"
reset_play 41
hung_play() {
  env -u PLAY_ACCESS_TOKEN FAKE_PLAY="$WORK/play" PATH="$WORK/hang-bin:$WORK/bin:$PATH" PACKAGE_NAME=com.example \
    PLAY_TOKEN_TIMEOUT=1 PLAY_API_ROOT=https://play.test AAB_PATH="$WORK/app.aab" NOTES_FILE="$WORK/notes.txt" \
    GITHUB_ENV="$WORK/play/github_env" "$SCRIPTS/play-publish.sh" deploy -- true
}
started="$(date +%s)"
expect_failure "play: a hung gcloud fails with a message naming the timeout" "gcloud did not return an access token within 1s" hung_play
check "play: the hung gcloud was cut off within seconds" "yes" "$([ $(( $(date +%s) - started )) -lt 15 ] && echo yes || echo no)"
reset_play 41

# Play: upload rejected twice for versionCode conflict, then succeeds.
reset_play 41; echo 2 > "$WORK/play/conflicts"
out="$(run_play 2>/dev/null)"
check "play: retries after upload conflicts" 44 "$out"
check "play: rebuilt with increasing codes" "42,43,44" "$(paste -sd, "$WORK/play/builds")"

# Play: conflict surfacing only at edit commit is retried too.
reset_play 8; echo 1 > "$WORK/play/commit_conflicts"
out="$(run_play 2>/dev/null)"
check "play: retries after commit conflict" 10 "$out"

# Play: alternate conflict shapes are retryable too.
for shape in http409 concurrent editDeleted apkUpgrade; do
  reset_play 41; echo 1 > "$WORK/play/conflicts"; echo "$shape" > "$WORK/play/conflict_shape"
  out="$(run_play 2>/dev/null)"
  check "play: retries after $shape conflict" 43 "$out"
done

# Play: the release name is composed after the versionCode settles,
# including after a conflict retry moves the code.
reset_play 41
out="$(RELEASE_NAME_PREFIX='1.2.3' RELEASE_NAME_SUFFIX='0123456' run_play 2>/dev/null)"
check "play: release name carries the shipped code" "1.2.3 (42) 0123456" "$(jq -r '.releases[0].name' "$WORK/play/track_body")"
reset_play 41; echo 2 > "$WORK/play/conflicts"
out="$(RELEASE_NAME_PREFIX='1.2.3' RELEASE_NAME_SUFFIX='0123456' run_play 2>/dev/null)"
check "play: release name follows the retried code" "1.2.3 (44) 0123456" "$(jq -r '.releases[0].name' "$WORK/play/track_body")"

# Play: NOTES_CMD, run the way the workflow sets it, carries the source, event,
# release body and CI run into the notes that reach Play, with the shipped code.
write_notes_info() {
  cat > "$1" <<'JSON'
{"sdkVersion":"1.2.3","appVersion":"1.2.3","flutterSdkRef":"1.2.3","androidSdkVersion":"4.5.1","androidSdkRef":"4.5.1","commitShort":"0123456","buildDate":"2026-10-13 12:00 UTC"}
JSON
}
write_notes_info "$WORK/notes-bi.json"
reset_play 41
NOTES_CMD_VALUE='printf '"'"'%s'"'"' "$RELEASE_BODY" > "$RUNNER_TEMP/release-body.txt" && '"$SCRIPTS"'/release-notes.sh 500 android '"$WORK"'/notes-bi.json "$BUILD_NUMBER" "$RUNNER_TEMP/release-body.txt"'
out="$(RUNNER_TEMP="$WORK" RELEASE_BODY='Fixed the thing' SOURCE_LABEL='release 1.2.3' EVENT_NAME=release \
  RUN_URL='https://example.com/run/1' NOTES_CMD="$NOTES_CMD_VALUE" run_play 2>/dev/null)"
sent="$(jq -r '.releases[0].releaseNotes[0].text' "$WORK/play/track_body")"
check "play: notes carry the source and event" "1" "$(grep -c '^Commit: 0123456 on release 1.2.3 (release)$' <<<"$sent" | tr -d ' ')"
check "play: notes carry the release body" "1" "$(grep -c '^Fixed the thing$' <<<"$sent" | tr -d ' ')"
check "play: notes carry the shipped build number" "Flutter Example 1.2.3 (42)" "$(head -1 <<<"$sent")"
check "play: notes carry the CI run" "1" "$(grep -c '^CI run: https://example.com/run/1$' <<<"$sent" | tr -d ' ')"
check "play: notes never show a placeholder source" "0" "$(grep -c 'on — (' <<<"$sent" | tr -d ' ')"
reset_play 41; echo 1 > "$WORK/play/conflicts"
out="$(RUNNER_TEMP="$WORK" RELEASE_BODY='Fixed the thing' SOURCE_LABEL='release 1.2.3' EVENT_NAME=release \
  RUN_URL='https://example.com/run/1' NOTES_CMD="$NOTES_CMD_VALUE" run_play 2>/dev/null)"
sent="$(jq -r '.releases[0].releaseNotes[0].text' "$WORK/play/track_body")"
check "play: notes follow a retried versionCode" "Flutter Example 1.2.3 (43)" "$(head -1 <<<"$sent")"
check "play: retried notes keep the release body" "1" "$(grep -c '^Fixed the thing$' <<<"$sent" | tr -d ' ')"

# Play: a notes command that fails, or prints nothing, stops the release before it is published. upload
# runs on the left of ||, where set -e is off, so the status has to be checked explicitly; without that the
# release would go out with an empty "What's new" and exit 0.
play_with_notes() { NOTES_CMD="$1" run_play; }
reset_play 41
: > "$WORK/play/calls"
expect_failure "play: a failing notes command stops the release and says why" \
  "release notes command failed \\(exit 7\\)" play_with_notes 'exit 7'
check "play: nothing was assigned to the track when the notes failed" "0" "$(grep -c 'PUT edits/edit1/tracks' "$WORK/play/calls" | tr -d ' ')"
check "play: nothing was committed when the notes failed" "0" "$(grep -c 'edit1:commit' "$WORK/play/calls" | tr -d ' ')"
# Every edit that was opened is discarded: the preflight opens and deletes one, and the upload that
# stopped at the notes opens and deletes another, so none is left dangling.
check "play: every opened edit was discarded, none left dangling" \
  "$(grep -c '^POST edits$' "$WORK/play/calls" | tr -d ' ')" "$(grep -c '^DELETE edits/edit1$' "$WORK/play/calls" | tr -d ' ')"
reset_play 41
expect_failure "play: a notes command that prints nothing stops the release" \
  "failed \\(exit 0\\) or printed nothing" play_with_notes 'true'
reset_play 41
: > "$WORK/play/calls"
out="$(play_with_notes 'echo fine' 2>/dev/null)"
check "play: working notes still release" "42" "$out"
check "play: working notes reach the track" "fine" "$(jq -r '.releases[0].releaseNotes[0].text' "$WORK/play/track_body")"

# Play: gives up after MAX_ATTEMPTS.
reset_play 41; echo 5 > "$WORK/play/conflicts"
expect_failure "play: stops after max attempts" "Play upload still conflicted after 3 attempts" run_play
check "play: three builds attempted" 3 "$(wc -l < "$WORK/play/builds" | tr -d ' ')"

# Internal App Sharing posts to the exact endpoint. The download URL is masked
# before anything else, goes to $GITHUB_OUTPUT as url=, and never reaches the log.
reset_play 41
SHARE_URL="https://play.google.com/apps/internaltest/abc123"
: > "$WORK/play/share_output"
out="$(FAKE_PLAY="$WORK/play" PATH="$WORK/bin:$PATH" PACKAGE_NAME=com.example PLAY_ACCESS_TOKEN=fake \
  PLAY_API_ROOT=https://play.test AAB_PATH="$WORK/app.aab" GITHUB_OUTPUT="$WORK/play/share_output" \
  "$SCRIPTS/play-publish.sh" share 2>&1)"
check "play: share writes the URL to GITHUB_OUTPUT" "url=$SHARE_URL" "$(cat "$WORK/play/share_output")"
check "play: share masks the URL" "::add-mask::$SHARE_URL" "$(head -1 <<<"$out")"
check "play: share logs the URL nowhere but the mask line" "1" "$(grep -c -F "$SHARE_URL" <<<"$out" | tr -d ' ')"
check "play: share posts to the upload endpoint" \
  "POST https://play.test/upload/androidpublisher/v3/applications/internalappsharing/com.example/artifacts/bundle?uploadType=media" \
  "$(cat "$WORK/play/full_calls")"

# ---------------------------------------------------------------- fake altool
cat > "$WORK/bin/altool" <<'FAKE'
#!/usr/bin/env bash
echo upload >> "$FAKE_TF/uploads"
n="$(cat "$FAKE_TF/rejections" 2>/dev/null || echo 0)"
built="$(cat "$FAKE_TF/built")"
if [ "$n" -gt 0 ]; then
  echo $((n - 1)) > "$FAKE_TF/rejections"
  mode="$(cat "$FAKE_TF/mode")"
  if [ "$mode" = redundant ]; then
    # ASC's next-number endpoint goes stale for a bit after a rejection.
    echo "stale:15" > "$FAKE_TF/next_asc"
  fi
  if [ "$mode" = previous ]; then
    echo "ERROR: [ContentDelivery.Uploader] The bundle version must be higher than the previously uploaded version. (previousBundleVersion = $((built + 4)))"
  elif [ "$mode" = redundant ]; then
    echo "ERROR: Redundant Binary Upload. You've already uploaded a build with build number '$built'."
  else
    echo "ERROR: Authentication failed"
  fi
  exit 1
fi
echo "No errors uploading 'Runner.ipa'"
FAKE
chmod +x "$WORK/bin/altool"

# Fake "next build number" command: prints the contents of $FAKE_TF/next_asc
# (empty file = recheck reports nothing new), or fails when the file contains
# "fail". A value wrapped as stale:N only answers numbers below N, modelling
# ASC not yet showing the rejection the script already saw.
cat > "$WORK/bin/next-asc" <<'FAKE'
#!/usr/bin/env bash
contents="$(cat "$FAKE_TF/next_asc" 2>/dev/null || true)"
if [ "$contents" = "fail" ]; then
  exit 1
fi
if [ "${contents#stale:}" != "$contents" ]; then
  value="${contents#stale:}"
  built="$(cat "$FAKE_TF/built" 2>/dev/null || echo 0)"
  if [ "$value" -gt "$built" ]; then
    echo "$value"
  fi
  exit 0
fi
if [ -n "$contents" ]; then
  echo "$contents"
fi
FAKE
chmod +x "$WORK/bin/next-asc"

# The fake build records the attempted number and, unless SKIP_IPA_CHECK is
# set, writes a real zip IPA whose Info.plist carries the number, so the
# script's CFBundleVersion assertion is exercised too.
run_tf() {
  FAKE_TF="$WORK/tf" ALTOOL="$WORK/bin/altool" IPA_PATH="$WORK/tf/Runner.ipa" \
    APP_STORE_CONNECT_API_KEY_ID=k APP_STORE_CONNECT_API_KEY_ISSUER_ID=i \
    GITHUB_ENV="$WORK/tf/github_env" NEXT_BUILD_NUMBER_CMD="$WORK/bin/next-asc" \
    SKIP_IPA_CHECK="${SKIP_IPA_CHECK:-1}" \
    "$SCRIPTS/testflight-publish.sh" "$1" -- \
    "$WORK/bin/fake-build"
}
cat > "$WORK/bin/fake-build" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
echo "$BUILD_NUMBER" > "$FAKE_TF/built"
echo "$BUILD_NUMBER" >> "$FAKE_TF/builds"
if [ "${SKIP_IPA_CHECK:-1}" = "1" ]; then
  touch "$IPA_PATH"
  exit 0
fi
rm -rf "$FAKE_TF/Payload"
mkdir -p "$FAKE_TF/Payload/Runner.app"
printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleVersion</key><string>%s</string></dict></plist>' \
  "$BUILD_NUMBER" > "$FAKE_TF/Payload/Runner.app/Info.plist"
rm -f "$IPA_PATH"
(cd "$FAKE_TF" && zip -q "$IPA_PATH" Payload/Runner.app/Info.plist)
FAKE
chmod +x "$WORK/bin/fake-build"

reset_tf() {
  rm -rf "$WORK/tf"; mkdir -p "$WORK/tf"
  echo "$1" > "$WORK/tf/rejections"
  echo "${2:-}" > "$WORK/tf/mode"
  : > "$WORK/tf/next_asc"
}


reset_tf 0
run_tf 7 >/dev/null 2>&1
check "testflight: clean upload keeps preflight number" "BUILD_NUMBER=7" "$(tail -1 "$WORK/tf/github_env")"

# Pre-upload recheck: ASC reports a higher number between build and upload.
reset_tf 0; echo 20 > "$WORK/tf/next_asc"
run_tf 7 >/dev/null 2>&1
check "testflight: pre-upload recheck rebuilds with the fresh number" "7,20" "$(paste -sd, "$WORK/tf/builds")"
check "testflight: exports the rechecked number" "BUILD_NUMBER=20" "$(tail -1 "$WORK/tf/github_env")"

# A failed recheck only warns; the upload still goes out.
reset_tf 0; echo fail > "$WORK/tf/next_asc"
run_tf 7 >/dev/null 2>&1
check "testflight: failed recheck still uploads" "BUILD_NUMBER=7" "$(tail -1 "$WORK/tf/github_env")"

reset_tf 1 previous
run_tf 7 >/dev/null 2>&1
check "testflight: retries with previousBundleVersion+1" "7,12" "$(paste -sd, "$WORK/tf/builds")"
check "testflight: exports final build number" "BUILD_NUMBER=12" "$(tail -1 "$WORK/tf/github_env")"

reset_tf 1 redundant
run_tf 7 >/dev/null 2>&1
check "testflight: redundant upload re-resolves from ASC" "7,15" "$(paste -sd, "$WORK/tf/builds")"

reset_tf 1 other
expect_failure "testflight: non-conflict error fails fast" "TestFlight upload failed with a non-recoverable error" run_tf 7
check "testflight: no retry on non-conflict error" 7 "$(paste -sd, "$WORK/tf/builds")"

reset_tf 5 previous
expect_failure "testflight: stops after max attempts" "TestFlight upload failed after 3 attempts" run_tf 7

# IPA assertion: the real zip carries the retried number on every attempt.
if command -v plutil >/dev/null 2>&1; then
  reset_tf 1 previous; SKIP_IPA_CHECK=
  run_tf 7 >/dev/null 2>&1
  check "testflight: retried IPA carries the new number" "7,12" "$(paste -sd, "$WORK/tf/builds")"
  check "testflight: exported number matches the uploaded IPA" "BUILD_NUMBER=12" "$(tail -1 "$WORK/tf/github_env")"

  # A build that ignored the retry (stale plist) fails loudly before upload.
  reset_tf 0; SKIP_IPA_CHECK=
  cat > "$WORK/bin/fake-build-stale" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
rm -rf "$FAKE_TF/Payload"
mkdir -p "$FAKE_TF/Payload/Runner.app"
printf '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleVersion</key><string>1</string></dict></plist>' \
  > "$FAKE_TF/Payload/Runner.app/Info.plist"
rm -f "$IPA_PATH"
(cd "$FAKE_TF" && zip -q "$IPA_PATH" Payload/Runner.app/Info.plist)
FAKE
  chmod +x "$WORK/bin/fake-build-stale"
  stale_build() {
    FAKE_TF="$WORK/tf" ALTOOL="$WORK/bin/altool" IPA_PATH="$WORK/tf/Runner.ipa" \
      APP_STORE_CONNECT_API_KEY_ID=k APP_STORE_CONNECT_API_KEY_ISSUER_ID=i \
      GITHUB_ENV="$WORK/tf/github_env" SKIP_IPA_CHECK='' \
      "$SCRIPTS/testflight-publish.sh" 9 -- "$WORK/bin/fake-build-stale"
  }
  expect_failure "testflight: stale IPA number fails loudly, naming both numbers" \
    "IPA carries CFBundleVersion 1, expected 9" stale_build
  uploads=0
  [ -f "$WORK/tf/uploads" ] && uploads="$(wc -l < "$WORK/tf/uploads" | tr -d ' ')"
  check "testflight: a stale IPA is never uploaded" "0" "$uploads"
fi

# ---------------------------------------------------------------- tool preflight
# A tool missing from the runner image must fail in seconds, before the expensive build, and name
# the tool. The scripts under test use the real `command -v` lookup, so each case runs them with a PATH
# directory that holds only the tools that case provides. Tools the preflight merely looks for
# (unzip, plutil, xcrun, gcloud, jq, curl) are empty executables made here, never links to the host's
# copies: ubuntu runners have no plutil, xcrun or gcloud, and a test that needs them from the host
# passes on a Mac and fails in CI. Only the tools the scripts actually run (bash and coreutils) are
# linked from the host. A build command records whether it ever ran.
REAL_BASH="$(command -v bash)"
BASE_TOOLS=(bash cat grep head tr sed seq mktemp rm mkdir date dirname basename env wc paste tail)
# tool_dir <dest> <tool...>: a PATH directory holding the base tools (linked from the host, which every
# runner has) plus an empty executable for each named tool.
tool_dir() {
  local dest="$1"; shift
  rm -rf "$dest"; mkdir -p "$dest"
  local t
  for t in "${BASE_TOOLS[@]}"; do ln -s "$(command -v "$t")" "$dest/$t"; done
  for t in "$@"; do printf '#!/bin/sh\nexit 0\n' > "$dest/$t"; chmod +x "$dest/$t"; done
}

reset_tf 0
tool_dir "$WORK/path-no-unzip" plutil xcrun
: > "$WORK/tf/build-ran"
tf_without() { # <PATH dir> -- runs the real script with that PATH and a build that records it ran
  PATH="$1" FAKE_TF="$WORK/tf" IPA_PATH="$WORK/tf/Runner.ipa" \
    APP_STORE_CONNECT_API_KEY_ID=k APP_STORE_CONNECT_API_KEY_ISSUER_ID=i GITHUB_ENV="$WORK/tf/github_env" \
    "$REAL_BASH" "$SCRIPTS/testflight-publish.sh" 7 -- "$REAL_BASH" -c 'echo ran >> "$FAKE_TF/build-ran"'
}
expect_failure "testflight: a missing unzip fails before the build and names it" \
  "needs these tools on PATH before it builds: unzip" tf_without "$WORK/path-no-unzip"
check "testflight: the build never ran when a tool was missing" "0" "$(wc -l < "$WORK/tf/build-ran" | tr -d ' ')"

tool_dir "$WORK/path-no-plutil" unzip xcrun
expect_failure "testflight: a missing plutil fails before the build and names it" \
  "before it builds: plutil" tf_without "$WORK/path-no-plutil"

tool_dir "$WORK/path-none"
expect_failure "testflight: every missing tool is named together" \
  "before it builds: unzip, plutil, xcrun" tf_without "$WORK/path-none"

tool_dir "$WORK/path-ok" unzip plutil xcrun
: > "$WORK/tf/build-ran"
tf_without "$WORK/path-ok" >/dev/null 2>&1 || true
check "testflight: with every tool present the check passes and the build runs" "1" "$(wc -l < "$WORK/tf/build-ran" | tr -d ' ')"

# Play: jq, curl and (without a supplied token) gcloud.
play_without() { # <PATH dir> [token]
  PATH="$1" PACKAGE_NAME=com.example PLAY_API_ROOT=https://play.test ${2:+PLAY_ACCESS_TOKEN=$2} \
    "$REAL_BASH" "$SCRIPTS/play-publish.sh" next-version-code
}
tool_dir "$WORK/path-play-nojq" curl gcloud
expect_failure "play: a missing jq fails first and names it" "play-publish.sh needs these tools on PATH: jq" play_without "$WORK/path-play-nojq"
tool_dir "$WORK/path-play-nogcloud" curl jq
expect_failure "play: a missing gcloud is named when no token is supplied" "PATH: gcloud" play_without "$WORK/path-play-nogcloud"
out="$(play_without "$WORK/path-play-nogcloud" tok 2>&1 || true)"
check "play: gcloud is not required when a token is supplied" "0" "$(grep -c 'needs these tools' <<<"$out" | tr -d ' ')"

# ---------------------------------------------------------------- release notes
# The header block is validated against the shared fixture the Dart build-info
# formatter also tests against, so the app and the store notes cannot drift.
write_fixture_info() {
  # $1 = case index into fixtures/build-info-cases.json; writes $2
  python3 -I - "$1" "$SCRIPTS/tests/fixtures/build-info-cases.json" "$2" <<'PY'
import json
import sys

idx, fixture, out = int(sys.argv[1]), sys.argv[2], sys.argv[3]
case = json.load(open(fixture))["cases"][idx]
info = {
    "sdkVersion": case["flutterVersion"],
    "flutterSdkRef": case["flutterRef"],
    "iosSdkVersion": case["nativeVersion"] if case["platform"] == "ios" else "—",
    "iosSdkRef": case["nativeRef"] if case["platform"] == "ios" else "—",
    "androidSdkVersion": case["nativeVersion"] if case["platform"] == "android" else "—",
    "androidSdkRef": case["nativeRef"] if case["platform"] == "android" else "—",
    "commit": case["commitShort"] + "0" * 33,
    "commitShort": case["commitShort"],
    "branch": case["sourceLabel"],
    "appVersion": case["appVersion"],
    "buildDate": case["buildDate"],
}
json.dump(info, open(out, "w"))
PY
}

fixture_field() {
  python3 -I -c "import json,sys; c=json.load(open('$SCRIPTS/tests/fixtures/build-info-cases.json'))['cases'][$1]; print(c[sys.argv[1]])" "$2"
}

printf '## Fixes\n- Thing' > "$WORK/body.txt"
printf '   \n' > "$WORK/blank.txt"

# Case 0: release build on iOS, with a release body.
write_fixture_info 0 "$WORK/bi.json"
notes="$(SOURCE_LABEL="$(fixture_field 0 sourceLabel)" EVENT_NAME=release \
  RUN_URL="$(fixture_field 0 runUrl)" \
  "$SCRIPTS/release-notes.sh" 4000 ios "$WORK/bi.json" 42 "$WORK/body.txt")"
check "notes: header matches the shared fixture (release, ios)" \
  "$(fixture_field 0 notesHeader)" "$(head -6 <<<"$notes")"
check "notes: release body after a blank line" "## Fixes|- Thing" "$(tail -2 <<<"$notes" | paste -sd'|' -)"

# Case 1: branch build on Android, no body (push event).
write_fixture_info 1 "$WORK/bi.json"
notes="$(SOURCE_LABEL="$(fixture_field 1 sourceLabel)" EVENT_NAME=pull_request \
  RUN_URL="$(fixture_field 1 runUrl)" \
  "$SCRIPTS/release-notes.sh" 4000 android "$WORK/bi.json" 4242 "$WORK/body.txt")"
check "notes: header matches the shared fixture (branch, android)" \
  "$(fixture_field 1 notesHeader)" "$(head -6 <<<"$notes")"
if grep -q '## Fixes' <<<"$notes"; then fail "notes: body only on release events"; else pass "notes: body only on release events"; fi

# Case 3/4: local and missing values render the em dash.
write_fixture_info 3 "$WORK/bi.json"
notes="$(SOURCE_LABEL='—' EVENT_NAME='—' RUN_URL='' \
  "$SCRIPTS/release-notes.sh" 4000 ios "$WORK/bi.json" 1 "$WORK/blank.txt")"
check "notes: local build omits the CI run line" "$(fixture_field 3 notesHeader)" "$notes"
write_fixture_info 4 "$WORK/bi.json"
notes="$(SOURCE_LABEL='—' EVENT_NAME='—' RUN_URL='' \
  "$SCRIPTS/release-notes.sh" 4000 android "$WORK/bi.json" 1 "$WORK/blank.txt")"
check "notes: missing values render as em dash" "$(fixture_field 4 notesHeader)" "$notes"

# Caps: TestFlight 4000 keeps a long multi-byte body (truncated, valid UTF-8).
write_fixture_info 0 "$WORK/bi.json"
printf 'é%.0s' $(seq 1 5000) > "$WORK/long.txt"
# No LC_ALL on the capture: macOS bash miscounts multi-byte characters in
# $(...) under LC_ALL=C.UTF-8 once the text crosses a pipe buffer boundary.
notes="$(SOURCE_LABEL=x EVENT_NAME=release RUN_URL='https://example.com/run/1' \
  "$SCRIPTS/release-notes.sh" 4000 ios "$WORK/bi.json" 42 "$WORK/long.txt")"
check "notes: TestFlight cap" 4000 "$(S="$notes" python3 -I -c 'import os; print(len(os.environ["S"]))')"
check "notes: truncation ends with marker" "1" "$(S="$notes" python3 -I -c 'import os; print(1 if os.environ["S"].endswith("…[truncated]") else 0)')"
check "notes: header survives truncation" "Flutter Example 1.2.3 (42)" "$(head -1 <<<"$notes")"
check "notes: truncation keeps valid UTF-8" "1" "$(S="$notes" python3 -I -c '
import os
try:
    os.environ["S"].encode("utf-8")
    print(1)
except UnicodeEncodeError:
    print(0)
')"

# Play's 500-char cap cuts the body first and keeps the CI run line.
notes="$(SOURCE_LABEL=x EVENT_NAME=release RUN_URL='https://example.com/run/1' \
  "$SCRIPTS/release-notes.sh" 500 ios "$WORK/bi.json" 42 "$WORK/long.txt")"
check "notes: Play cap" 500 "$(S="$notes" python3 -I -c 'import os; print(len(os.environ["S"]))')"
check "notes: body is cut before the CI run line" "1" "$(grep -c '^CI run: https://example.com/run/1$' <<<"$notes" || true)"
check "notes: marker counts toward the cap" "1" "$(S="$notes" python3 -I -c 'import os; print(1 if os.environ["S"].endswith("…[truncated]") else 0)')"

# Cap edge cases around the header. HEAD is the header block alone, WITH_CI adds
# the CI run line, FULL adds a short release body.
printf 'Short body' > "$WORK/short.txt"
notes_cap() { # <cap> <body-file> <run-url>
  SOURCE_LABEL=x EVENT_NAME=release RUN_URL="$3" "$SCRIPTS/release-notes.sh" "$1" ios "$WORK/bi.json" 42 "$2"
}
chars() { S="$1" python3 -I -c 'import os; print(len(os.environ["S"]))'; }
MARKER_LINE=$'\n…[truncated]'
HEAD="$(SOURCE_LABEL=x EVENT_NAME=release "$SCRIPTS/release-notes.sh" 4000 ios "$WORK/bi.json" 42)"
RUN='https://example.com/run/1'
WITH_CI="$HEAD"$'\n'"CI run: $RUN"
FULL="$WITH_CI"$'\n\n'"Short body"
HLEN="$(chars "$HEAD")"
WLEN="$(chars "$WITH_CI")"
MLEN="$(chars "$MARKER_LINE")"

check "notes: a text that fits exactly has no marker" "$FULL" "$(notes_cap "$(chars "$FULL")" "$WORK/short.txt" "$RUN")"
check "notes: cap just above the header keeps the marker" "$HEAD$MARKER_LINE" \
  "$(notes_cap $((HLEN + MLEN + 3)) "$WORK/long.txt" "$RUN")"
check "notes: cap exactly header plus marker" "$HEAD$MARKER_LINE" \
  "$(notes_cap $((HLEN + MLEN)) "$WORK/long.txt" "$RUN")"
check "notes: body gone, CI run line kept, marker present" "$WITH_CI$MARKER_LINE" \
  "$(notes_cap $((WLEN + MLEN)) "$WORK/long.txt" "$RUN")"
out="$(notes_cap $((WLEN + MLEN + 20)) "$WORK/long.txt" "$RUN")"
check "notes: body cut, header and CI run line intact" "$WITH_CI" "$(head -n "$(grep -c '' <<<"$WITH_CI")" <<<"$out")"
check "notes: partial body stays within the cap" "1" "$(S="$out" CAP=$((WLEN + MLEN + 20)) python3 -I -c 'import os; print(1 if len(os.environ["S"]) <= int(os.environ["CAP"]) else 0)')"
check "notes: partial body ends with the marker" "1" "$(S="$out" python3 -I -c 'import os; print(1 if os.environ["S"].endswith("…[truncated]") else 0)')"
check "notes: no CI line configured, body cut, marker present" "$HEAD$MARKER_LINE" \
  "$(notes_cap $((HLEN + MLEN)) "$WORK/long.txt" "")"
check "notes: cap equals the header, marker cannot fit" "$HEAD" "$(notes_cap "$HLEN" "$WORK/long.txt" "$RUN")"
check "notes: cap one short of header plus marker" "$HEAD" "$(notes_cap $((HLEN + MLEN - 1)) "$WORK/long.txt" "$RUN")"
SOURCE_LABEL=x EVENT_NAME=release RUN_URL="$RUN" "$SCRIPTS/release-notes.sh" "$HLEN" ios "$WORK/bi.json" 42 "$WORK/long.txt" >/dev/null
check "notes: header-only cap exits 0" "0" "$?"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All publish script tests passed"
