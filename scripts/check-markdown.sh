#!/usr/bin/env bash
# Markdown structure must stay well-formed.
#
# The third check exists so CI is not purely a pair of tripwires: it
# asserts a positive property of the CONTENT an agent edits, so a
# careless-but-non-destructive edit is caught too.
#
# DELIBERATELY NARROW. An earlier draft also checked code-fence PARITY,
# and that was removed rather than kept: `^```' matches a nested fence
# inside a fenced example, and matches 4-backtick wrappers too, so a
# perfectly valid docs file can read as "odd number of fences". This
# repo's README is exactly that kind of file. A check that can reject a
# legitimate edit would surface as a driving-proof failure and send an
# operator hunting the agent instead of the check -- so the only rules
# kept here are ones with no legitimate counter-example.
set -euo pipefail

fail=0

while IFS= read -r f; do
  [ -z "$f" ] && continue

  # An empty link target is always a mistake -- never a style choice.
  if grep -nE '\]\(\s*\)' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f contains a markdown link with an empty target:"
    grep -nE '\]\(\s*\)' "$f" | head -5 | sed 's/^/    /'
    fail=1
  fi

  # A file that is entirely blank is not an edit, it is a deletion
  # wearing a filename.
  if [ ! -s "$f" ]; then
    echo "FAIL: $f is empty."
    fail=1
  fi
done < <(git ls-files '*.md')

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "OK: markdown is well-formed."
