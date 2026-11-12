#!/usr/bin/env bash
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PODSPEC="$ROOT_DIR/ios/klaviyo_flutter_sdk.podspec"
PACKAGE_SWIFT="$ROOT_DIR/ios/klaviyo_flutter_sdk/Package.swift"
BUILD_GRADLE="$ROOT_DIR/android/build.gradle.kts"
EXAMPLE_PBXPROJ="$ROOT_DIR/example/ios/Runner.xcodeproj/project.pbxproj"
EXAMPLE_PACKAGE_RESOLVED="$ROOT_DIR/example/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
SETTINGS_GRADLE="$ROOT_DIR/example/android/settings.gradle"

SWIFT_REPO="https://github.com/klaviyo/klaviyo-swift-sdk.git"
ANDROID_REPO="https://github.com/klaviyo/klaviyo-android-sdk.git"

GITHUB_API="https://api.github.com/repos/klaviyo"

# Default local SDK paths (relative to repo root)
DEFAULT_IOS_LOCAL_PATH="$ROOT_DIR/../klaviyo-swift-sdk"
DEFAULT_ANDROID_LOCAL_PATH="$ROOT_DIR/../klaviyo-android-sdk"

# Marker comments for injected overrides
ANDROID_MARKER_START='// \[KLAVIYO-SDK-OVERRIDE-START\]'
ANDROID_MARKER_END='// \[KLAVIYO-SDK-OVERRIDE-END\]'
ANDROID_MARKER_START_LITERAL='// [KLAVIYO-SDK-OVERRIDE-START]'
ANDROID_MARKER_END_LITERAL='// [KLAVIYO-SDK-OVERRIDE-END]'

# ─── Colors & logging ────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf '%b\n' "${BLUE}ℹ${NC}  $*"; }
success() { printf '%b\n' "${GREEN}✔${NC}  $*"; }
warn()    { printf '%b\n' "${YELLOW}⚠${NC}  $*" >&2; }
error()   { printf '%b\n' "${RED}✖${NC}  $*" >&2; }

# Portable in-place sed (macOS vs Linux)
sedi() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Fetch the latest release tag from a GitHub repo.
# $1 = repo name (e.g. "klaviyo-swift-sdk")
# Prints the version string, or empty if the fetch fails.
fetch_latest_version() {
    local repo="$1"
    curl -sf --max-time 5 "$GITHUB_API/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# Prompt for a published version, using the fetched latest as the default if available.
# $1 = platform ("ios" or "android")
# Prints the chosen version.
prompt_version() {
    local platform="$1"
    local latest=""
    if [[ "$platform" == "ios" ]]; then
        latest="$(fetch_latest_version "klaviyo-swift-sdk")"
    else
        latest="$(fetch_latest_version "klaviyo-android-sdk")"
    fi

    # All prompts go to stderr since stdout is captured by the caller
    local version
    if [[ -n "$latest" ]]; then
        read -rp "Enter version [$latest]: " version </dev/tty
        version="${version:-$latest}"
    else
        warn "Could not fetch latest version from GitHub."
        read -rp "Enter version: " version </dev/tty
        [[ -z "$version" ]] && { error "Version cannot be empty"; return 1; }
    fi
    printf '%s' "$version"
}

# Arrow-key menu selector.
# Usage: arrow_menu "prompt" "option1" "option2" ...
# Sets MENU_SELECTION to the 0-based index of the selected option.
arrow_menu() {
    local prompt="$1"; shift
    local options=("$@")
    local count=${#options[@]}
    local selected=0

    # Hide cursor
    printf '\033[?25l'

    # Ensure cursor is restored on exit or interrupt
    trap 'printf "\033[?25h"' RETURN
    trap 'printf "\033[?25h"; exit 1' INT

    # Draw menu
    draw_menu() {
        local i
        for ((i = 0; i < count; i++)); do
            if ((i == selected)); then
                printf '%b\n' "  ${CYAN}❯${NC} ${BOLD}${options[$i]}${NC}"
            else
                printf '%b\n' "    ${options[$i]}"
            fi
        done
    }

    printf '%b\n' "$prompt"
    draw_menu

    # Read input
    while true; do
        # Read a single character in raw mode
        IFS= read -rsn1 key

        # Arrow keys send ESC [ A/B sequences
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn1 key2
            read -rsn1 key3
            case "$key3" in
                A) # Up arrow
                    ((selected > 0)) && ((--selected)) || true
                    ;;
                B) # Down arrow
                    ((selected < count - 1)) && ((++selected)) || true
                    ;;
            esac
        elif [[ "$key" == "" ]]; then
            # Enter pressed
            break
        fi

        # Move cursor up to redraw menu
        printf "\033[%dA" "$count"
        draw_menu
    done

    # Show cursor
    printf '\033[?25h'

    # Clear the menu lines (move up past prompt + menu, clear, rewrite selection)
    local total_lines=$((count + 1))
    printf "\033[%dA" "$total_lines"
    # Clear each line
    for ((i = 0; i < total_lines; i++)); do
        printf '\033[2K\n'
    done
    # Move back up and print the final selection
    printf "\033[%dA" "$total_lines"
    printf '%b\n' "${prompt} ${BOLD}${options[$selected]}${NC}"

    MENU_SELECTION=$selected
}

