# i18n View Guardrail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Machine-enforce the AGENTS i18n rule for views — a CI guardrail that turns CI red when a *new* hard-coded Vietnamese literal appears outside `t(...)` in `app/views/**/*.erb`, while grandfathering existing ones through a content-based baseline.

**Architecture:** A native-bash, fail-loud script (`check-view-i18n.sh`, ADR-024/030 lineage) scans every `.erb` file; for each line it strips ERB/HTML comment spans (greedy — only failure mode is a harmless false-negative, never a false-positive) and flags lines whose remainder still contains a Latin-with-diacritics codepoint (the Vietnamese signal). Each violating line is recorded as `relpath<TAB>whitespace-normalized-text` (no line numbers → stable against line shifts). The script compares the current set against a committed baseline `.github/i18n-view-baseline.txt`; only entries **not** in the baseline fail. `UPDATE_BASELINE=1` regenerates the baseline (the escape hatch, visible as a reviewable diff). A dedicated always-on CI job runs it.

**Tech Stack:** Bash, Perl (Unicode line scan — present on `ubuntu-latest` CI runner and macOS), GitHub Actions.

**Spec:** [`docs/superpowers/specs/2026-06-13-guardrail-i18n-view-design.md`](2026-06-13-guardrail-i18n-view-design.md) (ADR-032).

**Branch:** `feature/i18n-view-guardrail` ← `develop` (already created). PR base `develop`, squash.

**Note on testing:** This change touches only `.github/**` + docs; it does **not** touch `app/` or `spec/`, so RSpec behavior is unaffected. Verification is the script's companion test (`check-view-i18n.test.sh`) plus a live red/green check on the real tree — same approach the ADR-024/030 guardrail PRs used.

---

### Task 1: Companion test for the guardrail script (write the test first)

The companion is a human-run harness (not wired into CI), mirroring `.github/scripts/check-test-dimensions.test.sh`. It builds throwaway fixtures and asserts exit codes + messages. Written **before** the script so it fails first.

**Files:**
- Create: `.github/scripts/check-view-i18n.test.sh`

- [ ] **Step 1: Write the failing companion test**

