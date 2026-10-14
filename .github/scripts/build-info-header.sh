#!/usr/bin/env bash
#
# Prints the shared "header block" used as the top of the TestFlight
# "What to Test" and Play release notes, and (verbatim) as the text the
# example app's build-info card copies. One source of truth on this side;
# the Dart formatter is validated against the same fixture
# (tests/fixtures/build-info-cases.json) so the two can never drift.
#
# Usage: build-info-header.sh <platform: ios|android> <build-info.json> <build-number>
#
# Env:
#   SOURCE_LABEL  sanitized source label (source-label.sh)
#   EVENT_NAME    github.event_name
#   RUN_URL       workflow run URL; the line is omitted when unset
#
set -euo pipefail

PLATFORM="${1:?usage: build-info-header.sh <ios|android> <build-info.json> <build-number>}"
BUILD_INFO="${2:?}"
BUILD_NUMBER="${3:?}"

case "$PLATFORM" in
  ios) NATIVE_NAME="iOS" ;;
  android) NATIVE_NAME="Android" ;;
  *) echo "::error::platform must be ios or android" >&2; exit 2 ;;
esac

SOURCE_LABEL="${SOURCE_LABEL:-—}"
EVENT_NAME="${EVENT_NAME:-—}"
RUN_URL="${RUN_URL:-}"

PLATFORM="$PLATFORM" NATIVE_NAME="$NATIVE_NAME" BUILD_INFO="$BUILD_INFO" \
  BUILD_NUMBER="$BUILD_NUMBER" SOURCE_LABEL="$SOURCE_LABEL" \
  EVENT_NAME="$EVENT_NAME" RUN_URL="$RUN_URL" \
  python3 -I - <<'PY'
import json
import os

with open(os.environ["BUILD_INFO"]) as fh:
    info = json.load(fh)

MISSING = "—"


def sdk_line(name, version, ref):
    # "<version> · <ref>"; the ref is omitted when it is missing or just
    # restates the release version.
    if not ref or ref == MISSING or ref == version:
        return f"{name} {version or MISSING}"
    return f"{name} {version or MISSING} · {ref}"


lines = [
    f"Flutter Example {info.get('appVersion') or MISSING} ({os.environ['BUILD_NUMBER']})",
    sdk_line("Klaviyo Flutter SDK", info.get("sdkVersion"), info.get("flutterSdkRef")),
    sdk_line(
        f"Klaviyo {os.environ['NATIVE_NAME']} SDK",
        info.get(f"{os.environ['PLATFORM']}SdkVersion"),
        info.get(f"{os.environ['PLATFORM']}SdkRef"),
    ),
    f"Commit: {info.get('commitShort') or MISSING} on {os.environ['SOURCE_LABEL']} ({os.environ['EVENT_NAME']})",
]
run_url = os.environ.get("RUN_URL")
if run_url:
    lines.append(f"CI run: {run_url}")
print("\n".join(lines))
PY
