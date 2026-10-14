#!/usr/bin/env bash
#
# Prints store release notes ("What's new" on Play, "What to Test" on TestFlight)
# for an example app build. Every build gets the SDK version, native SDK refs,
# source ref, commit and build date; a human-authored body (e.g. a GitHub
# release body) is appended when present, otherwise the commit subject is used.
#
# Usage: release-notes.sh <max-chars> [body-file]
#
# Env (all optional, defaults come from git / pubspec.yaml):
#   SDK_VERSION   SDK version string (default: version from pubspec.yaml)
#   GIT_SHA       commit to describe (default: HEAD)
#   GIT_REF_NAME  branch or tag name shown next to the commit
#   EVENT_NAME    github.event_name, shown next to the ref when set
#   RELEASE_NAME  GitHub release name, shown above the body on releases
#   RUN_URL       workflow run URL; appended when it fits (TestFlight's 4000
#                 chars leave room; Play's 500 usually don't)
#   BUILD_DATE    override for the build date (default: now, UTC)
#   BUILD_INFO    path to a build-info.json from scripts/sdk-ref.sh; when
#                 present, its three SDK refs are listed
#
set -euo pipefail

MAX_CHARS="${1:?usage: release-notes.sh <max-chars> [body-file]}"
BODY_FILE="${2:-}"

REPO_ROOT="$(git rev-parse --show-toplevel)"

if [ -z "${SDK_VERSION:-}" ]; then
  SDK_VERSION="$(grep '^version:' "$REPO_ROOT/pubspec.yaml" | awk '{print $2}')"
fi
GIT_SHA="${GIT_SHA:-$(git rev-parse HEAD)}"
SHORT_SHA="${GIT_SHA:0:7}"
BUILD_DATE="${BUILD_DATE:-$(date -u '+%Y-%m-%d %H:%M UTC')}"

REF_LINE="Ref: ${GIT_REF_NAME:-unknown}"
if [ -n "${EVENT_NAME:-}" ]; then
  REF_LINE="$REF_LINE ($EVENT_NAME)"
fi

SDK_REFS=""
if [ -n "${BUILD_INFO:-}" ] && [ -f "$BUILD_INFO" ]; then
  SDK_REFS="$(python3 -I - "$BUILD_INFO" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as fh:
        info = json.load(fh)
except (OSError, ValueError):
    sys.exit(0)
for key, label in (("flutterSdkRef", "Flutter"), ("iosSdkRef", "iOS"), ("androidSdkRef", "Android")):
    ref = info.get(key)
    if ref:
        print(f"{label} SDK: {ref}")
PY
)"
fi

BODY=""
if [ -n "$BODY_FILE" ] && [ -s "$BODY_FILE" ]; then
  BODY="$(cat "$BODY_FILE")"
fi
if [ -z "${BODY//[[:space:]]/}" ]; then
  BODY="$(git log -1 --format=%s "$GIT_SHA" 2>/dev/null || true)"
fi
if [ -n "${RELEASE_NAME:-}" ]; then
  BODY="$RELEASE_NAME
$BODY"
fi

NOTES="Klaviyo Flutter SDK $SDK_VERSION
$REF_LINE
Commit: $SHORT_SHA
Built: $BUILD_DATE"
if [ -n "$SDK_REFS" ]; then
  NOTES="$NOTES
$SDK_REFS"
fi
if [ -n "$BODY" ]; then
  NOTES="$NOTES

$BODY"
fi
if [ -n "${RUN_URL:-}" ]; then
  NOTES="$NOTES

CI run: $RUN_URL"
fi

# Truncate by character, not byte, so multi-byte text near the limit stays
# valid UTF-8. Requires a UTF-8 locale (the default on GitHub runners).
MARKER="[truncated]"
if [ "${#NOTES}" -gt "$MAX_CHARS" ]; then
  NOTES="${NOTES:0:$((MAX_CHARS - ${#MARKER} - 1))}
$MARKER"
fi

printf '%s\n' "$NOTES"
