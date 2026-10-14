#!/usr/bin/env bash
#
# Publishes an Android App Bundle to a Google Play track via the Play Developer
# (Edits) API, retrying with a higher versionCode when Play itself rejects the
# upload because the versionCode is already taken.
#
# Usage:
#   play-publish.sh next-version-code
#       Prints (highest versionCode Play has ever seen) + 1.
#   play-publish.sh deploy -- <build command...>
#       Resolves the next versionCode, runs the build command with VERSION_CODE
#       exported, uploads AAB_PATH and releases it to PLAY_TRACK. If Play
#       rejects the bundle with a versionCode conflict, re-resolves, rebuilds
#       and retries (up to MAX_ATTEMPTS). On success writes VERSION_CODE=<n> to
#       $GITHUB_ENV when set.
#
# Env:
#   PACKAGE_NAME        (required) Play application id
#   AAB_PATH            (deploy) bundle produced by the build command
#   NOTES_CMD           (deploy, optional) command printing the en-US release
#                       notes; runs per attempt with BUILD_NUMBER set to the
#                       versionCode, so a retry never ships a stale number
#   NOTES_FILE          (deploy, optional) static notes file; ignored when
#                       NOTES_CMD is set
#   PLAY_TRACK          (default: internal)
#   PLAY_RELEASE_STATUS (default: completed; must be "draft" until the app's
#                        first release has been rolled out from the console)
#   RELEASE_NAME_PREFIX, RELEASE_NAME_SUFFIX
#                       (deploy, optional) the release name shown in Play
#                       Console is "<prefix> (<versionCode>) <suffix>",
#                       composed after the versionCode settles so retries
#                       show the code actually shipped
#   MAX_ATTEMPTS        (default: 3)
#   PLAY_ACCESS_TOKEN   (optional) OAuth token; otherwise minted with gcloud
#                       from the active service-account credentials
#   PLAY_API_ROOT       (optional) API origin override, used by tests
#   PLAY_CONNECT_TIMEOUT (default: 15) seconds to open a connection
#   PLAY_API_TIMEOUT    (default: 60) seconds for one API call
#   PLAY_UPLOAD_TIMEOUT (default: 600) seconds for a bundle upload
#   PLAY_TOKEN_TIMEOUT  (default: 60) seconds to mint a token with gcloud
#
set -euo pipefail

: "${PACKAGE_NAME:?PACKAGE_NAME is required}"

# Fail in seconds if a tool is missing, not after a build. gcloud is only needed to mint a token.
needed="jq curl"
[ -n "${PLAY_ACCESS_TOKEN:-}" ] || needed="$needed gcloud"
missing=""
for tool in $needed; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing${missing:+, }$tool"
done
if [ -n "$missing" ]; then
  echo "::error::play-publish.sh needs these tools on PATH: $missing" >&2
  exit 1
fi

PLAY_TRACK="${PLAY_TRACK:-internal}"
PLAY_RELEASE_STATUS="${PLAY_RELEASE_STATUS:-completed}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
PLAY_CONNECT_TIMEOUT="${PLAY_CONNECT_TIMEOUT:-15}"
PLAY_API_TIMEOUT="${PLAY_API_TIMEOUT:-60}"
PLAY_UPLOAD_TIMEOUT="${PLAY_UPLOAD_TIMEOUT:-600}"
PLAY_TOKEN_TIMEOUT="${PLAY_TOKEN_TIMEOUT:-60}"
PLAY_API_ROOT="${PLAY_API_ROOT:-https://androidpublisher.googleapis.com}"
API="$PLAY_API_ROOT/androidpublisher/v3/applications/$PACKAGE_NAME"
UPLOAD_API="$PLAY_API_ROOT/upload/androidpublisher/v3/applications/$PACKAGE_NAME"

# Exit code used internally to signal "versionCode already used".
CONFLICT=3

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

# run_bounded <seconds> <command...>: runs the command and kills it if it overruns, without depending on
# timeout(1), which stock macOS does not have. Output goes through files, so a child that outlives the kill
# cannot keep the caller's pipes open. Prints the command's stdout and stderr; exits 124 on a timeout.
run_bounded() {
  local limit="$1" out err pid watcher rc=0
  shift
  out="$(mktemp)"
  err="$(mktemp)"
  "$@" > "$out" 2> "$err" < /dev/null &
  pid=$!
  ( sleep "$limit"; pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null ) > /dev/null 2>&1 &
  watcher=$!
  wait "$pid" 2>/dev/null || rc=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  # 143 and 137 are the exit codes of a process killed by TERM and KILL: the watcher fired.
  if [ "$rc" -eq 143 ] || [ "$rc" -eq 137 ]; then
    rc=124
  else
    cat "$out"
  fi
  cat "$err" >&2
  rm -f "$out" "$err"
  return "$rc"
}

