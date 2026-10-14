#!/usr/bin/env bash
#
# Offline tests for scripts/sdk-ref.sh. Uses fixture Podfile.lock / Podfile /
# build.gradle files and a stubbed ls-remote so no network or store access is
# needed.
#
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/../../.." && pwd)/scripts"
SCRIPT="$SCRIPTS/sdk-ref.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$name"; else fail "$name (expected '$expected', got '$actual')"; fi
}

# ---------------------------------------------------------------- fixtures

mkdir -p "$WORK/repo"

cat > "$WORK/repo/pubspec.yaml" <<'EOF'
name: klaviyo_flutter_sdk
version: 1.2.3
EOF

cat > "$WORK/repo/example-pubspec.yaml" <<'EOF'
name: klaviyo_flutter_sdk_example
version: 1.2.3
EOF

cat > "$WORK/repo/podspec" <<'EOF'
  s.dependency 'KlaviyoSwift', '~> 5.4.1'
EOF

cat > "$WORK/repo/build-gradle-release" <<'EOF'
def klaviyoSdkVersion = "4.5.1"
EOF

cat > "$WORK/repo/build-gradle-commit" <<'EOF'
def klaviyoSdkVersion = "0123456789abcdef0123456789abcdef01234567"
EOF

cat > "$WORK/repo/build-gradle-snapshot" <<'EOF'
def klaviyoSdkVersion = "feat~widgets-SNAPSHOT"
EOF

cat > "$WORK/repo/settings-plain.gradle" <<'EOF'
include ":app"
EOF

cat > "$WORK/repo/settings-local.gradle" <<EOF
include ":app"
// [KLAVIYO-SDK-OVERRIDE-START]
includeBuild('$WORK/local-android-sdk') {
    dependencySubstitution {
        substitute module('com.github.klaviyo.klaviyo-android-sdk:core') using project(':sdk:core')
    }
}
// [KLAVIYO-SDK-OVERRIDE-END]
EOF

# Podfile.lock fixtures
cat > "$WORK/repo/podlock-release" <<'EOF'
PODS:
  - KlaviyoSwift (5.4.1):
    - KlaviyoCore (= 5.4.1)
  - klaviyo_flutter_sdk (0.0.1):
    - KlaviyoSwift (~> 5.4.1)

DEPENDENCIES:
  - klaviyo_flutter_sdk (from `.symlinks/plugins/klaviyo_flutter_sdk/ios`)

EXTERNAL SOURCES:
  klaviyo_flutter_sdk:
    :path: ".symlinks/plugins/klaviyo_flutter_sdk/ios"

SPEC CHECKSUMS:
  KlaviyoSwift: abc
EOF

cat > "$WORK/repo/podlock-branch" <<'EOF'
PODS:
  - KlaviyoSwift (5.5.0):
    - KlaviyoCore (= 5.5.0)

DEPENDENCIES:
  - KlaviyoSwift (from `https://github.com/klaviyo/klaviyo-swift-sdk.git`, branch `feat/widgets`)

EXTERNAL SOURCES:
  KlaviyoSwift:
    :branch: feat/widgets
    :git: https://github.com/klaviyo/klaviyo-swift-sdk.git

CHECKOUT OPTIONS:
  KlaviyoSwift:
    :commit: 0bb71d7aaaabbbccdd00112233445566778899aa
    :git: https://github.com/klaviyo/klaviyo-swift-sdk.git

SPEC CHECKSUMS:
  KlaviyoSwift: abc
EOF

cat > "$WORK/repo/podlock-commit" <<'EOF'
PODS:
  - KlaviyoSwift (5.5.0)

EXTERNAL SOURCES:
  KlaviyoSwift:
    :commit: deadbeefcafe00112233445566778899001122
    :git: https://github.com/klaviyo/klaviyo-swift-sdk.git

CHECKOUT OPTIONS:
  KlaviyoSwift:
    :commit: deadbeefcafe00112233445566778899001122
    :git: https://github.com/klaviyo/klaviyo-swift-sdk.git
EOF

cat > "$WORK/repo/podlock-local" <<EOF
PODS:
  - KlaviyoSwift (5.4.1)

EXTERNAL SOURCES:
  KlaviyoSwift:
    :path: "$WORK/local-swift-sdk"

SPEC CHECKSUMS:
  KlaviyoSwift: abc
EOF

cat > "$WORK/repo/podfile-branch-override" <<'EOF'
target 'Runner' do
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  # [KLAVIYO-SDK-OVERRIDE-START]
  pod 'KlaviyoSwift', :git => 'https://github.com/klaviyo/klaviyo-swift-sdk.git', :branch => 'feat/widgets'
  # [KLAVIYO-SDK-OVERRIDE-END]
