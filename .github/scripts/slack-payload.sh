#!/usr/bin/env bash
#
# Prints the Slack message payload (JSON) for an example app publish result.
# Every value arrives through the environment and is encoded by jq, so
# newlines, quotes and Slack markup in a value cannot break the request.
#
# Usage: slack-payload.sh > payload.json
#
# Env:
#   RESULT         success | failure | warning
#   OS             iOS | Android
#   PLATFORM       store label, e.g. "TestFlight", "Play internal"
#   VERSION_LABEL  full version with build number
#   SDK_INFO       pre-formatted SDK line
#   SOURCE_LABEL   sanitized source label
#   EVENT_NAME     github.event_name
#   COMMIT_SHA     commit to link
#   COMMIT_SHORT   7-char sha
#   FAILED_STEP    step name for failure and warning messages
#   ACCESS_URL     link testers must sign in to reach (optional)
#   ACCESS_LABEL   link text for ACCESS_URL
#   INSTALL_NOTES  install guidance (optional)
#   SERVER_URL, REPOSITORY, RUN_ID  from the github context
#
set -euo pipefail

jq -n \
  --arg result "${RESULT:?RESULT is required}" \
  --arg os "${OS:-}" \
  --arg platform "${PLATFORM:-}" \
  --arg version "${VERSION_LABEL:-}" \
  --arg sdks "${SDK_INFO:-}" \
  --arg source "${SOURCE_LABEL:-}" \
  --arg event "${EVENT_NAME:-}" \
  --arg sha "${COMMIT_SHA:-}" \
  --arg short "${COMMIT_SHORT:-}" \
  --arg step "${FAILED_STEP:-an unknown step}" \
  --arg url "${ACCESS_URL:-}" \
  --arg urllabel "${ACCESS_LABEL:-Get the build}" \
  --arg notes "${INSTALL_NOTES:-}" \
  --arg server "${SERVER_URL:-https://github.com}" \
  --arg repo "${REPOSITORY:-}" \
  --arg run "${RUN_ID:-}" '
  def icon: if $result == "success" then "✅" elif $result == "warning" then "⚠️" else "❌" end;
  def headline:
    "\(icon) Flutter Example (\($os)) → \($platform)"
    + (if $result == "failure" then " deploy failed at \($step)"
       elif $result == "warning" then " notes failed at \($step)" else "" end);
  def runlink: "<\($server)/\($repo)/actions/runs/\($run)|CI run>";
  def commit:
    if $short == "" then runlink
    else "<\($server)/\($repo)/commit/\($sha)|\($short)> · " + runlink end;
  ([ (if $version != "" then "*Build:* \($version)" else empty end),
     (if $sdks != "" then "*SDKs:* \($sdks)" else empty end),
     (if $source != "" then "*Source:* \($source) (\($event))" else empty end),
     "*Commit:* " + commit,
     (if $url != "" then "*Get the build:* <\($url)|\($urllabel)>" else empty end),
     (if $notes != "" then $notes else empty end) ] | join("\n")) as $body
  | { text: headline,
      blocks: [
        { type: "header", text: { type: "plain_text", text: headline } },
        { type: "section", text: { type: "mrkdwn", text: $body } } ] }'
