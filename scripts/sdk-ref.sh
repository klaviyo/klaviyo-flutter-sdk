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

set -u

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PUBSPEC="${PUBSPEC:-$REPO_ROOT/pubspec.yaml}"
EXAMPLE_PUBSPEC="${EXAMPLE_PUBSPEC:-$REPO_ROOT/example/pubspec.yaml}"
PACKAGE_RESOLVED="${PACKAGE_RESOLVED:-$REPO_ROOT/example/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved}"
EXAMPLE_PBXPROJ="${EXAMPLE_PBXPROJ:-$REPO_ROOT/example/ios/Runner.xcodeproj/project.pbxproj}"
PODSPEC="${PODSPEC:-$REPO_ROOT/ios/klaviyo_flutter_sdk.podspec}"
ANDROID_BUILD_GRADLE="${ANDROID_BUILD_GRADLE:-$REPO_ROOT/android/build.gradle.kts}"
ANDROID_SETTINGS_GRADLE="${ANDROID_SETTINGS_GRADLE:-$REPO_ROOT/example/android/settings.gradle}"
SWIFT_REPO="https://github.com/klaviyo/klaviyo-swift-sdk.git"
ANDROID_REPO="https://github.com/klaviyo/klaviyo-android-sdk.git"
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

# branch_for_commit <sha>: master, else a rel/* branch, else any branch whose head is <sha>.
branch_for_commit() {
  local commit="$1" heads best
  heads="$(git ls-remote --heads "$SWIFT_REPO" 2>/dev/null \
    | awk -v c="$commit" 'index($1, c) == 1 {sub("refs/heads/", "", $2); print $2}' \
    | sort || true)"
  best="$(printf '%s\n' "$heads" | { grep -x master || true; } | head -1)"
  [ -n "$best" ] || best="$(printf '%s\n' "$heads" | grep '^rel/' | head -1)"
  [ -n "$best" ] || best="$(printf '%s\n' "$heads" | head -1)"
  printf '%s' "$best"
}

# resolve_ios_package_reference reads the example's klaviyo-swift-sdk package
# reference in project.pbxproj and the matching Package.resolved pin.
resolve_ios_package_reference() {
  [ -f "$EXAMPLE_PBXPROJ" ] || return 1
  local req
  # shellcheck disable=SC2016
  req="$(perl -0ne '
    my %ids = map { $_ => 1 } /^\t\t[0-9A-F]{24} \/\* Klaviyo\w+ \*\/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = ([0-9A-F]{24}) /mg;
    my @ids = keys %ids;
    exit 0 unless @ids == 1;
    if (/^\t\t$ids[0] \/\* (XC(?:Remote|Local)SwiftPackageReference) "[^"]*" \*\/ = \{\n(.*?)\n\t\t\};\n/ms) {
      my ($isa, $body) = ($1, $2);
      if ($isa eq "XCLocalSwiftPackageReference") { my ($p) = $body =~ /relativePath = "?([^";\n]+)"?;/; print "local $p\n"; exit 0 }
      my %f = $body =~ /^\t\t\t\t(\w+) = "?([^";\n]+)"?;$/mg;
      print "$f{kind} ", ($f{branch} // $f{revision} // $f{minimumVersion} // $f{version} // "-"), "\n";
    }' "$EXAMPLE_PBXPROJ" 2>/dev/null)"
  [ -n "$req" ] || return 1
  local kind value pinned_version pinned_revision
  read -r kind value <<<"$req"
  if [ "$kind" = "local" ]; then
    local path
    case "$value" in
      /*) path="$value" ;;
      *) path="$(cd "$(dirname "$(dirname "$EXAMPLE_PBXPROJ")")/$value" 2>/dev/null && pwd)" ;;
    esac
    if [ -n "$path" ] && [ -d "$path" ]; then local_ref "$path"; else printf 'local'; fi
    return 0
  fi
  if [ -f "$PACKAGE_RESOLVED" ]; then
    # shellcheck disable=SC2016
    read -r pinned_version pinned_revision <<<"$(perl -MJSON::PP -0777 -ne '
      my $d = eval { decode_json($_) } or exit 0;
      for my $p (@{ $d->{pins} || [] }) {
        next unless $p->{identity} eq "klaviyo-swift-sdk";
        print(($p->{state}{version} // "-"), " ", ($p->{state}{revision} // "-"), "\n");
      }' "$PACKAGE_RESOLVED" 2>/dev/null)"
  fi
  case "$kind" in
    branch)
      if [ -n "${pinned_revision:-}" ] && [ "$pinned_revision" != "-" ]; then
        printf '%s@%s' "$value" "$(printf '%s' "$pinned_revision" | cut -c1-$SHORT)"
      else
        printf '%s' "$value"
      fi
      ;;
    revision)
      local best
      best="$(branch_for_commit "$value")"
      if [ -n "$best" ]; then
        printf '%s@%s' "$best" "$(printf '%s' "$value" | cut -c1-$SHORT)"
      else
        printf '%s' "$(printf '%s' "$value" | cut -c1-$SHORT)"
      fi
      ;;
    *)
      if [ -n "${pinned_version:-}" ] && [ "$pinned_version" != "-" ]; then
        printf '%s' "$pinned_version"
      else
        printf '%s' "$value"
      fi
      ;;
  esac
}

resolve_ios_ref() {
  local ref
  if ref="$(resolve_ios_package_reference)"; then
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
  coordinate="$(sed -n 's/^val klaviyoSdkVersion = "\([^"]*\)".*/\1/p' "$ANDROID_BUILD_GRADLE" 2>/dev/null | head -1)"
  [ -n "$coordinate" ] || { printf 'unknown'; return; }

  if is_semver "$coordinate"; then
    printf '%s' "$coordinate"
    return
  fi

  if printf '%s' "$coordinate" | grep -qE '^[0-9a-f]{7,40}$'; then
    # Commit pin via JitPack: report the branch only when the commit is a
    # current head (master first, then release branches).
    local heads
    heads="$(git ls-remote --heads "$ANDROID_REPO" 2>/dev/null \
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
      sha="$(git ls-remote --heads "$ANDROID_REPO" "$branch" 2>/dev/null | awk '{print $1}' | head -1)"
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

COMMIT="${GITHUB_SHA:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)}"
BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}}"
if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] && [ -f "${GITHUB_EVENT_PATH:-}" ]; then
  HEAD_SHA="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["pull_request"]["head"]["sha"])' "$GITHUB_EVENT_PATH" 2>/dev/null)"
  [ -n "$HEAD_SHA" ] && COMMIT="$HEAD_SHA"
fi
FLUTTER_REF="$(resolve_flutter_ref)"
IOS_REF="$(resolve_ios_ref)"
ANDROID_REF="$(resolve_android_ref)"
SDK_VERSION="$(grep '^version:' "$PUBSPEC" 2>/dev/null | awk '{print $2}' | cut -d+ -f1)"
APP_VERSION="$(grep '^version:' "$EXAMPLE_PUBSPEC" 2>/dev/null | awk '{print $2}' | cut -d+ -f1)"

BUILD_DATE="${BUILD_DATE:-$(date -u '+%Y-%m-%d %H:%M UTC')}"

SOURCE_LABEL="${SOURCE_LABEL:-$("$(cd "$(dirname "$0")" && pwd)/../.github/scripts/source-label.sh" || true)}"
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
