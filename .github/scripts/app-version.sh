#!/usr/bin/env bash
#
# Prints the example app version for a publish run, derived from the SDK
# version and the store build number:
#   official release  X.Y.Z
#   rel/* branch      X.Y.Z-rc.<build>
#   anything else     X.Y.Z-alpha.<build>
# Exits non-zero when the SDK version, build number, or release tag cannot be
# resolved.
#
# Usage: app-version.sh <sdk-version> <build-number>
#
# Env (set by the workflow from github context, never inline-interpolated):
#   EVENT_NAME   github.event_name
#   RELEASE_TAG  github.event.release.tag_name
#   HEAD_REF     github.head_ref
#   REF_NAME     github.ref_name
#   GITHUB_REF_TYPE  set by Actions; "tag" when dispatched on a tag
#
set -euo pipefail

SDK_VERSION="${1:-}"
BUILD_NUMBER="${2:-}"

fail() {
  echo "::error::app-version.sh: $1" >&2
  exit 1
}

base="${SDK_VERSION%%[-+]*}"
[[ "$base" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "SDK version '$SDK_VERSION' does not start with X.Y.Z"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || fail "build number '$BUILD_NUMBER' is not numeric"

tag="${RELEASE_TAG:-}"
if [ -z "$tag" ] && [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
  tag="${REF_NAME:-}"
fi
if [ -n "$tag" ]; then
  # Strip an optional v prefix, then split the tag into its X.Y.Z base and
  # any -prerelease suffix. The base must match the SDK version; a suffix is
  # carried through so a prerelease release stamps the full tag.
  tag_base="${tag#v}"
  suffix=""
  case "$tag_base" in
    *-*) suffix="-${tag_base#*-}"; tag_base="${tag_base%%-*}" ;;
  esac
  [ "$tag_base" = "$base" ] || fail "release tag '$tag' does not match SDK version $base"
  printf '%s%s\n' "$base" "$suffix"
  exit 0
fi

if [ "${EVENT_NAME:-}" = "pull_request" ]; then
  branch="${HEAD_REF:-}"
else
  branch="${REF_NAME:-}"
fi
[ -n "$branch" ] || fail "no branch name to classify the build"

case "$branch" in
  rel/*) printf '%s-rc.%s\n' "$base" "$BUILD_NUMBER" ;;
  *) printf '%s-alpha.%s\n' "$base" "$BUILD_NUMBER" ;;
esac
