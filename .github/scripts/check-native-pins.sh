#!/usr/bin/env bash
# Fails unless every Klaviyo native SDK dependency is pinned to a released
# version (X.Y.Z, or X.Y.Z-alpha/beta/rc with an optional number): no commit
# SHA, branch, SNAPSHOT or local path on Android; no
# unversioned podspec dependency; no :git/:branch/:commit/:tag/:path pod in
# the example Podfile; and a version requirement (not a revision, branch or
# path) for klaviyo-swift-sdk in Package.swift.
#
# Usage: check-native-pins.sh [repo-root]   (defaults to the current directory)
set -euo pipefail

root="${1:-.}"
gradle="android/build.gradle"
podspec="ios/klaviyo_flutter_sdk.podspec"
podfile="example/ios/Podfile"
package="ios/klaviyo_flutter_sdk/Package.swift"

errors=()

android=$(sed -nE 's/^[[:space:]]*def[[:space:]]+klaviyoSdkVersion[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''].*/\1/p' "$root/$gradle")
if ! [[ "$android" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)(\.?[0-9]+)?)?$ ]]; then
  errors+=("${gradle}: klaviyoSdkVersion is '${android}', not a released version")
fi

while IFS= read -r line; do
  errors+=("${podspec}: unversioned Klaviyo dependency: ${line}")
done < <(grep -nE "^[[:space:]]*s\.dependency[[:space:](]+['\"]Klaviyo[A-Za-z]*['\"][[:space:])]*(#.*)?$" "$root/$podspec" || true)

while IFS= read -r line; do
  errors+=("${podfile}: Klaviyo pod not from a release: ${line}")
done < <(awk '
  { code = $0; sub(/[[:space:]]*#.*$/, "", code) }
  /^[[:space:]]*pod[[:space:](]+['\''"]Klaviyo/ { decl = $0; start = NR; if (code !~ /,[[:space:]]*$/) { print start ":" decl; decl = "" }; next }
  decl != "" { decl = decl " " $0; if (code !~ /,[[:space:]]*$/) { print start ":" decl; decl = "" } }
' "$root/$podfile" | grep -E "(:(git|branch|commit|path|tag)[[:space:]]*=>|[[:space:],](git|branch|commit|path|tag):[[:space:]])" || true)

if [ -f "$root/$package" ]; then
  swift_pin=$(awk '/klaviyo-swift-sdk/ { grab = 1 } grab { print; if (/\)/) exit }' "$root/$package" | tr -d '\n')
  if [ -z "$swift_pin" ]; then
    errors+=("${package}: no klaviyo-swift-sdk package dependency found")
  elif ! [[ "$swift_pin" =~ (from:|exact:|upToNextMinor|upToNextMajor)[^\)]*\"[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)(\.?[0-9]+)?)?\" ]]; then
    errors+=("${package}: klaviyo-swift-sdk is not pinned to a released version: $(echo "$swift_pin" | tr -s ' ')")
  fi
fi

if [ "${#errors[@]}" -gt 0 ]; then
  for e in "${errors[@]}"; do
    echo "::error::${e}"
  done
  echo "::error::Revert the pin and bump to released SDK versions before releasing."
  exit 1
fi

echo "Native SDK dependencies are pinned to released versions (Android ${android})"
