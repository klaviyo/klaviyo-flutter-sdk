#!/usr/bin/env python3
"""Static checks on the publish workflows that actionlint cannot make.

Prints one PASS/FAIL line per case and exits 1 if any case fails.

Env (used by the self-test):
  WORKFLOW_DIR   directory with publish-example.yml and publish-example-checks.yml
  ACTIONS_DIR    directory with the composite actions

The workflows are read as text and sliced by indentation, so the checks depend
neither on a YAML library nor on the awk dialect of the machine.
"""

import fnmatch
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WORKFLOW_DIR = os.environ.get("WORKFLOW_DIR", os.path.join(ROOT, ".github", "workflows"))
ACTIONS_DIR = os.environ.get("ACTIONS_DIR", os.path.join(ROOT, ".github", "actions"))
DEPLOY_PATH = os.path.join(WORKFLOW_DIR, "publish-example.yml")
CHECKS_PATH = os.path.join(WORKFLOW_DIR, "publish-example-checks.yml")
SLACK_ACTION = "./.github/actions/notify-slack-publish"

# Functions GitHub Actions expressions provide. Anything else called inside ${{ }}
# fails when it evaluates, usually only after the upload has already happened.
# Function names are case-insensitive in expressions, so the set is compared lowercased.
ALLOWED_FUNCTIONS = {
    name.lower() for name in (
        "contains", "startsWith", "endsWith", "format", "join", "toJSON", "fromJSON",
        "hashFiles", "case", "success", "always", "cancelled", "failure",
    )
}

SAME_REPO = "github.event.pull_request.head.repo.full_name == github.repository"

failures = 0


def read(path):
    with open(path) as handle:
        return handle.read()


def report(ok, name, detail=""):
    global failures
    if ok:
        print(f"PASS: {name}")
        return
    failures += 1
    print(f"FAIL: {name}")
    for line in detail.splitlines():
        print(f"  | {line}")


def split_jobs(text):
    """Maps job id to the text of that top-level job."""
    body = text.split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([a-z][a-z0-9-]*):\n", body, flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def split_steps(job_text):
    """The steps of a job as text blocks, each starting at its first key."""
    return re.split(r"(?m)^      - ", job_text)[1:]


def job_if(job_text):
    """The job-level `if:` expression, including a multi-line block."""
    match = re.search(r"(?ms)^    if:(.*?)(?=^    [a-z-]+:)", job_text)
    return match.group(1) if match else ""


def top_level_conjuncts(expression):
    """Splits an expression on `&&` outside parentheses and quotes. Returns None when a top-level `||`
    is present, because then no single clause is required for the whole expression to be true."""
    text = " ".join(expression.split())
    parts, depth, quote, start, index = [], 0, None, 0, 0
    while index < len(text):
        char = text[index]
        if quote:
            if char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif depth == 0 and text.startswith("||", index):
            return None
        elif depth == 0 and text.startswith("&&", index):
            parts.append(text[start:index].strip())
            start = index + 2
            index += 1
        index += 1
    parts.append(text[start:].strip())
    return parts


def checkout_states(text):
    """Yields (line number, safe) for each checkout. A checkout is safe when
    persist-credentials: false appears anywhere in its own step, however far
    below `uses:` the `with:` block puts it."""
    lines = text.split("\n")
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(- )?uses: actions/checkout@", line)
        if not match:
            continue
        key_indent = len(match.group(1)) + (2 if match.group(2) else 0)
        step_indent = len(match.group(1))
        safe = False
        for following in lines[index + 1:]:
            if not following.strip():
                continue
            indent = len(following) - len(following.lstrip())
            if indent < key_indent:
                break
            if indent == step_indent and re.match(r"^\s*- ", following):
                break
            if re.match(r"^\s*persist-credentials:\s*false\s*$", following):
                safe = True
        yield index + 1, safe


def reusable_job(text, name):
    """Job ids (in a workflow) that call a reusable workflow instead of running steps."""
    return name in split_jobs(text) and "    uses: ./" in split_jobs(text)[name]


