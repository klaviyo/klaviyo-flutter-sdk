#!/usr/bin/env bash
#
# Runs a flutter build command, retrying only when Android dependency
# resolution fails. android/build.gradle resolves com.github.klaviyo.*
# artifacts from JitPack, which builds branch/commit/SNAPSHOT targets on first
# request — the first fetch can time out or 404, and Gradle caches the 404, so
# each retry first refreshes the dependency cache with a resolution-only
# ./gradlew run in example/android.
#
# Usage: gradle-retry.sh <build command...>
#
# Env:
#   MAX_ATTEMPTS        (default: 3)
#   RETRY_DELAY_SECONDS (default: 60; set 0 in tests)
#   EXAMPLE_ANDROID_DIR (default: example/android relative to the repo root)
#   GRADLEW             (default: ./gradlew; used by tests)
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXAMPLE_ANDROID_DIR="${EXAMPLE_ANDROID_DIR:-$SCRIPT_DIR/../../example/android}"
GRADLEW="${GRADLEW:-./gradlew}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-60}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

is_resolution_error() {
  grep -q -E 'Could not resolve|Could not get resource|Could not GET|Could not find|Read timed out' "$LOG"
}

refresh_dependencies() {
  # The flutter build that just failed generates gradlew on its way up, so it
  # exists by the time a retry needs it.
  if [ ! -x "$EXAMPLE_ANDROID_DIR/${GRADLEW#./}" ]; then
    echo "::warning::No gradlew in $EXAMPLE_ANDROID_DIR; skipping dependency refresh"
    return 0
  fi
  (cd "$EXAMPLE_ANDROID_DIR" && "$GRADLEW" --refresh-dependencies :app:dependencies \
    --configuration releaseRuntimeClasspath)
}

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "=== Build attempt $attempt of $MAX_ATTEMPTS ==="
  if "$@" 2>&1 | tee "$LOG"; then
    exit 0
  fi
  if ! is_resolution_error; then
    echo "Build failed with a non-dependency error"
    exit 1
  fi
  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    break
  fi
  echo "Dependency resolution failed; refreshing Gradle's dependency cache before retrying"
  refresh_dependencies || true
  sleep "$RETRY_DELAY_SECONDS"
done

echo "Build failed after $MAX_ATTEMPTS attempts"
exit 1
