#!/bin/bash

# Version Bump Script for Klaviyo Flutter SDK
# Usage: ./scripts/bump_version.sh <new-version>
# Example: ./scripts/bump_version.sh 0.2.0-alpha.1

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if version argument is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    echo "Usage: ./scripts/bump_version.sh <new-version>"
    echo "Example: ./scripts/bump_version.sh 0.2.0-alpha.1"
    exit 1
fi

NEW_VERSION=$1

# Validate version format (semantic versioning with optional prerelease)
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
    echo -e "${RED}Error: Invalid version format${NC}"
    echo "Version must follow semantic versioning: X.Y.Z or X.Y.Z-prerelease"
    echo "Examples: 1.0.0, 0.1.0-alpha.1, 1.2.3-beta.2"
    exit 1
fi

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d '[:space:]')

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Klaviyo Flutter SDK Version Bump    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Current version:${NC} $CURRENT_VERSION"
echo -e "${YELLOW}New version:${NC}     $NEW_VERSION"
echo ""

echo ""
echo -e "${BLUE}Updating files...${NC}"

# 1. Update pubspec.yaml
echo -e "${GREEN}✓${NC} Updating pubspec.yaml"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
else
    # Linux
    sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
fi

# 2. Update README.md
echo -e "${GREEN}✓${NC} Updating README.md"
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/klaviyo_flutter_sdk: \^.*/klaviyo_flutter_sdk: ^$NEW_VERSION/" README.md
else
    sed -i "s/klaviyo_flutter_sdk: \^.*/klaviyo_flutter_sdk: ^$NEW_VERSION/" README.md
fi

# 3. Update Android strings.xml
echo -e "${GREEN}✓${NC} Updating android/src/main/res/values/strings.xml"
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/<string name=\"klaviyo_sdk_version_override\">.*<\/string>/<string name=\"klaviyo_sdk_version_override\">$NEW_VERSION<\/string>/" android/src/main/res/values/strings.xml
else
    sed -i "s/<string name=\"klaviyo_sdk_version_override\">.*<\/string>/<string name=\"klaviyo_sdk_version_override\">$NEW_VERSION<\/string>/" android/src/main/res/values/strings.xml
fi

# 4. Update iOS plist via sync_version.sh
echo -e "${GREEN}✓${NC} Updating ios/klaviyo-sdk-configuration.plist"
./scripts/sync_version.sh

# 5. Update CHANGELOG.md (add new section at top if version doesn't exist)
echo -e "${GREEN}✓${NC} Updating CHANGELOG.md"
if ! grep -q "## $NEW_VERSION" CHANGELOG.md; then
    # Get current date
    CURRENT_DATE=$(date +"%Y-%m-%d")

    # Create temp file with new version section
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/# Changelog/# Changelog\n\n## $NEW_VERSION - $CURRENT_DATE\n\n### Changes\n- TODO: Add changelog entries\n/" CHANGELOG.md
    else
        sed -i "s/# Changelog/# Changelog\n\n## $NEW_VERSION - $CURRENT_DATE\n\n### Changes\n- TODO: Add changelog entries\n/" CHANGELOG.md
    fi
    echo -e "${YELLOW}  ⚠ Added new CHANGELOG section - please update with actual changes${NC}"
else
    echo -e "${YELLOW}  ⚠ Version already exists in CHANGELOG - please update manually${NC}"
fi

echo ""
echo -e "${BLUE}Verifying changes...${NC}"

# Verify all files were updated
ERRORS=0

check_file_version() {
    local file=$1
    local pattern=$2
    local version=$(grep -A1 "$pattern" "$file")

    if [[ $version == *"$NEW_VERSION"* ]]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file - version not updated correctly"
        ERRORS=$((ERRORS + 1))
    fi
}

check_file_version "pubspec.yaml" "^version:"
check_file_version "README.md" "klaviyo_flutter_sdk:"
check_file_version "android/src/main/res/values/strings.xml" "klaviyo_sdk_version_override"
check_file_version "ios/klaviyo-sdk-configuration.plist" "klaviyo_sdk_version"
check_file_version "example/pubspec.yaml" "^version:"
check_file_version "CHANGELOG.md" "## $NEW_VERSION"

# Verify ALL hardcoded MARKETING_VERSION entries in the example pbxproj are at the new
# version. sync_version.sh rewrites entries matching `MARKETING_VERSION = <semver>;`; the
# main Runner target's dynamic `$(FLUTTER_BUILD_NAME)` reference is intentionally excluded
# from both the sync and this check. If sync_version.sh's sed silently fails to match
# (e.g. the pbxproj format changes), a stale entry would otherwise slip through.
PBXPROJ="example/ios/Runner.xcodeproj/project.pbxproj"
escaped_version=${NEW_VERSION//./\\.}
# `grep -c` already prints `0` on no-match; `|| true` keeps that count and prevents
# the non-zero exit from tripping `set -e`.
hardcoded_total=$(grep -Ec 'MARKETING_VERSION = [0-9A-Za-z.-]+;' "$PBXPROJ" || true)
matching=$(grep -Ec "MARKETING_VERSION = ${escaped_version};" "$PBXPROJ" || true)
if [ "$hardcoded_total" -gt 0 ] && [ "$matching" -eq "$hardcoded_total" ]; then
    echo -e "${GREEN}✓${NC} $PBXPROJ ($matching MARKETING_VERSION entries)"
else
    echo -e "${RED}✗${NC} $PBXPROJ — $matching of $hardcoded_total MARKETING_VERSION entries at $NEW_VERSION"
    ERRORS=$((ERRORS + 1))
fi

echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ Version successfully bumped to $NEW_VERSION${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Update CHANGELOG.md with actual changes"
    echo "2. Review changes: git diff"
    echo "3. Commit: git add -A && git commit -m 'Bump version to $NEW_VERSION'"
    echo "4. Tag: git tag v$NEW_VERSION"
    echo "5. Push: git push && git push --tags"
else
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo -e "${RED}✗ Version bump completed with $ERRORS error(s)${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"
    exit 1
fi
