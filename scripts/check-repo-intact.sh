#!/usr/bin/env bash
# The repository must survive an agent edit.
#
# THE FAILURE THIS ENCODES, observed not imagined: PR #3 on this repo
# is an agent edit that deleted 466 of README.md's 466 lines and
# replaced them with one. The turn "succeeded" -- it edited a file,
# committed, pushed, and opened a PR. Every mechanical signal was green
# while the repository had been emptied.
#
# EXPRESSED AS A NET-DELETION BOUND, not an absolute floor. An absolute
# floor is the tempting version and it is too weak: with a 466-line
# README, a floor of 50 would permit deleting 89% and still pass, so it
# would catch "deleted everything" while waving through "deleted almost
# everything" -- the same defect wearing a smaller number. A bound
# relative to the base ref also cannot drift as the file legitimately
# grows.
set -euo pipefail

MAX_NET_DELETED_LINES=100
BASE="${GITHUB_BASE_REF:-}"

if [ ! -f README.md ]; then
  echo "FAIL: README.md is missing entirely."
  exit 1
fi

if [ -z "$BASE" ]; then
  # Push-to-main build: no base to diff against, so assert only that the
  # file still exists and is non-trivial. Stated plainly rather than
  # silently skipped -- a check that quietly does nothing is worse than
  # one that says what it did not check.
  lines=$(wc -l < README.md | tr -d ' ')
  if [ "$lines" -lt 20 ]; then
    echo "FAIL: README.md is down to $lines lines on a non-PR build."
    exit 1
  fi
  echo "OK: README.md present ($lines lines). Net-deletion bound is PR-only."
  exit 0
fi

git fetch -q --depth=1 origin "$BASE" 2>/dev/null || true
stats=$(git diff --numstat "origin/$BASE" -- README.md 2>/dev/null || true)
if [ -z "$stats" ]; then
  echo "OK: README.md unchanged relative to $BASE."
  exit 0
fi

added=$(echo "$stats" | awk '{print $1}')
deleted=$(echo "$stats" | awk '{print $2}')
net=$((deleted - added))

if [ "$net" -gt "$MAX_NET_DELETED_LINES" ]; then
  echo "FAIL: README.md loses $net net lines (+$added/-$deleted) vs $BASE,"
  echo "      above the bound of $MAX_NET_DELETED_LINES."
  echo
  echo "This is the PR #3 failure mode: an 'edit' that truncates the file"
  echo "rather than amending it. An edit should add to this repo or change"
  echo "a bounded part of it -- never replace it wholesale. If a genuine"
  echo "large rewrite is intended, raise the bound deliberately as part of"
  echo "that change."
  exit 1
fi

echo "OK: README.md +$added/-$deleted vs $BASE (net $net, bound $MAX_NET_DELETED_LINES)."
