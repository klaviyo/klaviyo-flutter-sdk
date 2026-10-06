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
#   NOTES_FILE          (deploy, optional) en-US release notes, <= 500 chars
#   PLAY_TRACK          (default: internal)
#   PLAY_RELEASE_STATUS (default: completed; must be "draft" until the app's
#                        first release has been rolled out from the console)
#   MAX_ATTEMPTS        (default: 3)
#   PLAY_ACCESS_TOKEN   (optional) OAuth token; otherwise minted with gcloud
#                       from the active service-account credentials
#   PLAY_API_ROOT       (optional) API origin override, used by tests
#
set -euo pipefail

: "${PACKAGE_NAME:?PACKAGE_NAME is required}"
PLAY_TRACK="${PLAY_TRACK:-internal}"
PLAY_RELEASE_STATUS="${PLAY_RELEASE_STATUS:-completed}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
PLAY_API_ROOT="${PLAY_API_ROOT:-https://androidpublisher.googleapis.com}"
API="$PLAY_API_ROOT/androidpublisher/v3/applications/$PACKAGE_NAME"
UPLOAD_API="$PLAY_API_ROOT/upload/androidpublisher/v3/applications/$PACKAGE_NAME"

# Exit code used internally to signal "versionCode already used".
CONFLICT=3

RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

access_token() {
  if [ -n "${PLAY_ACCESS_TOKEN:-}" ]; then
    printf '%s' "$PLAY_ACCESS_TOKEN"
  else
    # The androidpublisher scope must be requested explicitly; the default
    # cloud-platform scope gets empty responses from the Play API.
    gcloud auth print-access-token --scopes=https://www.googleapis.com/auth/androidpublisher
  fi
}

# api METHOD URL [curl args...]  -> sets API_STATUS, body in $RESPONSE_FILE.
# Never uses -v / set -x so the bearer token is not written to the log.
api() {
  local method="$1" url="$2"
  shift 2
  API_STATUS="$(curl -sS -X "$method" -o "$RESPONSE_FILE" -w '%{http_code}' \
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
  grep -qiE 'version ?code[^"]*(has )?already been used|versionCodeAlreadyUsed|UpgradeVersionConflict' "$RESPONSE_FILE"
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
  api POST "$UPLOAD_API/edits/$EDIT_ID/bundles?uploadType=media" \
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
  if [ -n "${NOTES_FILE:-}" ] && [ -s "$NOTES_FILE" ]; then
    notes="$(cat "$NOTES_FILE")"
  fi
  local release
  release="$(jq -n \
    --arg track "$PLAY_TRACK" \
    --arg code "$version_code" \
    --arg status "$PLAY_RELEASE_STATUS" \
    --arg notes "$notes" \
    '{track: $track, releases: [{versionCodes: [$code], status: $status}
      + (if $notes == "" then {} else {releaseNotes: [{language: "en-US", text: $notes}]} end)]}')"
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
    VERSION_CODE="$version_code" "$@"
    rc=0
    upload "$version_code" || rc=$?
    if [ "$rc" -eq 0 ]; then
      if [ -n "${GITHUB_ENV:-}" ]; then
        echo "VERSION_CODE=$version_code" >> "$GITHUB_ENV"
      fi
      echo "$version_code"
      return 0
    fi
    [ "$rc" -eq "$CONFLICT" ] || exit "$rc"

    # Play rejected the code itself; re-read the floor rather than trusting
    # the earlier preflight, and never go backwards.
    local resolved
    resolved="$(next_version_code)"
    echo "versionCode $version_code was rejected as already used; Play now reports next=$resolved" >&2
    version_code=$(( resolved > version_code + 1 ? resolved : version_code + 1 ))
  done
  echo "::error::Play upload still conflicted after $MAX_ATTEMPTS attempts" >&2
  exit 1
}

case "${1:-}" in
  next-version-code) next_version_code ;;
  deploy) shift; deploy "$@" ;;
  *) echo "usage: $0 next-version-code | deploy -- <build command...>" >&2; exit 2 ;;
esac