Create `.github/scripts/check-view-i18n.test.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Test cho check-view-i18n.sh (ADR-032). Dựng fixture tạm rồi kiểm exit code +
# thông báo cho từng luật. Chạy tay: bash .github/scripts/check-view-i18n.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
# Cần perl (line scan Unicode) — có sẵn trên macOS và ubuntu-latest.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-view-i18n.sh"
fails=0

# mk <erb-line> <baseline-body> → in ra thư mục fixture (views/ + baseline.txt).
# Dùng printf '%s' để literal '%' của tag ERB không bị diễn giải.
mk() {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/views"
  printf '%s\n' "$1" > "$tmp/views/page.html.erb"
  printf '%s\n' "$2" > "$tmp/baseline.txt"
  printf '%s' "$tmp"
}

# run <fixture-dir> [env...] — chạy script với đường dẫn TƯƠNG ĐỐI (cd vào fixture)
# để find phát ra "views/page.html.erb" ổn định, không kèm tiền tố tmp tuyệt đối.
run() { (cd "$1" && bash "$SCRIPT" views baseline.txt 2>&1); }

# assert <label> <expected-exit> <erb-line> <baseline-body> [needle]
assert() {
  local label="$1" expected="$2" erb="$3" base="$4" needle="${5:-}"
  local tmp out rc
  tmp="$(mk "$erb" "$base")"
  out="$(run "$tmp")"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# 1. FAIL: new diacritic line not in baseline.
assert "fail: new hard-coded literal" 1 \
  '<%= f.submit "Lưu" %>' \
  '' \
  "new hard-coded"

# 2. PASS: line's normalized text is already in the baseline.
assert "pass: grandfathered in baseline" 0 \
  '<%= f.submit "Lưu" %>' \
  'views/page.html.erb	<%= f.submit "Lưu" %>'

# 3. PASS: diacritic only inside an ERB comment.
assert "pass: diacritic only in ERB comment" 0 \
  '<%# ghi chú tiếng Việt %>' \
  ''

# 4. PASS: diacritic only inside an HTML comment.
assert "pass: diacritic only in HTML comment" 0 \
  '<!-- ghi chú tiếng Việt -->' \
  ''

# 5. FAIL: mixed line — code carries the diacritic, comment is stripped.
assert "fail: code diacritic on a mixed line" 1 \
  '<%= f.submit "Lưu" %> <%# nút lưu %>' \
  '' \
  "new hard-coded"

# 6. PASS: content-based — same text, shifted by a blank line, still matches baseline.
shift_case() {
  local tmp out rc
  tmp="$(mktemp -d)"; mkdir -p "$tmp/views"
  printf '\n\n<%%= f.submit "Lưu" %%>\n' > "$tmp/views/page.html.erb"
  printf '%s\n' 'views/page.html.erb	<%= f.submit "Lưu" %>' > "$tmp/baseline.txt"
  out="$(cd "$tmp" && bash "$SCRIPT" views baseline.txt 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "✗ pass: content-based (line shifted) — expected exit 0, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ pass: content-based (line shifted)"
  fi
  rm -rf "$tmp"
}
shift_case

# 7. PASS: UPDATE_BASELINE=1 captures current violations, then a normal run is green.
regen_case() {
  local tmp out rc
  tmp="$(mktemp -d)"; mkdir -p "$tmp/views"
  printf '%s\n' '<%= f.submit "Lưu" %>' > "$tmp/views/page.html.erb"
  (cd "$tmp" && UPDATE_BASELINE=1 bash "$SCRIPT" views baseline.txt >/dev/null 2>&1)
  out="$(cd "$tmp" && bash "$SCRIPT" views baseline.txt 2>&1)"; rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "✗ pass: regenerate then green — expected exit 0, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif ! grep -qF 'views/page.html.erb' "$tmp/baseline.txt"; then
    echo "✗ pass: regenerate then green — baseline missing the entry"; fails=$((fails + 1))
  else
    echo "✓ pass: regenerate then green"
  fi
  rm -rf "$tmp"
}
regen_case

# 8. PASS: plain ASCII English literal is not flagged (no diacritic).
assert "pass: ascii english not flagged" 0 \
  '<%= f.submit "Save" %>' \
  ''

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
```

- [ ] **Step 2: Run the companion test, verify it fails (script not yet present)**

Run: `bash .github/scripts/check-view-i18n.test.sh`
Expected: FAIL — every case errors because `check-view-i18n.sh` does not exist yet (e.g. `bash: .../check-view-i18n.sh: No such file or directory`), ending with `✗ N case(s) failed`.

- [ ] **Step 3: Commit the test**

```bash
git add .github/scripts/check-view-i18n.test.sh
git commit -m "test: companion test for the i18n view guardrail (ADR-032)

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Implement the guardrail script

**Files:**
- Create: `.github/scripts/check-view-i18n.sh`
- Test: `.github/scripts/check-view-i18n.test.sh` (from Task 1)

- [ ] **Step 1: Write the script**

Create `.github/scripts/check-view-i18n.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Guardrail i18n cho view (ADR-032): quét app/views/**/*.erb, chặn literal tiếng
# Việt MỚI nằm ngoài t(...). Phần hard-code đã có được grandfather qua baseline
# .github/i18n-view-baseline.txt (app single-locale → không ép migration). Tín
# hiệu: dòng (sau khi bỏ comment span) còn chứa ký tự Latin có dấu = chữ tiếng
# Việt người-dùng-thấy. Bản ghi vi phạm = "relpath<TAB>text chuẩn-hoá khoảng-trắng"
# (KHÔNG số dòng → ổn định khi dòng dịch chuyển). Vi phạm không có trong baseline
# → đỏ. UPDATE_BASELINE=1 → ghi lại baseline (escape hatch, diff thấy ở PR).
# Theo pattern ADR-024/030 (bash fail-loud). Cần perl (line scan Unicode) — có ở
# ubuntu-latest (CI) và macOS. FAIL-LOUD: vi phạm/lỗi → exit 1.
set -uo pipefail

VIEWS_DIR="${1:-app/views}"
BASELINE="${2:-.github/i18n-view-baseline.txt}"

