#!/usr/bin/env bash
# Guardrail jargon "per" (Issue #432): Vietnamese docs must not use English
# "per" in prose. Use "mỗi" (each) or "theo" (by) instead.
# Scans .md files under docs/ + root meta files. Skips code fences, inline
# backticks, and changelog sections (frozen history). "Per page" kept as
# UI label reference. FAIL-LOUD: violation → exit 1.
set -uo pipefail

DOCS_DIR="${1:-docs}"
ROOT_FILES="${2:-CONTRIBUTING.md AGENTS.md}"

violations=0

check_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  local in_changelog=0 in_code=0 lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))

    # Track code fences
    case "$raw" in '```'*|'~~~'*) in_code=$((1 - in_code)); continue ;; esac
    (( in_code )) && continue

    # Skip changelog sections (frozen history — ADR-002)
    case "$raw" in
      '## Lịch sử thay đổi'*|'## '[0-9]*'. Lịch sử thay đổi'*) in_changelog=1; continue ;;
    esac
    (( in_changelog )) && continue

    # Strip inline backticks before checking
    local clean
    clean="$(printf '%s' "$raw" | sed 's/`[^`]*`//g')"

    # Check for standalone "per" (word boundary)
    # Allow "Per page" (UI label reference to per_page code concept)
    if printf '%s' "$clean" | grep -qiE '\bper\b' && \
       ! printf '%s' "$clean" | grep -qiE '\bper page\b'; then
      echo "✗ check-jargon-per: $f:$lineno — found 'per' in Vietnamese text. Use 'mỗi' or 'theo'."
      echo "    $raw"
      violations=$((violations + 1))
    fi
  done < "$f"
}

# Scan docs/ recursively
if [[ -d "$DOCS_DIR" ]]; then
  while IFS= read -r mdfile; do
    # Skip specs and plans (frozen history)
    case "$mdfile" in
      */superpowers/specs/*|*/superpowers/plans/*) continue ;;
    esac
    check_file "$mdfile"
  done < <(find "$DOCS_DIR" -type f -name '*.md' | sort)
fi

# Scan root meta files
for rf in $ROOT_FILES; do
  check_file "$rf"
done

if (( violations > 0 )); then
  echo "✗ check-jargon-per: $violations violation(s). Replace 'per' with 'mỗi' or 'theo' in Vietnamese text."
  exit 1
fi
echo "✓ check-jargon-per: no English 'per' jargon in Vietnamese docs."
