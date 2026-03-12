#!/usr/bin/env bash
set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PODSPEC="$ROOT_DIR/ios/klaviyo_flutter_sdk.podspec"
BUILD_GRADLE="$ROOT_DIR/android/build.gradle"
PODFILE="$ROOT_DIR/example/ios/Podfile"
SETTINGS_GRADLE="$ROOT_DIR/example/android/settings.gradle"

SWIFT_REPO="https://github.com/klaviyo/klaviyo-swift-sdk.git"
ANDROID_REPO="https://github.com/klaviyo/klaviyo-android-sdk.git"

GITHUB_API="https://api.github.com/repos/klaviyo"

# Default local SDK paths (relative to repo root)
DEFAULT_IOS_LOCAL_PATH="../klaviyo-swift-sdk"
DEFAULT_ANDROID_LOCAL_PATH="../klaviyo-android-sdk"

# Marker comments for injected overrides
IOS_MARKER_START='# \[KLAVIYO-SDK-OVERRIDE-START\]'
IOS_MARKER_END='# \[KLAVIYO-SDK-OVERRIDE-END\]'
IOS_MARKER_START_LITERAL='# [KLAVIYO-SDK-OVERRIDE-START]'
IOS_MARKER_END_LITERAL='# [KLAVIYO-SDK-OVERRIDE-END]'
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
warn()    { printf '%b\n' "${YELLOW}⚠${NC}  $*"; }
error()   { printf '%b\n' "${RED}✖${NC}  $*" >&2; }

