#!/usr/bin/env bash

set -eux

git config user.name "GitHub Actions"
git config user.email "actions@users.noreply.github.com"

BASE_BRANCH=main
git fetch origin
git checkout "${BASE_BRANCH}"
git reset --hard "origin/${BASE_BRANCH}"
git clean -ffdx

./scripts/update_blocklist.exs
if [[ -z $(git status -s) ]]; then
    # no update
    exit
fi

BLOCKLIST_REF=$(pushd deps/sqids_blocklist 2>&1 1>/dev/null && git rev-parse --short HEAD)
NEW_BRANCH=automation/default-blocklist-update/$BLOCKLIST_REF
if git branch -a | grep "${NEW_BRANCH}" >/dev/null; then
    # branch already created
    exit
fi

REMOTE=origin
PR_TITLE="Update default blocklist to $BLOCKLIST_REF"
git checkout -b "$NEW_BRANCH"
git add .
git commit -a -m "${PR_TITLE}"
git push "$REMOTE" "$NEW_BRANCH"

PR_LABEL="enhancement"
if ! gh pr list --state open --label "$PR_LABEL" | grep "${PR_TITLE}" >/dev/null; then
    gh pr create --fill \
        --title "${PR_TITLE}" \
        --label "${PR_LABEL}"
fi
