#!/usr/bin/env bash
#
# Writes a JSON file describing exactly which SDK builds the example app is
# compiled against. The workflow passes it to flutter builds via
# --dart-define-from-file and the app shows it in the Profile tab; release
# notes and Slack messages reuse the same values.
#
# Usage: sdk-ref.sh [output-file]   (default: example/build-info.json)
#
# Refs are plain versions for official releases, otherwise branch@shortsha
# (7 chars), with a `local:` prefix and optional `-dirty` suffix for local
# checkouts, mirroring the native test apps. Any resolution failure degrades
# to a readable string; the script never exits non-zero.
#
# Env overrides (used by the offline tests):
#   REPO_ROOT, PUBSPEC, PODFILE_LOCK, PODFILE, PODSPEC,
#   ANDROID_BUILD_GRADLE, ANDROID_SETTINGS_GRADLE, ANDROID_LS_REMOTE_CMD
#   GITHUB_REF_TYPE, GITHUB_REF_NAME, GITHUB_HEAD_REF, GITHUB_EVENT_NAME,
#   GITHUB_EVENT_PATH, GITHUB_SHA, BUILD_DATE

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PUBSPEC="${PUBSPEC:-$REPO_ROOT/pubspec.yaml}"
EXAMPLE_PUBSPEC="${EXAMPLE_PUBSPEC:-$REPO_ROOT/example/pubspec.yaml}"
PODFILE_LOCK="${PODFILE_LOCK:-$REPO_ROOT/example/ios/Podfile.lock}"
PODFILE="${PODFILE:-$REPO_ROOT/example/ios/Podfile}"
PODSPEC="${PODSPEC:-$REPO_ROOT/ios/klaviyo_flutter_sdk.podspec}"
ANDROID_BUILD_GRADLE="${ANDROID_BUILD_GRADLE:-$REPO_ROOT/android/build.gradle}"
ANDROID_SETTINGS_GRADLE="${ANDROID_SETTINGS_GRADLE:-$REPO_ROOT/example/android/settings.gradle}"
SWIFT_REPO="https://github.com/klaviyo/klaviyo-swift-sdk.git"
ANDROID_REPO="https://github.com/klaviyo/klaviyo-android-sdk.git"
ANDROID_LS_REMOTE_CMD="${ANDROID_LS_REMOTE_CMD:-git -c http.connectTimeout=15 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 ls-remote --heads $ANDROID_REPO}"
IOS_LS_REMOTE_CMD="${IOS_LS_REMOTE_CMD:-git -c http.connectTimeout=15 -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=10 ls-remote --heads $SWIFT_REPO}"
OUT="${1:-$REPO_ROOT/example/build-info.json}"
SHORT=7

is_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
}

# local_ref <path>: branch@sha[-dirty] for a local checkout, or "local".
local_ref() {
  local path="$1" branch sha dirty=""
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  sha="$(git -C "$path" rev-parse --short=$SHORT HEAD 2>/dev/null)"
  if [ -z "$branch" ] || [ -z "$sha" ]; then
    printf 'local'
    return
  fi
  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
    dirty="-dirty"
  fi
  printf 'local:%s@%s%s' "$branch" "$sha" "$dirty"
}

# ─── Flutter SDK (this repo) ──────────────────────────────────────────

resolve_flutter_ref() {
  local version
  version="$(grep '^version:' "$PUBSPEC" 2>/dev/null | awk '{print $2}' | cut -d+ -f1)"
  [ -n "$version" ] || version="unknown"

  local sha="$COMMIT" branch="$BRANCH" tag=""
  if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
    tag="${GITHUB_REF_NAME:-}"
  elif [ -z "${GITHUB_SHA:-}" ]; then
    tag="$(git -C "$REPO_ROOT" describe --exact-match --tags "$sha" 2>/dev/null)"
  fi
  # Official release: building the tag that matches the pubspec version.
  if [ -n "$tag" ] && { [ "$tag" = "$version" ] || [ "$tag" = "v$version" ]; }; then
    printf '%s' "$version"
    return
  fi

  [ -n "$branch" ] || branch="detached"   # local builds only: CI fails before this
  if [ -n "$sha" ]; then
    printf '%s@%s' "$branch" "$(printf '%s' "$sha" | cut -c1-$SHORT)"
  else
    printf '%s' "$branch"
  fi
}

# ─── iOS (KlaviyoSwift) ───────────────────────────────────────────────

