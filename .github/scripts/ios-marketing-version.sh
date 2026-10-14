#!/usr/bin/env bash
#
# Prints the iOS marketing version (CFBundleShortVersionString) for an SDK
# version: the numeric core only, with any -prerelease or +build suffix
# stripped. Apple accepts at most three period-separated integers, and
# build numbers reset per marketing version, so 0.3.2-alpha.1 and 0.3.2
# share one build-number sequence. Anything that is not a numeric core of
# one to three components fails the caller's step loudly.
#
# Usage: ios-marketing-version.sh <sdk-version>
#
set -euo pipefail

v="${1:?usage: ios-marketing-version.sh <sdk-version>}"
stripped="${v%%[-+]*}"
if ! [[ "$stripped" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "::error::SDK version '$v' has no numeric marketing version Apple would accept (want X[.Y[.Z]])." >&2
  exit 1
fi
printf '%s\n' "$stripped"
