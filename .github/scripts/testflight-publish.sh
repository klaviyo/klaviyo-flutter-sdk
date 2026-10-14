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
#                                         latest+1; also consulted between the
#                                         build and the upload so a competing
#                                         run never reaches altool
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

# Fail in seconds, before the first archive, if a tool the post-build steps need is missing from the
# runner image. SKIP_IPA_CHECK drops the IPA inspection (and so unzip and plutil) for tests.
needed=""
[ -n "${SKIP_IPA_CHECK:-}" ] || needed="$needed unzip plutil"
[ -n "${ALTOOL:-}" ] || needed="$needed xcrun"
missing=""
for tool in $needed; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing${missing:+, }$tool"
done
if [ -n "$missing" ]; then
  echo "::error::testflight-publish.sh needs these tools on PATH before it builds: $missing" >&2
  exit 1
fi

altool() {
  if [ -n "${ALTOOL:-}" ]; then
    "$ALTOOL" "$@"
  else
    xcrun altool "$@"
  fi
}

# Prints a fresh latest+1 from App Store Connect, or nothing on failure.
recheck_build_number() {
  [ -n "${NEXT_BUILD_NUMBER_CMD:-}" ] || return 0
  bash -c "$NEXT_BUILD_NUMBER_CMD" 2>/dev/null || true
}

BUILD_NUMBER="$INITIAL"
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "=== Attempt $attempt/$MAX_ATTEMPTS: build number $BUILD_NUMBER ==="
  if [ -n "${GITHUB_ENV:-}" ]; then
    # The failure notification reads BUILD_NUMBER too; keep it at the last
    # attempted number so it never implies an unshipped build shipped.
    echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"
  fi
  rm -f "$IPA_PATH"
  BUILD_NUMBER="$BUILD_NUMBER" "$@"
  [ -f "$IPA_PATH" ] || { echo "::error::Build did not produce $IPA_PATH" >&2; exit 1; }

  # A stale bundle would be rejected as a duplicate below and burn an
  # attempt; catch it while the message is still clear.
  if [ -z "${SKIP_IPA_CHECK:-}" ]; then
    ACTUAL="$(unzip -p "$IPA_PATH" 'Payload/*.app/Info.plist' 2>/dev/null \
      | plutil -extract CFBundleVersion raw -o - - 2>/dev/null || true)"
    if [ -z "$ACTUAL" ]; then
      echo "::error::Could not read CFBundleVersion from $IPA_PATH" >&2
      exit 1
    fi
    if [ "$ACTUAL" != "$BUILD_NUMBER" ]; then
      echo "::error::IPA carries CFBundleVersion $ACTUAL, expected $BUILD_NUMBER — the build did not pick up the retried number" >&2
      exit 1
    fi
  fi

  # A competing run can take the number while we build; catch it before
  # burning an upload.
  FRESH="$(recheck_build_number)"
  if [ -n "$FRESH" ] && [ "$FRESH" -gt "$BUILD_NUMBER" ] && [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    echo "Build $BUILD_NUMBER was taken since preflight; rebuilding with $FRESH"
    BUILD_NUMBER="$FRESH"
    continue
  fi
  if [ -n "${NEXT_BUILD_NUMBER_CMD:-}" ] && [ -z "$FRESH" ]; then
    echo "::warning::Pre-upload build number recheck failed; relying on upload conflict detection"
  fi

  UPLOAD_OUTPUT="$(altool --upload-app --type ios --file "$IPA_PATH" \
    --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_API_KEY_ISSUER_ID" 2>&1)" && UPLOAD_RC=0 || UPLOAD_RC=$?
  echo "$UPLOAD_OUTPUT"

  if [ "$UPLOAD_RC" -eq 0 ] && ! grep -q "ERROR:" <<<"$UPLOAD_OUTPUT"; then
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