# ─── Validation helpers ───────────────────────────────────────────────

# Check that a branch exists on a remote repo.
# $1 = repo URL, $2 = branch name
validate_remote_branch() {
    local repo="$1" branch="$2"
    if ! git ls-remote --heads --quiet "$repo" "$branch" 2>/dev/null | grep -q .; then
        error "Branch '$branch' not found on $repo"
        return 1
    fi
}

# ─── iOS helpers ──────────────────────────────────────────────────────

# Update podspec dependency versions.
# $1 = version string (e.g. "~> 5.2.1") or empty to remove version constraint.
update_podspec_versions() {
    local version="$1"
    if [[ -n "$version" ]]; then
        sedi -E "s|(s\.dependency 'KlaviyoSwift').*|\1, '$version'|" "$PODSPEC"
        sedi -E "s|(s\.dependency 'KlaviyoForms').*|\1, '$version'|" "$PODSPEC"
        sedi -E "s|(s\.dependency 'KlaviyoLocation').*|\1, '$version'|" "$PODSPEC"
    else
        sedi -E "s|(s\.dependency 'KlaviyoSwift').*|\1|" "$PODSPEC"
        sedi -E "s|(s\.dependency 'KlaviyoForms').*|\1|" "$PODSPEC"
        sedi -E "s|(s\.dependency 'KlaviyoLocation').*|\1|" "$PODSPEC"
    fi
}

# Resolve a path to absolute, or error if it doesn't exist.
resolve_path() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        error "Directory does not exist: $path"
        return 1
    fi
    (cd "$path" && pwd)
}

# Print $1 relative to directory $2 (both absolute).
relative_path() {
    perl -MFile::Spec -e 'print File::Spec->abs2rel($ARGV[0], $ARGV[1])' "$1" "$2"
}

# Matches the klaviyo-swift-sdk entry in Package.swift in any form this script writes.
PACKAGE_SWIFT_DEP_RE='\.package\(\s*(?:url:\s*"https://github\.com/klaviyo/klaviyo-swift-sdk(?:\.git)?"|name:\s*"klaviyo-swift-sdk",\s*path:\s*"[^"]*")\s*(?:,\s*(?:\.\w+\([^()]*\)|\w+:\s*"[^"]*"))?\s*\)'

has_package_swift_dependency() {
    PACKAGE_SWIFT_DEP_RE="$PACKAGE_SWIFT_DEP_RE" perl -0ne 'exit(/$ENV{PACKAGE_SWIFT_DEP_RE}/ ? 0 : 1)' "$PACKAGE_SWIFT"
}

# Replace the klaviyo-swift-sdk entry in Package.swift.
# $1 = dependency arguments, e.g. 'url: "https://github.com/klaviyo/klaviyo-swift-sdk", branch: "main"'
set_package_swift_dependency() {
    if ! has_package_swift_dependency; then
        error "klaviyo-swift-sdk dependency not found in $PACKAGE_SWIFT"
        return 1
    fi
    PACKAGE_SWIFT_DEP_RE="$PACKAGE_SWIFT_DEP_RE" PACKAGE_SWIFT_DEP_ARGS="$1" \
        perl -0pi -e 's/$ENV{PACKAGE_SWIFT_DEP_RE}/.package(\n            $ENV{PACKAGE_SWIFT_DEP_ARGS}\n        )/' "$PACKAGE_SWIFT"
}

