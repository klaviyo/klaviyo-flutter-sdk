#!/usr/bin/env bash
# Fails unless every Klaviyo native SDK dependency is pinned to a released
# version (X.Y.Z, or X.Y.Z-alpha/beta/rc with an optional number): no commit
# SHA, branch, SNAPSHOT or local path on Android; no
# unversioned podspec dependency; a version requirement (not a revision,
# branch or path) for klaviyo-swift-sdk in Package.swift; and an example
# Xcode project whose klaviyo-swift-sdk package reference is a version
# requirement matching Package.swift.
#
# Usage: check-native-pins.sh [repo-root]   (defaults to the current directory)
set -euo pipefail

root="${1:-.}"
gradle="android/build.gradle.kts"
podspec="ios/klaviyo_flutter_sdk.podspec"
pbxproj="example/ios/Runner.xcodeproj/project.pbxproj"
package="ios/klaviyo_flutter_sdk/Package.swift"

errors=()

android=$(sed -nE 's/^[[:space:]]*val[[:space:]]+klaviyoSdkVersion[[:space:]]*=[[:space:]]*["'\'']([^"'\'']*)["'\''].*/\1/p' "$root/$gradle")
if ! [[ "$android" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)(\.?[0-9]+)?)?$ ]]; then
  errors+=("${gradle}: klaviyoSdkVersion is '${android}', not a released version")
fi

while IFS= read -r line; do
  errors+=("${podspec}: unversioned Klaviyo dependency: ${line}")
done < <(grep -nE "^[[:space:]]*s\.dependency[[:space:](]+['\"]Klaviyo[A-Za-z]*['\"][[:space:])]*(#.*)?$" "$root/$podspec" || true)

if [ -f "$root/$package" ]; then
  swift_pin=$(awk '/klaviyo-swift-sdk/ { grab = 1 } grab { print; if (/\)/) exit }' "$root/$package" | tr -d '\n')
  if [ -z "$swift_pin" ]; then
    errors+=("${package}: no klaviyo-swift-sdk package dependency found")
  elif ! [[ "$swift_pin" =~ (from:|exact:|upToNextMinor|upToNextMajor)[^\)]*\"[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)(\.?[0-9]+)?)?\" ]]; then
    errors+=("${package}: klaviyo-swift-sdk is not pinned to a released version: $(echo "$swift_pin" | tr -s ' ')")
  fi
fi

# Prints "<kind> <version>" for Package.swift's klaviyo-swift-sdk requirement,
# normalized to Xcode's requirement kinds.
swift_requirement() {
  perl -0ne '
    if (/\.package\(\s*url:\s*"https:\/\/github\.com\/klaviyo\/klaviyo-swift-sdk(?:\.git)?"\s*,\s*(.*?)\s*\)\s*[,\]]/s) {
      my $r = $1;
      if ($r =~ /^\.upToNextMinor\(from:\s*"([^"]+)"\)$/) { print "upToNextMinorVersion $1\n" }
      elsif ($r =~ /^(?:\.upToNextMajor\(from:\s*|from:\s*)"([^"]+)"\)?$/) { print "upToNextMajorVersion $1\n" }
      elsif ($r =~ /^(?:\.exact\(|exact:\s*)"([^"]+)"\)?$/) { print "exactVersion $1\n" }
    }' "$1"
}

# Prints "<isa> <kind> <version>" for the example's klaviyo-swift-sdk package
# reference: the one the Klaviyo* XCSwiftPackageProductDependency entries use.
pbxproj_requirement() {
  perl -0ne '
    my %ids = map { $_ => 1 } /^\t\t[0-9A-F]{24} \/\* Klaviyo\w+ \*\/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = ([0-9A-F]{24}) /mg;
    my @ids = keys %ids;
    exit 0 unless @ids == 1;
    my $id = $ids[0];
    if (/^\t\t$id \/\* (XC(?:Remote|Local)SwiftPackageReference) "[^"]*" \*\/ = \{\n(.*?)\n\t\t\};\n/ms) {
      my ($isa, $body) = ($1, $2);
      my %f = $body =~ /^\t\t\t\t(\w+) = "?([^";\n]+)"?;$/mg;
      my $v = $f{minimumVersion} // $f{version} // $f{branch} // $f{revision} // "-";
      print "$isa ", ($f{kind} // "-"), " $v\n";
    }' "$1"
}

if [ -f "$root/$pbxproj" ] && grep -qE "productName = Klaviyo[A-Za-z]*;" "$root/$pbxproj"; then
  example_pin="$(pbxproj_requirement "$root/$pbxproj")"
  read -r example_isa example_kind example_version <<<"${example_pin:-- - -}"
  package_pin="$(swift_requirement "$root/$package" 2>/dev/null || true)"
  read -r package_kind package_version <<<"${package_pin:-- -}"
  if [ -z "$example_pin" ]; then
    errors+=("${pbxproj}: no single klaviyo-swift-sdk package reference found for the Klaviyo* package products")
  elif [ "$example_isa" != "XCRemoteSwiftPackageReference" ]; then
    errors+=("${pbxproj}: klaviyo-swift-sdk is a local package (${example_isa}), not a released version")
  elif [[ "$example_kind" == "branch" || "$example_kind" == "revision" ]]; then
    errors+=("${pbxproj}: klaviyo-swift-sdk is pinned to a ${example_kind} (${example_version}), not a released version")
  elif [ -n "$package_pin" ] && [[ "$example_kind" != "$package_kind" || "$example_version" != "$package_version" ]]; then
    errors+=("${pbxproj}: klaviyo-swift-sdk requirement (${example_kind} ${example_version}) does not match ${package} (${package_kind} ${package_version})")
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