deploy = read(DEPLOY_PATH)
checks = read(CHECKS_PATH)
jobs = split_jobs(deploy)
action_paths = sorted(glob.glob(os.path.join(ACTIONS_DIR, "*", "action.yml")))
slack_action_path = os.path.join(ACTIONS_DIR, "notify-slack-publish", "action.yml")
slack_action = read(slack_action_path)
workflow_paths = [DEPLOY_PATH, CHECKS_PATH]
# Every workflow file the deploy workflow calls, because they run with the same trust.
for called in re.findall(r"uses: \./\.github/workflows/([A-Za-z0-9_.-]+)", deploy):
    workflow_paths.append(os.path.join(WORKFLOW_DIR, called))
VERSION_CHECK_PATH = os.path.join(WORKFLOW_DIR, "version-check.yml")
if os.path.exists(VERSION_CHECK_PATH) and VERSION_CHECK_PATH not in workflow_paths:
    workflow_paths.append(VERSION_CHECK_PATH)
all_paths = workflow_paths + action_paths

# --- expressions -----------------------------------------------------------

def expressions(text):
    """Every expression GitHub evaluates: ${{ }} spans, plus the bare values of `if:` keys
    (a step or job `if:` has no ${{ }} and is evaluated as an expression all the same)."""
    found = re.findall(r"\$\{\{.*?\}\}", text, flags=re.S)
    for match in re.finditer(r"(?m)^(\s*)(?:- )?if:[ \t]*(\|[-+]?)?[ \t]*(.*)$", text):
        indent, block, rest = len(match.group(1)), match.group(2), match.group(3)
        if not block:
            found.append(rest)
            continue
        lines = []
        for following in text[match.end():].split("\n")[1:]:
            if following.strip() and len(following) - len(following.lstrip()) <= indent:
                break
            lines.append(following)
        found.append("\n".join(lines))
    return found


