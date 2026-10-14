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

# Play: gives up after MAX_ATTEMPTS.
reset_play 41; echo 5 > "$WORK/play/conflicts"
if run_play >/dev/null 2>&1; then fail "play: stops after max attempts"; else pass "play: stops after max attempts"; fi
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
if run_tf 7 >/dev/null 2>&1; then fail "testflight: non-conflict error fails fast"; else pass "testflight: non-conflict error fails fast"; fi
check "testflight: no retry on non-conflict error" 7 "$(paste -sd, "$WORK/tf/builds")"

reset_tf 5 previous
if run_tf 7 >/dev/null 2>&1; then fail "testflight: stops after max attempts"; else pass "testflight: stops after max attempts"; fi

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
  if FAKE_TF="$WORK/tf" ALTOOL="$WORK/bin/altool" IPA_PATH="$WORK/tf/Runner.ipa" \
    APP_STORE_CONNECT_API_KEY_ID=k APP_STORE_CONNECT_API_KEY_ISSUER_ID=i \
    GITHUB_ENV="$WORK/tf/github_env" SKIP_IPA_CHECK='' \
    "$SCRIPTS/testflight-publish.sh" 9 -- "$WORK/bin/fake-build-stale" >/dev/null 2>&1; then
    fail "testflight: stale IPA number fails loudly"
  else
    pass "testflight: stale IPA number fails loudly"
  fi
fi

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

# Play's 500-char cap drops the CI run line before cutting the body.
notes="$(SOURCE_LABEL=x EVENT_NAME=release RUN_URL='https://example.com/run/1' \
  "$SCRIPTS/release-notes.sh" 500 ios "$WORK/bi.json" 42 "$WORK/long.txt")"
check "notes: Play cap" 500 "$(S="$notes" python3 -I -c 'import os; print(len(os.environ["S"]))')"
check "notes: CI run line dropped before the body is cut" "0" "$(grep -c 'CI run:' <<<"$notes" || true)"
check "notes: marker counts toward the cap" "1" "$(S="$notes" python3 -I -c 'import os; print(1 if os.environ["S"].endswith("…[truncated]") else 0)')"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All publish script tests passed"
