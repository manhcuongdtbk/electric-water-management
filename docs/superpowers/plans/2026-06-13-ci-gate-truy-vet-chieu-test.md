# CI gate truy vết chiều test ↔ test — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fail-loud CI guardrail (`check-test-dimensions.sh`, 4th script of the `doc-governance` job) that reconciles each spec's `## Truy vết chiều test` table against `CHIEU-<slug>` anchors embedded in `spec/` test descriptions, so silently dropping/downgrading a spec test dimension turns CI red.

**Architecture:** A portable bash script (macOS bash 3.2-safe: `while IFS= read`, no `mapfile`/associative arrays, temp-file accumulators) parses every spec's opt-in table, classifies each row as covered-required or `DEFERRED #issue`, and cross-checks against a grep of the test tree. It applies 4 rules: missing-test, deferred-without-issue, orphan-anchor, anchor-collision. A committed bash test harness drives TDD. Then docs (THUAT_NGU glossary, CONTRIBUTING §8/§9, PR template, V2_CHIEU_TEST note) and a retrofit of all three milestone 1.2.0 specs (TN1+TN3 real anchors, TN2 all `DEFERRED #319`) prove it end-to-end.

**Tech Stack:** Bash (portable, BSD+GNU grep), GitHub Actions, RSpec (test descriptions only — no behavior change), Markdown docs (ADR-002 versioning).

**Design source:** [`docs/superpowers/specs/2026-06-13-truy-vet-chieu-test-design.md`](../specs/2026-06-13-truy-vet-chieu-test-design.md) (ADR-030).

**Branch:** `feature/ci-gate-truy-vet-chieu-test` ← `develop` (already created; ADR-030 spec already committed as `3b0930d`).

---

## Conventions used throughout

- **`CHIEU-<slug>` anchor:** no-accent, theme-based, globally unique; mirrors `NV-<slug>`. Lives in a spec's `## Truy vết chiều test` table and in the matching test's `it`/`describe` description (`it "CHIEU-<slug>: ..."`).
- **Status cell:** a row is **DEFERRED** iff its row text contains `DEFERRED` *and* a `#<number>`; otherwise it is **required** (must have ≥1 test). The words "có test" are for humans only — the machine only special-cases DEFERRED.
- **Run tests in Docker:** `bin/docker rspec <paths>` (never raw `rspec`).
- **Commit discipline:** Conventional Commits, English subject, subject does NOT start with an uppercase token (no `ADR:`/`CT:`/`TN3:` leading). End every commit body with the Co-Authored-By trailer.
- **Doc versioning (ADR-002):** any `docs/**` file with a version header → bump version + add a changelog entry in the SAME commit. Root meta (`CONTRIBUTING.md`, `.github/**`) are NOT versioned.

---

## File Structure

**Create:**
- `.github/scripts/check-test-dimensions.sh` — the guardrail (one responsibility: reconcile tables ↔ test anchors).
- `.github/scripts/check-test-dimensions.test.sh` — committed fixture-based test harness for the guardrail (run locally; not wired into CI).

**Modify:**
- `.github/workflows/ci.yml` — add the 4th script to the `doc-governance` step + rename job label.
- `docs/THUAT_NGU.md` — add a `CHIEU-<slug>` gloss row next to the `NV-` Anchor row (bump version + changelog).
- `CONTRIBUTING.md` §8 + §9 — document the `CHIEU-` convention and the plan/PR requirement (not versioned).
- `.github/pull_request_template.md` — one traceability-checklist line.
- `docs/V2_CHIEU_TEST.md` — note that per-feature dimensions live in spec `CHIEU-` tables (bump version + changelog).
- `docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md` (TN3) — bullet list → `CHIEU-` table (bump + changelog).
- `docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md` (TN1) — bullet list → `CHIEU-` table (bump + changelog).
- `docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md` (TN2) — bullet list → `CHIEU-` table, all `DEFERRED #319` (bump + changelog).
- `spec/requests/meter_entries_spec.rb`, `spec/requests/pump_entries_spec.rb`, `spec/requests/billing_spec.rb` — convert TN3 `Dn:` description prefixes → `CHIEU-<slug>:`.
- `spec/services/summary_calculator_spec.rb`, `spec/models/other_deduction_spec.rb`, `spec/requests/unit_config_spec.rb`, `spec/services/period_service_spec.rb` — prepend TN1 `CHIEU-<slug>:` to identified tests.

> **Refinement vs spec (note for reviewer):** ADR-030's "Tệp sửa" listed adding `CT` to `.github/dictionaries/glossary-terms.txt`. We instead document `CHIEU-` in the existing **Anchor** gloss concept in `THUAT_NGU.md` (parallel to how `NV-` is handled — `NV` is itself not a registered glossary term; the protected term is `anchor`). This avoids needing a `CT`-headed table row and keeps the guardrail's baseline term count unchanged. No `glossary-terms.txt` change.

---

## Phase 1 — The guardrail script (TDD via committed harness)

### Task 1: Write the failing test harness

**Files:**
- Create: `.github/scripts/check-test-dimensions.test.sh`

- [ ] **Step 1: Write the harness (it will fail because the script does not exist yet)**