[[ -d "$VIEWS_DIR" ]] || { echo "✗ check-view-i18n: views dir not found: $VIEWS_DIR"; exit 1; }
command -v perl >/dev/null 2>&1 || { echo "✗ check-view-i18n: perl not found (required for the Unicode line scan)"; exit 1; }

# extract_violations: in mỗi dòng vi phạm dạng "relpath<TAB>normalized-text".
# Bỏ comment span ERB (<%# … %>) và HTML (<!-- … -->) theo greedy: sai sót duy
# nhất là FALSE NEGATIVE hiếm (comment đứng trước code trên cùng dòng), KHÔNG bao
# giờ false positive (đỏ oan). Lớp ký tự: Latin Extended (U+00C0–U+024F) + Latin
# Extended Additional (U+1E00–U+1EFF) = các chữ tiếng Việt precomposed; ASCII Anh
# thuần không khớp. Key chuẩn-hoá từ phần ĐÃ bỏ comment (sửa comment không churn).
extract_violations() {
  find "$VIEWS_DIR" -type f -name '*.erb' | LC_ALL=C sort | while IFS= read -r f; do
    perl -CSD -ne '
      my $code = $_;
      $code =~ s/<!--.*-->//g;
      $code =~ s/<%#.*%>//g;
      next unless $code =~ /[\x{00C0}-\x{024F}\x{1E00}-\x{1EFF}]/;
      my $t = $code;
      $t =~ s/\s+/ /g; $t =~ s/^ //; $t =~ s/ $//;
      print "$ARGV\t$t\n";
    ' "$f"
  done
}

current="$(mktemp)"
base="$(mktemp)"
trap 'rm -f "$current" "$base"' EXIT
extract_violations | LC_ALL=C sort -u > "$current"

# Chế độ regenerate: ghi baseline rồi thoát xanh.
if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
  {
    echo "# i18n view guardrail baseline (ADR-032) — grandfathered hard-coded"
    echo "# Vietnamese literals outside t(...) in $VIEWS_DIR/**/*.erb."
    echo "# Regenerate: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh"
    echo "# Format: <relpath><TAB><whitespace-normalized offending text>"
    cat "$current"
  } > "$BASELINE"
  echo "✓ check-view-i18n: baseline written to $BASELINE ($(grep -c . "$current") entr(ies))."
  exit 0
fi

[[ -f "$BASELINE" ]] || { echo "✗ check-view-i18n: baseline not found: $BASELINE (run UPDATE_BASELINE=1 to create it)"; exit 1; }

# So sánh: bỏ dòng comment/blank của baseline rồi sort giống current.
grep -v '^#' "$BASELINE" | grep -v '^[[:space:]]*$' | LC_ALL=C sort -u > "$base"

new="$(comm -23 "$current" "$base")"    # có ở current, không có ở baseline → mới
stale="$(comm -13 "$current" "$base")"  # có ở baseline, không còn ở current → cũ/đã sửa

violations=0
if [[ -n "$new" ]]; then
  echo "✗ check-view-i18n: new hard-coded Vietnamese literal(s) outside t(...) in $VIEWS_DIR/:"
  printf '%s\n' "$new" | while IFS="$(printf '\t')" read -r path text; do
    echo "  ✗ $path  →  $text"
  done
  echo "  Fix: wrap the text in t(...) and add the key to config/locales/vi.yml."
  echo "  (If it is genuinely not user-facing, regenerate the baseline: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh)"
  violations=1
fi

if [[ -n "$stale" ]]; then
  echo "ℹ check-view-i18n: $(printf '%s\n' "$stale" | grep -c .) stale baseline entr(ies) (fixed/migrated). Prune: UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh"
fi

if (( violations > 0 )); then exit 1; fi
echo "✓ check-view-i18n: no new hard-coded Vietnamese literals in views (baseline grandfathered)."
exit 0
```

- [ ] **Step 2: Run the companion test, verify all cases pass**

Run: `bash .github/scripts/check-view-i18n.test.sh`
Expected: every line `✓ …`, ending with `✓ all cases passed` (exit 0).

If any case fails, fix the script (not the test) and re-run until green.

- [ ] **Step 3: Commit the script**

```bash
git add .github/scripts/check-view-i18n.sh
git commit -m "feat: i18n view guardrail script (ADR-032)

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Generate the baseline and wire the CI job

