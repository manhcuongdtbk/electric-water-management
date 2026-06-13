#!/usr/bin/env bash
# Companion tests for post-close-traceability.sh pure helpers (ADR-035).
# Human-run (NOT wired into CI), no network/gh. Sources the script to get the
# pure helpers; `main` does not run because the script guards on BASH_SOURCE.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$here/post-close-traceability.sh"

fail=0
check() { # $1 desc, $2 expected, $3 actual
  if [[ "$2" == "$3" ]]; then
    echo "✓ $1"
  else
    echo "✗ $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fail=1
  fi
}
contains() { # $1 desc, $2 haystack, $3 needle
  case "$2" in
    *"$3"*) echo "✓ $1" ;;
    *) echo "✗ $1"; echo "  missing: [$3]"; fail=1 ;;
  esac
}

# --- extract_issue_numbers ---
check "Closes #12"                 "12"    "$(extract_issue_numbers 'Closes #12')"
check "Fixes + closes multi+dedup" $'3\n4' "$(extract_issue_numbers 'Fixes #3, closes #4, fixes #3')"
check "Resolved (past tense)"      "9"     "$(extract_issue_numbers 'Resolved #9')"
check "case-insensitive CLOSES"    "5"     "$(extract_issue_numbers 'CLOSES #5')"
check "Refs is not closing"        ""      "$(extract_issue_numbers 'Refs #7')"
check "bare reference no keyword"  ""      "$(extract_issue_numbers 'see #7 for context')"
check "closed (past tense)"        "10"    "$(extract_issue_numbers 'closed #10')"
check "fixed (past tense)"         "11"    "$(extract_issue_numbers 'fixed #11')"
check "resolves (present plural)"  "12"    "$(extract_issue_numbers 'resolves #12')"

# --- comment_marker ---
check "marker format" "<!-- auto-close-traceability:pr-123 -->" "$(comment_marker 123)"

# --- render_comment ---
body="$(render_comment 123 'My PR title' a1b2c3d aaaaaaaaaaaaaaa develop '2026-06-13 21:40' '1.2.0')"
contains "render has marker"    "$body" "<!-- auto-close-traceability:pr-123 -->"
contains "render has PR line"   "$body" "#123 — My PR title"
contains "render has base"      "$body" "**Nhánh đích:** \`develop\`"
contains "render has milestone" "$body" "**Milestone:** 1.2.0"

if (( fail )); then echo "✗ post-close-traceability.test: FAIL"; exit 1; fi
echo "✓ post-close-traceability.test: all pass"