```bash
#!/usr/bin/env bash
# Test cho check-test-dimensions.sh (ADR-030). Tạo fixture tạm rồi kiểm exit code
# + thông báo cho từng luật. Chạy tay: bash .github/scripts/check-test-dimensions.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-test-dimensions.sh"
fails=0

# make_case <specs-table-body> <test-file-body> → in ra "$tmp" (thư mục gốc fixture)
make_case() {
  local tmp specdir testdir
  tmp="$(mktemp -d)"
  specdir="$tmp/specs"; testdir="$tmp/spec"
  mkdir -p "$specdir" "$testdir"
  {
    printf '# Fixture spec\n\n## Truy vết chiều test\n\n'
    printf '| Mã | Chiều test | Trạng thái |\n|---|---|---|\n'
    printf '%s\n' "$1"
    printf '\n## Giới hạn\n\nkết section.\n'
  } > "$specdir/fixture-design.md"
  printf '%s\n' "$2" > "$testdir/fixture_spec.rb"
  printf '%s' "$tmp"
}

assert() {
  # assert <label> <expected-exit> <specs-table-body> <test-file-body> [grep-needle]
  local label="$1" expected="$2" body="$3" testbody="$4" needle="${5:-}"
  local tmp out rc
  tmp="$(make_case "$body" "$testbody")"
  out="$(bash "$SCRIPT" "$tmp/specs" "$tmp/spec" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

# 1. PASS: required row has a matching test; deferred row has an issue.
assert "pass: covered + deferred" 0 \
  '| `CHIEU-alpha` | mô tả | có test |
| `CHIEU-beta` | mô tả | DEFERRED #319 |' \
  'it "CHIEU-alpha: hành vi" do; end'

# 2. FAIL: required row with no test.
assert "fail: missing test" 1 \
  '| `CHIEU-alpha` | mô tả | có test |' \
  'it "khong co anchor" do; end' \
  "Thiếu test"

# 3. FAIL: deferred row without an issue number.
assert "fail: deferred without issue" 1 \
  '| `CHIEU-beta` | mô tả | DEFERRED |' \
  'it "noop" do; end' \
  "Deferred thiếu Issue"

# 4. FAIL: orphan anchor used in a test but not declared.
assert "fail: orphan" 1 \
  '| `CHIEU-alpha` | mô tả | có test |' \
  'it "CHIEU-alpha: ok" do; end
it "CHIEU-ghost: orphan" do; end' \
  "Orphan"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
```

- [ ] **Step 2: Make it executable and run it — verify it FAILS (script missing)**

Run: `chmod +x .github/scripts/check-test-dimensions.test.sh && bash .github/scripts/check-test-dimensions.test.sh`
Expected: FAIL — every case errors because `check-test-dimensions.sh` does not exist (non-zero exits / "No such file"). Confirms the harness actually exercises the script.

> Collision (rule 4b) is covered by a separate manual fixture in Task 4 because the harness's `make_case` writes a single spec file; a 2-file collision is verified by hand there.

### Task 2: Write the guardrail script

**Files:**
- Create: `.github/scripts/check-test-dimensions.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Guardrail truy vết chiều test (ADR-030): mỗi spec trong docs/superpowers/specs/
# có thể khai một bảng "## Truy vết chiều test" với hàng `CHIEU-<slug> | mô tả |
# trạng thái`. Test mang anchor `CHIEU-<slug>` ở mô tả `it`. Script đối chiếu bảng ↔
# grep cây spec/ với 4 luật: (1) hàng required (không DEFERRED) phải có ≥1 test;
# (2) hàng DEFERRED phải kèm #<số>; (3) anchor CHIEU- dùng trong test phải có trong
# một bảng (chống orphan/typo); (4) một anchor không được khai ở >1 spec (unique).
# Opt-in: spec không có section thì không đóng góp khai báo. Portable bash (macOS
# 3.2: while-read, không mapfile/assoc-array). FAIL-LOUD: vi phạm/lỗi → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
TESTS_DIR="${2:-spec}"
SECTION_HEADER='## Truy vết chiều test'

[[ -d "$SPECS_DIR" ]] || { echo "✗ check-test-dimensions: specs dir not found: $SPECS_DIR"; exit 1; }
[[ -d "$TESTS_DIR" ]]  || { echo "✗ check-test-dimensions: tests dir not found: $TESTS_DIR"; exit 1; }

decl="$(mktemp)"   # mỗi dòng: anchor<TAB>specfile<TAB>deferred(0|1)
trap 'rm -f "$decl"' EXIT

violations=0

# (1) Trích khai báo từ mọi spec: hàng bảng trong section, bỏ code fence.
while IFS= read -r spec; do
  insection=0; incode=0
  while IFS= read -r raw; do
    case "$raw" in
      '```'* | '~~~'*) incode=$((1 - incode)); continue ;;
    esac
    (( incode )) && continue
    case "$raw" in
      "$SECTION_HEADER"*) insection=1; continue ;;
      '## '*) insection=0; continue ;;
    esac
    (( insection )) || continue
    case "$raw" in '|'*) : ;; *) continue ;; esac     # chỉ hàng bảng
    case "$raw" in *CHIEU-*) : ;; *) continue ;; esac     # có token CHIEU-
    anchor="$(printf '%s' "$raw" | grep -oE 'CHIEU-[a-z0-9-]+' | head -n1)"
    [[ -z "$anchor" ]] && continue
    deferred=0
    if printf '%s' "$raw" | grep -qE 'DEFERRED'; then
      deferred=1
      if ! printf '%s' "$raw" | grep -qE '#[0-9]+'; then
        echo "✗ Deferred thiếu Issue  $spec  → $anchor  (cần dạng 'DEFERRED #<số>')"
        violations=$((violations + 1))
      fi
    fi
    printf '%s\t%s\t%s\n' "$anchor" "$spec" "$deferred" >> "$decl"
  done < "$spec"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

# (2) Đụng tên: cùng anchor khai ở >1 spec khác nhau.
while IFS= read -r anchor; do
  [[ -z "$anchor" ]] && continue
  nfiles="$(awk -F'\t' -v a="$anchor" '$1==a {print $2}' "$decl" | sort -u | wc -l | tr -d ' ')"
  if [[ "$nfiles" -gt 1 ]]; then
    echo "✗ Đụng tên anchor  $anchor  khai ở $nfiles spec khác nhau"
    violations=$((violations + 1))
  fi
done < <(cut -f1 "$decl" | sort -u)

# (3) Độ phủ: mỗi anchor required (deferred=0) phải có ≥1 test nhắc tới
#     (theo sau anchor là ký tự không-slug để tránh khớp tiền tố nhầm).
while IFS=$'\t' read -r anchor spec deferred; do
  [[ "$deferred" == "1" ]] && continue
  if ! grep -rqE -- "${anchor}([^a-z0-9-]|\$)" "$TESTS_DIR" 2>/dev/null; then
    echo "✗ Thiếu test  $anchor  (khai ở $spec, không DEFERRED) — không test nào trong $TESTS_DIR/ nhắc tới"
    violations=$((violations + 1))
  fi
done < "$decl"

