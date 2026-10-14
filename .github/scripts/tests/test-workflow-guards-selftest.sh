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
  cp "$ROOT/.github/dependabot.yml" "$TMP/repo/.github/"
  cp "$ROOT/.github/scripts/check-secrets.sh" "$TMP/repo/.github/scripts/"
  mkdir -p "$TMP/repo/scripts"
  cp "$ROOT/scripts/sdk-ref.sh" "$TMP/repo/scripts/"
  cp "$ROOT/.github/scripts/tests/test-workflow-guards.py" "$TMP/repo/.github/scripts/tests/"
  cp "$ROOT/.github/scripts/lint-action-shell.py" "$TMP/repo/.github/scripts/"
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
CHECKS="$W/publish-example-checks.yml"
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

fresh_copy
edit "$SLACK" 's = s.replace("inputs.commit_sha || github.sha", "SubStr(inputs.commit_sha, 0, 7) || github.sha", 1)'
expect_fail "a mixed-case unsupported function is caught" "expressions only call functions"

fresh_copy
edit "$DEPLOY" 's = s.replace("needs.preflight-android.outputs.ready == \x27true\x27", "CONTAINS(needs.preflight-android.outputs.ready, \x27true\x27)", 1)'
expect_pass "a supported function in other casing is accepted"

# --- pinned actions

LINT_WF="$W/lint.yml"
VERSION_WF="$W/version-check.yml"

fresh_copy
edit "$TEST_WF" 's = s.replace("uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4", "uses: actions/checkout@v4", 1)'
expect_fail "an unpinned action in a workflow the deploy calls is caught" "every action is pinned to a full commit SHA"

fresh_copy
edit "$TEST_WF" 's = s.replace("uses: codecov/codecov-action@b9fd7d16f6d7d1b5d2bec1a2887e65ceed900238 # v4.6.0", "uses: codecov/codecov-action@v4", 1)'
expect_fail "an unpinned third-party action is caught" "every action is pinned to a full commit SHA"

fresh_copy
edit "$LINT_WF" 's = s.replace("uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2", "uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2", 1)'
expect_fail "a pinned action with no version comment is caught" "every action is pinned to a full commit SHA"

fresh_copy
edit "$LINT_WF" 's = s.replace("uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2", "uses: subosito/flutter-action@1a44944 # v2", 1)'
expect_fail "an abbreviated SHA is caught" "every action is pinned to a full commit SHA"

fresh_copy
edit "$VERSION_WF" 's = s.replace("uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4", "uses: actions/checkout@v4", 1)'
expect_fail "an unpinned action in version-check.yml is caught" "every action is pinned to a full commit SHA"

fresh_copy
edit "$VERSION_WF" 's = s.replace("        with:\n          persist-credentials: false\n", "", 1)'
expect_fail "version-check.yml checking out with credentials is caught" "every checkout sets persist-credentials"

# --- lint coverage

fresh_copy
mkdir -p "$TMP/repo/.github/tools"
printf '#!/usr/bin/env bash\necho hi\n' > "$TMP/repo/.github/tools/new-helper.sh"
expect_fail "a script added outside the shellcheck globs is caught" "the shellcheck step covers every script"

fresh_copy
edit "$CHECKS" 's = s.replace("shellcheck .github/scripts/*.sh .github/scripts/tests/*.sh scripts/sdk-ref.sh", "shellcheck .github/scripts/*.sh .github/scripts/tests/*.sh", 1)'
expect_fail "dropping scripts/sdk-ref.sh from the shellcheck step is caught" "the shellcheck step covers every script"

# --- script injection: each untrusted source inside a run script is caught, runner paths are not