end
EOF

# Local SDK checkouts (real git repos so branch/sha/-dirty are exercised)
git init -q -b feat/widgets "$WORK/local-swift-sdk"
echo x > "$WORK/local-swift-sdk/f"
git -C "$WORK/local-swift-sdk" add f
git -C "$WORK/local-swift-sdk" -c user.email=t@t -c user.name=t commit -qm init
SWIFT_LOCAL_SHA="$(git -C "$WORK/local-swift-sdk" rev-parse --short=7 HEAD)"

git init -q -b main "$WORK/local-android-sdk"
echo x > "$WORK/local-android-sdk/f"
git -C "$WORK/local-android-sdk" add f
git -C "$WORK/local-android-sdk" -c user.email=t@t -c user.name=t commit -qm init
ANDROID_LOCAL_SHA="$(git -C "$WORK/local-android-sdk" rev-parse --short=7 HEAD)"
echo dirty > "$WORK/local-android-sdk/dirty"

# Stub ls-remote: serves heads from $FAKE_HEADS, fails when the file is absent.
cat > "$WORK/ls-remote" <<'FAKE'
#!/usr/bin/env bash
[ -f "$FAKE_HEADS" ] || exit 128
cat "$FAKE_HEADS"
FAKE
chmod +x "$WORK/ls-remote"

# ---------------------------------------------------------------- runner

run_ref() {
  local out="$WORK/out.json"
  rm -f "$out"
  # Re-set GITHUB_* explicitly from the caller's overrides so the runner's
  # own ambient values (real checkout on CI) never reach the script.
  REPO_ROOT="$WORK/repo" \
    PUBSPEC="$WORK/repo/pubspec.yaml" \
    EXAMPLE_PUBSPEC="$WORK/repo/example-pubspec.yaml" \
    PODFILE_LOCK="${PODFILE_LOCK:-$WORK/repo/no-lock}" \
    PODFILE="${PODFILE:-$WORK/repo/no-podfile}" \
    PODSPEC="$WORK/repo/podspec" \
    ANDROID_BUILD_GRADLE="${ANDROID_BUILD_GRADLE:-$WORK/repo/build-gradle-release}" \
    ANDROID_SETTINGS_GRADLE="${ANDROID_SETTINGS_GRADLE:-$WORK/repo/settings-plain.gradle}" \
    ANDROID_LS_REMOTE_CMD="$WORK/ls-remote" \
    GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    GITHUB_REF_NAME=feat/thing \
    GITHUB_REF_TYPE="${T_REF_TYPE:-}" \
    GITHUB_HEAD_REF="${T_HEAD_REF:-}" \
    GITHUB_EVENT_NAME="${T_EVENT_NAME:-}" \
    GITHUB_EVENT_PATH="${T_EVENT_PATH:-}" \
    BUILD_DATE='2026-10-13 12:00 UTC' \
    bash "$SCRIPT" "$out" >/dev/null
  python3 -I -c "import json,sys; d=json.load(open('$out')); print(d[sys.argv[1]])" "$1"
}

# ---------------------------------------------------------------- iOS

PODFILE_LOCK="$WORK/repo/podlock-release"
check "ios: release pin from Podfile.lock" "5.4.1" "$(run_ref iosSdkRef)"

PODFILE_LOCK="$WORK/repo/podlock-branch"
check "ios: branch pin from Podfile.lock" "feat/widgets@0bb71d7" "$(run_ref iosSdkRef)"

# iOS commit pin: the stub remote reports the pinned commit as master's head.
PODFILE_LOCK="$WORK/repo/podlock-commit"
FAKE_HEADS="$WORK/heads-master" bash -c 'echo "deadbee0cafe00112233445566778899001122	refs/heads/other" > "$FAKE_HEADS"'
printf 'deadbeefcafe00112233445566778899001122\trefs/heads/master\ndeadbee0cafe00112233445566778899001122\trefs/heads/other\n' > "$WORK/heads-master"
check "ios: commit pin that is a branch head" "master@deadbee" "$(FAKE_HEADS="$WORK/heads-master" run_ref iosSdkRef)"

printf '0000000000000000000000000000000000000000\trefs/heads/master\n' > "$WORK/heads-other"
check "ios: commit pin that is not a head" "deadbee" "$(FAKE_HEADS="$WORK/heads-other" run_ref iosSdkRef)"

PODFILE_LOCK="$WORK/repo/podlock-local"
check "ios: local path pod" "local:feat/widgets@$SWIFT_LOCAL_SHA" "$(run_ref iosSdkRef)"

