#!/usr/bin/env bash
#
# Offline tests for slack-payload.sh: valid JSON for hostile values, the
# agreed message layout, and the success / failure / warning headlines.
#
# The hostile fixture below holds literal $(...) and backticks on purpose.
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/slack-payload.sh"
FAILURES=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
check() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

base() {
  env -i PATH="$PATH" SERVER_URL=https://github.com REPOSITORY=klaviyo/r RUN_ID=9 \
    OS=iOS PLATFORM=TestFlight VERSION_LABEL='0.3.2-alpha.1 (7)' \
    SDK_INFO='Flutter 0.3.2-alpha.1 | iOS 5.4.1' SOURCE_LABEL='feat/x (PR #138)' \
    EVENT_NAME=pull_request COMMIT_SHA=abcdef0123 COMMIT_SHORT=abcdef0 "$@" "$SCRIPT"
}

out="$(base RESULT=success ACCESS_URL=https://example.com/x ACCESS_LABEL='TestFlight')"
check "success: valid JSON" "ok" "$(jq -e . >/dev/null <<<"$out" && echo ok)"
check "success: headline" "✅ Flutter Example (iOS) → TestFlight" "$(jq -r .text <<<"$out")"
check "success: body layout" \
  "*Build:* 0.3.2-alpha.1 (7)
*SDKs:* Flutter 0.3.2-alpha.1 | iOS 5.4.1
*Source:* feat/x (PR #138) (pull_request)
*Commit:* <https://github.com/klaviyo/r/commit/abcdef0123|abcdef0> · <https://github.com/klaviyo/r/actions/runs/9|CI run>
*Get the build:* <https://example.com/x|TestFlight>" \
  "$(jq -r '.blocks[1].text.text' <<<"$out")"

out="$(base RESULT=failure FAILED_STEP='sign, build and upload')"
check "failure: headline names the step" \
  "❌ Flutter Example (iOS) → TestFlight deploy failed at sign, build and upload" "$(jq -r .text <<<"$out")"

out="$(base RESULT=warning FAILED_STEP='saving What to Test')"
check "warning: headline" \
  "⚠️ Flutter Example (iOS) → TestFlight notes failed at saving What to Test" "$(jq -r .text <<<"$out")"

out="$(base RESULT=success INSTALL_NOTES=$'Line one "quoted"\nLine two <!channel> $(whoami) `id`' \
  SOURCE_LABEL='a"b')"
check "hostile values: valid JSON" "ok" "$(jq -e . >/dev/null <<<"$out" && echo ok)"
# Shell-looking text stays literal (it is only text), and <!channel> is escaped so it cannot ping.
check "hostile values: shell text stays literal, the ping is escaped, one message" \
  'Line one "quoted"
Line two &lt;!channel&gt; $(whoami) `id`' \
  "$(jq -r '.blocks[1].text.text' <<<"$out" | tail -2)"

out="$(base RESULT=success COMMIT_SHORT='' COMMIT_SHA='')"
check "no commit: CI run link only" "*Commit:* <https://github.com/klaviyo/r/actions/runs/9|CI run>" \
  "$(jq -r '.blocks[1].text.text' <<<"$out" | grep '^\*Commit')"

out="$(base RESULT=failure)"
check "failure without a step name falls back" \
  "❌ Flutter Example (iOS) → TestFlight deploy failed at an unknown step" "$(jq -r .text <<<"$out")"

# Branch- and tag-derived text is escaped so <!channel>, <!here> and <url|text> cannot render. Git allows
# <!channel> in a branch name, so this is reachable. The links the payload builds itself stay markup.
out="$(base RESULT=success SDK_INFO='Flutter 1.2.3 · feat/<!channel>@abc1234 | iOS 5.4.1' \
  SOURCE_LABEL='feat/<!here>&x (PR #1)' VERSION_LABEL='1.0<!everyone>' COMMIT_SHORT='a<b' \
  INSTALL_NOTES='<https://evil.example|click me> & <!channel>' ACCESS_URL=https://ok.example/x ACCESS_LABEL='get <it>')"
body="$(jq -r '.blocks[1].text.text' <<<"$out")"
check "mrkdwn: a branch in the SDK line cannot ping the channel" "*SDKs:* Flutter 1.2.3 · feat/&lt;!channel&gt;@abc1234 | iOS 5.4.1" "$(grep '^\*SDKs' <<<"$body")"
check "mrkdwn: the source label is escaped and keeps its ampersand as an entity" "*Source:* feat/&lt;!here&gt;&amp;x (PR #1) (pull_request)" "$(grep '^\*Source' <<<"$body")"
check "mrkdwn: the build line is escaped" "*Build:* 1.0&lt;!everyone&gt;" "$(grep '^\*Build' <<<"$body")"
check "mrkdwn: install notes cannot render a link or a ping" "&lt;https://evil.example|click me&gt; &amp; &lt;!channel&gt;" "$(tail -1 <<<"$body")"
check "mrkdwn: the access link keeps its markup and only its text is escaped" "*Get the build:* <https://ok.example/x|get &lt;it&gt;>" "$(grep '^\*Get the build' <<<"$body")"
check "mrkdwn: the commit and CI links keep their markup" "1" "$(grep -c '^\*Commit:\* <https://github.com/klaviyo/r/commit/abcdef0123|a&lt;b> · <https://github.com/klaviyo/r/actions/runs/9|CI run>$' <<<"$body" | tr -d ' ')"
head_text="$(jq -r .text <<<"$(base RESULT=failure FAILED_STEP='build <!channel>' OS='i<OS>')")"
check "mrkdwn: the failed step is escaped in the headline too" "❌ Flutter Example (i&lt;OS&gt;) → TestFlight deploy failed at build &lt;!channel&gt;" "$head_text"
none="$(jq -r '.blocks[1].text.text' <<<"$out" | grep -c '<!channel>\|<!here>\|<!everyone>' || true)"
check "mrkdwn: no raw broadcast mention survives anywhere in the message" "0" "$none"

if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES test(s) failed"; exit 1; fi
echo "All slack payload tests passed"