SWIFT_PACKAGE_URL="https://github.com/klaviyo/klaviyo-swift-sdk"

# Reads or rewrites the klaviyo-swift-sdk package reference in the example's project.pbxproj.
# The reference is the one the Klaviyo* XCSwiftPackageProductDependency entries point at,
# as an XCRemoteSwiftPackageReference or an XCLocalSwiftPackageReference.
# Usage: pbxproj_tool check|show FILE
#        pbxproj_tool set FILE remote KIND VALUE   (KIND = branch | revision | upToNextMinorVersion)
#        pbxproj_tool set FILE local RELATIVE_PATH
# shellcheck disable=SC2016
PBXPROJ_TOOL='
use strict; use warnings;
my ($mode, $file, $form, $a1, $a2) = @ARGV;
open my $in, "<", $file or die "cannot read $file\n"; local $/; my $s = <$in>; close $in;
my %ids = map { $_ => 1 } $s =~ /^\t\t[0-9A-F]{24} \/\* Klaviyo\w+ \*\/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = ([0-9A-F]{24}) \/\* XC(?:Remote|Local)SwiftPackageReference "[^"]*" \*\/;\n/mg;
my @ids = keys %ids;
my $id = @ids == 1 ? $ids[0] : undef;
my $objre = $id ? qr/^\t\t$id \/\* (XC(?:Remote|Local)SwiftPackageReference) "[^"]*" \*\/ = \{\n(?:\t\t\t[^\n]*\n)*?\t\t\};\n/m : undef;
my ($obj, $isa) = $id && $s =~ $objre ? ($&, $1) : ();
my $ok = $obj && ($isa eq "XCLocalSwiftPackageReference" || $obj =~ /repositoryURL = "?https:\/\/github\.com\/klaviyo\/klaviyo-swift-sdk(?:\.git)?"?;/);
if ($mode eq "check") { exit($ok ? 0 : 1) }
die "no klaviyo-swift-sdk package reference\n" unless $ok;
if ($mode eq "show") {
    if ($isa eq "XCLocalSwiftPackageReference") { my ($p) = $obj =~ /relativePath = ([^;\n]+);/; print "local, relativePath = $p\n" }
    else { my %f = $obj =~ /^\t\t\t\t(\w+) = ([^;\n]+);$/mg; print join(", ", map { "$_ = $f{$_}" } sort keys %f), "\n" }
    exit 0;
}
sub pbx_value { my $v = shift; return $v =~ /^[A-Za-z0-9_\$.\/]+$/ && $v !~ m{//|___} ? $v : "\"" . ($v =~ s/(["\\])/\\$1/gr) . "\"" }
my ($newisa, $name, $body);
if ($form eq "local") {
    ($newisa, $name) = ("XCLocalSwiftPackageReference", $a1);
    $body = "\t\t\tisa = $newisa;\n\t\t\trelativePath = " . pbx_value($a1) . ";\n";
} else {
    ($newisa, $name) = ("XCRemoteSwiftPackageReference", "klaviyo-swift-sdk");
    my $key = $a1 eq "upToNextMinorVersion" ? "minimumVersion" : $a1;
    my %req = (kind => $a1, $key => pbx_value($a2));
    $body = "\t\t\tisa = $newisa;\n\t\t\trepositoryURL = \"https://github.com/klaviyo/klaviyo-swift-sdk\";\n\t\t\trequirement = {\n"
        . join("", map { "\t\t\t\t$_ = $req{$_};\n" } sort keys %req) . "\t\t\t};\n";
}
my $newobj = "\t\t$id /* $newisa \"$name\" */ = {\n$body\t\t};\n";
$s =~ s/\Q$obj\E//;
$s =~ s{\b$id /\* XC(?:Remote|Local)SwiftPackageReference "[^"]*" \*/}{$id /* $newisa "$name" */}g;
if ($s =~ m{/\* Begin $newisa section \*/\n(.*?)/\* End $newisa section \*/\n}s) {
    my $sec = $1;
    my @objs = $sec =~ /(\t\t[0-9A-F]{24} \/\*.*?\n\t\t\};\n)/sg;
    push @objs, $newobj;
    my $joined = join "", sort { substr($a, 2, 24) cmp substr($b, 2, 24) } @objs;
    $s =~ s{(/\* Begin $newisa section \*/\n).*?(/\* End $newisa section \*/\n)}{$1$joined$2}s;
} else {
    my @after = grep { $_ gt $newisa } $s =~ m{^/\* Begin (\w+) section \*/$}mg;
    my $next = (sort @after)[0];
    my $block = "/* Begin $newisa section */\n$newobj/* End $newisa section */\n\n";
    if ($next) { $s =~ s{(/\* Begin $next section \*/\n)}{$block$1} } else { $s =~ s{(\t\};\n\trootObject = )}{$block$1} }
}
$s =~ s{/\* Begin (XC(?:Remote|Local)SwiftPackageReference) section \*/\n/\* End \1 section \*/\n\n}{}g;
open my $out, ">", $file or die "cannot write $file\n"; print $out $s; close $out;
'

