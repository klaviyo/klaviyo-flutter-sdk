#!/usr/bin/env bash
#
# Prints the SOURCE_LABEL for a publish run: the release tag on release
# events, otherwise the PR head branch (with the PR number) on pull_request
# events, otherwise the branch name. Sanitized to a conservative character
# set so it is safe to echo into Slack messages and store release notes.
#
# Usage: source-label.sh
#
# Env (set by the workflow from github context, never inline-interpolated):
#   EVENT_NAME   github.event_name
#   RELEASE_TAG  github.event.release.tag_name
#   HEAD_REF     github.head_ref
#   PR_NUMBER    github.event.pull_request.number
#   REF_NAME     github.ref_name
#
set -euo pipefail

if [ -n "${RELEASE_TAG:-}" ]; then
  label="release $RELEASE_TAG"
elif [ "${EVENT_NAME:-}" = "pull_request" ] && [ -n "${HEAD_REF:-}" ]; then
  label="$HEAD_REF"
  if [ -n "${PR_NUMBER:-}" ]; then
    label="$label (PR #$PR_NUMBER)"
  fi
else
  # On a pull_request event ref_name is "<n>/merge". In CI a pull request without a head ref must not
  # fall through to it, or a label deploy reports the merge ref as its source.
  if [ -n "${CI:-}" ] && [ "${EVENT_NAME:-}" = "pull_request" ]; then
    echo "::error::source-label.sh: HEAD_REF is empty on a pull_request in CI. Refusing to use REF_NAME, which is \"<n>/merge\"." >&2
    exit 1
  fi
  label="${REF_NAME:-unknown}"
fi

printf '%s' "$label" | tr -cd 'A-Za-z0-9._/ ()#+-' | head -c 100
echo
