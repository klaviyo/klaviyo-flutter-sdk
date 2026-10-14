#!/usr/bin/env bash
#
# Prints store release notes ("What's new" on Play, "What to Test" on
# TestFlight) for an example app build: the shared header block (kept in sync
# with the app's "Copy build info" text via tests/fixtures/build-info-cases.json)
# followed by the GitHub release body (release events only). Header lines are
# never cut; the CI run line is dropped before the body is cut. Truncation is
# by character and any cut is marked "…[truncated]", which counts toward the
# cap. All text handling is in Python: bash 3.2 command substitution corrupts
# multi-byte text at pipe-buffer boundaries.
#
# Usage: release-notes.sh <max-chars> <platform: ios|android> <build-info.json> <build-number> [body-file]
#
# Env:
#   SOURCE_LABEL  sanitized source label (source-label.sh)
#   EVENT_NAME    github.event_name
#   RUN_URL       workflow run URL
#
set -euo pipefail

MAX_CHARS="${1:?usage: release-notes.sh <max-chars> <ios|android> <build-info.json> <build-number> [body-file]}"
PLATFORM="${2:?}"
BUILD_INFO="${3:?}"
BUILD_NUMBER="${4:?}"
BODY_FILE="${5:-}"

case "$PLATFORM" in
  ios) NATIVE_NAME="iOS" ;;
  android) NATIVE_NAME="Android" ;;
  *) echo "::error::platform must be ios or android" >&2; exit 2 ;;
esac

MAX_CHARS="$MAX_CHARS" NATIVE_NAME="$NATIVE_NAME" BUILD_INFO="$BUILD_INFO" \
  BUILD_NUMBER="$BUILD_NUMBER" BODY_FILE="$BODY_FILE" \
  SOURCE_LABEL="${SOURCE_LABEL:-—}" EVENT_NAME="${EVENT_NAME:-—}" RUN_URL="${RUN_URL:-}" \
  python3 -I - <<'PY'
import os

MISSING = "—"
MARKER = "…[truncated]"

import json

with open(os.environ["BUILD_INFO"]) as fh:
    info = json.load(fh)

cap = int(os.environ["MAX_CHARS"])


def sdk_line(name, version, ref):
    # "<version> · <ref>"; the ref is omitted when it is missing or just
    # restates the release version.
    if not ref or ref == MISSING or ref == version:
        return f"{name} {version or MISSING}"
    return f"{name} {version or MISSING} · {ref}"


platform = "ios" if os.environ["NATIVE_NAME"] == "iOS" else "android"
header = [
    f"Flutter Example {info.get('appVersion') or MISSING} ({os.environ['BUILD_NUMBER']})",
    sdk_line("Klaviyo Flutter SDK", info.get("sdkVersion"), info.get("flutterSdkRef")),
    sdk_line(
        f"Klaviyo {os.environ['NATIVE_NAME']} SDK",
        info.get(f"{platform}SdkVersion"),
        info.get(f"{platform}SdkRef"),
    ),
    f"Commit: {info.get('commitShort') or MISSING} on {os.environ['SOURCE_LABEL']} ({os.environ['EVENT_NAME']})",
    f"Built: {info.get('buildDate') or MISSING}",
]

run_url = os.environ.get("RUN_URL", "")

body = ""
body_file = os.environ.get("BODY_FILE", "")
if os.environ.get("EVENT_NAME") == "release" and body_file:
    try:
        body = open(body_file).read().strip()
    except OSError:
        body = ""


def render(with_run):
    lines = list(header)
    if with_run and run_url:
        lines.append(f"CI run: {run_url}")
    text = "\n".join(lines)
    if body:
        text += "\n\n" + body
    return text


notes = render(with_run=True)
if len(notes) > cap:
    # Drop the CI run line first; the header itself is never cut.
    notes = render(with_run=False)
if len(notes) > cap:
    notes = notes[: cap - len(MARKER)] + MARKER
print(notes)
PY