has_example_package_reference() {
    [[ -f "$EXAMPLE_PBXPROJ" ]] && perl -e "$PBXPROJ_TOOL" check "$EXAMPLE_PBXPROJ"
}

# Fails unless both Package.swift and the example's project.pbxproj carry a
# klaviyo-swift-sdk dependency this script can rewrite.
preflight_ios_manifests() {
    if ! has_package_swift_dependency; then
        error "klaviyo-swift-sdk dependency not found in $PACKAGE_SWIFT"
        return 1
    fi
    if ! has_example_package_reference; then
        error "No klaviyo-swift-sdk Swift package reference (XCRemoteSwiftPackageReference or XCLocalSwiftPackageReference used by the Klaviyo* package products) found in $EXAMPLE_PBXPROJ"
        return 1
    fi
}

# Drop the klaviyo-swift-sdk pin from the example's Package.resolved so the next
# Xcode or flutter build re-resolves it against the new requirement.
drop_resolved_pin() {
    [[ -f "$EXAMPLE_PACKAGE_RESOLVED" ]] || return 0
    perl -MJSON::PP -0777 -i -ne '
        my $json = JSON::PP->new->canonical->pretty->indent_length(2)->space_before(1)->space_after(1);
        my $data = $json->decode($_);
        $data->{pins} = [ grep { $_->{identity} ne "klaviyo-swift-sdk" } @{ $data->{pins} || [] } ];
        print $json->encode($data);
    ' "$EXAMPLE_PACKAGE_RESOLVED"
}

# Point Package.swift and the example's Xcode project at the same klaviyo-swift-sdk source.
# $1 = Package.swift dependency arguments; remaining args are pbxproj_tool set arguments.
set_ios_sources() {
    local package_swift_args="$1"
    shift
    preflight_ios_manifests || return 1
    set_package_swift_dependency "$package_swift_args"
    perl -e "$PBXPROJ_TOOL" set "$EXAMPLE_PBXPROJ" "$@"
    drop_resolved_pin
}

configure_ios_version() {
    local version="$1"
    info "Configuring iOS SDK: published version ${BOLD}$version${NC}"
    # Preflight version format and every target pin before mutating any file, so
    # a bad version or missing pin cannot leave the manifests out of sync.
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?$ ]]; then
        error "Invalid iOS SDK version: $version (expected semver, e.g. 5.4.0)"
        return 1
    fi
    local dep
    for dep in KlaviyoSwift KlaviyoForms KlaviyoLocation; do
        if ! grep -qE "s\.dependency '$dep'" "$PODSPEC"; then
            error "Expected podspec dependency '$dep' not found in $PODSPEC"
            return 1
        fi
    done
    set_ios_sources "url: \"$SWIFT_PACKAGE_URL\",
            .upToNextMinor(from: \"$version\")" remote upToNextMinorVersion "$version" || return 1
    update_podspec_versions "~> $version"
    success "iOS SDK → published version $version"
}