access_token() {
  if [ -n "${PLAY_ACCESS_TOKEN:-}" ]; then
    printf '%s' "$PLAY_ACCESS_TOKEN"
  else
    # The androidpublisher scope must be requested explicitly; the default
    # cloud-platform scope gets empty responses from the Play API.
    local rc=0
    run_bounded "$PLAY_TOKEN_TIMEOUT" gcloud auth print-access-token --scopes=https://www.googleapis.com/auth/androidpublisher || rc=$?
    if [ "$rc" -eq 124 ]; then
      echo "::error::gcloud did not return an access token within ${PLAY_TOKEN_TIMEOUT}s" >&2
    fi
    return "$rc"
  fi
}

# api METHOD URL [curl args...]  -> sets API_STATUS, body in $RESPONSE_FILE.
api() {
  local method="$1" url="$2" max_time="$PLAY_API_TIMEOUT"
  shift 2
  if [ "${1:-}" = "--upload" ]; then
    max_time="$PLAY_UPLOAD_TIMEOUT"
    shift
  fi
  # Every call is bounded, or a stalled connection would hold the job until its own timeout. A failure,
  # including a timeout (curl exit 28), leaves API_STATUS at 000 and surfaces as a failed call.
  API_STATUS="$(curl -sS --connect-timeout "$PLAY_CONNECT_TIMEOUT" --max-time "$max_time" \
    -X "$method" -o "$RESPONSE_FILE" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" "$@" "$url")" || API_STATUS=000
}

api_ok() {
  [[ "$API_STATUS" =~ ^2 ]]
}

fail() {
  echo "::error::$1 (HTTP $API_STATUS)" >&2
  cat "$RESPONSE_FILE" >&2 || true
  echo >&2
  exit 1
}

is_version_conflict() {
  [ "$API_STATUS" = "409" ] && return 0
  grep -qiE 'version ?code[^"]*(has )?already been used|versionCodeAlreadyUsed|apkUpgradeVersionConflict|UpgradeVersionConflict|Concurrent uploads for app|editDeleted' "$RESPONSE_FILE"
}

open_edit() {
  api POST "$API/edits" -H 'Content-Type: application/json' -d '{}'
  api_ok || fail "Could not open a Play edit for $PACKAGE_NAME"
  EDIT_ID="$(jq -r '.id' "$RESPONSE_FILE")"
}

discard_edit() {
  api DELETE "$API/edits/$EDIT_ID" || true
}

next_version_code() {
  TOKEN="$(access_token)"
  open_edit
  # /edits/{id}/bundles and /apks list every artifact ever uploaded to the
  # app, not just this edit's, so their max is the floor for the next upload.
  api GET "$API/edits/$EDIT_ID/bundles"
  api_ok || fail "Could not list bundles"
  local bundles apks
  bundles="$(jq '[.bundles[]?.versionCode // 0] | max // 0' "$RESPONSE_FILE")"
  api GET "$API/edits/$EDIT_ID/apks"
  api_ok || fail "Could not list APKs"
  apks="$(jq '[.apks[]?.versionCode // 0] | max // 0' "$RESPONSE_FILE")"
  discard_edit
  local highest=$(( bundles > apks ? bundles : apks ))
  echo "Highest versionCode on Play: $highest" >&2
  echo $(( highest + 1 ))
}

