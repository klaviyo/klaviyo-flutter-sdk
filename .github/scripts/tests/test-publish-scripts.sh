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

# Play: RELEASE_NAME is sent as the release name.
reset_play 41
out="$(RELEASE_NAME='1.2.3 (42) 0123456' run_play 2>/dev/null)"
check "play: release name sent" "1.2.3 (42) 0123456" "$(jq -r '.releases[0].name' "$WORK/play/track_body")"

# Play: gives up after MAX_ATTEMPTS.
reset_play 41; echo 5 > "$WORK/play/conflicts"
if run_play >/dev/null 2>&1; then fail "play: stops after max attempts"; else pass "play: stops after max attempts"; fi
check "play: three builds attempted" 3 "$(wc -l < "$WORK/play/builds" | tr -d ' ')"

# Internal App Sharing upload returns the download URL.
reset_play 41
out="$(FAKE_PLAY="$WORK/play" PATH="$WORK/bin:$PATH" PACKAGE_NAME=com.example PLAY_ACCESS_TOKEN=fake \
  PLAY_API_ROOT=https://play.test AAB_PATH="$WORK/app.aab" \
  "$SCRIPTS/play-publish.sh" share 2>/dev/null)"
check "play: share prints the Internal App Sharing URL" \
  "https://play.google.com/apps/internaltest/abc123" "$out"

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

run_tf() {
  FAKE_TF="$WORK/tf" ALTOOL="$WORK/bin/altool" IPA_PATH="$WORK/tf/Runner.ipa" \
    APP_STORE_CONNECT_API_KEY_ID=k APP_STORE_CONNECT_API_KEY_ISSUER_ID=i \
    GITHUB_ENV="$WORK/tf/github_env" NEXT_BUILD_NUMBER_CMD="$WORK/bin/next-asc" \
    "$SCRIPTS/testflight-publish.sh" "$1" -- \
    bash -c 'echo "$BUILD_NUMBER" > "$FAKE_TF/built"; echo "$BUILD_NUMBER" >> "$FAKE_TF/builds"; touch "$IPA_PATH"'
}
reset_tf() {
  rm -rf "$WORK/tf"; mkdir -p "$WORK/tf"
  echo "$1" > "$WORK/tf/rejections"
  echo "${2:-}" > "$WORK/tf/mode"
  : > "$WORK/tf/next_asc"
}

reset_tf 0
run_tf 7 >/dev/null 2>&1
check "testflight: clean upload keeps preflight number" "BUILD_NUMBER=7" "$(cat "$WORK/tf/github_env")"

# Pre-upload recheck: ASC reports a higher number between build and upload.
reset_tf 0; echo 20 > "$WORK/tf/next_asc"
run_tf 7 >/dev/null 2>&1
check "testflight: pre-upload recheck rebuilds with the fresh number" "7,20" "$(paste -sd, "$WORK/tf/builds")"
check "testflight: exports the rechecked number" "BUILD_NUMBER=20" "$(cat "$WORK/tf/github_env")"

# A failed recheck only warns; the upload still goes out.
reset_tf 0; echo fail > "$WORK/tf/next_asc"
run_tf 7 >/dev/null 2>&1
check "testflight: failed recheck still uploads" "BUILD_NUMBER=7" "$(cat "$WORK/tf/github_env")"

reset_tf 1 previous
run_tf 7 >/dev/null 2>&1
check "testflight: retries with previousBundleVersion+1" "7,12" "$(paste -sd, "$WORK/tf/builds")"
check "testflight: exports final build number" "BUILD_NUMBER=12" "$(cat "$WORK/tf/github_env")"

reset_tf 1 redundant
run_tf 7 >/dev/null 2>&1
check "testflight: redundant upload re-resolves from ASC" "7,15" "$(paste -sd, "$WORK/tf/builds")"

reset_tf 1 other
if run_tf 7 >/dev/null 2>&1; then fail "testflight: non-conflict error fails fast"; else pass "testflight: non-conflict error fails fast"; fi
check "testflight: no retry on non-conflict error" 7 "$(paste -sd, "$WORK/tf/builds")"

reset_tf 5 previous
if run_tf 7 >/dev/null 2>&1; then fail "testflight: stops after max attempts"; else pass "testflight: stops after max attempts"; fi