configure_ios_branch() {
    local branch="$1"
    validate_remote_branch "$SWIFT_REPO" "$branch"
    info "Configuring iOS SDK: branch ${BOLD}$branch${NC}"
    set_ios_sources "url: \"$SWIFT_PACKAGE_URL\",
            branch: \"$branch\"" remote branch "$branch" || return 1
    update_podspec_versions ""
    success "iOS SDK → branch '$branch'"
}

configure_ios_commit() {
    local commit="$1"
    info "Configuring iOS SDK: commit ${BOLD}$commit${NC}"
    set_ios_sources "url: \"$SWIFT_PACKAGE_URL\",
            revision: \"$commit\"" remote revision "$commit" || return 1
    update_podspec_versions ""
    success "iOS SDK → commit '$commit'"
}

configure_ios_local() {
    local path
    path="$(resolve_path "$1")"
    info "Configuring iOS SDK: local path ${BOLD}$path${NC}"
    set_ios_sources "name: \"klaviyo-swift-sdk\", path: \"$path\"" \
        local "$(relative_path "$path" "$(dirname "$(dirname "$EXAMPLE_PBXPROJ")")")" || return 1
    update_podspec_versions ""
    success "iOS SDK → local path '$path'"
}

# ─── Android helpers ──────────────────────────────────────────────────

# Remove any existing settings.gradle override block
remove_android_override() {
    if grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$SETTINGS_GRADLE" 2>/dev/null; then
        sedi "\\#${ANDROID_MARKER_START}#,\\#${ANDROID_MARKER_END}#d" "$SETTINGS_GRADLE"
    fi
}

update_android_version() {
    local version="$1"
    sedi -E "s|val klaviyoSdkVersion = \".*\"|val klaviyoSdkVersion = \"$version\"|" "$BUILD_GRADLE"
}

# Inject an includeBuild block into settings.gradle for local development.
# $1 = absolute path to the local klaviyo-android-sdk checkout.
inject_android_include_build() {
    local path="$1"
    cat >> "$SETTINGS_GRADLE" << EOF
$ANDROID_MARKER_START_LITERAL
includeBuild('$path') {
    dependencySubstitution {
        substitute module('com.github.klaviyo.klaviyo-android-sdk:analytics') using project(':sdk:analytics')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:core') using project(':sdk:core')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:push-fcm') using project(':sdk:push-fcm')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:location') using project(':sdk:location')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:location-core') using project(':sdk:location-core')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:forms') using project(':sdk:forms')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:forms-core') using project(':sdk:forms-core')
    }
}
$ANDROID_MARKER_END_LITERAL
EOF
}

configure_android_version() {
    local version="$1"
    info "Configuring Android SDK: published version ${BOLD}$version${NC}"
    remove_android_override
    update_android_version "$version"
    success "Android SDK → published version $version"
}

configure_android_branch() {
    local branch="$1"
    validate_remote_branch "$ANDROID_REPO" "$branch"
    info "Configuring Android SDK: branch ${BOLD}$branch${NC}"
    remove_android_override
    local tilde='~'
    local jitpack_version="${branch//\//$tilde}-SNAPSHOT"
    update_android_version "$jitpack_version"
    success "Android SDK → branch '$branch' (via JitPack: ${jitpack_version})"
}

configure_android_commit() {
    local commit="$1"
    info "Configuring Android SDK: commit ${BOLD}$commit${NC}"
    remove_android_override
    update_android_version "$commit"
    success "Android SDK → commit '$commit' (via JitPack)"
}

configure_android_local() {
    local path
    path="$(resolve_path "$1")"
    info "Configuring Android SDK: local path ${BOLD}$path${NC}"
    remove_android_override
    inject_android_include_build "$path"
    success "Android SDK → local path '$path'"
}

# ─── Status ───────────────────────────────────────────────────────────

