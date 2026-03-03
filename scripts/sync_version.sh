#!/bin/bash
#
# Syncs the SDK version from pubspec.yaml into platform-specific config files.
# Run this as part of the release process after bumping the version in pubspec.yaml.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$REPO_ROOT/pubspec.yaml"
PLIST="$REPO_ROOT/ios/klaviyo-sdk-configuration.plist"

# Extract version from pubspec.yaml
VERSION=$(grep '^version:' "$PUBSPEC" | awk '{print $2}')

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