# ---------------------------------------------------------------- release notes
notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef GIT_REF_NAME=master EVENT_NAME=push BUILD_DATE='2026-10-06 12:00 UTC' \
  "$SCRIPTS/release-notes.sh" 500 /dev/null)"
check "notes: header synthesized from git metadata" \
  "Klaviyo Flutter SDK 1.2.3|Ref: master (push)|Commit: 0123456|Built: 2026-10-06 12:00 UTC" \
  "$(head -4 <<<"$notes" | paste -sd'|' -)"

printf '## Fixes\n- Thing' > "$WORK/body.txt"
notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef BUILD_DATE=x "$SCRIPTS/release-notes.sh" 500 "$WORK/body.txt")"
check "notes: human release body appended" "## Fixes|- Thing" "$(tail -2 <<<"$notes" | paste -sd'|' -)"

printf '   \n' > "$WORK/blank.txt"
notes="$(SDK_VERSION=1.2.3 BUILD_DATE=x "$SCRIPTS/release-notes.sh" 500 "$WORK/blank.txt")"
check "notes: falls back to commit subject" "$(git log -1 --format=%s)" "$(tail -1 <<<"$notes")"

notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef GIT_REF_NAME=v1.2.3 EVENT_NAME=release \
  RELEASE_NAME='Flutter SDK 1.2.3' BUILD_DATE=x "$SCRIPTS/release-notes.sh" 500 "$WORK/blank.txt")"
check "notes: release name above the body on releases" \
  "Ref: v1.2.3 (release)" "$(sed -n 2p <<<"$notes")"
check "notes: release name line present" \
  "Flutter SDK 1.2.3" "$(tail -1 <<<"$notes")"

notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef BUILD_DATE=x RUN_URL='https://example.com/run/1' \
  "$SCRIPTS/release-notes.sh" 4000 "$WORK/blank.txt")"
check "notes: CI run line appended" "CI run: https://example.com/run/1" "$(tail -1 <<<"$notes")"

printf 'é%.0s' $(seq 1 2000) > "$WORK/long.txt"
notes="$(SDK_VERSION=1.2.3 BUILD_DATE=x LC_ALL=C.UTF-8 "$SCRIPTS/release-notes.sh" 500 "$WORK/long.txt")"
check "notes: truncated to the store limit" 500 "$(LC_ALL=C.UTF-8 bash -c 'n="$1"; echo ${#n}' _ "$notes")"
check "notes: truncation ends with marker" "[truncated]" "$(tail -1 <<<"$notes")"
if iconv -f UTF-8 -t UTF-8 <<<"$notes" >/dev/null 2>&1; then pass "notes: truncation keeps valid UTF-8"; else fail "notes: truncation keeps valid UTF-8"; fi

# SDK refs come from build-info.json when present.
cat > "$WORK/build-info.json" <<'EOF'
{
  "sdkVersion": "1.2.3",
  "flutterSdkRef": "feat/thing@0123456",
  "iosSdkRef": "5.4.1",
  "androidSdkRef": "rel/4.6.0@0123456",
  "commit": "0123456789abcdef0123456789abcdef01234567",
  "commitShort": "0123456",
  "branch": "feat/thing",
  "appVersion": "1.2.3",
  "buildDate": "2026-10-06 12:00 UTC"
}
EOF
notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef BUILD_DATE=x BUILD_INFO="$WORK/build-info.json" \
  "$SCRIPTS/release-notes.sh" 4000 "$WORK/blank.txt")"
check "notes: SDK refs from build-info.json" \
  "Flutter SDK: feat/thing@0123456|iOS SDK: 5.4.1|Android SDK: rel/4.6.0@0123456" \
  "$(sed -n '5,7p' <<<"$notes" | paste -sd'|' -)"
notes="$(SDK_VERSION=1.2.3 GIT_SHA=0123456789abcdef BUILD_DATE=x BUILD_INFO="$WORK/absent.json" \
  "$SCRIPTS/release-notes.sh" 500 "$WORK/blank.txt")"
check "notes: missing build-info.json adds no refs" "0" "$(grep -c 'SDK:' <<<"$notes" || true)"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All publish script tests passed"