show_status() {
    echo ""
    printf '%b\n' "${BOLD}Current native SDK configuration:${NC}"
    echo ""

    # iOS
    local ios_version
    ios_version=$(grep -oE "s\.dependency 'KlaviyoSwift'.*" "$PODSPEC" | head -1)
    printf '%b\n' "  ${CYAN}iOS${NC}:     $ios_version"
    PACKAGE_SWIFT_DEP_RE="$PACKAGE_SWIFT_DEP_RE" perl -0ne 'if (/($ENV{PACKAGE_SWIFT_DEP_RE})/) { (my $d = $1) =~ s/\s+/ /g; print "          (Package.swift: $d)\n" }' "$PACKAGE_SWIFT"
    if has_example_package_reference; then
        printf '%s\n' "          (example Xcode project: $(perl -e "$PBXPROJ_TOOL" show "$EXAMPLE_PBXPROJ"))"
    else
        printf '%s\n' "          (example Xcode project: no klaviyo-swift-sdk package reference)"
    fi

    # Android
    local android_version
    android_version=$(grep -oE 'val klaviyoSdkVersion = "[^"]*"' "$BUILD_GRADLE")
    printf '%b\n' "  ${CYAN}Android${NC}: $android_version"
    if grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$SETTINGS_GRADLE" 2>/dev/null; then
        printf '%b\n' "          ${YELLOW}(settings.gradle override active — local includeBuild)${NC}"
    fi
    echo ""
}

# ─── Interactive mode ─────────────────────────────────────────────────

prompt_platform_config() {
    local platform="$1"
    local label
    [[ "$platform" == "ios" ]] && label="iOS (Swift)" || label="Android"

    echo ""
    arrow_menu "${CYAN}━━━ Configure ${BOLD}$label${NC}${CYAN} SDK ━━━${NC}" \
        "Published version" \
        "Git branch" \
        "Git commit" \
        "Local path" \
        "Skip (no changes)"

    case "$MENU_SELECTION" in
        0)
            local version
            version="$(prompt_version "$platform")"
            "configure_${platform}_version" "$version"
            ;;
        1)
            local branch
            read -rp "Enter branch name: " branch
            [[ -z "$branch" ]] && { error "Branch cannot be empty"; return 1; }
            "configure_${platform}_branch" "$branch"
            ;;
        2)
            local commit
            read -rp "Enter commit hash: " commit
            [[ -z "$commit" ]] && { error "Commit hash cannot be empty"; return 1; }
            "configure_${platform}_commit" "$commit"
            ;;
        3)
            local default_path
            [[ "$platform" == "ios" ]] && default_path="$DEFAULT_IOS_LOCAL_PATH" || default_path="$DEFAULT_ANDROID_LOCAL_PATH"
            local path
            read -rp "Enter local SDK path [$default_path]: " path
            path="${path:-$default_path}"
            "configure_${platform}_local" "$path"
            ;;
        4)
            info "Skipping $label configuration"
            ;;
    esac
}

interactive_mode() {
    printf '%b\n' "${BOLD}Klaviyo Flutter SDK — Native SDK Configuration${NC}"
    echo "Configure which versions of the native iOS and Android SDKs to consume."

    show_status
    prompt_platform_config "ios"
    prompt_platform_config "android"

    echo ""
    success "Configuration complete."
    warn "Run ${CYAN}cd example && flutter pub get${NC} to apply changes."
    warn "For iOS, the next ${CYAN}flutter build ios${NC} or Xcode build re-resolves the klaviyo-swift-sdk package; commit the regenerated Package.resolved only for a released version."
}

# ─── CLI mode ─────────────────────────────────────────────────────────

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Configure which versions of the native iOS and Android SDKs are consumed
by the Klaviyo Flutter SDK. Run without arguments for interactive mode.

iOS Options:
  --ios-version VERSION      Use a published iOS SDK version (e.g., 5.2.1)
  --ios-branch BRANCH        Use iOS SDK from a git branch
  --ios-commit HASH          Use iOS SDK from a git commit
  --ios-local [PATH]         Use a local iOS SDK checkout (default: $DEFAULT_IOS_LOCAL_PATH)

  iOS options rewrite the klaviyo-swift-sdk dependency in ios/klaviyo_flutter_sdk/Package.swift
  and in example/ios/Runner.xcodeproj/project.pbxproj, clear its pin from the example's
  Package.resolved, and set the podspec's Klaviyo* version constraints.