# (4) Orphan: token CHIEU- trong test phải có trong một bảng spec.
while IFS= read -r token; do
  [[ -z "$token" ]] && continue
  if ! cut -f1 "$decl" | grep -qxF -- "$token"; then
    echo "✗ Orphan  $token  dùng trong $TESTS_DIR/ nhưng không có trong bảng spec nào"
    violations=$((violations + 1))
  fi
done < <(grep -rhoE 'CHIEU-[a-z0-9-]+' "$TESTS_DIR" 2>/dev/null | sort -u)

if (( violations > 0 )); then
  echo "✗ check-test-dimensions: $violations test-dimension traceability issue(s)."
  exit 1
fi
echo "✓ check-test-dimensions: every declared test dimension is covered or DEFERRED."
```

- [ ] **Step 2: Make it executable and run the harness — verify PASS**

Run: `chmod +x .github/scripts/check-test-dimensions.sh && bash .github/scripts/check-test-dimensions.test.sh`
Expected: PASS — `✓ pass: covered + deferred`, `✓ fail: missing test`, `✓ fail: deferred without issue`, `✓ fail: orphan`, then `✓ all cases passed`.

- [ ] **Step 3: Run the script on the real repo — verify PASS (no spec has the section yet)**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: PASS — `✓ check-test-dimensions: every declared test dimension is covered or DEFERRED.` (No `## Truy vết chiều test` section exists yet, so there are zero declarations and zero orphan anchors — green by construction.)

### Task 3: Verify the collision rule (manual fixture)

**Files:** none committed — temporary fixture only.

- [ ] **Step 1: Create a two-spec collision fixture and run the script**

```bash
T="$(mktemp -d)"; mkdir -p "$T/specs" "$T/spec"
printf '## Truy vết chiều test\n| Mã | M | T |\n|---|---|---|\n| `CHIEU-dup` | x | có test |\n## Giới hạn\n' > "$T/specs/a-design.md"
printf '## Truy vết chiều test\n| Mã | M | T |\n|---|---|---|\n| `CHIEU-dup` | y | có test |\n## Giới hạn\n' > "$T/specs/b-design.md"
printf 'it "CHIEU-dup: ok" do; end\n' > "$T/spec/x_spec.rb"
bash .github/scripts/check-test-dimensions.sh "$T/specs" "$T/spec"; echo "exit=$?"
rm -rf "$T"
```

Expected: prints `✗ Đụng tên anchor  CHIEU-dup  khai ở 2 spec khác nhau` and `exit=1`.

### Task 4: Commit Phase 1

- [ ] **Step 1: Commit the script + harness**

```bash
git add .github/scripts/check-test-dimensions.sh .github/scripts/check-test-dimensions.test.sh
git commit -m "$(cat <<'EOF'
feat(ci): add test-dimension traceability guardrail script

Reconciles each spec's "## Truy vết chiều test" table against CHIEU-<slug>
anchors in spec/ test descriptions. Four rules: missing-test,
deferred-without-issue, orphan-anchor, anchor-collision. Portable bash
(macOS 3.2-safe). Committed fixture harness drives the cases.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Wire into the `doc-governance` CI job

### Task 5: Add the 4th script to ci.yml

**Files:**
- Modify: `.github/workflows/ci.yml` (the `doc-governance` job, ~lines 76-92)

- [ ] **Step 1: Update the job label and the run block**

Replace this:

```yaml
  doc-governance:
    name: Doc governance (links, map, glossary definitions)
```

with:

```yaml
  doc-governance:
    name: Doc governance (links, map, glossary, test dimensions)
```

Then, inside the `run: |` block, add the 4th script before `exit $rc`:

```yaml
          bash .github/scripts/check-glossary-definitions.sh || rc=1
          bash .github/scripts/check-test-dimensions.sh || rc=1
          exit $rc
