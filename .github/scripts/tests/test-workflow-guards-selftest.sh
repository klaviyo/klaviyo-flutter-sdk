#!/usr/bin/env bash
# Self-test for test-workflow-guards.sh. Each case breaks a copy of the workflows
# and actions in one way, asserts the break really changed the file, and expects
# the guard to fail on the matching rule. A guard that passes on a broken
# workflow proves nothing.
#
# Prints one PASS/FAIL line per case and exits non-zero if any case fails.
# The mutations contain ${{ }} expressions inside single quotes on purpose.
# shellcheck disable=SC2016
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0

report() {
  if (($1 == 0)); then
    echo "PASS: $2"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL: $2"
    FAILED=$((FAILED + 1))
  fi
}

# The guard reads the repo's scripts, so the copy keeps the same layout under $TMP/repo.
fresh_copy() {
  rm -rf "$TMP/repo"
  mkdir -p "$TMP/repo/.github/workflows" "$TMP/repo/.github/actions" "$TMP/repo/.github/scripts/tests"
  cp "$ROOT"/.github/workflows/*.yml "$TMP/repo/.github/workflows/"
  cp -R "$ROOT"/.github/actions/. "$TMP/repo/.github/actions/"
  cp "$ROOT/.github/scripts/check-secrets.sh" "$TMP/repo/.github/scripts/"
  cp "$ROOT/.github/scripts/tests/test-workflow-guards.py" "$TMP/repo/.github/scripts/tests/"
}

run_guard() {
  python3 -B "$TMP/repo/.github/scripts/tests/test-workflow-guards.py" > "$TMP/out.log" 2>&1
}

# expect_fail <name> <expected FAIL text>: the guard must exit non-zero and name the broken rule
expect_fail() {
  if run_guard; then
    report 1 "$1 (guard passed on a broken workflow)"
  elif grep -q "^FAIL: .*$2" "$TMP/out.log"; then
    report 0 "$1"
  else
    report 1 "$1 (guard failed, but not on '$2')"
  fi
}

expect_pass() {
  if run_guard; then
    report 0 "$1"
  else
    report 1 "$1 (guard failed on a safe workflow)"
  fi
}

# edit <file> <python body>: rewrites a file. The body gets `s` and must assign `s`. The edit
# aborts the self-test if it did not change the file, so a case cannot pass by mutating nothing.
edit() {
  python3 - "$1" "$2" <<'PY' || { echo "FAIL: a mutation did not apply, so its case proves nothing"; exit 1; }
import sys
path, body = sys.argv[1], sys.argv[2]
s = open(path).read()
before = s
scope = {"s": s}
exec(body, scope)
if scope["s"] == before:
    sys.exit("mutation did not change the file: " + body[:90])
open(path, "w").write(scope["s"])
PY
}

W="$TMP/repo/.github/workflows"
DEPLOY="$W/publish-example.yml"
TEST_WF="$W/test.yml"
SLACK="$TMP/repo/.github/actions/notify-slack-publish/action.yml"
SECRETS="$TMP/repo/.github/scripts/check-secrets.sh"

fresh_copy
expect_pass "the guard passes on the real workflows"

fresh_copy
edit "$SLACK" 's = s.replace("inputs.commit_sha || github.sha", "substr(inputs.commit_sha, 0, 7) || github.sha", 1)'
expect_fail "substr in an expression is caught" "expressions only call functions"

fresh_copy
edit "$DEPLOY" 's = s.replace("needs.preflight-android.outputs.ready == \x27true\x27", "toLower(needs.preflight-android.outputs.ready) == \x27true\x27", 1)'
expect_fail "an unknown function in a job-level if is caught" "expressions only call functions"

fresh_copy
edit "$DEPLOY" 's = s.replace("RELEASE_TAG: ${{ github.event.release.tag_name }}", "RELEASE_TAG: ${{ toLower(github.event.release.tag_name) }}", 1)'
expect_fail "an unknown function inside an expression is caught" "expressions only call functions"

# --- checkouts

fresh_copy
edit "$DEPLOY" 's = s.replace("          persist-credentials: false\n          ref:", "          ref:", 1)'
expect_fail "a checkout that persists credentials is caught" "every checkout sets persist-credentials"

fresh_copy
edit "$TEST_WF" 's = s.replace("        with:\n          persist-credentials: false\n", "", 1)'
expect_fail "an unsafe checkout in a reusable workflow the deploy calls is caught" "every checkout sets persist-credentials"

fresh_copy
edit "$DEPLOY" 's = s.replace("          fetch-depth: 2\n          persist-credentials: false\n          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n", "          persist-credentials: false\n          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n          fetch-depth: 2\n", 1)'
expect_pass "persist-credentials is found wherever it sits in the with block"

fresh_copy
edit "$DEPLOY" 's = s.replace("          fetch-depth: 2\n          persist-credentials: false\n          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n", "          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n          fetch-depth: 2\n          submodules: false\n          lfs: false\n          clean: true\n          persist-credentials: true\n", 1)'
expect_fail "persist-credentials: true far below uses is caught" "every checkout sets persist-credentials"

fresh_copy
edit "$DEPLOY" 's = s.replace("    steps:\n      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4\n        with:\n          persist-credentials: false\n\n      - name: Check Android deploy secrets", "    steps:\n      - name: Check Android deploy secrets", 1)'
expect_fail "a preflight that runs a repo script without a checkout is caught" "the preflight-android job checks out the repository"

# --- Slack

fresh_copy
edit "$DEPLOY" '
i = s.index("      - name: Notify Slack on success")
j = s.index("        continue-on-error: true\n", i)
s = s[:j] + s[j + len("        continue-on-error: true\n"):]
'
expect_fail "a Slack step without continue-on-error is caught" "every Slack step has continue-on-error"

fresh_copy
edit "$DEPLOY" '
i = s.index("      - name: Warn in Slack that What to Test failed")
j = s.index("        continue-on-error: true\n", i)
s = s[:j] + s[j + len("        continue-on-error: true\n"):]
'
expect_fail "a notes warning step without continue-on-error is caught" "every Slack step has continue-on-error"

fresh_copy
edit "$DEPLOY" '
i = s.index("      - name: Notify Slack on failure")
j = s.index("        continue-on-error: true\n", i)
s = s[:j] + s[j + len("        continue-on-error: true\n"):]
'
expect_fail "a failure notifier without continue-on-error is caught" "every Slack step has continue-on-error"

fresh_copy
edit "$DEPLOY" '
s = s.replace("      - name: Notify Slack on success", "      - name: Tell the channel", 1)
i = s.index("      - name: Tell the channel")
j = s.index("        continue-on-error: true\n", i)
s = s[:j] + s[j + len("        continue-on-error: true\n"):]
'
expect_fail "a renamed Slack step is still found by the action it uses" "every Slack step has continue-on-error"

fresh_copy
edit "$SLACK" '
i = s.index("    - name: Build Slack payload")
j = s.index("      continue-on-error: true\n", i)
s = s[:j] + s[j + len("      continue-on-error: true\n"):]
'
expect_fail "a Slack payload step that can fail the job is caught" "the Slack action tolerates a failure of its own payload step"

fresh_copy
edit "$SLACK" 's = s.replace("payload-file-path: ${{ runner.temp }}/slack-payload.json", "payload: |\n          text: \"x ${{ inputs.version_label }}\"", 1)'
expect_fail "a YAML payload block is caught" "the Slack payload is sent from a JSON file"

fresh_copy
edit "$DEPLOY" 's = s.replace("      - name: Clean up signing material\n        if: always()\n        run: rm -f", "      - uses: slackapi/slack-github-action@91efab103c0de0a537f72a35f6b8cda0ee76bf0a\n        with:\n          webhook: x\n      - name: Clean up signing material\n        if: always()\n        run: rm -f", 1)'
expect_fail "a direct Slack post that bypasses the composite action is caught" "Slack is only posted through the composite action"

# --- preflight

fresh_copy
edit "$DEPLOY" 's = s.replace("  preflight-ios:\n", "  preflight-ios:\n    environment: testflight\n", 1)'
expect_fail "a preflight that declares an environment is caught" "the preflight-ios job declares no environment"

fresh_copy
edit "$DEPLOY" 's = s.replace("          P12_PASSWORD: ${{ secrets.P12_PASSWORD }}\n        run: .github/scripts/check-secrets.sh ios", "          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}\n        run: .github/scripts/check-secrets.sh ios", 1)'
expect_fail "SLACK_WEBHOOK_URL in the preflight is caught" "SLACK_WEBHOOK_URL is not a required secret in preflight-ios"

fresh_copy
edit "$SECRETS" 's = s.replace("MATCH_PASSWORD MATCH_DEPLOY_KEY", "MATCH_PASSWORD SLACK_WEBHOOK_URL MATCH_DEPLOY_KEY", 1)'
expect_fail "SLACK_WEBHOOK_URL in the required-secrets list is caught" "check-secrets.sh never requires SLACK_WEBHOOK_URL"

# --- event fields and commit

fresh_copy
edit "$DEPLOY" '
i = s.index("  deploy-ios:")
j = s.index("          RELEASE_TAG: ${{ github.event.release.tag_name }}\n", i)
s = s[:j] + s[j + len("          RELEASE_TAG: ${{ github.event.release.tag_name }}\n"):]
'
expect_fail "a stamping step missing RELEASE_TAG is caught" "the deploy-ios stamping step sets the shared event fields"

fresh_copy
edit "$DEPLOY" '
i = s.index("  deploy-android:")
j = s.index("          HEAD_REF: ${{ github.head_ref }}\n", i)
s = s[:j] + s[j + len("          HEAD_REF: ${{ github.head_ref }}\n"):]
'
expect_fail "a stamping step missing the head ref is caught" "the deploy-android stamping step sets the shared event fields"

fresh_copy
edit "$DEPLOY" 's = s.replace("          ref: ${{ github.event.pull_request.head.sha || github.sha }}", "          ref: ${{ github.sha }}", 1)'
expect_fail "building the merge commit is caught" "builds the pull request head, not the merge commit"

# --- notes inputs

fresh_copy
edit "$DEPLOY" 's = s.replace("          RELEASE_BODY: ${{ github.event.release.body }}\n          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\n          NOTES_CMD:", "          NOTES_CMD:", 1)'
expect_fail "an Android notes command without the release body and run url is caught" "the deploy-android notes command gets"

fresh_copy
edit "$DEPLOY" 's = s.replace("\"$RUNNER_TEMP/release-body.txt\"\x27", "/dev/null\x27", 1) if False else s.replace("release-notes.sh 500 android build-info.json \"$BUILD_NUMBER\" \"$RUNNER_TEMP/release-body.txt\"", "release-notes.sh 500 android build-info.json \"$BUILD_NUMBER\" /dev/null", 1)'
expect_fail "an Android notes command that passes /dev/null as the body is caught" "the deploy-android notes command gets"

fresh_copy
edit "$DEPLOY" 's = s.replace("set-whats-new \"$IOS_MARKETING_VERSION\" \"$BUILD_NUMBER\"", "set-whats-new \"$BUILD_NUMBER\"", 1)'
expect_fail "a What to Test lookup by build number alone is caught" "what-to-test looks the build up by the iOS marketing version"

fresh_copy
edit "$DEPLOY" 's = s.replace("            echo \"ios_marketing_version=$IOS_MARKETING_VERSION\"\n", "", 1)'
expect_fail "a missing stripped marketing version output is caught" "the deploy-ios result step exports the stripped marketing version"

# --- gating

fresh_copy
edit "$DEPLOY" 's = s.replace("    needs: [gate-test, gate-lint, preflight-ios]", "    needs: [preflight-ios]", 1)'
expect_fail "a deploy that does not wait for the gates is caught" "the deploy-ios job needs the test and lint gates"

fresh_copy
edit "$DEPLOY" 's = s.replace("        || (needs.gate-test.result == \x27success\x27 && needs.gate-lint.result == \x27success\x27))", "        || needs.gate-test.result != \x27failure\x27)", 1)'
expect_fail "a deploy that lets a skipped gate through is caught" "requires the gates to have succeeded"

# --- fork pull requests: every job a pull_request can reach checks the head repo itself

for job in gate-test gate-lint preflight-android preflight-ios deploy-android deploy-ios what-to-test cleanup-label; do
  fresh_copy
  JOB="$job" edit "$DEPLOY" '
import os
job = os.environ["JOB"]
i = s.index("\n  " + job + ":\n")
j = s.index("\n  ", i + 3 + len(job)) if "\n  " in s[i + 3 + len(job):] else len(s)
# cut the job at the next top-level job id
import re
m = re.search(r"\n  [a-z][a-z0-9-]*:\n", s[i + 1:])
end = i + 1 + m.start() if m else len(s)
body = s[i:end]
new = body.replace("github.event.pull_request.head.repo.full_name == github.repository", "true")
assert new != body, "no same-repo condition to remove in " + job
s = s[:i] + new + s[end:]
'
  expect_fail "a $job job without the same-repo check is caught" "the $job job requires a same-repo pull request"
done

fresh_copy
edit "$DEPLOY" 's = s.replace("  pull_request:\n    types: [labeled]", "  pull_request:\n    types: [labeled, synchronize]", 1)'
expect_fail "a trigger that also fires on every push to a PR is caught" "the pull_request trigger is labeled only"

fresh_copy
edit "$DEPLOY" 's = s.replace("      always()\n      && github.event_name == \x27pull_request\x27", "      github.event_name == \x27pull_request\x27", 1)'
expect_fail "a label cleanup without always() is caught" "the label cleanup runs with always()"

echo
echo "$PASSED passed, $FAILED failed"
if ((FAILED > 0)); then
  exit 1
fi
echo "All guard self-tests passed"
