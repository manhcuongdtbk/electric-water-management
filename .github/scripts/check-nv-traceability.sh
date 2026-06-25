#!/usr/bin/env bash
# Guardrail truy vết nghiệp vụ (ADR-065): cross-reference NV-... anchors declared
# in the canonical business document with NV-... tags embedded in test descriptions.
# 4 rules: (R1) anchor must have test or be deferred; (R2) deferred must cite #issue;
# (R3) test tag must match an anchor; (R4) deferred slug must match an anchor.
# Portable bash (macOS 3.2: while-read, no mapfile/assoc-array). FAIL-LOUD:
# violations → exit 1.
set -uo pipefail

CANONICAL="${1:-docs/V2_XAC_NHAN_NGHIEP_VU.md}"
TESTS_DIR="${2:-spec}"
DEFERRED_FILE="${3:-.github/nv-test-deferred.txt}"

[[ -f "$CANONICAL" ]] || { echo "✗ check-nv-traceability: canonical doc not found: $CANONICAL"; exit 1; }
[[ -d "$TESTS_DIR" ]] || { echo "✗ check-nv-traceability: tests dir not found: $TESTS_DIR"; exit 1; }

anchors="$(mktemp)"
test_tags="$(mktemp)"
deferred="$(mktemp)"
trap 'rm -f "$anchors" "$test_tags" "$deferred"' EXIT

violations=0

# --- Extract NV anchors from canonical doc ---
grep -oE '<a id="NV-[a-z0-9-]+"' "$CANONICAL" \
  | sed 's/<a id="//; s/"$//' \
  | sort -u > "$anchors"

# --- Extract NV tags from tests ---
# Pattern 1: it descriptions — lines matching  it ['"]NV-
grep -rhE "it ['\"]NV-" "$TESTS_DIR" 2>/dev/null \
  | grep -oE 'NV-[a-z0-9-]+' \
  | sort -u > "$test_tags"

# Pattern 2: demo_nv metadata — lines containing demo_nv with NV- slugs
grep -rhE 'demo_nv:.*NV-' "$TESTS_DIR" 2>/dev/null \
  | grep -oE 'NV-[a-z0-9-]+' \
  | sort -u >> "$test_tags"

# Deduplicate after merging both patterns
sort -u -o "$test_tags" "$test_tags"

# --- Extract deferred slugs ---
if [[ -f "$DEFERRED_FILE" ]]; then
  grep -vE '^\s*#|^\s*$' "$DEFERRED_FILE" \
    | grep -oE 'NV-[a-z0-9-]+' \
    | sort -u > "$deferred"
fi

# --- R1: anchor in canonical, NOT deferred, no test match ---
while IFS= read -r slug; do
  [[ -z "$slug" ]] && continue
  # Skip if deferred
  if grep -qxF "$slug" "$deferred" 2>/dev/null; then
    continue
  fi
  # Check if any test covers it
  if ! grep -qxF "$slug" "$test_tags" 2>/dev/null; then
    echo "✗ R1 missing test: $slug has no test coverage (tag it \"$slug: ...\" in a test or defer in deferred file)"
    violations=$((violations + 1))
  fi
done < "$anchors"

# --- R2: deferred line without #issue gate ---
if [[ -f "$DEFERRED_FILE" ]]; then
  while IFS= read -r line; do
    # Same filter as deferred extraction: skip comments and blanks
    printf '%s' "$line" | grep -qE '^\s*#|^\s*$' && continue
    [[ -z "$line" ]] && continue
    # Non-comment, non-blank line must have #digits to be a valid deferral
    if ! printf '%s' "$line" | grep -qE '#[0-9]+'; then
      slug="$(printf '%s' "$line" | grep -oE 'NV-[a-z0-9-]+' | head -n1)"
      if [[ -n "$slug" ]]; then
        echo "✗ R2 unlinked deferred: $slug in deferred file without #issue gate"
        violations=$((violations + 1))
      fi
    fi
  done < "$DEFERRED_FILE"
fi

# --- R3: orphan test tag — NV tag in test not matching any anchor ---
while IFS= read -r slug; do
  [[ -z "$slug" ]] && continue
  if ! grep -qxF "$slug" "$anchors" 2>/dev/null; then
    echo "✗ R3 orphan test tag: $slug found in test but no anchor in canonical"
    violations=$((violations + 1))
  fi
done < "$test_tags"

# --- R4: orphan deferred — slug in deferred not matching any anchor ---
while IFS= read -r slug; do
  [[ -z "$slug" ]] && continue
  if ! grep -qxF "$slug" "$anchors" 2>/dev/null; then
    echo "✗ R4 orphan deferred: $slug in deferred file but no anchor in canonical"
    violations=$((violations + 1))
  fi
done < "$deferred"

# --- Summary ---
if (( violations > 0 )); then
  echo "✗ check-nv-traceability: $violations NV traceability issue(s)."
  exit 1
fi

total="$(wc -l < "$anchors" | tr -d ' ')"
tested="$(comm -12 "$anchors" "$test_tags" | wc -l | tr -d ' ')"
deferred_count="$(wc -l < "$deferred" | tr -d ' ')"
echo "✓ check-nv-traceability: $total NV anchor(s) covered ($tested tested, $deferred_count deferred)."
