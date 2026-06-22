#!/usr/bin/env bash
# Guardrail trạng thái ADR (ADR-033): docs/superpowers/specs/*.md —
#   R1: khối frontmatter YAML (giữa cặp '---' đầu file) KHÔNG có key `status:`
#       (một nguồn sự thật = inline per-ADR `**Trạng thái:**`).
#   R2: dòng ADR `**Trạng thái:** Proposed` phải kèm deferred-marker `chờ quyết
#       #<số>` (đúng convention `Proposed (chờ quyết #<issue>)`). KHÔNG nhận
#       provenance kiểu "(Issue #N)". Bỏ code fence + span inline-code (`...`) trước
#       khi soi (giống check-doc-links.sh) để ví dụ prose bọc backtick không báo
#       nhầm. KHÔNG đụng `**Trạng thái khách:**`.
# Theo pattern ADR-024/030 (bash fail-loud). FAIL-LOUD: vi phạm/lỗi → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
[[ -d "$SPECS_DIR" ]] || { echo "✗ check-adr-status: specs dir not found: $SPECS_DIR"; exit 1; }

violations=0
while IFS= read -r f; do
  # R1: frontmatter block (between the first pair of '---') must not have status:.
  if awk '
      NR==1 && $0=="---" { infm=1; next }
      infm && $0=="---" { exit }
      infm && /^status:[[:space:]]*/ { found=1 }
      END { exit !found }
    ' "$f"; then
    echo "✗ R1 frontmatter status:  $f  → drop the frontmatter status: field (single source is inline **Trạng thái**)"
    violations=$((violations + 1))
  fi

  # R2: strip code fences + inline-code, then flag ADR Proposed lines that are not
  # a genuine deferral. A genuine deferral carries the marker "chờ quyết" + "#<số>"
  # (the convention `Proposed (chờ quyết #<issue>)`); a mere provenance "(Issue #N)"
  # does NOT count — a merged ADR stays Accepted even if it cites its origin issue.
  incode=0; lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    case "$raw" in '```'*|'~~~'*) incode=$((1 - incode)); continue ;; esac
    (( incode )) && continue
    line="$(printf '%s' "$raw" | sed 's/`[^`]*`//g')"
    case "$line" in *'**Trạng thái:**'*) : ;; *) continue ;; esac
    after="${line#*'**Trạng thái:**'}"
    case "$after" in *Proposed*) : ;; *) continue ;; esac
    if ! { printf '%s' "$after" | grep -qF 'chờ quyết' && printf '%s' "$after" | grep -qE '#[0-9]+'; }; then
      echo "✗ R2 undeferred Proposed  $f:$lineno  → mark Accepted (merged) or Proposed (chờ quyết #<issue>)"
      violations=$((violations + 1))
    fi
  done < "$f"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

if (( violations > 0 )); then
  echo "✗ check-adr-status: $violations ADR-status issue(s)."
  exit 1
fi
echo "✓ check-adr-status: ADR status conforms (no frontmatter status:, no undeferred Proposed)."