# resolve_ios_pod_lock prints the ref if Podfile.lock pins KlaviyoSwift.
resolve_ios_pod_lock() {
  [ -f "$PODFILE_LOCK" ] || return 1

  local ext
  ext="$(awk '
    /^EXTERNAL SOURCES:/ { in_ext = 1; next }
    /^[A-Z][A-Z ]*:/ { in_ext = 0 }
    in_ext && /^  KlaviyoSwift:/ { in_pod = 1; next }
    in_ext && in_pod && /^  [^ ]/ { in_pod = 0 }
    in_ext && in_pod { print }
  ' "$PODFILE_LOCK")"
  if [ -n "$ext" ]; then
    path="$(printf '%s\n' "$ext" | sed -n 's/.*:path: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1)"
    if [ -n "$path" ]; then
      local_ref "$path"
      return 0
    fi
    local branch commit
    branch="$(printf '%s\n' "$ext" | sed -n 's/.*:branch: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1)"
    commit="$(awk '
      /^CHECKOUT OPTIONS:/ { in_co = 1; next }
      /^[A-Z][A-Z ]*:/ { in_co = 0 }
      in_co && /^  KlaviyoSwift:/ { in_pod = 1; next }
      in_co && in_pod && /^  [^ ]/ { in_pod = 0 }
      in_co && in_pod { print }
    ' "$PODFILE_LOCK" | sed -n 's/.*:commit: *\([0-9a-f]*\).*/\1/p' | head -1)"
    if [ -n "$branch" ]; then
      if [ -n "$commit" ]; then
        printf '%s@%s' "$branch" "$(printf '%s' "$commit" | cut -c1-$SHORT)"
      else
        printf '%s' "$branch"
      fi
      return 0
    fi
    if [ -n "$commit" ]; then
      # Commit pin: report the branch only if the commit is still its head.
      local heads
      heads="$($IOS_LS_REMOTE_CMD 2>/dev/null \
        | awk -v c="$commit" 'index($1, c) == 1 {sub("refs/heads/", "", $2); print $2}' \
        | sort || true)"
      local best
      best="$(printf '%s\n' "$heads" | { grep -x master || true; } | head -1)"
      [ -n "$best" ] || best="$(printf '%s\n' "$heads" | grep '^rel/' | head -1)"
      [ -n "$best" ] || best="$(printf '%s\n' "$heads" | head -1)"
      if [ -n "$best" ]; then
        printf '%s@%s' "$best" "$(printf '%s' "$commit" | cut -c1-$SHORT)"
      else
        printf '%s' "$(printf '%s' "$commit" | cut -c1-$SHORT)"
      fi
      return 0
    fi
  fi

  # Release pin: "  - KlaviyoSwift (5.4.1):" in the PODS section.
  local ver
  ver="$(sed -n 's/^  - KlaviyoSwift (\([^)]*\)):*.*$/\1/p' "$PODFILE_LOCK" | head -1)"
  if [ -n "$ver" ]; then
    printf '%s' "$ver"
    return 0
  fi
  return 1
}

# resolve_ios_podfile_override reads the configure-sdk.sh marker block.
resolve_ios_podfile_override() {
  [ -f "$PODFILE" ] || return 1
  local block
  block="$(sed -n '/\[KLAVIYO-SDK-OVERRIDE-START\]/,/\[KLAVIYO-SDK-OVERRIDE-END\]/p' "$PODFILE" 2>/dev/null)"
  [ -n "$block" ] || return 1
  local line
  line="$(printf '%s\n' "$block" | grep "pod 'KlaviyoSwift'" | head -1)"
  [ -n "$line" ] || return 1
  if printf '%s' "$line" | grep -q ':path'; then
    local path
    path="$(printf '%s' "$line" | sed -n "s/.*:path => '\([^']*\)'.*/\1/p")"
    [ -n "$path" ] && { local_ref "$path"; return 0; }
    printf 'local'
    return 0
  fi
  local branch commit
  branch="$(printf '%s' "$line" | sed -n "s/.*:branch => '\([^']*\)'.*/\1/p")"
  commit="$(printf '%s' "$line" | sed -n "s/.*:commit => '\([^']*\)'.*/\1/p")"
  if [ -n "$branch" ]; then
    printf '%s' "$branch"
    return 0
  fi
  if [ -n "$commit" ]; then
    printf '%s' "$(printf '%s' "$commit" | cut -c1-$SHORT)"
    return 0
  fi
  return 1
}

