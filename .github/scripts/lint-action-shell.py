#!/usr/bin/env python3
"""Runs shellcheck over the shell in composite actions' `run:` steps.

actionlint reads workflows but not .github/actions/*/action.yml, so the shell in a composite
action's steps would never be linted. This extracts every `run:` block (one line or a block
scalar) from every composite action, replaces each ${{ ... }} expression with a plain
placeholder so shellcheck can parse it, and runs shellcheck on the result.

It fails when it finds no run blocks at all, so a parsing change cannot make the check pass by
finding nothing.

Usage: lint-action-shell.py [actions-dir]    (default: .github/actions)
Env:   SHELLCHECK  shellcheck binary (default: shellcheck)
"""

import glob
import os
import re
import subprocess
import sys
import tempfile

ACTIONS_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(".github", "actions")
SHELLCHECK = os.environ.get("SHELLCHECK", "shellcheck")


# A YAML block scalar header: | or >, then an indentation digit and a chomping sign in either order,
# then optionally a comment (|, |-, |2, |2-, |-2, >-, | # note).
BLOCK_HEADER = re.compile(r"^[|>](?:[1-9][+-]?|[+-][1-9]?)?[ \t]*(?:#.*)?$")

def run_blocks(text):
    """Yields (line number, script) for each `run:` key in the file."""
    lines = text.split("\n")
    for index, line in enumerate(lines):
        match = re.match(r"^(\s*)(?:- )?run:[ \t]*(.*)$", line)
        if not match:
            continue
        indent, rest = len(match.group(1)), match.group(2)
        if BLOCK_HEADER.match(rest):
            body = []
            block_indent = None
            for following in lines[index + 1:]:
                if not following.strip():
                    body.append("")
                    continue
                current = len(following) - len(following.lstrip())
                if block_indent is None:
                    block_indent = current
                if current < block_indent or current <= indent:
                    break
                body.append(following[block_indent:])
            yield index + 1, "\n".join(body).rstrip() + "\n"
        else:
            yield index + 1, rest.strip() + "\n"


def neutralize(script):
    """Replaces ${{ ... }} (which shellcheck cannot parse) with a placeholder word."""
    return re.sub(r"\$\{\{.*?\}\}", "EXPR", script, flags=re.S)


failures = 0
blocks_found = 0
for path in sorted(glob.glob(os.path.join(ACTIONS_DIR, "*", "action.yml"))):
    for number, script in run_blocks(open(path).read()):
        blocks_found += 1
        with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as handle:
            handle.write("#!/usr/bin/env bash\n" + neutralize(script))
            temp = handle.name
        try:
            result = subprocess.run([SHELLCHECK, "--shell=bash", temp], capture_output=True, text=True)
        finally:
            os.unlink(temp)
        label = f"{path}:{number}"
        if result.returncode == 0:
            print(f"PASS: {label}")
        else:
            failures += 1
            print(f"FAIL: {label}")
            for line in result.stdout.splitlines():
                print(f"  | {line}")

if blocks_found == 0:
    print(f"FAIL: no run: blocks found under {ACTIONS_DIR}; a composite action's shell would go unlinted")
    sys.exit(1)
print(f"{blocks_found} run block(s) checked")
sys.exit(1 if failures else 0)