inject_case() { # <label> <expression to place in a run script> <expect: fail|pass>
  fresh_copy
  # An extra step, so every other rule still sees the workflow it expects.
  JUNK="$2" edit "$W/publish-example-checks.yml" '
import os
i = s.index("      - name: Lint composite action shell")
s = s[:i] + "      - name: Probe\n        run: echo " + os.environ["JUNK"] + "\n\n" + s[i:]
'
  if [ "$3" = fail ]; then
    expect_fail "$1" "no run script interpolates a branch, tag, release"
  else
    expect_pass "$1"
  fi
}
inject_case "a branch name in a run script is caught" '${{ github.head_ref }}' fail
inject_case "ref_name in a run script is caught" '${{ github.ref_name }}' fail
inject_case "a release body in a run script is caught" '${{ github.event.release.body }}' fail
inject_case "a release name in a run script is caught" '${{ github.event.release.name }}' fail
inject_case "a pull request title in a run script is caught" '${{ github.event.pull_request.title }}' fail
inject_case "a step output in a run script is caught" '${{ steps.buildinfo.outputs.sdk_info }}' fail
inject_case "a job output in a run script is caught" '${{ needs.deploy-ios.outputs.source_label }}' fail
inject_case "a workflow input in a run script is caught" '${{ inputs.platform }}' fail
inject_case "an env context value in a run script is caught" '${{ env.SOURCE_LABEL }}' fail
inject_case "the case-insensitive spelling of a context is caught" '${{ GitHub.Head_Ref }}' fail
inject_case "the action path in a run script is allowed" '${{ github.action_path }}' pass
inject_case "the runner temp directory in a run script is allowed" '${{ runner.temp }}' pass
inject_case "the run id in a run script is allowed" '${{ github.run_id }}' pass

# a secret in an env: block is the safe form and must not be flagged
fresh_copy
expect_pass "values in env: blocks are not flagged"

# --- portability: each one-sided flag is caught, the portable forms are not

portable_case() { # <label> <script line> <expect: fail|pass>
  fresh_copy
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$TMP/repo/.github/scripts/probe.sh"
  if [ "$3" = fail ]; then
    expect_fail "$1" "no scripts use flags that exist on only one of macOS and Linux"
  else
    expect_pass "$1"
  fi
}
portable_case "mktemp -d -p is caught" 'D="$(mktemp -d -p /tmp)"' fail
portable_case "date -d is caught" 'date -d yesterday' fail
portable_case "readlink -f is caught" 'readlink -f "$0"' fail
portable_case "stat -c is caught" 'stat -c %s "$f"' fail
portable_case "sed -i with no suffix argument is caught" "sed -i 's/a/b/' \"\$f\"" fail
portable_case "sed -i with a separate empty suffix is caught, GNU reads it as the script" "sed -i '' 's/a/b/' \"\$f\"" fail
portable_case "sed -i with an attached empty suffix is caught, BSD reads it as a bare -i" "sed -i'' 's/a/b/' \"\$f\"" fail
portable_case "grep -P is caught" "grep -P '\\d+' \"\$f\"" fail
portable_case "the portable mktemp template form is accepted" 'D="$(mktemp -d "${TMPDIR:-/tmp}/x.XXXXXX")"' pass
portable_case "sed -i with a suffix is accepted" "sed -i.bak 's/a/b/' \"\$f\"" pass
portable_case "a flag named only in a comment is accepted" '# do not use date -d here' pass

# --- composite actions

fresh_copy
edit "$CHECKS" '
i = s.index("      - name: Lint composite action shell")
j = s.index("      # An Internal App Sharing path does not resolve", i)
s = s[:i] + s[j:]
'
expect_fail "dropping the composite action shell lint is caught" "the checks workflow shellchecks the composite actions"

fresh_copy
edit "$DEPLOY" 's = s.replace("uses: ./.github/actions/notify-slack-publish", "uses: ./.github/actions/notify-slack-renamed", 1)'
expect_fail "a workflow using a local action that is not under .github/actions is caught" "every local action the workflows use is found"

# A nested directory is not reached by .github/scripts/*.sh: the shell's * does not cross a /. A script in
# .github/scripts/lib/ must fail the coverage check even though fnmatch would call it covered.
fresh_copy
mkdir -p "$TMP/repo/.github/scripts/lib"
printf '#!/usr/bin/env bash\necho hi\n' > "$TMP/repo/.github/scripts/lib/helper.sh"
expect_fail "a script one directory below a lint glob is caught, as the shell would not reach it" "the shellcheck step covers every script"

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

# --- every stamper call carries the event fields