resolve_ios_ref() {
  local ref
  if ref="$(resolve_ios_pod_lock)"; then
    printf '%s' "$ref"
    return
  fi
  if ref="$(resolve_ios_podfile_override)"; then
    printf '%s' "$ref"
    return
  fi
  # Fallback: the ~> pin in the podspec.
  local pin
  pin="$(sed -n "s/.*s\.dependency 'KlaviyoSwift', *'~> *\([^']*\)'.*/\1/p" "$PODSPEC" 2>/dev/null | head -1)"
  printf '%s' "${pin:-unknown}"
}

# ─── Android (klaviyo-android-sdk) ────────────────────────────────────

resolve_android_ref() {
  # Local includeBuild override in settings.gradle (configure-sdk.sh).
  if [ -f "$ANDROID_SETTINGS_GRADLE" ] \
    && grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$ANDROID_SETTINGS_GRADLE" 2>/dev/null; then
    local path
    path="$(sed -n "/KLAVIYO-SDK-OVERRIDE-START/,/KLAVIYO-SDK-OVERRIDE-END/p" "$ANDROID_SETTINGS_GRADLE" \
      | sed -n "s/.*includeBuild('\([^']*\)').*/\1/p" | head -1)"
    if [ -n "$path" ]; then
      case "$path" in
        /*) : ;;
        *) path="$(cd "$(dirname "$ANDROID_SETTINGS_GRADLE")/$path" 2>/dev/null && pwd)" ;;
      esac
    fi
    if [ -n "$path" ] && [ -d "$path" ]; then
      local_ref "$path"
    else
      printf 'local'
    fi
    return
  fi

  local coordinate
  coordinate="$(sed -n 's/^def klaviyoSdkVersion = "\([^"]*\)".*/\1/p' "$ANDROID_BUILD_GRADLE" 2>/dev/null | head -1)"
  [ -n "$coordinate" ] || { printf 'unknown'; return; }

  if is_semver "$coordinate"; then
    printf '%s' "$coordinate"
    return
  fi

  if printf '%s' "$coordinate" | grep -qE '^[0-9a-f]{7,40}$'; then
    # Commit pin via JitPack: report the branch only when the commit is a
    # current head (master first, then release branches).
    local heads
    heads="$($ANDROID_LS_REMOTE_CMD 2>/dev/null \
      | awk -v c="$coordinate" 'index($1, c) == 1 {sub("refs/heads/", "", $2); print $2}' \
      | sort || true)"
    local best
    best="$(printf '%s\n' "$heads" | { grep -x master || true; } | head -1)"
    [ -n "$best" ] || best="$(printf '%s\n' "$heads" | grep '^rel/' | head -1)"
    [ -n "$best" ] || best="$(printf '%s\n' "$heads" | head -1)"
    if [ -n "$best" ]; then
      printf '%s@%s' "$best" "$(printf '%s' "$coordinate" | cut -c1-$SHORT)"
    else
      printf '%s' "$(printf '%s' "$coordinate" | cut -c1-$SHORT)"
    fi
    return
  fi

  case "$coordinate" in
    *-SNAPSHOT)
      # JitPack builds the branch head; `~` encodes `/`.
      local branch sha
      branch="$(printf '%s' "${coordinate%-SNAPSHOT}" | tr '~' '/')"
      sha="$($ANDROID_LS_REMOTE_CMD "$branch" 2>/dev/null | awk '{print $1}' | head -1)"
      if [ -n "$sha" ]; then
        printf '%s@%s' "$branch" "$(printf '%s' "$sha" | cut -c1-$SHORT)"
      else
        printf '%s@unresolved' "$branch"
      fi
      return
      ;;
  esac

  printf '%s' "$coordinate"
}

# ─── JSON output ──────────────────────────────────────────────────────

# In CI the commit, branch and source must come from the event: GITHUB_SHA and GITHUB_REF_NAME are the
# synthetic merge commit and "<n>/merge" on a label deploy, and git in a CI checkout reports the same
# merge commit. A missing input fails the build and names the field. Local builds keep the git fallback.
fail_stamp() {
  echo "::error::sdk-ref.sh: $1 is empty in CI. Refusing to fall back to git or GITHUB_SHA/GITHUB_REF_NAME, which are the merge commit and \"<n>/merge\" on a label deploy." >&2
  exit 1
}

