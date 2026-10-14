#!/usr/bin/env bash
#
# Offline tests for check-secrets.sh: output shape, exit codes per event
# type, and that no secret value or length ever appears in the output.
#
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILURES=$((FAILURES + 1)); }
check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$name"; else fail "$name (expected '$expected', got '$actual')"; fi
}

ANDROID_SECRETS=(GOOGLE_SERVICES_JSON SIGNING_KEY ALIAS KEY_STORE_PASSWORD KEY_PASSWORD SERVICE_ACCOUNT_JSON)
IOS_SECRETS=(APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_BASE64 MATCH_PASSWORD MATCH_DEPLOY_KEY BUILD_CERTIFICATE_BASE64 P12_PASSWORD)

# run_secrets <platform> <event> <present...>: runs the check with the listed
# secrets set to a marker value; prints "rc=<n> ready=<bool> out=<stdout>".
run_secrets() {
  local platform="$1" event="$2"
  shift 2
  local pairs=()
  local s
  for s in "$@"; do
    pairs+=("$s=SECRET-VALUE-$s")
  done
  local out rc
  out="$(env -i PATH="$PATH" GITHUB_OUTPUT="$WORK/ghout" EVENT_NAME="$event" \
    "${pairs[@]}" \
    bash "$SCRIPTS/check-secrets.sh" "$platform" 2>&1)" && rc=0 || rc=$?
  local ready
  ready="$(grep '^ready=' "$WORK/ghout" 2>/dev/null | cut -d= -f2)"
  echo "rc=$rc"
  echo "ready=$ready"
  echo "out=$out"
  : > "$WORK/ghout"
}

# without <name> <list...>: prints the list minus the named entry.
without() {
  local drop="$1"
  shift
  local s
  for s in "$@"; do
    [ "$s" = "$drop" ] || printf '%s\n' "$s"
  done
}

# All present -> ready, exit 0 on every event type.
for event in push release workflow_dispatch pull_request; do
  result="$(run_secrets android "$event" "${ANDROID_SECRETS[@]}")"
  check "secrets: android ready ($event)" "rc=0
ready=true
out=All android deploy secrets are present" "$result"
done

# One missing on push -> skip quietly, exit 0, notice names the missing one.
mapfile -t ios_no_p12 < <(without P12_PASSWORD "${IOS_SECRETS[@]}")
result="$(run_secrets ios push "${ios_no_p12[@]}")"
check "secrets: push with one missing skips green" "rc=0" "$(head -1 <<<"$result")"
check "secrets: ready=false" "ready=false" "$(sed -n 2p <<<"$result")"
if grep -q '::notice::Skipping ios deploy, missing secrets: P12_PASSWORD' <<<"$result"; then
  pass "secrets: notice names the missing secret"
else
  fail "secrets: notice names the missing secret"
fi

# One missing on release -> same skip.
mapfile -t android_no_alias < <(without ALIAS "${ANDROID_SECRETS[@]}")
result="$(run_secrets android release "${android_no_alias[@]}")"
check "secrets: release with one missing skips green" "rc=0" "$(head -1 <<<"$result")"
if grep -q '::notice::Skipping android deploy, missing secrets: ALIAS' <<<"$result"; then
  pass "secrets: release notice names the missing secret"
else
  fail "secrets: release notice names the missing secret"
fi

# Missing on workflow_dispatch -> fail loudly.
result="$(run_secrets ios workflow_dispatch)"
check "secrets: dispatch with missing secrets fails" "rc=1" "$(head -1 <<<"$result")"
if grep -q '::error::Missing ios deploy secrets:' <<<"$result"; then
  pass "secrets: dispatch error names the missing secrets"
else
  fail "secrets: dispatch error names the missing secrets"
fi

# Missing on a label deploy (pull_request) -> fail loudly too.
result="$(run_secrets android pull_request)"
check "secrets: label deploy with missing secrets fails" "rc=1" "$(head -1 <<<"$result")"
if grep -q '::error::Missing android deploy secrets:' <<<"$result" && ! grep -q '::notice::' <<<"$result"; then
  pass "secrets: label deploy error names the missing secrets and is not a skip notice"
else
  fail "secrets: label deploy error names the missing secrets and is not a skip notice"
fi

# Empty string counts as missing.
out="$(env -i PATH="$PATH" GITHUB_OUTPUT="$WORK/ghout" EVENT_NAME=push \
  GOOGLE_SERVICES_JSON=x SIGNING_KEY='' ALIAS=x KEY_STORE_PASSWORD=x KEY_PASSWORD=x SERVICE_ACCOUNT_JSON=x \
  bash "$SCRIPTS/check-secrets.sh" android 2>&1)"
if grep -q 'SIGNING_KEY' <<<"$out"; then pass "secrets: empty string counts as missing"; else fail "secrets: empty string counts as missing"; fi
: > "$WORK/ghout"

# No secret value ever appears in the output.
result="$(run_secrets ios push)"
if grep -q 'SECRET-VALUE' <<<"$result"; then
  fail "secrets: output never contains a value"
else
  pass "secrets: output never contains a value"
fi
result="$(run_secrets android push "${ANDROID_SECRETS[@]}")"
if grep -q 'SECRET-VALUE' <<<"$result"; then
  fail "secrets: ready output never contains a value"
else
  pass "secrets: ready output never contains a value"
fi

# Optional secrets are ignored: missing SLACK_WEBHOOK_URL and APPLE_TEAM_ID
# keep ready=true.
result="$(run_secrets android push "${ANDROID_SECRETS[@]}")"
check "secrets: optional webhook/team id are not required" "ready=true" "$(sed -n 2p <<<"$result")"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "All check-secrets tests passed"