fresh_copy
edit "$CHECKS" '
i = s.index("      - name: Build release App Bundle")
j = s.index("        env:\n", i)
k = s.index("        run: |\n", j)
s = s[:j] + s[k:]
'
expect_fail "a dry-run stamper call with no env is caught" "every step that runs sdk-ref.sh passes the shared event fields"

fresh_copy
edit "$CHECKS" '
i = s.index("      - name: Build unsigned release archive")
j = s.index("          PR_NUMBER: ${{ github.event.pull_request.number }}\n", i)
s = s[:j] + s[j + len("          PR_NUMBER: ${{ github.event.pull_request.number }}\n"):]
'
expect_fail "a dry-run stamper call missing PR_NUMBER is caught" "every step that runs sdk-ref.sh passes the shared event fields"

fresh_copy
edit "$DEPLOY" '
i = s.index("  deploy-android:")
j = s.index("      - uses: actions/setup-java@", i)
s = s[:j] + "      - name: Seed versions\n        run: ./scripts/sdk-ref.sh\n\n" + s[j:]
'
expect_fail "a new seed step that calls the stamper bare is caught" "every step that runs sdk-ref.sh passes the shared event fields"

# A step that only passes the stamper's path to another command (the lint step runs shellcheck on it) is
# not a stamper call and must not be asked for the event fields.
fresh_copy
edit "$CHECKS" '
i = s.index("      - name: Lint scripts")
j = s.index("          shellcheck .github/scripts/", i)
s = s[:j] + "          shellcheck scripts/sdk-ref.sh .github/scripts/*.sh\n" + s[j:]
'
expect_pass "passing sdk-ref.sh to shellcheck is not mistaken for running it"

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

# --- what to test needs a build

fresh_copy
edit "$DEPLOY" 's = s.replace("      needs.deploy-ios.result == \x27success\x27\n      && inputs.check_credentials != true\n", "      needs.deploy-ios.result == \x27success\x27\n", 1)'
expect_fail "what-to-test running on a check_credentials run is caught" "the what-to-test job does not run on a check_credentials run"

fresh_copy
edit "$DEPLOY" 's = s.replace("      && inputs.check_credentials != true\n      && (github.event_name != \x27pull_request\x27 || github.event.pull_request.head.repo.full_name == github.repository)\n    runs-on: ubuntu-24.04\n    timeout-minutes: 60", "      && (inputs.check_credentials != true || true)\n      && (github.event_name != \x27pull_request\x27 || github.event.pull_request.head.repo.full_name == github.repository)\n    runs-on: ubuntu-24.04\n    timeout-minutes: 60", 1)'
expect_fail "a what-to-test condition that ORs the check away is caught" "the what-to-test job does not run on a check_credentials run"

fresh_copy
edit "$DEPLOY" 's = s.replace("      needs.deploy-ios.result == \x27success\x27\n      && inputs.check_credentials != true\n", "      needs.deploy-ios.result == \x27success\x27 || inputs.check_credentials != true\n", 1)'
expect_fail "a what-to-test condition with a top-level OR is caught" "the what-to-test job does not run on a check_credentials run"

# --- network timeouts

fresh_copy
edit "$CHECKS" 's = s.replace("curl --connect-timeout 15 --max-time 120 -fsSLo shellcheck.tar.xz", "curl -fsSLo shellcheck.tar.xz", 1)'
expect_fail "a workflow curl with no timeouts is caught" "every curl sets --connect-timeout and --max-time"

fresh_copy
edit "$CHECKS" 's = s.replace("curl --connect-timeout 15 --max-time 120 -fsSLo actionlint.tar.gz", "curl --connect-timeout 15 -fsSLo actionlint.tar.gz", 1)'
expect_fail "a curl with a connect timeout but no total limit is caught" "every curl sets --connect-timeout and --max-time"

# --- dependabot

fresh_copy
edit "$TMP/repo/.github/dependabot.yml" 's = s.replace("      - /.github/actions/*\n", "", 1)'
expect_fail "dependabot not watching the composite action directory is caught" "dependabot watches the workflows and every composite action directory"

fresh_copy
edit "$TMP/repo/.github/dependabot.yml" 's = s.replace("      - /\n", "", 1)'
expect_fail "dependabot not watching the workflows is caught" "dependabot watches the workflows and every composite action directory"

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
