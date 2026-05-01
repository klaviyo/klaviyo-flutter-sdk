#!/bin/bash
#
# Syncs the SDK version from pubspec.yaml into platform-specific config files.
# Run this as part of the release process after bumping the version in pubspec.yaml.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$REPO_ROOT/pubspec.yaml"
PLIST="$REPO_ROOT/ios/klaviyo-sdk-configuration.plist"
EXAMPLE_PUBSPEC="$REPO_ROOT/example/pubspec.yaml"
EXAMPLE_PBXPROJ="$REPO_ROOT/example/ios/Runner.xcodeproj/project.pbxproj"

# Extract version from pubspec.yaml. Strip any +<buildnumber> suffix — the plugin convention
# is to omit it, but if it's ever present we don't want to propagate it into downstream files.
RAW_VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}')
VERSION="${RAW_VERSION%%+*}"

if [ -z "$VERSION" ]; then
  echo "Error: Could not read version from $PUBSPEC" >&2
  exit 1
fi

# Update iOS plist
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>klaviyo_sdk_name</key>
    <string>flutter</string>
    <key>klaviyo_sdk_version</key>
    <string>$VERSION</string>
</dict>
</plist>
PLIST

echo "Synced version $VERSION to $PLIST"

# Update example app pubspec.yaml — peg version to plugin version. The example app is
# publish_to: 'none' and never goes to a store, so no build number suffix is needed; Flutter
# defaults FLUTTER_BUILD_NUMBER to 1 when omitted.
if [ -f "$EXAMPLE_PUBSPEC" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" "$EXAMPLE_PUBSPEC"
  else
    sed -i "s/^version: .*/version: $VERSION/" "$EXAMPLE_PUBSPEC"
  fi

  echo "Synced version $VERSION to $EXAMPLE_PUBSPEC"
fi

# Update hardcoded MARKETING_VERSION in example app pbxproj (RunnerTests + NotificationServiceExtension targets).
# The main Runner target reads $(FLUTTER_BUILD_NAME) via Info.plist + Generated.xcconfig, so it isn't hardcoded.
# The character class accepts SemVer pre-release identifiers (digits, letters, dots, hyphens) so values like
# "0.3.0-alpha.1" round-trip correctly. It deliberately excludes "$" / "(" / ")" / quotes so dynamic references
# like `MARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";` are left untouched.
if [ -f "$EXAMPLE_PBXPROJ" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/MARKETING_VERSION = [0-9A-Za-z.-][0-9A-Za-z.-]*;/MARKETING_VERSION = $VERSION;/g" "$EXAMPLE_PBXPROJ"
  else
    sed -i "s/MARKETING_VERSION = [0-9A-Za-z.-][0-9A-Za-z.-]*;/MARKETING_VERSION = $VERSION;/g" "$EXAMPLE_PBXPROJ"
  fi

  echo "Synced MARKETING_VERSION to $VERSION in $EXAMPLE_PBXPROJ"
fi
