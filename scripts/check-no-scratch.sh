#!/usr/bin/env bash
# No agent scratch output may be committed.
#
# THE FAILURE THIS ENCODES, again observed: the leaf's agent runtime
# writes per-step records to `debug/turn-debug/` relative to the
# PROJECT ROOT -- which, inside the driving guest, is the checkout
# itself. The ship step then stages with `git add -A`, so those files
# are swept into the commit and shipped in the PR. Three such files are
# tracked on `main` today, and PR #3 adds more.
#
# That does not break anything, which is exactly why it needs a gate:
# it silently turns the artifact the proof exists to produce -- a clean,
# reviewable PR -- into a pile of machine scratch. The right fix is
# .gitignore (added alongside this check); this asserts the fix holds.
set -euo pipefail

fail=0

# Anything under a debug/scratch dir that git is TRACKING.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  echo "FAIL: agent scratch output is tracked: $f"
  fail=1
done < <(git ls-files 'debug/turn-debug/*' 2>/dev/null || true)

if [ "$fail" -ne 0 ]; then
  echo
  echo "These are per-step agent records written relative to the project"
  echo "root. They are a byproduct of HOW the edit was produced, never"
  echo "part of the edit. Remove them from the index and rely on"
  echo ".gitignore:  git rm -r --cached debug/turn-debug"
  exit 1
fi

echo "OK: no agent scratch output is tracked."