if [ -n "${CI:-}" ]; then
  if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
    COMMIT=""
    if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "$GITHUB_EVENT_PATH" ]; then
      COMMIT="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["pull_request"]["head"]["sha"])' "$GITHUB_EVENT_PATH" 2>/dev/null || true)"
    fi
    BRANCH="${GITHUB_HEAD_REF:-}"
  else
    COMMIT="${GITHUB_SHA:-}"
    BRANCH="${GITHUB_REF_NAME:-}"
  fi
  [ -n "$COMMIT" ] || fail_stamp "the commit"
  [ -n "$BRANCH" ] || fail_stamp "the branch"
else
  COMMIT="${GITHUB_SHA:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)}"
  if [ -n "${GITHUB_EVENT_NAME:-}" ] && [ "$GITHUB_EVENT_NAME" = "pull_request" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "$GITHUB_EVENT_PATH" ]; then
    HEAD_SHA="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["pull_request"]["head"]["sha"])' "$GITHUB_EVENT_PATH" 2>/dev/null)"
    [ -n "$HEAD_SHA" ] && COMMIT="$HEAD_SHA"
  fi
  BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}}"
fi
FLUTTER_REF="$(resolve_flutter_ref)"
IOS_REF="$(resolve_ios_ref)"
ANDROID_REF="$(resolve_android_ref)"
SDK_VERSION="$(grep '^version:' "$PUBSPEC" 2>/dev/null | awk '{print $2}' | cut -d+ -f1)"
APP_VERSION="$(grep '^version:' "$EXAMPLE_PUBSPEC" 2>/dev/null | awk '{print $2}' | cut -d+ -f1)"

# The commit and source label are stamped once here; every consumer
# (dart-defines, release notes, Slack) reads them from the JSON so the
# surfaces cannot diverge. On PR events both come from the PR head, never
# the synthetic merge commit.
BUILD_DATE="${BUILD_DATE:-$(date -u '+%Y-%m-%d %H:%M UTC')}"

SOURCE_LABEL="${SOURCE_LABEL:-$("$(cd "$(dirname "$0")" && pwd)/../.github/scripts/source-label.sh" || true)}"
if [ -n "${CI:-}" ] && { [ -z "$SOURCE_LABEL" ] || [ "$SOURCE_LABEL" = "unknown" ]; }; then
  fail_stamp "the source label"
fi
[ -n "$SOURCE_LABEL" ] || SOURCE_LABEL='—'
EVENT_NAME_OUT="${GITHUB_EVENT_NAME:-—}"

# The native SDK version is known only when the ref is a release pin.
IOS_SDK_VERSION="—"
is_semver "$IOS_REF" && IOS_SDK_VERSION="$IOS_REF"
ANDROID_SDK_VERSION="—"
is_semver "$ANDROID_REF" && ANDROID_SDK_VERSION="$ANDROID_REF"

mkdir -p "$(dirname "$OUT")"
FLUTTER_REF="$FLUTTER_REF" IOS_REF="$IOS_REF" ANDROID_REF="$ANDROID_REF" \
  IOS_SDK_VERSION="$IOS_SDK_VERSION" ANDROID_SDK_VERSION="$ANDROID_SDK_VERSION" \
  SDK_VERSION="$SDK_VERSION" APP_VERSION="$APP_VERSION" COMMIT="$COMMIT" \
  BRANCH="$BRANCH" BUILD_DATE="$BUILD_DATE" SOURCE_LABEL="$SOURCE_LABEL" \
  EVENT_NAME_OUT="$EVENT_NAME_OUT" OUT="$OUT" \
  python3 -I - <<'PY'
import json
import os

info = {
    "sdkVersion": os.environ.get("SDK_VERSION") or "—",
    "flutterSdkRef": os.environ.get("FLUTTER_REF") or "—",
    "iosSdkVersion": os.environ.get("IOS_SDK_VERSION") or "—",
    "iosSdkRef": os.environ.get("IOS_REF") or "—",
    "androidSdkVersion": os.environ.get("ANDROID_SDK_VERSION") or "—",
    "androidSdkRef": os.environ.get("ANDROID_REF") or "—",
    "commit": os.environ.get("COMMIT") or "—",
    "commitShort": (os.environ.get("COMMIT") or "—")[:7],
    "branch": os.environ.get("BRANCH") or "—",
    "appVersion": os.environ.get("APP_VERSION") or "—",
    "buildDate": os.environ.get("BUILD_DATE") or "—",
    "sourceLabel": os.environ.get("SOURCE_LABEL") or "—",
    "event": os.environ.get("EVENT_NAME_OUT") or "—",
}
with open(os.environ["OUT"], "w") as fh:
    json.dump(info, fh, indent=2)
    fh.write("\n")
PY

echo "Wrote $OUT"
cat "$OUT"