**Files:**
- Create: `.github/i18n-view-baseline.txt` (generated)
- Modify: `.github/workflows/ci.yml` (add the `i18n-view-guardrail` job)

- [ ] **Step 1: Generate the baseline from the real tree**

Run: `UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh`
Expected: `✓ check-view-i18n: baseline written to .github/i18n-view-baseline.txt (NNN entr(ies)).` where NNN is ~470.

- [ ] **Step 2: Verify the script is now green on the real tree**

Run: `bash .github/scripts/check-view-i18n.sh`
Expected: `✓ check-view-i18n: no new hard-coded Vietnamese literals in views (baseline grandfathered).` (exit 0).

- [ ] **Step 3: Add the CI job**

In `.github/workflows/ci.yml`, add this job immediately after the `doc-governance` job block (after its last line, before the `tests:` job):

```yaml
  i18n-view-guardrail:
    name: i18n view guardrail (no new hard-coded Vietnamese)
    runs-on: ubuntu-latest
    # Chạy LUÔN trên mọi pull request (KHÔNG gate qua `changes`): guardrail grep
    # rẻ, cần bắt đúng lúc pull request đụng .erb (ADR-032, triết lý ADR-024).
    steps:
      - uses: actions/checkout@v6
      - name: Check views for new hard-coded Vietnamese literals (ADR-032)
        run: bash .github/scripts/check-view-i18n.sh
```

- [ ] **Step 4: Commit the baseline and CI job**

