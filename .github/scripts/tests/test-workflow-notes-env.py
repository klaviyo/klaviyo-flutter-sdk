#!/usr/bin/env python3
"""Runs the release notes the way the workflow does, with the env the workflow defines.

A composer that falls back to a placeholder when an env var is missing passes
tests that set the env by hand while the workflow never sets it. This test reads
the `env:` block of the Android build step and the iOS What to Test step out of
publish-example.yml, resolves each value for a push, a release and a
pull_request label event, runs release-notes.sh with exactly that env, and
stamps a DECOY into build-info.json for every field the notes should take from
the environment. A variable the workflow forgets to set shows up as the decoy or
as the placeholder dash, and the test fails.

Prints one PASS/FAIL line per case and exits 1 if any case fails.
"""

import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WORKFLOW = os.environ.get("WORKFLOW", os.path.join(ROOT, ".github", "workflows", "publish-example.yml"))
NOTES = os.path.join(ROOT, ".github", "scripts", "release-notes.sh")
DECOY = "DECOY-from-build-info"

failures = 0


def report(ok, name, detail=""):
    global failures
    if ok:
        print(f"PASS: {name}")
        return
    failures += 1
    print(f"FAIL: {name}")
    for line in detail.splitlines():
        print(f"  | {line}")


def jobs_of(text):
    body = text.split("\njobs:\n", 1)[1]
    parts = re.split(r"^  ([a-z][a-z0-9-]*):\n", body, flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def step_env(job_text, step_id):
    """The `env:` mapping of the step with this id, as {NAME: raw value}."""
    for block in re.split(r"(?m)^      - ", job_text)[1:]:
        if re.search(rf"(?m)^\s+id: {re.escape(step_id)}$", block):
            match = re.search(r"(?ms)^        env:\n(.*?)(?=^        [a-z-]+:|\Z)", block)
            env = {}
            for line in (match.group(1) if match else "").splitlines():
                pair = re.match(r"^          ([A-Z_][A-Z0-9_]*): (.*)$", line)
                if pair:
                    env[pair.group(1)] = pair.group(2).strip()
            return env, block
    return {}, ""


def resolve(raw, event):
    """Evaluates the ${{ }} expressions the notes steps use, for one event."""
    def one(match):
        expr = match.group(1).strip()
        parts = [p.strip() for p in expr.split("||")]
        for part in parts:
            value = lookup(part, event)
            if value:
                return value
        return ""
    return re.sub(r"\$\{\{(.*?)\}\}", one, raw)


def lookup(name, event):
    table = {
        "github.event.release.body": event["release_body"],
        "github.event.release.tag_name": event["tag"],
        "github.event_name": event["name"],
        "github.server_url": "https://github.com",
        "github.repository": "klaviyo/klaviyo-flutter-sdk",
        "github.run_id": "4242",
        "github.head_ref": event["head_ref"],
        "github.ref_name": event["ref_name"],
        "github.event.pull_request.number": event["pr"],
        "steps.buildinfo.outputs.source_label": event["source_label"],
        "steps.buildinfo.outputs.sdk_version": "1.2.3",
        "needs.deploy-ios.outputs.source_label": event["source_label"],
        "needs.deploy-ios.outputs.event": event["name"],
        "needs.deploy-ios.outputs.build_number": "7",
        "needs.deploy-ios.outputs.marketing_version": "1.2.3",
    }
    if name.startswith("'") and name.endswith("'"):
        return name[1:-1]
    if "/" in name and "github." in name:  # composed run url
        return name
    return table.get(name, "")


EVENTS = [
    {"name": "push", "tag": "", "release_body": "", "head_ref": "", "ref_name": "master", "pr": "",
     "source_label": "master", "expect_source": "master (push)", "expect_body": None},
    {"name": "release", "tag": "1.2.3", "release_body": "Fixed the thing", "head_ref": "", "ref_name": "1.2.3", "pr": "",
     "source_label": "release 1.2.3", "expect_source": "release 1.2.3 (release)", "expect_body": "Fixed the thing"},
    {"name": "pull_request", "tag": "", "release_body": "", "head_ref": "feat/x", "ref_name": "138/merge", "pr": "138",
     "source_label": "feat/x (PR #138)", "expect_source": "feat/x (PR #138) (pull_request)", "expect_body": None},
]


def run_notes(platform, env, event, run_url_expected):
    with tempfile.TemporaryDirectory() as tmp:
        info = {
            "sdkVersion": "1.2.3", "appVersion": "1.2.3", "flutterSdkRef": "1.2.3",
            "iosSdkVersion": "5.4.1", "iosSdkRef": "5.4.1", "androidSdkVersion": "4.5.1", "androidSdkRef": "4.5.1",
            "commitShort": "0123456", "buildDate": "2026-10-13 12:00 UTC",
            # Decoys: the notes must take these from the environment, never from here.
            "sourceLabel": DECOY, "event": DECOY,
        }
        info_path = os.path.join(tmp, "build-info.json")
        with open(info_path, "w") as handle:
            json.dump(info, handle)
        body_path = os.path.join(tmp, "release-body.txt")
        child = {"PATH": os.environ["PATH"], "RUNNER_TEMP": tmp, "HOME": tmp}
        for key, raw in env.items():
            child[key] = resolve(raw, event)
        if "RELEASE_BODY" in child:
            with open(body_path, "w") as handle:
                handle.write(child["RELEASE_BODY"])
        cmd = ["bash", NOTES, "4000", platform, info_path, "7", body_path if "RELEASE_BODY" in child else "/dev/null"]
        result = subprocess.run(cmd, env=child, capture_output=True, text=True)
        return result.returncode, result.stdout, result.stderr, child


deploy = open(WORKFLOW).read()
jobs = jobs_of(deploy)

# Android: the env on the build step, which carries NOTES_CMD. Compose the command as play-publish.sh does.
android_env, android_block = step_env(jobs["deploy-android"], "build")
report("NOTES_CMD" in android_env, "the Android build step defines NOTES_CMD")
for event in EVENTS:
    label = f"android notes on {event['name']}"
    if "NOTES_CMD" not in android_env:
        report(False, label + " (no NOTES_CMD)")
        continue
    with tempfile.TemporaryDirectory() as tmp:
        info = {
            "sdkVersion": "1.2.3", "appVersion": "1.2.3", "flutterSdkRef": "1.2.3", "androidSdkVersion": "4.5.1",
            "androidSdkRef": "4.5.1", "commitShort": "0123456", "buildDate": "2026-10-13 12:00 UTC",
            "sourceLabel": DECOY, "event": DECOY,
        }
        with open(os.path.join(tmp, "build-info.json"), "w") as handle:
            json.dump(info, handle)
        child = {"PATH": os.environ["PATH"], "RUNNER_TEMP": tmp, "HOME": tmp, "BUILD_NUMBER": "7"}
        for key, raw in android_env.items():
            if key in ("NOTES_CMD",):
                continue
            child[key] = resolve(raw, event)
        cmd = resolve(android_env["NOTES_CMD"], event).replace("../.github/scripts/release-notes.sh", NOTES)
        cmd = cmd.replace("build-info.json", os.path.join(tmp, "build-info.json"))
        result = subprocess.run(["bash", "-c", cmd], env=child, capture_output=True, text=True, cwd=tmp)
        out = result.stdout
        problems = []
        if result.returncode != 0:
            problems.append(f"exit {result.returncode}: {result.stderr.strip()[:200]}")
        if DECOY in out:
            problems.append("a decoy from build-info.json reached the notes, so the workflow does not set that env var")
        if f"({event['name']})" not in out or event["expect_source"] not in out:
            problems.append(f"expected '{event['expect_source']}' in the Commit line")
        if "on — (" in out:
            problems.append("the source is the placeholder dash")
        if event["expect_body"] and event["expect_body"] not in out:
            problems.append("the release body is missing")
        if not event["expect_body"] and event["name"] != "release" and "Fixed the thing" in out:
            problems.append("a release body appeared on a non-release event")
        if "CI run: https://github.com/klaviyo/klaviyo-flutter-sdk/actions/runs/4242" not in out:
            problems.append("the CI run line is missing")
        report(not problems, label, "\n".join(problems) + "\n" + out)

# iOS: the env on the What to Test notes step.
ios_env, _ = step_env(jobs["what-to-test"], "notes")
report("EVENT_NAME" in ios_env and "SOURCE_LABEL" in ios_env and "RUN_URL" in ios_env,
       "the What to Test step defines EVENT_NAME, SOURCE_LABEL and RUN_URL")
for event in EVENTS:
    label = f"ios notes on {event['name']}"
    needed = {k: v for k, v in ios_env.items() if k in ("EVENT_NAME", "SOURCE_LABEL", "RUN_URL", "RELEASE_BODY")}
    code, out, err, _ = run_notes("ios", needed, event, True)
    problems = []
    if code != 0:
        problems.append(f"exit {code}: {err.strip()[:200]}")
    if DECOY in out:
        problems.append("a decoy from build-info.json reached the notes")
    if event["expect_source"] not in out:
        problems.append(f"expected '{event['expect_source']}' in the Commit line")
    if "on — (" in out:
        problems.append("the source is the placeholder dash")
    if event["expect_body"] and event["expect_body"] not in out:
        problems.append("the release body is missing")
    report(not problems, label, "\n".join(problems) + "\n" + out)

# --- the stamping step -----------------------------------------------------
# The step that writes commit, branch and source into build-info.json runs sdk-ref.sh with the env the
# workflow defines. On a label deploy GITHUB_SHA is the synthetic merge commit and GITHUB_REF_NAME is
# "<n>/merge"; the stamp must carry the PR head SHA and head branch instead. The runner supplies the
# GITHUB_* variables, so the test supplies them the way a runner would, with decoys where they are wrong.
MERGE_SHA = "a" * 40
HEAD_SHA = "b" * 40
SDK_REF = os.path.join(ROOT, "scripts", "sdk-ref.sh")

for job in ("deploy-android", "deploy-ios"):
    stamp_env, stamp_block = step_env(jobs[job], "buildinfo")
    report(bool(stamp_env), f"the {job} job has a stamping step with its own env")
    for event in EVENTS:
        label = f"{job} stamps the right commit and source on {event['name']}"
        with tempfile.TemporaryDirectory() as tmp:
            repo = os.path.join(tmp, "repo")
            os.makedirs(os.path.join(repo, "example"))
            os.makedirs(os.path.join(repo, "scripts"))
            os.makedirs(os.path.join(repo, ".github", "scripts"))
            for rel in ("scripts/sdk-ref.sh", ".github/scripts/source-label.sh"):
                with open(os.path.join(ROOT, rel)) as src, open(os.path.join(repo, rel), "w") as dst:
                    dst.write(src.read())
                os.chmod(os.path.join(repo, rel), 0o755)
            with open(os.path.join(repo, "pubspec.yaml"), "w") as handle:
                handle.write("name: x\nversion: 1.2.3\n")
            with open(os.path.join(repo, "example", "pubspec.yaml"), "w") as handle:
                handle.write("name: e\nversion: 1.2.3\n")
            event_path = os.path.join(tmp, "event.json")
            payload = {"pull_request": {"number": int(event["pr"] or 0), "head": {"sha": HEAD_SHA, "ref": event["head_ref"]}}}
            with open(event_path, "w") as handle:
                json.dump(payload, handle)
            is_pr = event["name"] == "pull_request"
            child = {
                "PATH": os.environ["PATH"], "HOME": tmp,
                # What the runner sets itself. CI=true makes the stamp strict, as it is on a real runner,
                # so an input the workflow stops supplying fails here instead of falling back to git.
                "CI": "true",
                "GITHUB_SHA": MERGE_SHA if is_pr else HEAD_SHA,
                "GITHUB_REF_NAME": event["ref_name"],
                "GITHUB_HEAD_REF": event["head_ref"],
                "GITHUB_EVENT_NAME": event["name"],
                "GITHUB_EVENT_PATH": event_path,
                "GITHUB_REF_TYPE": "tag" if event["name"] == "release" else "branch",
                "BUILD_DATE": "2026-10-13 12:00 UTC",
            }
            # What the workflow's step defines for itself.
            for key, raw in stamp_env.items():
                child[key] = resolve(raw, event)
            out_path = os.path.join(tmp, "build-info.json")
            result = subprocess.run(["bash", os.path.join(repo, "scripts", "sdk-ref.sh"), out_path],
                                    env=child, capture_output=True, text=True, cwd=repo)
            problems = []
            if result.returncode != 0 or not os.path.exists(out_path):
                problems.append(f"sdk-ref.sh failed: {result.stderr.strip()[:200]}")
            else:
                info = json.load(open(out_path))
                if info["commit"] != HEAD_SHA:
                    problems.append(f"commit is {info['commit'][:7]}, expected the head {HEAD_SHA[:7]} (merge commit is {MERGE_SHA[:7]})")
                if info["sourceLabel"] != event["source_label"]:
                    problems.append(f"source label is {info['sourceLabel']!r}, expected {event['source_label']!r}")
                if "/merge" in info["sourceLabel"] or "/merge" in info["branch"]:
                    problems.append(f"a merge ref reached the stamp: label={info['sourceLabel']!r} branch={info['branch']!r}")
                if info["event"] != event["name"]:
                    problems.append(f"event is {info['event']!r}, expected {event['name']!r}")
            report(not problems, label, "\n".join(problems))

print()
if failures:
    print(f"{failures} test(s) failed")
    sys.exit(1)
print("All tests passed")
