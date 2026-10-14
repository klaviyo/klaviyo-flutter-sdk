#!/usr/bin/env bash
#
# Offline tests for source-label.sh and ios-marketing-version.sh.
#
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$name"; else fail "$name (expected '$expected', got '$actual')"; fi
}

# ---------------------------------------------------------------- source-label.sh

check "label: push to a branch" "feat/x" "$(
  EVENT_NAME=push RELEASE_TAG='' HEAD_REF='' PR_NUMBER='' REF_NAME=feat/x \
    "$SCRIPTS/source-label.sh"
)"

check "label: release names the tag" "release 1.2.3-alpha.1" "$(
  EVENT_NAME=release RELEASE_TAG=1.2.3-alpha.1 HEAD_REF='' PR_NUMBER='' REF_NAME=1.2.3-alpha.1 \
    "$SCRIPTS/source-label.sh"
)"

check "label: PR label deploy uses head ref and PR number" "feat/y (PR #138)" "$(
  EVENT_NAME=pull_request RELEASE_TAG='' HEAD_REF=feat/y PR_NUMBER=138 REF_NAME=138/merge \
    "$SCRIPTS/source-label.sh"
)"

check "label: hostile value is sanitized" "release x(rm -rf /)channel.cd" "$(
  EVENT_NAME=release RELEASE_TAG=$'x`$(rm -rf /)`<!channel>\n.c;d' HEAD_REF='' PR_NUMBER='' REF_NAME=x \
    "$SCRIPTS/source-label.sh"
)"
# Backticks, $, <, >, ! and newlines must never survive.
out="$(EVENT_NAME=release RELEASE_TAG=$'x`$(y)`<!c>\nz' HEAD_REF='' PR_NUMBER='' REF_NAME=x "$SCRIPTS/source-label.sh")"
if printf '%s' "$out" | grep -qE '[`$<>!]'; then
  fail "label: no dangerous characters survive"
else
  pass "label: no dangerous characters survive"
fi
check "label: newlines stripped" "1" "$(printf '%s' "$out" | grep -c .)"

# ---------------------------------------------------------------- ios-marketing-version.sh

MV="$SCRIPTS/ios-marketing-version.sh"
check "marketing: plain version" "0.3.2" "$("$MV" 0.3.2)"
check "marketing: prerelease stripped" "0.3.2" "$("$MV" 0.3.2-alpha.1)"
check "marketing: prerelease and build metadata stripped" "0.3.2" "$("$MV" 0.3.2-rc.1+meta)"
check "marketing: two-part version kept" "0.3" "$("$MV" 0.3)"
if "$MV" abc >/dev/null 2>&1; then fail "marketing: rejects non-numeric"; else pass "marketing: rejects non-numeric"; fi
if "$MV" 1.2.3.4 >/dev/null 2>&1; then fail "marketing: rejects four components"; else pass "marketing: rejects four components"; fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All source-label / marketing-version tests passed"
