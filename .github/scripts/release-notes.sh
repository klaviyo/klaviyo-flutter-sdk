#!/usr/bin/env bash
#
# Prints store release notes ("What's new" on Play, "What to Test" on
# TestFlight) for an example app build: the shared header block
# followed by the GitHub release body (release events only). Header lines are
# never cut. When the text is over the cap the release body is cut first, then
# the CI run line. Truncation is by character and any cut is marked
# "…[truncated]" on its own last line, which counts toward the cap. Only when
# the header alone leaves no room for the marker is it left off. All text handling is in Python: bash 3.2 command substitution corrupts
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


def fit():
    head = "\n".join(header)
    with_ci = head + (f"\nCI run: {run_url}" if run_url else "")
    full = with_ci + (f"\n\n{body}" if body else "")
    if len(full) <= cap:
        return full

    marker_line = "\n" + MARKER
    if body:
        room = cap - len(with_ci) - len("\n\n") - len(marker_line)
        if room > 0:
            return with_ci + "\n\n" + body[:room].rstrip() + marker_line
    if len(with_ci + marker_line) <= cap:
        return with_ci + marker_line
    if len(head + marker_line) <= cap:
        return head + marker_line
    return head


notes = fit()
print(notes)
PY