```bash
git add .github/i18n-view-baseline.txt .github/workflows/ci.yml
git commit -m "ci: grandfather baseline and i18n-view-guardrail job (ADR-032)

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Live red/green verification on the real tree

Prove the guardrail actually catches a new violation (ADR-024/030 acceptance style). No commit in this task.

- [ ] **Step 1: Inject a temporary new hard-coded literal**

Append a new violating line to a real view (string chosen so its normalized text is NOT already in the baseline):

```bash
printf '\n<p>%s</p>\n' 'Dòng kiểm thử guardrail tạm thời' >> app/views/sessions/new.html.erb
```

- [ ] **Step 2: Run the guardrail, verify it goes red**

Run: `bash .github/scripts/check-view-i18n.sh; echo "exit=$?"`
Expected: `✗ check-view-i18n: new hard-coded Vietnamese literal(s) …`, a line `✗ app/views/sessions/new.html.erb  →  <p>Dòng kiểm thử guardrail tạm thời</p>`, and `exit=1`.

- [ ] **Step 3: Revert the injection, verify it goes green again**

```bash
git checkout -- app/views/sessions/new.html.erb
bash .github/scripts/check-view-i18n.sh; echo "exit=$?"
```
Expected: `✓ check-view-i18n: no new hard-coded Vietnamese literals …` and `exit=0`. Confirm `git status` is clean for `app/views/`.

---

### Task 5: Canonical documentation (CONTRIBUTING §8 + THUAT_NGU gloss)

**Files:**
- Modify: `CONTRIBUTING.md` (§8 — i18n row + new guardrail paragraph)
- Modify: `docs/THUAT_NGU.md` (§3 gloss + version bump + changelog)

- [ ] **Step 1: Update the i18n row in the ADR-031 "Chiều review tuân AGENTS" table**

In `CONTRIBUTING.md`, replace the i18n table row (currently the "Cơ chế phủ" cell reads `Tạm bằng mắt người (mục A của #329 sẽ máy-ép sau)`):

Old line:
```
| **i18n** | Chữ người dùng qua `t(...)` + `config/locales/vi.yml`; không hard-code tiếng Việt | Tạm bằng mắt người (mục A của #329 sẽ máy-ép sau) |
```
New line:
```
| **i18n** | Chữ người dùng qua `t(...)` + `config/locales/vi.yml`; không hard-code tiếng Việt | Máy-ép: guardrail i18n cho view (ADR-032) bắt literal tiếng Việt **mới** ngoài `t(...)` trong `app/views/**/*.erb`; phần cũ grandfather qua baseline. Chữ không-dấu/ngoài view còn người/AI |
```

- [ ] **Step 2: Add a new §8 paragraph documenting the guardrail**

In `CONTRIBUTING.md`, immediately after the ADR-031 block (the paragraph ending `…ADR-031 (\`docs/superpowers/specs/2026-06-13-dimension-review-tuan-agents-design.md\`).`), add a blank line then:

```
**CI guardrail i18n cho view (ADR-032):** một job `i18n-view-guardrail` chạy trên **mọi** pull request (`.github/scripts/check-view-i18n.sh`, native bash fail-loud) quét `app/views/**/*.erb` và **đỏ** khi có literal tiếng Việt **mới** — ký tự có dấu, ngoài comment, ngoài `t(...)` — **không** có trong baseline `.github/i18n-view-baseline.txt`. Phần hard-code **đã có** được grandfather qua baseline (không ép migration vì app single-locale). Ngoại lệ hợp lệ / ghi nhận một đợt migrate: regenerate baseline bằng `UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh` (diff baseline hiện trong pull request, người gác merge duyệt). Không bắt chữ người-dùng **không dấu** hoặc **ngoài view** — phần đó còn người/AI (chiều i18n ở bảng trên). Chi tiết + lý do: ADR-032 trong `docs/superpowers/specs/2026-06-13-guardrail-i18n-view-design.md`.
```

- [ ] **Step 3: Add the "Baseline" gloss to THUAT_NGU §3**

In `docs/THUAT_NGU.md` §3 table, add this row immediately after the `**Guardrail**` row:

```
| **Baseline** (mốc nền) | Ảnh chụp **hiện trạng được chấp nhận** của một lớp vi phạm, để guardrail chỉ chặn cái **mới** (vượt mốc) và **grandfather** (bỏ qua, không bắt) cái cũ — tránh phải dọn sạch trước khi bật luật. Ví dụ `.github/i18n-view-baseline.txt` (ADR-032) chốt các literal tiếng Việt hard-code đang có; `.rubocop_todo.yml` cũng là một baseline. (Khác nghĩa "baseline" trong vài changelog cũ — chỉ *số jargon nền* của ADR-024.) |
```

- [ ] **Step 4: Bump THUAT_NGU version and add a changelog entry**

In `docs/THUAT_NGU.md`, change the version line `> **Phiên bản:** 1.4.0` to `> **Phiên bản:** 1.5.0`. Then add this entry at the top of the `## Lịch sử thay đổi` list (immediately above the `- **1.4.0 …** ` line):

```
- **1.5.0 (13/06/2026):** §3 thêm gloss **"Baseline"** (mốc nền) — ảnh chụp hiện trạng vi phạm để guardrail grandfather cái cũ, chặn cái mới (dùng ở ADR-032 cho `.github/i18n-view-baseline.txt`; `.rubocop_todo.yml` cũng là một baseline). Theo nguyên tắc glossary (ADR-023): định nghĩa ở canonical; không đăng ký vào `.github/dictionaries/glossary-terms.txt` (giữ baseline guardrail ADR-024). Issue #329.
```

- [ ] **Step 5: Run the doc-governance guardrails locally**

Run:
```bash
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions; do
  echo "=== $s ==="; bash .github/scripts/$s.sh; echo "exit=$?"
done
```
Expected: all four print `✓ …` with `exit=0`.

- [ ] **Step 6: Commit the documentation**

```bash
git add CONTRIBUTING.md docs/THUAT_NGU.md
git commit -m "docs: document i18n view guardrail in CONTRIBUTING and glossary (ADR-032)

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Final verification, push, and open the PR

- [ ] **Step 1: Re-run the full local verification suite**

Run:
```bash
bash .github/scripts/check-view-i18n.test.sh            # companion: ✓ all cases passed
bash .github/scripts/check-view-i18n.sh; echo "exit=$?" # real tree: green, exit=0
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions; do
  bash .github/scripts/$s.sh; done                       # all ✓
git status                                               # only the intended files changed
```
Expected: companion green, guardrail green on real tree, all four doc-governance scripts green, working tree clean.

- [ ] **Step 2: Confirm #329's remaining open sub-items (Closes vs Refs)**

Run: `gh issue view 329 --comments | tail -40`
If mục A (this guardrail) is the **last open** sub-item (i.e. #335 truy-vết and #336 mục B are both merged), use `Closes #329` in the PR body. Otherwise use `Refs #329`.

- [ ] **Step 3: Push the branch**

```bash
git push -u origin feature/i18n-view-guardrail
```

- [ ] **Step 4: Open the PR (base `develop`)**

```bash
gh pr create --base develop --title "feat: i18n view guardrail (ADR-032)" --body "$(cat <<'EOF'
## What

Machine-enforce the AGENTS i18n rule for views (mục A of #329). A native-bash CI guardrail (`check-view-i18n.sh`) flags **new** hard-coded Vietnamese literals outside `t(...)` in `app/views/**/*.erb` and turns CI red, while grandfathering the existing ~470 occurrences through a content-based baseline (`.github/i18n-view-baseline.txt`).

## Why this shape (M, not XL)

The app is single-locale (vi), so a full i18n migration would buy a multi-language capability that is never used, at big-bang regression risk. The baseline approach stops the bleeding (the #329 failure mode: implementers copying existing hard-coded patterns) without forcing a migration. Off-the-shelf tools (`rubocop-i18n`, `erb_lint`, `i18n-tasks`) were surveyed and don't fit — see ADR-032. Text-level check → bash, consistent with ADR-024/030.

## How it works

- Per `.erb` line: strip ERB/HTML comment spans, then flag if a Latin-with-diacritics codepoint remains (the Vietnamese signal; ~1/476 overlap with `t()`).
- Record `relpath<TAB>normalized-text` (no line numbers → stable against shifts); fail only on entries **not** in the baseline.
- Escape hatch / migration ledger: `UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh` regenerates the baseline (a reviewable diff).
- Dedicated always-on job `i18n-view-guardrail`.

## Verification

- Companion test `check-view-i18n.test.sh`: 8 cases (new violation → red; grandfathered → green; comment-only → green; mixed line → red; line shift → green; regenerate → green; ASCII English → green).
- Live tree: green after baseline commit; injecting a new literal → red; revert → green.
- All four doc-governance guardrails green.

## Docs

- Spec/ADR-032: `docs/superpowers/specs/2026-06-13-guardrail-i18n-view-design.md`
- Plan: `docs/superpowers/plans/2026-06-13-guardrail-i18n-view.md`
- CONTRIBUTING §8 updated (i18n row → machine-enforced; new guardrail paragraph); THUAT_NGU §3 "Baseline" gloss (v1.5.0).

Closes #329
EOF
)"
```

(If Step 2 found other open sub-items, change `Closes #329` to `Refs #329` in the body above before creating.)

- [ ] **Step 5: Monitor CI and report pass/fail**

After the PR is created, the `gh-pr-monitor` hook prompts CI tracking. Run `gh pr checks <number> --watch` (or poll), then report pass/fail. Do **not** merge — merge is the owner's gate.

---

## Self-review notes

- **Spec coverage:** detection rule (Task 2) ✓; comment stripping (Task 2 perl + Task 1 cases 3–5) ✓; content-based baseline (Task 2 + Task 1 cases 6–7) ✓; regenerate/escape (Task 2 + Task 1 case 7) ✓; new dedicated always-on job (Task 3) ✓; CONTRIBUTING §8 + ADR-031 i18n-row flip (Task 5) ✓; THUAT_NGU gloss + version bump (Task 5) ✓; live red/green (Task 4) ✓; Closes/Refs #329 decision (Task 6) ✓; no `.erb` migration (intentional — none of the tasks edit views except the temporary, reverted Task 4 injection) ✓.
- **Naming consistency:** `check-view-i18n.sh` / `check-view-i18n.test.sh` / `.github/i18n-view-baseline.txt` / job `i18n-view-guardrail` / env `UPDATE_BASELINE` used identically across all tasks.
- **No placeholders:** every script, YAML block, doc line, and command is concrete.
