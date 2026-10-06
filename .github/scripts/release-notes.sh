#!/usr/bin/env bash
#
# Prints store release notes ("What's new" on Play, "What to Test" on TestFlight)
# for an example app build. Every build gets the SDK version, commit and build
# date from git metadata; a human-authored body (e.g. a GitHub release body) is
# appended when present, otherwise the commit subject is used.
#
# Usage: release-notes.sh <max-chars> [body-file]
#
# Env (all optional, defaults come from git / pubspec.yaml):
#   SDK_VERSION   SDK version string (default: version from pubspec.yaml)
#   GIT_SHA       commit to describe (default: HEAD)
#   GIT_REF_NAME  branch or tag name shown next to the commit
#   BUILD_DATE    override for the build date (default: now, UTC)
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

COMMIT_LINE="Commit: $SHORT_SHA"
if [ -n "${GIT_REF_NAME:-}" ]; then
  COMMIT_LINE="$COMMIT_LINE ($GIT_REF_NAME)"
fi

BODY=""
if [ -n "$BODY_FILE" ] && [ -s "$BODY_FILE" ]; then
  BODY="$(cat "$BODY_FILE")"
fi
# Strip whitespace-only bodies so they fall back to the commit subject.
if [ -z "${BODY//[[:space:]]/}" ]; then
  # A shallow checkout may not have the commit object for an arbitrary SHA;
  # fall back to an empty subject rather than failing the deploy.
  BODY="$(git log -1 --format=%s "$GIT_SHA" 2>/dev/null || true)"
fi

NOTES="Klaviyo Flutter SDK $SDK_VERSION
$COMMIT_LINE
Built: $BUILD_DATE"
if [ -n "$BODY" ]; then
  NOTES="$NOTES

$BODY"
fi

# Truncate by character, not byte, so multi-byte text near the limit stays
# valid UTF-8. Requires a UTF-8 locale (the default on GitHub runners).
if [ "${#NOTES}" -gt "$MAX_CHARS" ]; then
  NOTES="${NOTES:0:$((MAX_CHARS - 1))}…"
fi

printf '%s\n' "$NOTES"