# upload VERSION_CODE -> 0 on success, $CONFLICT on versionCode conflict.
upload() {
  local version_code="$1"
  TOKEN="$(access_token)"
  open_edit

  echo "Uploading $AAB_PATH (versionCode $version_code)…" >&2
  api POST "$UPLOAD_API/edits/$EDIT_ID/bundles?uploadType=media" --upload \
    -H 'Content-Type: application/octet-stream' --data-binary "@$AAB_PATH"
  if ! api_ok; then
    if is_version_conflict; then
      cat "$RESPONSE_FILE" >&2
      echo >&2
      discard_edit
      return $CONFLICT
    fi
    fail "Bundle upload failed"
  fi
  local uploaded
  uploaded="$(jq -r '.versionCode' "$RESPONSE_FILE")"
  if [ "$uploaded" != "$version_code" ]; then
    discard_edit
    API_STATUS=200
    fail "Play reports versionCode $uploaded, expected $version_code"
  fi

  local notes=""
  if [ -n "${NOTES_CMD:-}" ]; then
    # upload runs on the left of ||, which turns set -e off for its whole body, so a failing notes
    # command must be checked here. Nothing is published yet at this point, so stopping is cheap; a
    # release that went out with an empty "What's new" would not be.
    local notes_rc=0
    notes="$(BUILD_NUMBER="$version_code" bash -c "$NOTES_CMD")" || notes_rc=$?
    if [ "$notes_rc" -ne 0 ] || [ -z "$notes" ]; then
      discard_edit
      echo "::error::The release notes command failed (exit $notes_rc) or printed nothing; not releasing without notes" >&2
      return 1
    fi
  elif [ -n "${NOTES_FILE:-}" ] && [ -s "$NOTES_FILE" ]; then
    notes="$(cat "$NOTES_FILE")"
  fi
  local name=""
  if [ -n "${RELEASE_NAME_PREFIX:-}" ]; then
    name="$RELEASE_NAME_PREFIX ($version_code)${RELEASE_NAME_SUFFIX:+ $RELEASE_NAME_SUFFIX}"
  fi
  local release
  release="$(jq -n \
    --arg track "$PLAY_TRACK" \
    --arg code "$version_code" \
    --arg status "$PLAY_RELEASE_STATUS" \
    --arg notes "$notes" \
    --arg name "$name" \
    '{track: $track, releases: [{versionCodes: [$code], status: $status}
      + (if $notes == "" then {} else {releaseNotes: [{language: "en-US", text: $notes}]} end)
      + (if $name == "" then {} else {name: $name} end)]}')"
  api PUT "$API/edits/$EDIT_ID/tracks/$PLAY_TRACK" \
    -H 'Content-Type: application/json' -d "$release"
  api_ok || fail "Could not assign versionCode $version_code to the $PLAY_TRACK track"

  api POST "$API/edits/$EDIT_ID:commit"
  if ! api_ok; then
    # A competing upload can claim the versionCode between our upload and commit.
    if is_version_conflict; then
      cat "$RESPONSE_FILE" >&2
      echo >&2
      return $CONFLICT
    fi
    fail "Committing the Play edit failed"
  fi
  echo "Released versionCode $version_code to the $PLAY_TRACK track" >&2
}

deploy() {
  [ "${1:-}" = "--" ] && shift
  [ "$#" -gt 0 ] || { echo "deploy needs a build command after --" >&2; exit 2; }
  : "${AAB_PATH:?AAB_PATH is required}"

  local version_code attempt rc
  version_code="$(next_version_code)"
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo "=== Attempt $attempt/$MAX_ATTEMPTS: versionCode $version_code ===" >&2
    if [ -n "${GITHUB_ENV:-}" ]; then
      # The failure notification reads VERSION_CODE too; keep it at the last
      # attempted code so it never implies an unshipped number shipped.
      echo "VERSION_CODE=$version_code" >> "$GITHUB_ENV"
    fi
    VERSION_CODE="$version_code" "$@"
    rc=0
    upload "$version_code" || rc=$?
    if [ "$rc" -eq 0 ]; then
      echo "$version_code"
      return 0
    fi
    [ "$rc" -eq "$CONFLICT" ] || exit "$rc"

    local resolved
    resolved="$(next_version_code)"
    echo "versionCode $version_code was rejected as already used; Play now reports next=$resolved" >&2
    version_code=$(( resolved > version_code + 1 ? resolved : version_code + 1 ))
  done
  echo "::error::Play upload still conflicted after $MAX_ATTEMPTS attempts" >&2
  exit 1
}

# share: upload AAB_PATH to Internal App Sharing. The download URL is masked
# before anything else, never printed, and written to $GITHUB_OUTPUT as url=.
share() {
  : "${AAB_PATH:?AAB_PATH is required}"
  TOKEN="$(access_token)"
  api POST "$PLAY_API_ROOT/upload/androidpublisher/v3/applications/internalappsharing/$PACKAGE_NAME/artifacts/bundle?uploadType=media" --upload \
    -H 'Content-Type: application/octet-stream' --data-binary "@$AAB_PATH"
  api_ok || fail "Internal App Sharing upload failed"
  local url
  url="$(jq -r '.downloadUrl // empty' "$RESPONSE_FILE")"
  if [ -z "$url" ]; then
    echo "::warning::Internal App Sharing did not return a download URL" >&2
    exit 1
  fi
  echo "::add-mask::$url"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "url=$url" >> "$GITHUB_OUTPUT"
  fi
  echo "Uploaded to Internal App Sharing" >&2
}

case "${1:-}" in
  next-version-code) next_version_code ;;
  deploy) shift; deploy "$@" ;;
  share) share ;;
  *) echo "usage: $0 next-version-code | deploy -- <build command...> | share" >&2; exit 2 ;;
esac
