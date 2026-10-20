#!/usr/bin/env bash
#
# Reports whether the store secrets a platform's deploy needs are present.
# Prints only the NAMES of missing secrets, never a value or length. Writes
# ready=true|false and missing=<comma list> to $GITHUB_OUTPUT when set.
#
# Push and release runs skip the deploy quietly when secrets are missing
# (::notice::, exit 0); a workflow_dispatch or label deploy asked for a build
# explicitly, so missing secrets fail loudly (::error::, exit 1).
#
# Usage: check-secrets.sh <android|ios>
#
# Env:
#   EVENT_NAME  github.event_name
#   The secrets themselves, passed via env by the workflow.
#
set -uo pipefail

PLATFORM="${1:?usage: check-secrets.sh <android|ios>}"

case "$PLATFORM" in
  android)
    required="GOOGLE_SERVICES_JSON SIGNING_KEY ALIAS KEY_STORE_PASSWORD KEY_PASSWORD SERVICE_ACCOUNT_JSON"
    ;;
  ios)
    required="APP_STORE_CONNECT_API_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_BASE64 MATCH_PASSWORD MATCH_DEPLOY_KEY BUILD_CERTIFICATE_BASE64 P12_PASSWORD"
    ;;
  *)
    echo "usage: check-secrets.sh <android|ios>" >&2
    exit 2
    ;;
esac

missing=""
for name in $required; do
  if [ -z "${!name:-}" ]; then
    missing="$missing${missing:+,}$name"
  fi
done

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    if [ -n "$missing" ]; then
      echo "ready=false"
    else
      echo "ready=true"
    fi
    echo "missing=$missing"
  } >> "$GITHUB_OUTPUT"
fi

if [ -z "$missing" ]; then
  echo "All $PLATFORM deploy secrets are present"
  exit 0
fi

case "${EVENT_NAME:-}" in
  workflow_dispatch | pull_request)
    echo "::error::Missing $PLATFORM deploy secrets: $missing"
    exit 1
    ;;
  *)
    echo "::notice::Skipping $PLATFORM deploy, missing secrets: $missing"
    exit 0
    ;;
esac