# Fetch the latest release tag from a GitHub repo.
# $1 = repo name (e.g. "klaviyo-swift-sdk")
# Prints the version string, or empty if the fetch fails.
fetch_latest_version() {
    local repo="$1"
    curl -sf --max-time 5 "$GITHUB_API/$repo/releases/latest" 2>/dev/null \
        | grep '"tag_name"' \
        | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# Resolved latest versions (fetched lazily and cached)
# Empty string = not yet fetched, special value "FAILED" = fetch attempted and failed
LATEST_IOS_VERSION=""
LATEST_ANDROID_VERSION=""

get_latest_ios_version() {
    if [[ -z "$LATEST_IOS_VERSION" ]]; then
        LATEST_IOS_VERSION=$(fetch_latest_version "klaviyo-swift-sdk") || true
        if [[ -z "$LATEST_IOS_VERSION" ]]; then
            LATEST_IOS_VERSION="FAILED"
        fi
    fi
    if [[ "$LATEST_IOS_VERSION" != "FAILED" ]]; then
        printf '%s' "$LATEST_IOS_VERSION"
    fi
}

get_latest_android_version() {
    if [[ -z "$LATEST_ANDROID_VERSION" ]]; then
        LATEST_ANDROID_VERSION=$(fetch_latest_version "klaviyo-android-sdk") || true
        if [[ -z "$LATEST_ANDROID_VERSION" ]]; then
            LATEST_ANDROID_VERSION="FAILED"
        fi
    fi
    if [[ "$LATEST_ANDROID_VERSION" != "FAILED" ]]; then
        printf '%s' "$LATEST_ANDROID_VERSION"
    fi
}

# Prompt for a published version, using the fetched latest as the default if available.
# $1 = platform ("ios" or "android")
# Prints the chosen version.
prompt_version() {
    local platform="$1"
    local latest=""
    if [[ "$platform" == "ios" ]]; then
        latest="$(get_latest_ios_version)"
    else
        latest="$(get_latest_android_version)"
    fi

    local version
    if [[ -n "$latest" ]]; then
        read -rp "Enter version [$latest]: " version
        version="${version:-$latest}"
    else
        warn "Could not fetch latest version from GitHub."
        read -rp "Enter version: " version
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

# Remove any existing Podfile override block
remove_ios_override() {
    if grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$PODFILE" 2>/dev/null; then
        sed -i '' "/${IOS_MARKER_START}/,/${IOS_MARKER_END}/d" "$PODFILE"
    fi
}

# Update podspec dependency versions.
# $1 = version string (e.g. "~> 5.2.1") or empty to remove version constraint.
update_podspec_versions() {
    local version="$1"
    if [[ -n "$version" ]]; then
        sed -i '' -E "s|(s\.dependency 'KlaviyoSwift').*|\1, '$version'|" "$PODSPEC"
        sed -i '' -E "s|(s\.dependency 'KlaviyoForms').*|\1, '$version'|" "$PODSPEC"
        sed -i '' -E "s|(s\.dependency 'KlaviyoLocation').*|\1, '$version'|" "$PODSPEC"
    else
        sed -i '' -E "s|(s\.dependency 'KlaviyoSwift').*|\1|" "$PODSPEC"
        sed -i '' -E "s|(s\.dependency 'KlaviyoForms').*|\1|" "$PODSPEC"
        sed -i '' -E "s|(s\.dependency 'KlaviyoLocation').*|\1|" "$PODSPEC"
    fi
}

# Update the KlaviyoSwiftExtension pod line in the Podfile.
# $1 = full pod arguments, e.g. "'KlaviyoSwiftExtension', '~> 5.2.1'"
update_podfile_extension() {
    local pod_spec="$1"
    sed -i '' -E "s|pod 'KlaviyoSwiftExtension'.*|pod $pod_spec|" "$PODFILE"
}

# Inject an override block into the Podfile, right after the flutter_install_all_ios_pods line.
# $1 = override content (multi-line string of pod declarations)
inject_ios_override() {
    local override_content="$1"
    local temp_file
    temp_file=$(mktemp)

    while IFS= read -r line; do
        printf '%s\n' "$line" >> "$temp_file"
        if [[ "$line" == *"flutter_install_all_ios_pods"* ]]; then
            echo "  $IOS_MARKER_START_LITERAL" >> "$temp_file"
            while IFS= read -r override_line; do
                echo "  $override_line" >> "$temp_file"
            done <<< "$override_content"
            echo "  $IOS_MARKER_END_LITERAL" >> "$temp_file"
        fi
    done < "$PODFILE"

    mv "$temp_file" "$PODFILE"
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

configure_ios_version() {
    local version="$1"
    info "Configuring iOS SDK: published version ${BOLD}$version${NC}"
    remove_ios_override
    update_podspec_versions "~> $version"
    update_podfile_extension "'KlaviyoSwiftExtension', '~> $version'"
    success "iOS SDK → published version $version"
}

configure_ios_branch() {
    local branch="$1"
    validate_remote_branch "$SWIFT_REPO" "$branch"
    info "Configuring iOS SDK: branch ${BOLD}$branch${NC}"
    remove_ios_override
    update_podspec_versions ""
    inject_ios_override "pod 'KlaviyoSwift', :git => '$SWIFT_REPO', :branch => '$branch'
pod 'KlaviyoForms', :git => '$SWIFT_REPO', :branch => '$branch'
pod 'KlaviyoLocation', :git => '$SWIFT_REPO', :branch => '$branch'"
    update_podfile_extension "'KlaviyoSwiftExtension', :git => '$SWIFT_REPO', :branch => '$branch'"
    success "iOS SDK → branch '$branch'"
}

configure_ios_commit() {
    local commit="$1"
    info "Configuring iOS SDK: commit ${BOLD}$commit${NC}"
    remove_ios_override
    update_podspec_versions ""
    inject_ios_override "pod 'KlaviyoSwift', :git => '$SWIFT_REPO', :commit => '$commit'
pod 'KlaviyoForms', :git => '$SWIFT_REPO', :commit => '$commit'
pod 'KlaviyoLocation', :git => '$SWIFT_REPO', :commit => '$commit'"
    update_podfile_extension "'KlaviyoSwiftExtension', :git => '$SWIFT_REPO', :commit => '$commit'"
    success "iOS SDK → commit '$commit'"
}

configure_ios_local() {
    local path
    path="$(resolve_path "$1")"
    info "Configuring iOS SDK: local path ${BOLD}$path${NC}"
    remove_ios_override
    update_podspec_versions ""
    inject_ios_override "pod 'KlaviyoSwift', :path => '$path'
pod 'KlaviyoForms', :path => '$path'
pod 'KlaviyoLocation', :path => '$path'"
    update_podfile_extension "'KlaviyoSwiftExtension', :path => '$path'"
    success "iOS SDK → local path '$path'"
}

# ─── Android helpers ──────────────────────────────────────────────────

# Remove any existing settings.gradle override block
remove_android_override() {
    if grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$SETTINGS_GRADLE" 2>/dev/null; then
        sed -i '' "\\#${ANDROID_MARKER_START}#,\\#${ANDROID_MARKER_END}#d" "$SETTINGS_GRADLE"
    fi
}

update_android_version() {
    local version="$1"
    sed -i '' -E "s|def klaviyoSdkVersion = \".*\"|def klaviyoSdkVersion = \"$version\"|" "$BUILD_GRADLE"
}

# Inject an includeBuild block into settings.gradle for local development.
# $1 = absolute path to the local klaviyo-android-sdk checkout.
inject_android_include_build() {
    local path="$1"
    cat >> "$SETTINGS_GRADLE" << EOF

$ANDROID_MARKER_START_LITERAL
includeBuild('$path') {
    dependencySubstitution {
        substitute module('com.github.klaviyo.klaviyo-android-sdk:analytics') using project(':analytics')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:core') using project(':core')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:push-fcm') using project(':push-fcm')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:location') using project(':location')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:location-core') using project(':location-core')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:forms') using project(':forms')
        substitute module('com.github.klaviyo.klaviyo-android-sdk:forms-core') using project(':forms-core')
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
    update_android_version "${branch}-SNAPSHOT"
    success "Android SDK → branch '$branch' (via JitPack: ${branch}-SNAPSHOT)"
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
    if grep -q 'KLAVIYO-SDK-OVERRIDE-START' "$PODFILE" 2>/dev/null; then
        printf '%b\n' "          ${YELLOW}(Podfile override active)${NC}"
        grep -A1 'KLAVIYO-SDK-OVERRIDE-START' "$PODFILE" | grep -v 'OVERRIDE' | sed 's/^/          /' || true
    fi

    # Android
    local android_version
    android_version=$(grep -oE 'def klaviyoSdkVersion = "[^"]*"' "$BUILD_GRADLE")
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
    warn "For iOS, also run ${CYAN}cd example/ios && pod install${NC}."
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
        latest_ios="$(get_latest_ios_version)"
        latest_android="$(get_latest_android_version)"
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
    warn "For iOS, also run ${CYAN}cd example/ios && pod install${NC}."
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
