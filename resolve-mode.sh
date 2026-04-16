#!/usr/bin/env bash
set -euo pipefail

out() { echo "$1" >> "${GITHUB_OUTPUT}"; }

# Explicit full override
if [[ "${SCANNER_MODE}" == "full" ]]; then
  out "mode=full"
  exit 0
fi

# Pull request: diff against PR base
if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]; then
  out "mode=diff"
  out "base_sha=${PR_BASE_SHA}"
  exit 0
fi

DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
CURRENT_BRANCH="${GITHUB_REF#refs/heads/}"

# Default branch: full scan if no push base is available
if [[ "${CURRENT_BRANCH}" == "${DEFAULT_BRANCH}" ]]; then
  if [[ -n "${GITHUB_BEFORE}" ]]; then
    out "mode=diff"
    out "base_sha=${GITHUB_BEFORE}"
  else
    echo "::warning::No base SHA available for differential scan (non-push event on default branch). Falling back to full scan."
    out "mode=full"
  fi
  exit 0
fi

# Any other branch: diff against default branch
out "mode=diff"
out "base_sha=$(git rev-parse origin/${DEFAULT_BRANCH})"
