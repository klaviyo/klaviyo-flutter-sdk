#!/usr/bin/env bash
#
# Offline tests for gradle-retry.sh. A fake `flutter` fails or succeeds based
# on files under $FAKE_BUILD, and a fake gradlew records that
# --refresh-dependencies ran.
#
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

mkdir -p "$WORK/bin" "$WORK/android"

cat > "$WORK/bin/flutter" <<'FAKE'
#!/usr/bin/env bash
# Behaviour driven by $FAKE_BUILD/failures (count) and $FAKE_BUILD/mode.
n="$(cat "$FAKE_BUILD/failures" 2>/dev/null || echo 0)"
echo build >> "$FAKE_BUILD/builds"
if [ "$n" -gt 0 ]; then
  echo $((n - 1)) > "$FAKE_BUILD/failures"
  case "$(cat "$FAKE_BUILD/mode")" in
    resolve)
      echo "FAILURE: Build failed with an exception."
      echo "* What went wrong:"
      echo "Execution failed for task ':app:mergeReleaseNativeLibs'."
      echo "> Could not resolve all files for configuration ':app:releaseRuntimeClasspath'."
      echo "   > Could not GET 'https://jitpack.io/com/github/klaviyo/klaviyo-android-sdk/core/feat~widgets-SNAPSHOT/maven-metadata.xml'. Received status code 404 from server: Not Found"
      ;;
    timeout)
      echo "> Could not GET 'https://jitpack.io/com/github/klaviyo/klaviyo-android-sdk/core/4.5.1/core-4.5.1.pom'."
      echo "   > Read timed out"
      ;;
    *)
      echo "e: file:///src/main.kt:1:1 Unresolved reference: nonsense"
      ;;
  esac
  exit 1
fi
echo "BUILD SUCCESSFUL"
FAKE
chmod +x "$WORK/bin/flutter"

cat > "$WORK/android/gradlew" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_BUILD/gradlew-calls"
FAKE
chmod +x "$WORK/android/gradlew"

run_retry() {
  FAKE_BUILD="$WORK/build" PATH="$WORK/bin:$PATH" \
    EXAMPLE_ANDROID_DIR="$WORK/android" RETRY_DELAY_SECONDS=0 \
    "$SCRIPTS/gradle-retry.sh" flutter build appbundle --release
}

reset_build() {
  rm -rf "$WORK/build"; mkdir -p "$WORK/build"
  echo "$1" > "$WORK/build/failures"
  echo "${2:-resolve}" > "$WORK/build/mode"
}

# Clean build: no gradlew refresh.
reset_build 0
run_retry >/dev/null 2>&1 && rc=0 || rc=$?
check "gradle-retry: clean build exits 0" 0 "$rc"
check "gradle-retry: clean build never refreshes" "" "$(cat "$WORK/build/gradlew-calls" 2>/dev/null)"

# JitPack 404 then success: refresh ran with --refresh-dependencies.
reset_build 1 resolve
run_retry >/dev/null 2>&1 && rc=0 || rc=$?
check "gradle-retry: resolution error then success exits 0" 0 "$rc"
check "gradle-retry: built twice" 2 "$(wc -l < "$WORK/build/builds" | tr -d ' ')"
check "gradle-retry: refresh passes --refresh-dependencies" \
  "--refresh-dependencies :app:dependencies --configuration releaseRuntimeClasspath" \
  "$(cat "$WORK/build/gradlew-calls")"

# Read timed out is also retryable.
reset_build 1 timeout
run_retry >/dev/null 2>&1 && rc=0 || rc=$?
check "gradle-retry: read timeout retries" 0 "$rc"

# Kotlin compile error: fails fast, no retry.
reset_build 1 compile
if run_retry >/dev/null 2>&1; then fail "gradle-retry: non-dependency error fails fast"; else pass "gradle-retry: non-dependency error fails fast"; fi
check "gradle-retry: no retry on compile error" 1 "$(wc -l < "$WORK/build/builds" | tr -d ' ')"
check "gradle-retry: no refresh on compile error" "" "$(cat "$WORK/build/gradlew-calls" 2>/dev/null)"

# Persistent resolution failure: gives up after MAX_ATTEMPTS.
reset_build 9 resolve
if run_retry >/dev/null 2>&1; then fail "gradle-retry: gives up after max attempts"; else pass "gradle-retry: gives up after max attempts"; fi
check "gradle-retry: three builds attempted" 3 "$(wc -l < "$WORK/build/builds" | tr -d ' ')"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All gradle-retry tests passed"