Android Options:
  --android-version VERSION  Use a published Android SDK version (e.g., 4.3.0)
  --android-branch BRANCH   Use Android SDK from a git branch
  --android-commit HASH     Use Android SDK from a git commit
  --android-local [PATH]    Use a local Android SDK checkout (default: $DEFAULT_ANDROID_LOCAL_PATH)

General:
  --reset                    Reset both SDKs to latest published versions
  --status                   Show current native SDK configuration
  -h, --help                 Show this help message

Examples:
  $(basename "$0")                                                  # Interactive mode
  $(basename "$0") --ios-version 5.2.1 --android-version 4.3.0     # Published versions
  $(basename "$0") --ios-local ../klaviyo-swift-sdk --android-branch main
  $(basename "$0") --ios-branch feature/new-api --android-commit abc1234
  $(basename "$0") --reset
EOF
}

parse_args() {
    local ios_action="" ios_value=""
    local android_action="" android_value=""
    local reset=false
    local status=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ios-version)
                ios_action="version"; ios_value="${2:?Missing value for --ios-version}"; shift 2 ;;
            --ios-branch)
                ios_action="branch"; ios_value="${2:?Missing value for --ios-branch}"; shift 2 ;;
            --ios-commit)
                ios_action="commit"; ios_value="${2:?Missing value for --ios-commit}"; shift 2 ;;
            --ios-local)
                ios_action="local"
                if [[ -n "${2:-}" && ! "$2" == --* ]]; then ios_value="$2"; shift 2;
                else ios_value="$DEFAULT_IOS_LOCAL_PATH"; shift; fi ;;
            --android-version)
                android_action="version"; android_value="${2:?Missing value for --android-version}"; shift 2 ;;
            --android-branch)
                android_action="branch"; android_value="${2:?Missing value for --android-branch}"; shift 2 ;;
            --android-commit)
                android_action="commit"; android_value="${2:?Missing value for --android-commit}"; shift 2 ;;
            --android-local)
                android_action="local"
                if [[ -n "${2:-}" && ! "$2" == --* ]]; then android_value="$2"; shift 2;
                else android_value="$DEFAULT_ANDROID_LOCAL_PATH"; shift; fi ;;
            --reset)
                reset=true; shift ;;
            --status)
                status=true; shift ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                error "Unknown option: $1"
                echo ""
                usage
                exit 1 ;;
        esac
    done

    if $status; then
        show_status
        return
    fi

    if $reset; then
        local latest_ios latest_android
        latest_ios="$(fetch_latest_version "klaviyo-swift-sdk")"
        latest_android="$(fetch_latest_version "klaviyo-android-sdk")"
        if [[ -z "$latest_ios" || -z "$latest_android" ]]; then
            error "Cannot reset: failed to fetch latest versions from GitHub."
            [[ -z "$latest_ios" ]] && error "  Could not determine latest iOS SDK version."
            [[ -z "$latest_android" ]] && error "  Could not determine latest Android SDK version."
            error "Use --ios-version and --android-version to specify versions explicitly."
            exit 1
        fi
        configure_ios_version "$latest_ios"
        configure_android_version "$latest_android"
        echo ""
        success "Reset to latest published versions (iOS: $latest_ios, Android: $latest_android)"
        return
    fi

    if [[ -z "$ios_action" && -z "$android_action" ]]; then
        error "No configuration specified. Use --help for usage or run without arguments for interactive mode."
        exit 1
    fi

    if [[ -n "$ios_action" ]]; then
        "configure_ios_${ios_action}" "$ios_value"
    fi

    if [[ -n "$android_action" ]]; then
        "configure_android_${android_action}" "$android_value"
    fi

    echo ""
    success "Configuration complete."
    warn "Run ${CYAN}cd example && flutter pub get${NC} to apply changes."
    warn "For iOS, the next ${CYAN}flutter build ios${NC} or Xcode build re-resolves the klaviyo-swift-sdk package; commit the regenerated Package.resolved only for a released version."
}

# ─── Main ─────────────────────────────────────────────────────────────

main() {
    if [[ $# -eq 0 ]]; then
        interactive_mode
    else
        parse_args "$@"
    fi
}

main "$@"
