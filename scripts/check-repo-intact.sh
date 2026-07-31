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
# floor is the tempting version and it is too weak: against a 466-line
# README a floor of 50 would permit deleting 89% and still pass, so it
# would catch "deleted everything" while waving through "deleted almost
# everything" -- the same defect wearing a smaller number. A bound
# relative to the base ref also cannot drift as the file legitimately
# grows.
#
# THIS CHECK FAILS CLOSED. An earlier draft suppressed the fetch and
# diff errors with `|| true`, so an unresolvable base ref left `stats`
# empty and the script printed "OK: README.md unchanged" -- a positive
# claim about a comparison it had never performed. A gate that cannot
# run must go RED, never green; anything else is worse than having no
# gate, because it manufactures false assurance.
set -euo pipefail

# Estimate, not a measurement: sized to catch PR #3 decisively (net
# -465) while leaving generous headroom for a legitimate edit, which is
# expected to ADD a line or two. Re-size deliberately if a genuine large
# rewrite is ever intended.
MAX_NET_DELETED_LINES=100

BASE="${GITHUB_BASE_REF:-}"

if [ ! -f README.md ]; then
  echo "FAIL: README.md is missing entirely."
  exit 1
fi

if [ -z "$BASE" ]; then
  # Push-to-main build: there is no base ref to diff against. Say so
  # explicitly rather than skipping silently -- a check that quietly
  # does nothing is the defect this whole file is written against.
  lines=$(wc -l < README.md | tr -d ' ')
  if [ "$lines" -lt 20 ]; then
    echo "FAIL: README.md is down to $lines lines on a non-PR build."
    exit 1
  fi
  echo "OK: README.md present ($lines lines). NOT CHECKED here: the"
  echo "    net-deletion bound, which requires a base ref and so runs"
  echo "    on pull_request builds only."
  exit 0
fi

# Explicit refspec. `git fetch origin "$BASE"` lands in FETCH_HEAD and
# may never create refs/remotes/origin/$BASE, because actions/checkout
# configures a narrow remote.origin.fetch for the PR ref alone. Shallow
# is fine: `git diff A B` is tree-to-tree and needs no merge base.
git fetch -q --depth=1 origin "+refs/heads/${BASE}:refs/remotes/origin/${BASE}"

if ! git rev-parse --verify -q "origin/${BASE}" >/dev/null; then
  echo "FAIL: cannot resolve origin/${BASE}, so the net-deletion bound"
  echo "      could not be evaluated. Failing closed: an unrunnable gate"
  echo "      must never report success."
  exit 1
fi

stats=$(git diff --numstat "origin/${BASE}" -- README.md)

if [ -z "$stats" ]; then
  echo "OK: README.md is byte-identical to origin/${BASE} (comparison ran)."
  exit 0
fi

added=$(echo "$stats" | awk '{print $1}')
deleted=$(echo "$stats" | awk '{print $2}')

# A binary README would render as '-' and break the arithmetic below.
case "$added$deleted" in
  *-*) echo "FAIL: README.md reads as binary in the diff; refusing to guess."; exit 1 ;;
esac

net=$((deleted - added))

if [ "$net" -gt "$MAX_NET_DELETED_LINES" ]; then
  echo "FAIL: README.md loses $net net lines (+$added/-$deleted) vs ${BASE},"
  echo "      above the bound of $MAX_NET_DELETED_LINES."
  echo
  echo "This is the PR #3 failure mode: an 'edit' that truncates the file"
  echo "rather than amending it. An edit should add to this repo or change"
  echo "a bounded part of it -- never replace it wholesale."
  exit 1
fi

echo "OK: README.md +$added/-$deleted vs ${BASE} (net $net, bound $MAX_NET_DELETED_LINES)."
