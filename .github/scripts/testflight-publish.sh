#!/usr/bin/env bash
#
# Builds and uploads an IPA to TestFlight, retrying with a higher build number
# when App Store Connect rejects the upload because the build number is already
# taken. Ported from klaviyo-ios-test-app's testflight.yml retry loop, with the
# App Store Connect API key used for altool instead of an Apple ID password.
#
# Usage: testflight-publish.sh <initial-build-number> -- <build command...>
#
# The build command runs with BUILD_NUMBER exported and must leave the IPA at
# IPA_PATH. On success writes BUILD_NUMBER=<n> to $GITHUB_ENV when set.
#
# Env:
#   IPA_PATH                              (required)
#   APP_STORE_CONNECT_API_KEY_ID          (required)
#   APP_STORE_CONNECT_API_KEY_ISSUER_ID   (required)
#   MAX_ATTEMPTS                          (default: 3)
#   NEXT_BUILD_NUMBER_CMD                 (optional) command printing a fresh
#                                         latest+1 when altool's error doesn't
#                                         say which build number it already has
#   ALTOOL                                (optional) override, used by tests
#
set -euo pipefail

INITIAL="${1:?usage: testflight-publish.sh <initial-build-number> -- <build command...>}"
shift
[ "${1:-}" = "--" ] && shift
[ "$#" -gt 0 ] || { echo "a build command is required after --" >&2; exit 2; }
: "${IPA_PATH:?IPA_PATH is required}"
: "${APP_STORE_CONNECT_API_KEY_ID:?APP_STORE_CONNECT_API_KEY_ID is required}"
: "${APP_STORE_CONNECT_API_KEY_ISSUER_ID:?APP_STORE_CONNECT_API_KEY_ISSUER_ID is required}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"

altool() {
  if [ -n "${ALTOOL:-}" ]; then
    "$ALTOOL" "$@"
  else
    xcrun altool "$@"
  fi
}

BUILD_NUMBER="$INITIAL"
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "=== Attempt $attempt/$MAX_ATTEMPTS: build number $BUILD_NUMBER ==="
  rm -f "$IPA_PATH"
  BUILD_NUMBER="$BUILD_NUMBER" "$@"
  [ -f "$IPA_PATH" ] || { echo "::error::Build did not produce $IPA_PATH" >&2; exit 1; }

  UPLOAD_OUTPUT="$(altool --upload-app --type ios --file "$IPA_PATH" \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" 2>&1)" && UPLOAD_RC=0 || UPLOAD_RC=$?
  echo "$UPLOAD_OUTPUT"

  if [ "$UPLOAD_RC" -eq 0 ] && ! grep -q "ERROR:" <<<"$UPLOAD_OUTPUT"; then
    if [ -n "${GITHUB_ENV:-}" ]; then
      echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"
    fi
    echo "Uploaded build $BUILD_NUMBER to TestFlight"
    exit 0
  fi

  # altool reports the conflicting number as `previousBundleVersion = N`.
  PREV_BUILD="$(grep -oE 'previousBundleVersion = [0-9]+' <<<"$UPLOAD_OUTPUT" | head -1 | grep -oE '[0-9]+' || true)"
  if [ -n "$PREV_BUILD" ]; then
    NEXT=$((PREV_BUILD + 1))
  elif grep -qiE 'Redundant Binary Upload|bundle version must be higher|already been used' <<<"$UPLOAD_OUTPUT"; then
    if [ -z "${NEXT_BUILD_NUMBER_CMD:-}" ]; then
      echo "::error::Build number conflict, but no way to resolve the next number" >&2
      exit 1
    fi
    NEXT="$(bash -c "$NEXT_BUILD_NUMBER_CMD")"
  else
    echo "::error::TestFlight upload failed with a non-recoverable error" >&2
    exit 1
  fi

  if [ "$NEXT" -le "$BUILD_NUMBER" ]; then
    NEXT=$((BUILD_NUMBER + 1))
  fi
  echo "Build $BUILD_NUMBER was rejected as a duplicate; retrying with $NEXT"
  BUILD_NUMBER="$NEXT"
done

echo "::error::TestFlight upload failed after $MAX_ATTEMPTS attempts" >&2
exit 1