# No lock: Podfile override markers, then podspec pin.
unset PODFILE_LOCK
PODFILE="$WORK/repo/podfile-branch-override"
check "ios: Podfile override without lock" "feat/widgets" "$(run_ref iosSdkRef)"

unset PODFILE
check "ios: podspec pin fallback" "5.4.1" "$(run_ref iosSdkRef)"

# ---------------------------------------------------------------- Android

check "android: release pin" "4.5.1" "$(run_ref androidSdkRef)"

ANDROID_BUILD_GRADLE="$WORK/repo/build-gradle-commit"
printf '0123456789abcdef0123456789abcdef01234567\trefs/heads/rel/4.6.0\n' > "$WORK/heads-commit"
check "android: commit pin that is a rel head" "rel/4.6.0@0123456" "$(FAKE_HEADS="$WORK/heads-commit" run_ref androidSdkRef)"

printf '0000000000000000000000000000000000000000\trefs/heads/master\n' > "$WORK/heads-nohead"
check "android: commit pin that is not a head" "0123456" "$(FAKE_HEADS="$WORK/heads-nohead" run_ref androidSdkRef)"

ANDROID_BUILD_GRADLE="$WORK/repo/build-gradle-snapshot"
printf 'feedfacefeedfacefeedfacefeedfacefeedface\trefs/heads/feat/widgets\n' > "$WORK/heads-snapshot"
check "android: SNAPSHOT resolves branch head" "feat/widgets@feedfac" "$(FAKE_HEADS="$WORK/heads-snapshot" run_ref androidSdkRef)"

rm -f "$WORK/absent-heads"
check "android: SNAPSHOT with unreachable remote" "feat/widgets@unresolved" "$(FAKE_HEADS="$WORK/absent-heads" run_ref androidSdkRef)"

ANDROID_BUILD_GRADLE="$WORK/repo/build-gradle-release"
ANDROID_SETTINGS_GRADLE="$WORK/repo/settings-local.gradle"
check "android: local includeBuild override" "local:main@$ANDROID_LOCAL_SHA-dirty" "$(run_ref androidSdkRef)"
unset ANDROID_SETTINGS_GRADLE

# ---------------------------------------------------------------- Flutter

check "flutter: branch@sha off tag" "feat/thing@aaaaaaa" "$(run_ref flutterSdkRef)"

# PR builds use the head ref/sha from the event payload.
cat > "$WORK/event.json" <<'EOF'
{"pull_request": {"head": {"sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}}
EOF
check "flutter: PR head sha" "pr-branch@bbbbbbb" "$(
  PODFILE_LOCK="$WORK/repo/podlock-release" T_EVENT_NAME=pull_request T_HEAD_REF=pr-branch \
    T_EVENT_PATH="$WORK/event.json" run_ref flutterSdkRef
)"
check "flutter: commit is PR head" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "$(
  PODFILE_LOCK="$WORK/repo/podlock-release" T_EVENT_NAME=pull_request T_HEAD_REF=pr-branch \
    T_EVENT_PATH="$WORK/event.json" run_ref commit
)"

# ---------------------------------------------------------------- misc

out="$WORK/out.json"
env -u GITHUB_REF_TYPE -u GITHUB_HEAD_REF -u GITHUB_EVENT_NAME -u GITHUB_EVENT_PATH \
  REPO_ROOT="$WORK/repo" PUBSPEC="$WORK/repo/pubspec.yaml" EXAMPLE_PUBSPEC="$WORK/repo/example-pubspec.yaml" \
  PODFILE_LOCK="$WORK/repo/podlock-release" PODFILE=/dev/null PODSPEC="$WORK/repo/podspec" \
  ANDROID_BUILD_GRADLE="$WORK/repo/build-gradle-release" ANDROID_SETTINGS_GRADLE="$WORK/repo/settings-plain.gradle" \
  ANDROID_LS_REMOTE_CMD="$WORK/ls-remote" GITHUB_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  GITHUB_REF_NAME=feat/thing BUILD_DATE='2026-10-13 12:00 UTC' bash "$SCRIPT" "$out" >/dev/null
check "json: sdkVersion" "1.2.3" "$(python3 -I -c "import json; print(json.load(open('$out'))['sdkVersion'])")"
check "json: commitShort" "aaaaaaa" "$(python3 -I -c "import json; print(json.load(open('$out'))['commitShort'])")"
check "json: no buildNumber key" "false" "$(python3 -I -c "import json; print(str('buildNumber' in json.load(open('$out'))).lower())")"
check "json: buildDate" "2026-10-13 12:00 UTC" "$(python3 -I -c "import json; print(json.load(open('$out'))['buildDate'])")"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All sdk-ref tests passed"