unsupported = set()
for path in all_paths:
    for expression in expressions(read(path)):
        for name in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\(", expression):
            if name.lower() not in ALLOWED_FUNCTIONS:
                unsupported.add(name)
report(not unsupported, "expressions only call functions that GitHub Actions provides",
       "unsupported: " + ", ".join(sorted(unsupported)))

# --- pinned actions ---------------------------------------------------------

# Every third-party action runs with the repository's trust, so it is pinned to a full commit SHA with a
# version comment. Local actions and reusable workflows (./) are exempt. This covers every workflow the
# deploy calls, not only the files the deploy itself defines.
PIN = re.compile(r"@[0-9a-f]{40}(\s+#\s*v?[0-9][\w.-]*)?\s*$")
unpinned = []
total_uses = 0
for path in all_paths:
    for number, line in enumerate(read(path).split("\n"), 1):
        match = re.match(r"^\s*(?:- )?uses:\s*(\S+)(.*)$", line)
        if not match or match.group(1).startswith("./"):
            continue
        total_uses += 1
        ref = match.group(1) + match.group(2)
        sha_ok = re.search(r"@[0-9a-f]{40}$", match.group(1))
        comment_ok = re.search(r"#\s*v?[0-9]", match.group(2))
        if not (sha_ok and comment_ok):
            unpinned.append(f"{os.path.relpath(path, ROOT)}:{number}: {ref.strip()}")
report(total_uses > 0 and not unpinned,
       f"every action is pinned to a full commit SHA with a version comment ({total_uses} checked)",
       "unpinned:\n" + "\n".join(unpinned))

# --- lint coverage ----------------------------------------------------------

# The lint step names its inputs as globs. A script added outside them would never be linted, so every
# shell script under .github/ and the stamper must match a glob the step passes to shellcheck. The
# scripts that predate this change are the only ones outside the globs.
def shell_glob_match(path, pattern):
    """Matches like the shell: * and ? never cross a /, so .github/scripts/*.sh reaches only one level.
    (fnmatch lets * match /, which would call a nested script covered when the shell never expands to it.)"""
    translated = ""
    for char in pattern:
        if char == "*":
            translated += "[^/]*"
        elif char == "?":
            translated += "[^/]"
        else:
            translated += re.escape(char)
    return re.fullmatch(translated, path) is not None


checks_text = read(CHECKS_PATH)
lint_step = re.search(r"(?ms)- name: Lint scripts\n.*?run: \|\n(.*?)(?=^      - |\Z)", checks_text)
shellcheck_line = ""
if lint_step:
    for line in lint_step.group(1).splitlines():
        if line.strip().startswith("shellcheck ") and "--version" not in line:
            shellcheck_line = line.strip()
globs = [tok for tok in shellcheck_line.split()[1:] if not tok.startswith("-")]
uncovered = []
scripts_seen = 0
for root, _dirs, names in os.walk(os.path.join(ROOT, ".github")):
    for name in names:
        if name.endswith(".sh"):
            rel = os.path.relpath(os.path.join(root, name), ROOT)
            scripts_seen += 1
            if not any(shell_glob_match(rel, pattern) for pattern in globs):
                uncovered.append(rel)
if os.path.exists(os.path.join(ROOT, "scripts", "sdk-ref.sh")) and not any(
        shell_glob_match("scripts/sdk-ref.sh", pattern) for pattern in globs):
    uncovered.append("scripts/sdk-ref.sh")
report(bool(globs) and scripts_seen > 0 and not uncovered,
       f"the shellcheck step covers every script under .github and scripts/sdk-ref.sh ({scripts_seen} found)",
       ("uncovered: " + ", ".join(uncovered)) if uncovered else "no shellcheck line found in the Lint scripts step")

# --- script injection ---------------------------------------------------------

# A ${{ }} inside a run: script is substituted into the shell text BEFORE the shell runs, so a value an
# attacker controls (a branch or tag name, a PR title, a release name or body, an actor, a commit message
# or a step output derived from one) executes: a branch named $(curl ...) runs the command. Pass it
# through env: and use "$VAR". Only this short allowlist of contexts the runner or GitHub fixes itself may
# appear in run text, and comment lines are checked too, because the substitution happens before the shell
# decides a line is a comment (a newline in the value ends the comment).
TRUSTED_EXPRESSION = re.compile(
    r"\s*(?:github\.(?:action_path|run_id|run_number|run_attempt|sha|repository|repository_owner|server_url|workspace)"
    r"|runner\.[a-z_]+|job\.status)\s*", re.I)


# A YAML block scalar header: | or >, then an indentation digit and a chomping sign in either order,
# then optionally a comment (|, |-, |2, |2-, |-2, >-, | # note).
BLOCK_HEADER = re.compile(r"^[|>](?:[1-9][+-]?|[+-][1-9]?)?[ \t]*(?:#.*)?$")

def run_script_lines(text):
    """Yields (line number, line) for every line inside a run: script, one line or a block scalar."""
    lines = text.split("\n")
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(?:- )?run:[ \t]*(.*)$", line)
        if not match:
            continue
        indent, rest = len(match.group(1)), match.group(2)
        if BLOCK_HEADER.match(rest):
            block_indent = None
            for number, following in enumerate(lines[index + 1:], index + 2):
                if not following.strip():
                    continue
                current = len(following) - len(following.lstrip())
                if block_indent is None:
                    block_indent = current
                if current < block_indent or current <= indent:
                    break
                yield number, following
        else:
            yield index + 1, rest


injection = []
run_lines_seen = 0
for path in all_paths:
    for number, line in run_script_lines(read(path)):
        run_lines_seen += 1
        for expression in re.findall(r"\$\{\{(.*?)\}\}", line):
            if not TRUSTED_EXPRESSION.fullmatch(expression):
                injection.append(f"{os.path.relpath(path, ROOT)}:{number}: ${{{{{expression}}}}} in a run script")
report(run_lines_seen > 0 and not injection,
       f"run scripts interpolate only trusted contexts, never a branch, tag, release, pull request, input, actor or step output ({run_lines_seen} script lines)",
       "\n".join(injection) + "\nmove the value into env: and use \"$VAR\"")

# --- portability -------------------------------------------------------------

# Scripts here run on macOS (a laptop, macos-26) and Linux (ubuntu runners). These flags exist on one
# side only: mktemp -p, date -d, readlink -f, stat -c, sed -i, grep -P. For sed -i only an attached,
# non-empty suffix is portable (-i.bak): a bare -i is GNU only, a separate empty suffix (-i '') is BSD only
# because GNU reads it as the script, and an attached empty one (-i'') is GNU only. Use the portable form
# instead (mktemp -d "${TMPDIR:-/tmp}/x.XXXXXX", python3 for dates and paths, sed -i.bak or sed to a temp
# file, grep -E). Comment lines and this file are ignored.
NON_PORTABLE = [
    (r"\bmktemp\b[^\n|;&]*\s-[a-zA-Z]*p\b|\bmktemp\b[^\n|;&]*--tmpdir", "mktemp -p / --tmpdir"),
    (r"\bdate\s+(-[a-zA-Z]*d\b|--date\b)", "date -d / --date"),
    (r"\breadlink\s+-[a-zA-Z]*f\b", "readlink -f"),
    (r"\bstat\s+(-c\b|--format\b)", "stat -c / --format"),
    (r"\bsed\s+-i(?![\w.])", "sed -i without an attached suffix (-i.bak)"),
    (r"\bgrep\s+(-[a-zA-Z]*P[a-zA-Z]*\b|--perl-regexp\b)", "grep -P"),
]
script_files = []
for base in (os.path.join(ROOT, ".github", "scripts"), os.path.join(ROOT, ".github", "actions")):
    for root, _dirs, names in os.walk(base):
        for name in names:
            if name.endswith((".sh", ".yml")) and name != "test-workflow-guards-selftest.sh":
                script_files.append(os.path.join(root, name))
script_files += [os.path.join(ROOT, "scripts", "sdk-ref.sh"), DEPLOY_PATH, CHECKS_PATH]
found = []
for path in script_files:
    if not os.path.exists(path):
        continue
    for number, line in enumerate(read(path).split("\n"), 1):
        if line.lstrip().startswith("#"):
            continue
        for pattern, label in NON_PORTABLE:
            if re.search(pattern, line):
                found.append(f"{os.path.relpath(path, ROOT)}:{number}: {label}: {line.strip()[:90]}")
report(not found, f"no scripts use flags that exist on only one of macOS and Linux ({len(script_files)} files scanned)",
       "\n".join(found))

# --- job timeouts --------------------------------------------------------------

# A job without timeout-minutes can hold a runner for the default six hours. Every job that runs steps,
# in every workflow the deploy runs or calls, sets one. A job that only calls a reusable workflow cannot.
missing_timeout = []
for name in ("publish-example.yml", "publish-example-checks.yml", "test.yml", "lint.yml", "version-check.yml"):
    wf = os.path.join(WORKFLOW_DIR, name)
    if not os.path.exists(wf):
        missing_timeout.append(f"{name}: file not found")
        continue
    for job_id, job_text in split_jobs(read(wf)).items():
        if re.search(r"(?m)^    uses:", job_text):
            continue
        if not re.search(r"(?m)^    timeout-minutes:\s*\d+\s*$", job_text):
            missing_timeout.append(f"{name}: {job_id}")
report(not missing_timeout, "every job that runs steps sets timeout-minutes", "no timeout-minutes: " + ", ".join(missing_timeout))

# --- network timeouts ----------------------------------------------------------

# A stalled connection holds a runner until the job's own timeout. Every curl in the shipped scripts and
# workflows sets --connect-timeout and --max-time. Backslash continuations are joined; tests and comments
# are skipped.
unbounded = []
for path in script_files:
    if not os.path.exists(path) or os.sep + "tests" + os.sep in path:
        continue
    text = read(path).replace("\\\n", " ")
    for number, line in enumerate(text.split("\n"), 1):
        if line.lstrip().startswith("#"):
            continue
        if re.search(r"(?<![\w./-])curl\s+-", line) and not ("--connect-timeout" in line and "--max-time" in line):
            unbounded.append(f"{os.path.relpath(path, ROOT)}: {line.strip()[:100]}")
report(not unbounded, "every curl sets --connect-timeout and --max-time", "\n".join(unbounded))

# --- dependabot ---------------------------------------------------------------

# Dependabot's github-actions ecosystem reads workflows from the listed directories only; a composite
# action under .github/actions is not covered by `/`, so its pins would go stale unseen.
DEPENDABOT_PATH = os.path.join(ROOT, ".github", "dependabot.yml")
dependabot = read(DEPENDABOT_PATH) if os.path.exists(DEPENDABOT_PATH) else ""
entries = re.split(r"(?m)^\s*-\s+(?=package-ecosystem:)", dependabot)[1:]
actions_entry = next((e for e in entries if re.match(r"package-ecosystem:\s*['\"]?github-actions", e)), "")
listed = re.findall(r"(?m)^\s*-?\s*directory:\s*['\"]?(/\S*?)['\"]?\s*$", actions_entry)
listed += re.findall(r"(?m)^\s+-\s+['\"]?(/\S*?)['\"]?\s*$", actions_entry)
action_dirs = sorted("/" + os.path.relpath(os.path.dirname(a), ROOT) for a in action_paths)
uncovered = [d for d in action_dirs if not any(fnmatch.fnmatchcase(d, pattern.rstrip("/") or "/") for pattern in listed)]
report("/" in listed and not uncovered, "dependabot watches the workflows and every composite action directory",
       "not covered: " + ", ".join((["/"] if "/" not in listed else []) + uncovered))

# Pinned gems that sign or upload (fastlane) live in a Gemfile Dependabot's bundler ecosystem watches,
# never in an inline `gem install` in a workflow, where no updater can see the pin.
inline_installs = []
for path in all_paths:
    for number, line in run_script_lines(read(path)):
        if re.search(r"\b(gem install|pip3? install|npm (?:i|install)\b)", line):
            inline_installs.append(f"{os.path.relpath(path, ROOT)}:{number}: {line.strip()[:90]}")
bundler_entry = next((e for e in entries if re.match(r"package-ecosystem:\s*['\"]?bundler", e)), "")
gemfile_dirs = [d for d in re.findall(r"(?m)^\s*directory:\s*['\"]?(/\S*?)['\"]?\s*$", bundler_entry)]
gemfiles = [os.path.join(ROOT, d.lstrip("/"), "Gemfile.lock") for d in gemfile_dirs]
# Dependabot's bundler updates always write a BUNDLED WITH line, so the line is allowed. bundler-cache
# installs exactly that Bundler, and Ruby 3.3 (the version the workflow sets up) needs Bundler 2.5 or newer,
# so an older version fails the guard before it breaks the deploy.
MIN_BUNDLER = (2, 5)
old_bundler = []
for g in gemfiles:
    if not os.path.exists(g):
        continue
    found = re.search(r"(?m)^BUNDLED WITH\s*\n\s+(\d+)\.(\d+)", read(g))
    if found and (int(found.group(1)), int(found.group(2))) < MIN_BUNDLER:
        old_bundler.append(f"{os.path.relpath(g, ROOT)}: BUNDLED WITH {found.group(1)}.{found.group(2)}")
report(not old_bundler, "no Gemfile.lock pins a Bundler older than 2.5, which cannot run on Ruby 3.3",
       "; ".join(old_bundler))
# A Dependabot bump of a pin file only reaches the guard and the tests if the PR-time path filter lists it.
checks_text_for_paths = read(CHECKS_PATH)
filter_paths = re.findall(r"(?m)^      - '([^']+)'\s*$", checks_text_for_paths.split("\npermissions:", 1)[0])
needed_paths = [os.path.relpath(g, ROOT) for g in gemfiles] + [os.path.relpath(g, ROOT)[: -len(".lock")] for g in gemfiles] + [".github/dependabot.yml"]
missing_paths = [n for n in needed_paths if n not in filter_paths]
report(not missing_paths, "the checks workflow path filter lists every pin file and dependabot.yml",
       "missing from on.pull_request.paths: " + ", ".join(missing_paths))
report(not inline_installs and bool(gemfiles) and all(os.path.exists(g) for g in gemfiles),
       "pinned gems come from a locked Gemfile that Dependabot's bundler entry watches, not an inline install",
       "\n".join(inline_installs) or "no bundler entry in dependabot.yml, or its directory has no Gemfile.lock")

# --- composite actions -------------------------------------------------------

# actionlint does not read composite actions, so the shell in their run: steps is only checked by
# lint-action-shell.py. The checks workflow must run it, and every local action any workflow in the call
# tree uses must live where it looks (.github/actions/<name>/action.yml), so none can escape the lint.
local_actions = set()
for path in workflow_paths:
    for ref in re.findall(r"uses:\s*\./\.github/actions/([A-Za-z0-9_.-]+)", read(path)):
        local_actions.add(ref)
missing_actions = sorted(a for a in local_actions if not os.path.exists(os.path.join(ACTIONS_DIR, a, "action.yml")))
report(not missing_actions, f"every local action the workflows use is found under .github/actions ({len(local_actions)} used)",
       "missing: " + ", ".join(missing_actions))
report(re.search(r"(?m)^\s+run: python3 -B \.github/scripts/lint-action-shell\.py\s*$", read(CHECKS_PATH)) is not None
       and os.path.exists(os.path.join(ROOT, ".github", "scripts", "lint-action-shell.py")),
       "the checks workflow shellchecks the composite actions' run: blocks")

# --- checkouts -------------------------------------------------------------

total = 0
unsafe = []
for path in all_paths:
    for line, safe in checkout_states(read(path)):
        total += 1
        if not safe:
            unsafe.append(f"{os.path.relpath(path, ROOT)}:{line}")
report(total > 0 and not unsafe, f"every checkout sets persist-credentials: false ({total} checked)",
       "unsafe:\n" + "\n".join(unsafe))

for job in ("preflight-android", "preflight-ios", "deploy-android", "deploy-ios", "what-to-test"):
    body = jobs.get(job)
    if body is None:
        report(False, f"the {job} job exists (the guard is out of date)")
    else:
        report("actions/checkout" in body, f"the {job} job checks out the repository")

# --- Slack -----------------------------------------------------------------

# Every Slack-posting step is found by the action it uses, never by its name. That covers the success
# message, the notes warning and the failure notifier alike, in every job.
slack_steps = [
    (job, block)
    for job, body in jobs.items()
    for block in split_steps(body)
    if f"uses: {SLACK_ACTION}" in block
]
intolerant = [f"{job}: {block.splitlines()[0]}" for job, block in slack_steps if "continue-on-error: true" not in block]
report(bool(slack_steps) and not intolerant, f"every Slack step has continue-on-error ({len(slack_steps)} checked)",
       "\n".join(intolerant) or "no Slack steps found")

direct = [os.path.relpath(p, ROOT) for p in all_paths
          if "slackapi/slack-github-action" in read(p) and p != slack_action_path]
report(not direct, "Slack is only posted through the composite action, so every rule sees every message",
       "direct use in: " + ", ".join(direct))

yaml_payload = [os.path.relpath(p, ROOT) for p in all_paths if re.search(r"^\s*payload: \|", read(p), flags=re.M)]
report(not yaml_payload and "payload-file-path:" in slack_action,
       "the Slack payload is sent from a JSON file, not a YAML block",
       ("YAML payload in: " + ", ".join(yaml_payload)) if yaml_payload else "no payload-file-path found")

build_step = re.search(r"(?ms)^    - name: Build Slack payload\n(.*?)(?=^    - )", slack_action)
report(bool(build_step) and "continue-on-error: true" in build_step.group(1),
       "the Slack action tolerates a failure of its own payload step",
       "the 'Build Slack payload' step is missing or has no continue-on-error")

# A result the workflow can post must be one the payload script knows, for every platform.
results = {}
for job, block in slack_steps:
    match = re.search(r"(?m)^\s+result: (\S+)", block)
    platform = "android" if "android" in job else "ios"
    results.setdefault(platform, set()).add(match.group(1) if match else "?")
report(results.get("android", set()) >= {"success", "failure"} and results.get("ios", set()) >= {"success", "failure", "warning"},
       "each platform posts a success and a failure, and iOS also posts a notes warning",
       f"seen: {results}")

# --- preflight -------------------------------------------------------------

for job in ("preflight-android", "preflight-ios"):
    body = jobs.get(job, "")
    report(not re.search(r"(?m)^    environment:", body), f"the {job} job declares no environment")
    report("SLACK_WEBHOOK_URL" not in body, f"SLACK_WEBHOOK_URL is not a required secret in {job}")

# --- one source of event fields -------------------------------------------

for job in ("deploy-android", "deploy-ios"):
    stamping = next((b for b in split_steps(jobs.get(job, "")) if "scripts/sdk-ref.sh" in b and "id: buildinfo" in b), "")
    needed = ("EVENT_NAME", "RELEASE_TAG", "HEAD_REF", "PR_NUMBER", "REF_NAME")
    missing = [var for var in needed if f"{var}:" not in stamping]
    report(bool(stamping) and not missing, f"the {job} stamping step sets the shared event fields",
           "missing: " + (", ".join(missing) or "the stamping step itself"))

for job in ("deploy-android", "deploy-ios"):
    checkout = next((b for b in split_steps(jobs.get(job, "")) if "actions/checkout" in b), "")
    report("ref: ${{ github.event.pull_request.head.sha || github.sha }}" in checkout,
           f"the {job} job builds the pull request head, not the merge commit")

# The notes are rendered from the same event fields and the release body the app is stamped with.
build_step = next((b for b in split_steps(jobs.get("deploy-android", "")) if "id: build\n" in b), "")
missing = [v for v in ("SOURCE_LABEL", "EVENT_NAME", "RELEASE_BODY", "RUN_URL", "NOTES_CMD") if f"{v}:" not in build_step]
report(bool(build_step) and not missing and "/dev/null" not in build_step,
       "the deploy-android notes command gets the event fields, run url and release body",
       "missing: " + (", ".join(missing) or ("a /dev/null body" if "/dev/null" in build_step else "the build step")))

# What to Test names the iOS marketing version, because build numbers restart for each one. The
# job output for it must be the stripped value, not the full SDK version used for display.
whats = next((b for b in split_steps(jobs.get("what-to-test", "")) if "id: notes" in b), "")
report('set-whats-new "$IOS_MARKETING_VERSION"' in whats and "IOS_MARKETING_VERSION: ${{ needs.deploy-ios.outputs.ios_marketing_version }}" in whats,
       "what-to-test looks the build up by the iOS marketing version, not just the build number")
result = next((b for b in split_steps(jobs.get("deploy-ios", "")) if "id: result" in b), "")
report('echo "ios_marketing_version=$IOS_MARKETING_VERSION"' in result,
       "the deploy-ios result step exports the stripped marketing version separately from the display version")

# Every step in every workflow that runs the build-info stamper carries the shared event fields. Runners
# set CI=true on every step, so a call with no env fails the moment the stamper refuses to fall back,
# including the dry-run builds and any seed or pre-build step added later.
STAMP_ENV = ("EVENT_NAME", "RELEASE_TAG", "HEAD_REF", "PR_NUMBER", "REF_NAME")
stamper_steps = []
for path in workflow_paths:
    text = read(path)
    for job_id, body in split_jobs(text).items():
        for block in split_steps(body):
            # Any step that RUNS the script: the path is the command itself, at the start of a line or after
            # a shell separator, in a multi-line run block or a one-line `run:`. It is not a run when the
            # path is an argument to another command (shellcheck scripts/sdk-ref.sh), or in a comment.
            code = "\n".join(line for line in block.splitlines() if not line.lstrip().startswith("#"))
            command_position = r"(?:^|[;&|(]|\$\(|run:)\s*(?:\./|\.\./)?scripts/sdk-ref\.sh(?:\s|$|;|&|\|)"
            if re.search(command_position, code, flags=re.M):
                stamper_steps.append((os.path.relpath(path, ROOT), job_id, block))
bare = []
for rel, job_id, block in stamper_steps:
    missing = [v for v in STAMP_ENV if f"{v}:" not in block]
    if missing:
        bare.append(f"{rel} {job_id}: {block.splitlines()[0]} is missing {', '.join(missing)}")
report(len(stamper_steps) >= 4 and not bare,
       f"every step that runs sdk-ref.sh passes the shared event fields ({len(stamper_steps)} found)",
       "\n".join(bare) or f"expected at least 4 stamper steps (2 deploy, 2 dry-run), found {len(stamper_steps)}")

# --- gating ----------------------------------------------------------------

for job in ("deploy-android", "deploy-ios"):
    body = jobs.get(job, "")
    needs = re.search(r"(?m)^    needs: (.+)$", body)
    gated = bool(needs) and "gate-test" in needs.group(1) and "gate-lint" in needs.group(1)
    report(gated, f"the {job} job needs the test and lint gates")
    condition = job_if(body)
    report("needs.gate-test.result == 'success'" in condition and "needs.gate-lint.result == 'success'" in condition,
           f"the {job} job requires the gates to have succeeded, not merely finished",
           "a skipped gate would otherwise let the deploy through when check_credentials is off")

for gate in ("gate-test", "gate-lint"):
    report(reusable_job(deploy, gate), f"the {gate} job calls a reusable workflow")

# What to Test attaches notes to a build that was uploaded. A check_credentials run completes deploy-ios
# without building, so what-to-test must not run then, or it waits for a build that never existed.
conjuncts = top_level_conjuncts(job_if(jobs.get("what-to-test", "")))
report(conjuncts is not None and "inputs.check_credentials != true" in conjuncts,
       "the what-to-test job does not run on a check_credentials run",
       "inputs.check_credentials != true must be a required clause, not part of an || or a substring")

# --- fork pull requests ----------------------------------------------------

# Every job a pull_request can reach needs the same-repo check itself, not only the first one in the
# chain, so a fork PR with a deploy label cannot reach a job that holds store secrets.
for job in ("gate-test", "gate-lint", "preflight-android", "preflight-ios", "deploy-android", "deploy-ios",
            "what-to-test", "cleanup-label"):
    report(SAME_REPO in job_if(jobs.get(job, "")), f"the {job} job requires a same-repo pull request")

for job in ("gate-test", "gate-lint"):
    report("startsWith(github.event.label.name, 'deploy-example-app')" in job_if(jobs.get(job, "")),
           f"the {job} job only runs for a deploy label on pull requests")

trigger = re.search(r"(?m)^  pull_request:\n((?:    .*\n)+)", deploy)
report(bool(trigger) and re.search(r"types:\s*\[labeled\]", trigger.group(1)) is not None,
       "the pull_request trigger is labeled only")

report(re.search(r"(?m)^      always\(\)", jobs.get("cleanup-label", "")) is not None,
       "the label cleanup runs with always()")

# --- optional Slack webhook, secrets ---------------------------------------

required = re.search(r'ios\)\n\s+required="([^"]+)"', read(os.path.join(ROOT, ".github", "scripts", "check-secrets.sh")))
android = re.search(r'android\)\n\s+required="([^"]+)"', read(os.path.join(ROOT, ".github", "scripts", "check-secrets.sh")))
report(bool(required) and bool(android) and "SLACK_WEBHOOK_URL" not in required.group(1) + android.group(1),
       "check-secrets.sh never requires SLACK_WEBHOOK_URL")

print()
if failures:
    print(f"{failures} test(s) failed")
    sys.exit(1)
print("All tests passed")
