#!/usr/bin/env bash
#
# Prints the Slack message payload (JSON) for an example app or SDK publish result.
# Every value arrives through the environment and is encoded by jq, so
# newlines, quotes and Slack markup in a value cannot break the request.
#
# Usage: slack-payload.sh > payload.json
#
# Env:
#   RESULT         success | failure | warning | pending
#   OS             iOS | Android
#   PLATFORM       store label, e.g. "TestFlight", "Play internal"
#   TITLE          headline subject (optional, replaces the OS/PLATFORM headline)
#   VERSION_LABEL  full version with build number
#   VERSION_HEADING  label for VERSION_LABEL (default "Build")
#   RELEASE_URL    GitHub release page (optional)
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
  --arg title "${TITLE:-}" \
  --arg version "${VERSION_LABEL:-}" \
  --arg versionheading "${VERSION_HEADING:-Build}" \
  --arg release "${RELEASE_URL:-}" \
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
  # Slack mrkdwn treats & < > as control characters: <!channel> pings everyone and <url|text> renders a
  # link. A branch or tag may contain them (git allows <!channel> as a branch name), so every value that
  # comes from one is escaped before it is placed in the message. The links built below are markup on
  # purpose and are not escaped; only their text is.
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  def icon: if $result == "success" then "✅" elif $result == "warning" then "⚠️" elif $result == "pending" then "⏳" else "❌" end;
  def headline:
    "\(icon) "
    + (if $title != "" then ($title | esc) else "Flutter Example (\($os | esc)) → \($platform | esc)" end)
    + (if $result == "failure" then " deploy failed at \($step | esc)"
       elif $result == "warning" then " notes failed at \($step | esc)" else "" end);
  def runlink: "<\($server)/\($repo)/actions/runs/\($run)|CI run>";
  def commit:
    if $short == "" then runlink
    else "<\($server)/\($repo)/commit/\($sha)|\($short | esc)> · " + runlink end;
  ([ (if $version != "" then "*\($versionheading | esc):* \($version | esc)" else empty end),
     (if $release != "" then "*Release:* <\($release)|GitHub release>" else empty end),
     (if $sdks != "" then "*SDKs:* \($sdks | esc)" else empty end),
     (if $source != "" then "*Source:* \($source | esc) (\($event | esc))" else empty end),
     "*Commit:* " + commit,
     (if $url != "" then "*Get the build:* <\($url)|\($urllabel | esc)>" else empty end),
     (if $notes != "" then ($notes | esc) else empty end) ] | join("\n")) as $body
  | { text: headline,
      blocks: [
        { type: "header", text: { type: "plain_text", text: (headline | .[0:150]) } },
        { type: "section", text: { type: "mrkdwn", text: $body } } ] }'