```

(The new line goes immediately after the existing `check-glossary-definitions.sh` line and before `exit $rc`.)

- [ ] **Step 2: Sanity-check the YAML by re-running all four scripts together (mirrors the job)**

Run:
```bash
rc=0
bash .github/scripts/check-doc-links.sh || rc=1
bash .github/scripts/check-doc-map.sh || rc=1
bash .github/scripts/check-glossary-definitions.sh || rc=1
bash .github/scripts/check-test-dimensions.sh || rc=1
echo "combined rc=$rc"
```
Expected: all four print `✓` and `combined rc=0`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci(doc-governance): run test-dimension traceability check

Add check-test-dimensions.sh as the 4th doc-governance script so the
guardrail runs on every pull request (incl. docs-only). Update job label.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 3 — Glossary: document the `CHIEU-` anchor

### Task 6: Add the CHIEU- gloss to THUAT_NGU.md

**Files:**
- Modify: `docs/THUAT_NGU.md` (§3 Anchor row at line 54; version line 3; changelog at line 67)

- [ ] **Step 1: Insert a sibling gloss row right after the existing Anchor row**

Find line 54:
```
| **Anchor** (`NV-...`) | Mã định danh gắn trước một mục yêu cầu trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` (dạng `<a id="NV-chủ-đề">`), để truy vết yêu cầu → thiết kế → test bằng grep (xem `CONTRIBUTING.md` mục 9). |
```
Insert immediately AFTER it:
```
| **Anchor chiều test** (`CHIEU-...`) | Mã định danh một chiều test, khai trong bảng `## Truy vết chiều test` của một spec (`CHIEU-<slug>`, không dấu, theo chủ đề, song song `NV-`). Khác `NV-`: anchor này **gắn thẳng vào mô tả `it` của test** (`it "CHIEU-<slug>: ..."`) để CI đối chiếu bảng ↔ test (ADR-030, `CONTRIBUTING.md` mục 9). |
```

- [ ] **Step 2: Bump the version header (line 3)**

Replace `> **Phiên bản:** 1.3.0` with `> **Phiên bản:** 1.4.0` and `> **Ngày:** 11/06/2026` with `> **Ngày:** 13/06/2026`.

- [ ] **Step 3: Add a changelog entry at the top of "## Lịch sử thay đổi" (above the `1.3.0` line)**

```
- **1.4.0 (13/06/2026):** §3 thêm gloss **"Anchor chiều test"** (`CHIEU-...`) song song `NV-...` — mã chiều test khai ở bảng `## Truy vết chiều test` của spec, gắn vào mô tả `it` để CI đối chiếu (ADR-030, Issue #329). Khác `NV-` ở chỗ cố ý nhúng mã vào test (đường nâng cấp ADR-015). Không đăng ký term mới vào `glossary-terms.txt` (giữ baseline; khái niệm "anchor" đã được bảo vệ).
```

- [ ] **Step 4: Verify glossary + links still pass**

Run: `bash .github/scripts/check-glossary-definitions.sh && bash .github/scripts/check-doc-links.sh`
Expected: both `✓`.

- [ ] **Step 5: Commit**

```bash
git add docs/THUAT_NGU.md
git commit -m "$(cat <<'EOF'
docs(glossary): define CHIEU- test-dimension anchor

Add an "Anchor chiều test" gloss parallel to the NV- requirement anchor;
CHIEU- anchors are embedded in test descriptions for CI reconciliation
(ADR-030). Bump THUAT_NGU to 1.4.0.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 4 — Process docs: CONTRIBUTING + PR template

### Task 7: Document the convention in CONTRIBUTING §8 and §9

**Files:**
- Modify: `CONTRIBUTING.md` (§8 ~line 133; §9 "Liên kết truy vết" ~line 170-174)

- [ ] **Step 1: Add a guardrail paragraph to §8, right after the ADR-024 paragraph (line 133)**

Insert after the line beginning `**CI guardrail quản trị tài liệu (ADR-024):** ...`:

```
**CI guardrail truy vết chiều test (ADR-030):** script thứ tư của job `doc-governance` (`check-test-dimensions.sh`) đối chiếu bảng `## Truy vết chiều test` của mỗi spec với anchor `CHIEU-<slug>` nhúng trong mô tả `it` của test (`spec/`). Đỏ nếu: một chiều **required** thiếu test; một chiều **DEFERRED** không kèm `#<số>`; anchor `CHIEU-` dùng trong test mà không có trong bảng nào (orphan); hoặc một anchor khai trùng ở hai spec. Biến luật AGENTS "test mọi output + cả 6 vai trò" thành máy-ép cho phần khai-tường-minh. Việc "spec có đủ chiều chưa" vẫn là review người (checklist plan/PR). Chi tiết: ADR-030 trong `docs/superpowers/specs/2026-06-13-truy-vet-chieu-test-design.md`.
```

- [ ] **Step 2: Extend §9 "Liên kết truy vết" — add a CHIEU- bullet without contradicting the NV- bullet**

Find the bullet at line 173:
```
- **Test ↔ yêu cầu:** link ở phía spec/pull request, **không** gắn mã vào code test. Yêu cầu cũ (chưa có design spec) trỏ `docs/V2_KICH_BAN_TEST.md` / `docs/V2_CHIEU_TEST.md`.
```
Insert a new bullet immediately AFTER it:
```
- **Chiều test ↔ test (`CHIEU-<slug>`):** khác với `NV-` ở trên — chiều test **có** gắn mã vào test. Spec tính năng kết phần chiều test bằng bảng `## Truy vết chiều test` (`| Mã `CHIEU-<slug>` | mô tả | có test \| DEFERRED #issue |`); test mang anchor ở mô tả `it "CHIEU-<slug>: ..."`. CI (`check-test-dimensions.sh`, ADR-030) đối chiếu hai bên. Hoãn một chiều → ghi `DEFERRED #<issue-gate>`, không bỏ im. Map mỗi chiều test của spec + 2 luật AGENTS (mọi-output, 6-vai-trò) → một hàng khi viết plan.
```

- [ ] **Step 3: Verify links still pass (CONTRIBUTING is scanned by check-doc-links)**

Run: `bash .github/scripts/check-doc-links.sh`
Expected: `✓`.

- [ ] **Step 4: Update the PR template**

**Files:** Modify `.github/pull_request_template.md` (Traceability checklist).

After the existing line:
```
- [ ] The design spec's `## Truy vết` section links the requirement (`NV-...`) and the covering test(s).
```
insert:
```
- [ ] If the change implements a feature spec with test dimensions: the spec has a `## Truy vết chiều test` table and every dimension maps to a test (`CHIEU-<slug>:`) or `DEFERRED #issue` (ADR-030).
```

- [ ] **Step 5: Commit**

```bash
git add CONTRIBUTING.md .github/pull_request_template.md
git commit -m "$(cat <<'EOF'
docs(contributing): document CHIEU- test-dimension traceability

Add the CHIEU-<slug> convention and CI guardrail to §8/§9 and the PR
template, parallel to (and explicitly distinct from) the NV- requirement
anchor which stays out of test code.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 5 — V2_CHIEU_TEST.md pointer note

### Task 8: Point V2_CHIEU_TEST at per-spec CHIEU- tables

**Files:**
- Modify: `docs/V2_CHIEU_TEST.md` (milestone section intro ~line 484; version line 3; changelog ~line 502)

- [ ] **Step 1: Add a pointer sentence to the milestone-1.2.0 section intro (the blockquote at line ~484)**

Append to the existing `> **Trạng thái:** ...` blockquote a new sentence:
```
Từ ADR-030, chiều test per-tính-năng được khai chính thức ở bảng `## Truy vết chiều test` (anchor `CHIEU-<slug>`) của từng spec và CI đối chiếu với test; mục này giữ vai trò catalog 12 chiều khái niệm + trỏ tới spec, không phải nơi theo dõi trạng thái triển khai.
```

- [ ] **Step 2: Bump version (line 3) and add changelog (top of "## Lịch sử thay đổi", line ~500)**

Replace `> **Phiên bản:** 1.3.1` → `> **Phiên bản:** 1.4.0` and `> **Ngày:** 12/06/2026` → `> **Ngày:** 13/06/2026`.

Add at the top of the changelog:
```
### v1.4.0 (13/06/2026)

- Thêm ghi chú: chiều test per-tính-năng khai ở bảng `## Truy vết chiều test` (anchor `CHIEU-<slug>`) của từng spec, CI đối chiếu với test (ADR-030, Issue #329). Mục này giữ vai trò catalog 12 chiều khái niệm + trỏ tới spec, không theo dõi trạng thái triển khai (giảm phụ thuộc prose current-state dễ lỗi thời).
```

- [ ] **Step 3: Verify links pass**

Run: `bash .github/scripts/check-doc-links.sh`
Expected: `✓`.

- [ ] **Step 4: Commit**

```bash
git add docs/V2_CHIEU_TEST.md
git commit -m "$(cat <<'EOF'
docs(test-dimensions): point V2_CHIEU_TEST at per-spec CHIEU- tables

Note that feature test dimensions are now declared in each spec's
"## Truy vết chiều test" table (ADR-030); this doc stays the conceptual
12-axis catalog. Bump to 1.4.0.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 6 — Retrofit TN3 (tổn hao): convert `Dn:` → `CHIEU-`

> TN3 tests already carry an informal, spec-local `Dn:` scheme (D1–D15). Convert every `Dn:` display-test prefix to its canonical `CHIEU-<slug>:`. Engine unit tests (`loss_calculator_spec`, `loss_snapshot_writer_spec`) keep their descriptive names — they support the dimensions but the request specs carry the anchors.

**Dn → CHIEU- slug map (TN3):**

| CHIEU- slug | Dimension | Existing Dn tests to convert |
|---|---|---|
| `CHIEU-ton-hao-chua-tinh` | chưa tính → cột trống / không A/B/C | D1, D2 |
| `CHIEU-ton-hao-sau-tinh` | sau tính → loss/usage/A/B/C đúng | D3, D4, D15 |
| `CHIEU-ton-hao-sua-giu-cu` | sửa chỉ số sau tính → giữ giá trị cũ | D5 |
| `CHIEU-ton-hao-bien` | C<0, B=0, khu vực trống → giá trị + cảnh báo | D6 + B=0 test + empty-zone test |
| `CHIEU-ton-hao-theo-zone` | A/B/C theo zone đang chọn | D9, D10 |
| `CHIEU-ton-hao-khong-ton-hao` | công tơ no_loss → loss=0 | D11 |
| `CHIEU-ton-hao-vai-tro` | 6 vai trò, 2 cột read-only | D12, D13, D14 |

### Task 9: Convert the TN3 test description prefixes

**Files:**
- Modify: `spec/requests/meter_entries_spec.rb`, `spec/requests/pump_entries_spec.rb`, `spec/requests/billing_spec.rb`

- [ ] **Step 1: In `spec/requests/meter_entries_spec.rb`, replace each `Dn:` description prefix per the map**

For each test, change only the leading code token inside the description string (keep the rest of the text). Apply:
- `it "D1: ...` → `it "CHIEU-ton-hao-chua-tinh: ...`
- `it "D3: ...` → `it "CHIEU-ton-hao-sau-tinh: ...`
- `it "D5: ...` → `it "CHIEU-ton-hao-sua-giu-cu: ...`
- `it "D11: ...` → `it "CHIEU-ton-hao-khong-ton-hao: ...`
- `it "D14: ...` → `it "CHIEU-ton-hao-vai-tro: ...`
- `describe "D12: ...` → `describe "CHIEU-ton-hao-vai-tro: ...`

- [ ] **Step 2: In `spec/requests/pump_entries_spec.rb`, apply the same map**

- `it "D1: ...` → `it "CHIEU-ton-hao-chua-tinh: ...`
- `it "D3: ...` → `it "CHIEU-ton-hao-sau-tinh: ...`
- `it "D14: ...` → `it "CHIEU-ton-hao-vai-tro: ...`
- `describe "D12: ...` → `describe "CHIEU-ton-hao-vai-tro: ...`

- [ ] **Step 3: In `spec/requests/billing_spec.rb`, apply the map (including the Excel-variant codes)**

- `it "D15: ...` → `it "CHIEU-ton-hao-sau-tinh: ...`
- `it "D2(Excel): ...` → `it "CHIEU-ton-hao-chua-tinh: ...` (Excel: chưa tính → không A/B/C)
- `it "D2: ...` → `it "CHIEU-ton-hao-chua-tinh: ...`
- `it "D4: ...` → `it "CHIEU-ton-hao-sau-tinh: ...`
- `it "D9: ...` → `it "CHIEU-ton-hao-theo-zone: ...`
- `it "D10: ...` → `it "CHIEU-ton-hao-theo-zone: ...`
- `it "D13: ...` → `it "CHIEU-ton-hao-vai-tro: ...`
- `it "D6: ...` → `it "CHIEU-ton-hao-bien: ...`

Then prepend `CHIEU-ton-hao-bien: ` to the two edge tests that have NO Dn prefix (so the `CHIEU-ton-hao-bien` row has all three cases tagged):
- the test described `B = 0 (mọi công tơ không tổn hao) → A/B/C hiển thị (B=C=0) + cảnh báo` → make it `CHIEU-ton-hao-bien: B = 0 (mọi công tơ không tổn hao) → ...`
- the test described `khu vực trống (có số điện lực, không đầu mối) → A/B/C (B=C=0) + cảnh báo trên billing` → make it `CHIEU-ton-hao-bien: khu vực trống ...`

> If any `Dn:` token above is not found in its file (codes drift), grep the file for `"D` to list the actual codes and re-map by matching the dimension description in the table; do NOT invent a test.

- [ ] **Step 4: Run the TN3 specs — confirm still green (only descriptions changed)**

Run: `bin/docker rspec spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb spec/requests/billing_spec.rb`
Expected: all examples pass (renaming an `it`/`describe` description never changes behavior).

### Task 10: Convert the TN3 spec bullet list to a CHIEU- table

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md` (the `## Chiều test cần bổ sung` section at lines 76-86; version line 3; changelog line ~100)

- [ ] **Step 1: Replace the section heading + bullet list (lines 76-86) with the table**

Replace the heading `## Chiều test cần bổ sung` and the 7 bullets with:

```
## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-ton-hao-chua-tinh` | Chưa bấm tính → hai cột Tổn hao / Sử dụng thực tế **trống**; chưa có tóm tắt A/B/C | có test |
| `CHIEU-ton-hao-sau-tinh` | Sau khi tính → hai cột đúng `meter_losses`; "Sử dụng thực tế" = sử dụng + loss; A/B/C khớp `LossCalculator` (HTML + Excel) | có test |
| `CHIEU-ton-hao-sua-giu-cu` | Sửa chỉ số sau khi tính (chưa tính lại) → hai cột **giữ** giá trị lần tính gần nhất | có test |
| `CHIEU-ton-hao-bien` | Trường hợp đặc biệt: C < 0, B = 0, khu vực trống → giá trị + cảnh báo đúng | có test |
| `CHIEU-ton-hao-theo-zone` | A/B/C theo zone đang chọn (quản trị viên hệ thống đổi zone → đổi A/B/C; nhiều zone → mỗi zone một dòng) | có test |
| `CHIEU-ton-hao-khong-ton-hao` | Công tơ không tổn hao (`no_loss`) → loss = 0 | có test |
| `CHIEU-ton-hao-vai-tro` | Sáu vai trò: hai cột read-only cho mọi vai trò; ai thấy bảng tính tiền nào thì thấy A/B/C tương ứng (TECH bị chặn) | có test |
```

- [ ] **Step 2: Bump version + changelog**

Line 3: bump the spec `version:` from `0.2.2` to `0.3.0`.

Add to the top of `## Changelog`:
```
### 0.3.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>` (ADR-030, Issue #329); gắn anchor vào mô tả test (chuyển mã `Dn:` cũ → `CHIEU-` chuẩn). CI đối chiếu bảng ↔ test.
```

- [ ] **Step 3: Run the new guardrail — confirm TN3 dimensions are all covered**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: `✓ check-test-dimensions: every declared test dimension is covered or DEFERRED.` (All 7 TN3 anchors now appear in the converted tests.)

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md \
  spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb spec/requests/billing_spec.rb
git commit -m "$(cat <<'EOF'
docs(tn3): adopt CHIEU- test-dimension table for loss display

Convert the TN3 loss-display spec's bullet list to a "## Truy vết chiều
test" table and replace the spec-local Dn: test codes with canonical
CHIEU-<slug> anchors. Guardrail now verifies all 7 dimensions.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 7 — Retrofit TN1 (cột Khác `unit_coefficient`): add anchors

> TN1 tests use descriptive Vietnamese names (no codes). Prepend `CHIEU-<slug>: ` to each identified covering test.

**CHIEU- slug map (TN1):**

| CHIEU- slug | Dimension | Covering test (file → current `it` description) |
|---|---|---|
| `CHIEU-khac-don-vi-dau` | other_value dương & âm | `spec/services/summary_calculator_spec.rb` → `khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối)` (negative) AND `khoản trừ = hệ số dương × (tổng quân số đơn vị − quân số đầu mối)` (positive) |
| `CHIEU-khac-don-vi-vi-du` | ví dụ số liệu nghiệp vụ | `spec/requests/billing_spec.rb` → `cell U7 (Khác của Văn thư) = -16` |
| `CHIEU-khac-don-vi-tu-tinh-lai` | quân số đổi → tự tính lại | `spec/services/summary_calculator_spec.rb` → `khoản trừ tự cập nhật = -2 × (13 − 2) = -22,00 sau khi quân số Ban Tác huấn tăng thêm 3` |
| `CHIEU-khac-don-vi-mot-dau-moi` | đơn vị một đầu mối → 0 | `spec/services/summary_calculator_spec.rb` → `khoản trừ = 0 khi đơn vị chỉ có một đầu mối sinh hoạt` |
| `CHIEU-khac-don-vi-zone-direct` | zone-direct chặn + ẩn option | `spec/models/other_deduction_spec.rb` → `invalid khi đầu mối thuộc khu vực trực tiếp (unit_id null)` AND `spec/requests/unit_config_spec.rb` → `PATCH updating zone-direct contact point OD to unit_coefficient is rejected by model validation` AND `GET unit config shows unit_coefficient option exactly for unit contact points (3 unit CPs, 0 zone CPs)` |
| `CHIEU-khac-don-vi-ke-thua` | kế thừa kỳ mới | `spec/services/period_service_spec.rb` → `unit_coefficient kế thừa sang kỳ mới và tính lại đúng khoản trừ` |
| `CHIEU-khac-don-vi-vai-tro` | 6 vai trò (chỉ huy chỉ xem) | `spec/requests/unit_config_spec.rb` → `select kiểu khoản trừ bị disabled cho chỉ huy đơn vị` |

### Task 11: Prepend CHIEU- anchors to the TN1 tests

**Files:**
- Modify: `spec/services/summary_calculator_spec.rb`, `spec/requests/billing_spec.rb`, `spec/models/other_deduction_spec.rb`, `spec/requests/unit_config_spec.rb`, `spec/services/period_service_spec.rb`

- [ ] **Step 1: `summary_calculator_spec.rb` — prepend anchors**

- `it "khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối)"` → `it "CHIEU-khac-don-vi-dau: khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối)"`
- `it "khoản trừ = hệ số dương × (tổng quân số đơn vị − quân số đầu mối)"` → prepend `CHIEU-khac-don-vi-dau: `
- `it "khoản trừ tự cập nhật = -2 × (13 − 2) = -22,00 sau khi quân số Ban Tác huấn tăng thêm 3"` → prepend `CHIEU-khac-don-vi-tu-tinh-lai: `
- `it "khoản trừ = 0 khi đơn vị chỉ có một đầu mối sinh hoạt"` → prepend `CHIEU-khac-don-vi-mot-dau-moi: `

- [ ] **Step 2: `billing_spec.rb` — prepend anchor**

- `it "cell U7 (Khác của Văn thư) = -16"` → prepend `CHIEU-khac-don-vi-vi-du: `

- [ ] **Step 3: `other_deduction_spec.rb` — prepend anchor**

- `it "invalid khi đầu mối thuộc khu vực trực tiếp (unit_id null)"` → prepend `CHIEU-khac-don-vi-zone-direct: `

- [ ] **Step 4: `unit_config_spec.rb` — prepend anchors**

- `it "PATCH updating zone-direct contact point OD to unit_coefficient is rejected by model validation"` → prepend `CHIEU-khac-don-vi-zone-direct: `
- `it "GET unit config shows unit_coefficient option exactly for unit contact points (3 unit CPs, 0 zone CPs)"` → prepend `CHIEU-khac-don-vi-zone-direct: `
- `it "select kiểu khoản trừ bị disabled cho chỉ huy đơn vị"` → prepend `CHIEU-khac-don-vi-vai-tro: `

- [ ] **Step 5: `period_service_spec.rb` — prepend anchor**

- `it "unit_coefficient kế thừa sang kỳ mới và tính lại đúng khoản trừ"` → prepend `CHIEU-khac-don-vi-ke-thua: `

> If any quoted description does not match exactly (text drift), grep the file for a distinctive substring (e.g. `một đầu mối sinh hoạt`, `kế thừa sang kỳ mới`) to locate the real test and prepend the anchor there. Do NOT create new tests.

- [ ] **Step 6: Run the TN1 specs — confirm still green**

Run: `bin/docker rspec spec/services/summary_calculator_spec.rb spec/requests/billing_spec.rb spec/models/other_deduction_spec.rb spec/requests/unit_config_spec.rb spec/services/period_service_spec.rb`
Expected: all examples pass.

### Task 12: Convert the TN1 spec bullet list to a CHIEU- table

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md` (`## Chiều test cần bổ sung` at lines 77-87; version line 3; changelog line ~102)

- [ ] **Step 1: Replace the section (lines 77-87) with the table**

Replace `## Chiều test cần bổ sung` and its intro + 7 bullets with:

```
## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-khac-don-vi-dau` | `unit_coefficient` với `other_value` dương (đầu mối bị trừ) và âm (đầu mối được cộng ngược, ví dụ bếp) | có test |
| `CHIEU-khac-don-vi-vi-du` | Khớp ví dụ số liệu nghiệp vụ (đơn vị, bếp, `other_value` âm → giá trị đúng) | có test |
| `CHIEU-khac-don-vi-tu-tinh-lai` | Quân số đổi giữa kỳ → khoản trừ tự tính lại (không sửa tay) | có test |
| `CHIEU-khac-don-vi-mot-dau-moi` | Đơn vị chỉ có một đầu mối (tổng − chính nó = 0) → khoản trừ = 0 | có test |
| `CHIEU-khac-don-vi-zone-direct` | Đầu mối zone-direct chọn `unit_coefficient` → validate chặn (request) + option bị ẩn (UI) | có test |
| `CHIEU-khac-don-vi-ke-thua` | Kế thừa sang kỳ mới giữ `unit_coefficient` + hệ số, tính lại theo quân số kỳ mới | có test |
| `CHIEU-khac-don-vi-vai-tro` | Sáu vai trò: ai sửa được cột Khác giữ nguyên (quản trị viên đơn vị; chỉ huy chỉ xem) | có test |
```

- [ ] **Step 2: Bump version + changelog**

Line 3: bump `version:` from `0.1.1` to `0.2.0`.

Add to the top of `## Changelog`:
```
### 0.2.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>` (ADR-030, Issue #329); gắn anchor vào mô tả các test sẵn có. CI đối chiếu bảng ↔ test.
```

- [ ] **Step 3: Run the guardrail — confirm TN1 + TN3 covered**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: `✓ ...every declared test dimension is covered or DEFERRED.`

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md \
  spec/services/summary_calculator_spec.rb spec/requests/billing_spec.rb \
  spec/models/other_deduction_spec.rb spec/requests/unit_config_spec.rb \
  spec/services/period_service_spec.rb
git commit -m "$(cat <<'EOF'
docs(tn1): adopt CHIEU- test-dimension table for unit_coefficient column

Convert the TN1 "Khác" unit_coefficient spec to a "## Truy vết chiều
test" table and tag the covering tests with CHIEU-<slug> anchors.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 8 — Retrofit TN2 (phân bổ bơm theo trạm): all DEFERRED

> TN2 is not implemented yet (no tests). Its table is the worked `DEFERRED #319` example — proving the deferred branch passes with zero tests.

### Task 13: Convert the TN2 spec bullet list to an all-DEFERRED table

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md` (`## Chiều test cần bổ sung` at lines 84-95; version line 3; changelog line ~111)

- [ ] **Step 1: Replace the section (lines 84-95) with the all-DEFERRED table**

Replace `## Chiều test cần bổ sung` and its intro + 8 bullets with:

```
## Truy vết chiều test

Tính năng **chưa triển khai** — mọi chiều `DEFERRED #319` cho tới khi build (ADR-030).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-phan-bo-tram-ky-cu` | Kỳ cũ (`per_station = false`): gộp toàn khu vực **không đổi** (regression) | DEFERRED #319 |
| `CHIEU-phan-bo-tram-tong` | Kỳ mới: hai trạm, recipient riêng; Σ per-trạm = `D` toàn khu vực | DEFERRED #319 |
| `CHIEU-phan-bo-tram-bon-recipient` | Bốn loại recipient (đơn vị / khối / nhóm / đầu mối) chia xuống đúng | DEFERRED #319 |
| `CHIEU-phan-bo-tram-rang-buoc` | Ràng buộc per-trạm: Σ fixed% ≤ 100; thiếu recipient hệ số → chặn; Σ(quân số×hệ số)=0 → chặn | DEFERRED #319 |
| `CHIEU-phan-bo-tram-chua-cau-hinh` | Trạm chưa cấu hình recipient → cảnh báo trên bảng tính tiền | DEFERRED #319 |
| `CHIEU-phan-bo-tram-chuyen-tiep` | Chuyển tiếp: kỳ per-trạm đầu trống; kỳ sau kế thừa đúng | DEFERRED #319 |
| `CHIEU-phan-bo-tram-da-xoa` | Recipient đã xóa (Discard) khi xem kỳ cũ → `.with_discarded` đúng chỗ | DEFERRED #319 |
| `CHIEU-phan-bo-tram-vai-tro` | Sáu vai trò + đơn vị quản lý khu vực cấu hình được, chỉ huy chỉ xem | DEFERRED #319 |
```

- [ ] **Step 2: Bump version + changelog**

Line 3: bump `version:` from `0.1.0` to `0.2.0`.

Add to the top of `## Changelog`:
```
### 0.2.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>`, mọi hàng `DEFERRED #319` (chưa triển khai) — ADR-030, Issue #329. Khi build TN2: đổi trạng thái từng hàng sang "có test" + gắn anchor vào test.
```

- [ ] **Step 3: Run the guardrail — confirm all three retrofits pass**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: `✓ ...every declared test dimension is covered or DEFERRED.` (TN2's rows are all DEFERRED-with-issue, so they require no tests; TN1+TN3 rows are covered.)

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md
git commit -m "$(cat <<'EOF'
docs(tn2): adopt CHIEU- table (all DEFERRED) for pump-by-station

Convert the not-yet-built pump-by-station spec to a "## Truy vết chiều
test" table with every row DEFERRED #319 — the worked example for the
guardrail's deferred branch.

Refs #329

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Phase 9 — Full verification

### Task 14: Run all guardrails, the harness, and the touched specs

- [ ] **Step 1: Run the 4 doc-governance scripts together (mirrors CI)**

Run:
```bash
rc=0
bash .github/scripts/check-doc-links.sh || rc=1
bash .github/scripts/check-doc-map.sh || rc=1
bash .github/scripts/check-glossary-definitions.sh || rc=1
bash .github/scripts/check-test-dimensions.sh || rc=1
echo "combined rc=$rc"
```
Expected: four `✓` lines and `combined rc=0`.

- [ ] **Step 2: Run the guardrail's own test harness**

Run: `bash .github/scripts/check-test-dimensions.test.sh`
Expected: `✓ all cases passed`.

- [ ] **Step 3: Run every retrofitted spec file (confirm no behavior changed)**

Run:
```bash
bin/docker rspec \
  spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb \
  spec/requests/billing_spec.rb spec/services/summary_calculator_spec.rb \
  spec/models/other_deduction_spec.rb spec/requests/unit_config_spec.rb \
  spec/services/period_service_spec.rb
```
Expected: 0 failures.

- [ ] **Step 4: Negative check — temporarily break one anchor and confirm RED, then revert**

Run:
```bash
git stash -- spec/requests/meter_entries_spec.rb 2>/dev/null || true
# Remove one anchor to simulate a silently-dropped dimension:
perl -0pi -e 's/CHIEU-ton-hao-chua-tinh: /TEMP-BROKEN: /' spec/requests/meter_entries_spec.rb
bash .github/scripts/check-test-dimensions.sh; echo "exit=$?"
git checkout -- spec/requests/meter_entries_spec.rb
```
Expected: prints `✗ Thiếu test  CHIEU-ton-hao-chua-tinh ...` (because `meter_entries`'s D1 was the only meter_entries copy — note `billing` may still carry it; if billing also tags `CHIEU-ton-hao-chua-tinh`, this won't go red. If it stays green, instead break the anchor in BOTH files, confirm red, then revert both with `git checkout --`). Confirms the guardrail actually fails on a dropped dimension. End state: working tree restored.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin feature/ci-gate-truy-vet-chieu-test
gh pr create --base develop --title "feat(ci): test-dimension traceability guardrail (ADR-030)" --body "$(cat <<'EOF'
## Summary

Adds `check-test-dimensions.sh` (4th `doc-governance` script): reconciles each spec's `## Truy vết chiều test` table against `CHIEU-<slug>` anchors in `spec/` test descriptions. Fail-loud, runs on every PR. Implements the test-dimension↔test traceability item of #329; activates ADR-015's foreseen upgrade.

Retrofits all three milestone 1.2.0 specs: TN1 + TN3 carry real anchors; TN2 is all `DEFERRED #319`.

## Linked change

Refs #329 (only the traceability item; the i18n guardrail and AGENTS-compliance review remain open as follow-ups — do NOT close).

## Traceability checklist

- [x] Links its change Issue (`Refs #329`).
- [ ] n/a business requirement.
- [x] Spec `## Truy vết` updated (ADR-030).
- [x] Tests cover the change (committed bash harness; guardrail self-runs on this PR which touches `.github/**`).
- [x] Changed `docs/` versioned + changelog bumped (THUAT_NGU 1.4.0, V2_CHIEU_TEST 1.4.0, TN1 0.2.0, TN2 0.2.0, TN3 0.3.0, ADR-030 spec 0.1.0).
- [x] Conventional Commits; squash into `develop`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Monitor CI and report pass/fail.**

Run: `gh pr checks --watch` (or the configured hook). Report the result; fix any red before requesting merge.

---

## Self-Review

**Spec coverage (ADR-030 → tasks):**
- `CHIEU-<slug>` anchor + glossary → Task 6. ✓
- `## Truy vết chiều test` table in specs → Tasks 10, 12, 13. ✓
- Anchor in `it` description → Tasks 9, 11. ✓
- `check-test-dimensions.sh` 4 rules (missing-test / deferred-without-issue / orphan / collision) → Task 2 (rules), Tasks 1 & 3 (tests). ✓
- Runs on every PR via `doc-governance` → Task 5. ✓
- Retrofit all milestone 1.2.0 (TN1+TN3 real, TN2 DEFERRED #319) → Tasks 9-13. ✓
- CONTRIBUTING §8/§9 + PR template → Task 7. ✓
- V2_CHIEU_TEST note → Task 8. ✓
- Fixture-based self-test → Tasks 1, 3; final negative check Task 14 Step 4. ✓
- `Refs #329` not `Closes` → Task 14 Step 5. ✓

**Out of scope (stated in spec "Giới hạn"):** prose-staleness check, real-action/AGENTS review dimension — no tasks (correct; #329 follow-ups).

**Placeholder scan:** no TBD/TODO; every code/edit step shows concrete content or an exact old→new transformation. The two "if text drifted, grep instead of inventing" notes are robustness guards, not placeholders.

**Type/name consistency:** script arg order `(SPECS_DIR, TESTS_DIR)` is identical in the script, the harness, and all manual invocations. CHIEU- slugs in each spec table exactly match the anchors prepended to tests in the same phase.
