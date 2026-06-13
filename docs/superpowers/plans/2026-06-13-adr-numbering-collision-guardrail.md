# ADR Numbering Collision Guardrail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop two specs from carrying the same ADR number — add a fail-loud CI script that detects duplicate ADR numbers across specs, and clean up the four duplicates already in `develop`.

**Architecture:** A new `doc-governance` bash script (`check-adr-numbering.sh`, 7th in the job) scans `docs/superpowers/specs/*.md` for ADR-defining headings at **both** `##` and `###` levels and fails if any `ADR-NNN` appears in more than one heading. A one-time renumber moves the duplicated `app-version-reporting` block (`ADR-001..004 → 042..045`, the cheapest set with zero external references) so the tree is clean and the new script passes whole-tree. Parallel-branch collisions are caught at the merge gate via the existing branch-behind-base hook + single-merger (ADR-007); no number registry.

**Tech Stack:** Bash (portable, macOS 3.2 / Ubuntu), GitHub Actions, Markdown specs. No Ruby/RSpec involved.

**Spec:** [docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md](../specs/2026-06-13-adr-numbering-collision-design.md) (ADR-046).

**Branch:** `ci/adr-numbering-collision-guardrail` ← `develop` (already created; spec already committed as `d5afee4`). All commits use Conventional Commits, English, lowercase subject start.

**Number facts (do not re-derive):** `develop` max = ADR-035; open draft PR #347 reserves 036..041; cleanup consumes 042..045; the spec's own ADR = 046.

---

## File Structure

- **Create** `.github/scripts/check-adr-numbering.sh` — the detector (one concern: ADR-number uniqueness across spec headings).
- **Create** `.github/scripts/check-adr-numbering.test.sh` — human-run companion test (temp fixtures, not wired to CI), mirroring `check-adr-status.test.sh`.
- **Modify** `.github/workflows/ci.yml` — add the script to the `doc-governance` job's guardrail step + job `name:`.
- **Modify** `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md` — renumber its ADR block 001..004 → 042..045 (4 headings + 2 internal refs) + version bump + changelog.
- **Modify** `docs/superpowers/ADR-TEMPLATE.md` — one-line reminder (meta file, not versioned).
- **Modify** `CONTRIBUTING.md` — one §8 paragraph (meta file, not versioned).

---

## Task 1: One-time cleanup — renumber the app-version-reporting ADR block

Do the cleanup first so the working tree has no duplicate ADR numbers before the detector is introduced.

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md`

- [ ] **Step 1: Renumber the four ADR headings**

In `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md`, change only the heading numbers (keep all titles/content/status lines verbatim):

- `### ADR-001: Vị trí hiển thị phiên bản trên giao diện` (line 75) → `### ADR-042: Vị trí hiển thị phiên bản trên giao diện`
- `### ADR-002: Dạng endpoint trả phiên bản` (line 86) → `### ADR-043: Dạng endpoint trả phiên bản`
- `### ADR-003: Nhãn môi trường — tiếng Anh, từ biến môi trường` (line 95) → `### ADR-044: Nhãn môi trường — tiếng Anh, từ biến môi trường`
- `### ADR-004: Cách gắn phiên bản (và môi trường) vào log` (line 103) → `### ADR-045: Cách gắn phiên bản (và môi trường) vào log`

- [ ] **Step 2: Fix the two internal cross-references**

Same file:
- Line 41: `- **Nhãn môi trường là tiếng Anh** (xem ADR-003).` → `(xem ADR-044)`
- Line 46: `Chỉ ghi **một dòng log khởi động** (xem ADR-004),` → `(xem ADR-045)`

- [ ] **Step 3: Verify no stale references remain in the file**

Run: `grep -nE 'ADR-00[1-4]' docs/superpowers/specs/2026-06-07-app-version-reporting-design.md`
Expected: no output (every old number replaced).

Run: `grep -nE 'ADR-04[2-5]' docs/superpowers/specs/2026-06-07-app-version-reporting-design.md`
Expected: 6 lines (4 headings + lines 41, 46).

- [ ] **Step 4: Confirm zero external references to these specific ADRs**

Run: `grep -rn 'ADR-00[1-4]' --include='*.md' . | grep -v node_modules | grep -v '2026-06-07-app-version-reporting'`
Expected: every hit points to the sdlc-overview ADR-001/002 (dev model, doc strategy) or release ADR-003/004 (Git Flow, SemVer) — none refers to version-reporting. (The version-reporting ADRs were only self-referenced; this confirms the renumber's blast radius outside the file is zero. If any hit *does* describe version display / endpoint / env-label / version-in-log, stop and update it.)

- [ ] **Step 5: Bump version + add changelog entry (ADR-002)**

In the same file, change the frontmatter `version: 0.8.1` → `version: 0.8.2`, and add this as the top entry under `## Lịch sử thay đổi` (above the `0.8.1` line):

```markdown
- **0.8.2 (2026-06-13):** Theo ADR-046 (#348): renumber khối ADR của spec này `ADR-001..004 → 042..045` để gỡ trùng số toàn cục (bốn số này trùng với ADR-001/002 của `sdlc-overview` và ADR-003/004 của `quy-trinh-release`). Chỉ đổi số (heading + 2 tham chiếu nội bộ); nội dung/ngày/trạng thái giữ nguyên. Blast radius ngoài file = 0 (các ADR này chỉ tham chiếu nội bộ).
```

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-app-version-reporting-design.md
git commit -m "docs: renumber app-version-reporting ADRs 001-004 to 042-045 (ADR-046)

Removes the four duplicate ADR numbers already in develop: this spec's
ADR-001/002 collided with sdlc-overview, and ADR-003/004 with the release
spec. Renumbers the version-reporting block (the cheapest set, referenced
only internally) to 042-045. Heading numbers and two internal refs only;
content unchanged. Version 0.8.1 -> 0.8.2 + changelog.

Refs #348

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Detector script + companion test (TDD)

The companion `.test.sh` is the test. Write it first (it fails because the script does not exist yet), then write the script.

**Files:**
- Create: `.github/scripts/check-adr-numbering.test.sh`
- Create: `.github/scripts/check-adr-numbering.sh`

- [ ] **Step 1: Write the failing companion test**

Create `.github/scripts/check-adr-numbering.test.sh`:

```bash
#!/usr/bin/env bash
# Test cho check-adr-numbering.sh (ADR-046). Dựng thư mục specs fixture tạm (nhiều
# file) rồi kiểm exit code + thông báo. Chạy tay: bash .github/scripts/check-adr-numbering.test.sh
# KHÔNG wire vào CI — test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-adr-numbering.sh"
fails=0

# assert <label> <expected-exit> <dir> [needle]
assert() {
  local label="$1" expected="$2" dir="$3" needle="${4:-}"
  local out rc
  out="$(bash "$SCRIPT" "$dir" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$dir"
}

# 1. PASS: distinct numbers across two specs.
d="$(mktemp -d)"
printf '%s\n' '### ADR-050: alpha' > "$d/a-design.md"
printf '%s\n' '### ADR-051: beta'  > "$d/b-design.md"
assert "pass: distinct numbers" 0 "$d"

# 2. FAIL: same number in two different specs.
d="$(mktemp -d)"
printf '%s\n' '### ADR-050: alpha' > "$d/a-design.md"
printf '%s\n' '### ADR-050: gamma' > "$d/b-design.md"
assert "fail: cross-file duplicate" 1 "$d" "Duplicate ADR number  ADR-050"

# 3. FAIL: mixed heading levels (## vs ###) — the bug that hid ADR-001/002.
d="$(mktemp -d)"
printf '%s\n' '## ADR-051: alpha'  > "$d/a-design.md"
printf '%s\n' '### ADR-051: gamma' > "$d/b-design.md"
assert "fail: mixed ## and ### levels" 1 "$d" "Duplicate ADR number  ADR-051"

# 4. PASS: a fenced code example of an ADR heading is not counted.
d="$(mktemp -d)"
printf '%s\n' '### ADR-052: alpha' > "$d/a-design.md"
printf '%s\n' 'prose' '```' '### ADR-052: example in a fence' '```' > "$d/b-design.md"
assert "pass: fenced example ignored" 0 "$d"

# 5. FAIL: same number twice within one spec.
d="$(mktemp -d)"
printf '%s\n' '### ADR-053: alpha' 'body' '### ADR-053: dup' > "$d/a-design.md"
assert "fail: duplicate within one file" 1 "$d" "Duplicate ADR number  ADR-053"

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
```

- [ ] **Step 2: Run the test to verify it fails (script missing)**

Run: `bash .github/scripts/check-adr-numbering.test.sh`
Expected: FAIL — cases error because `check-adr-numbering.sh` does not exist yet (non-zero exits / missing-file output).

- [ ] **Step 3: Write the detector script**

Create `.github/scripts/check-adr-numbering.sh`:

```bash
#!/usr/bin/env bash
# Guardrail chống trùng số ADR (ADR-046): mỗi số ADR-NNN chỉ được định nghĩa ở
# ĐÚNG MỘT dòng heading trên toàn cây docs/superpowers/specs/. "Định nghĩa" = dòng
# khớp heading '## ADR-NNN' HOẶC '### ADR-NNN' — BẮT CẢ HAI CẤP (chỉ '###' sẽ bỏ
# sót '## ADR-NNN', đúng lỗ hổng từng che trùng ADR-001/002). Bỏ code fence trước
# khi soi (giống check-adr-status.sh) để ví dụ trong fence không bị tính. Khi ≥2
# nhánh song song cùng +1 một số → trùng; script bắt khi cả hai định nghĩa cùng
# có mặt (nhánh sau đồng bộ develop), dựa single-merger (ADR-007) renumber nhánh
# gộp sau. Portable bash (macOS 3.2). Output/echo tiếng Anh. FAIL-LOUD → exit 1.
set -uo pipefail

SPECS_DIR="${1:-docs/superpowers/specs}"
[[ -d "$SPECS_DIR" ]] || { echo "✗ check-adr-numbering: specs dir not found: $SPECS_DIR"; exit 1; }

defs="$(mktemp)"   # mỗi dòng: ADR-NNN<TAB>specfile
trap 'rm -f "$defs"' EXIT

# Trích mọi dòng định nghĩa ADR (bỏ code fence), ghi (số, file).
while IFS= read -r spec; do
  incode=0
  while IFS= read -r raw; do
    case "$raw" in '```'*|'~~~'*) incode=$((1 - incode)); continue ;; esac
    (( incode )) && continue
    # Heading '## ' hoặc '### ' theo sau là 'ADR-' + 3 chữ số.
    case "$raw" in
      '## ADR-'[0-9][0-9][0-9]* | '### ADR-'[0-9][0-9][0-9]*) : ;;
      *) continue ;;
    esac
    num="$(printf '%s' "$raw" | grep -oE 'ADR-[0-9]{3}' | head -n1)"
    [[ -z "$num" ]] && continue
    printf '%s\t%s\n' "$num" "$spec" >> "$defs"
  done < "$spec"
done < <(find "$SPECS_DIR" -type f -name '*.md' | sort)

violations=0
# Số nào xuất hiện ở >1 dòng định nghĩa → trùng.
while IFS= read -r num; do
  [[ -z "$num" ]] && continue
  count="$(awk -F'\t' -v n="$num" '$1==n {c++} END{print c+0}' "$defs")"
  if [[ "$count" -gt 1 ]]; then
    echo "✗ Duplicate ADR number  $num  defined $count times:"
    awk -F'\t' -v n="$num" '$1==n {print "    - "$2}' "$defs" | sort
    violations=$((violations + 1))
  fi
done < <(cut -f1 "$defs" | sort -u)

if (( violations > 0 )); then
  echo "✗ check-adr-numbering: $violations duplicate ADR number(s)."
  exit 1
fi
echo "✓ check-adr-numbering: every ADR number is defined in exactly one spec heading."
```

- [ ] **Step 4: Run the companion test to verify it passes**

Run: `bash .github/scripts/check-adr-numbering.test.sh`
Expected: all 5 cases `✓`, final line `✓ all cases passed`.

- [ ] **Step 5: Run the detector against the real tree (must be green after Task 1)**

Run: `bash .github/scripts/check-adr-numbering.sh`
Expected: `✓ check-adr-numbering: every ADR number is defined in exactly one spec heading.` (exit 0). If it reports a duplicate, Task 1 was incomplete — fix before continuing.

- [ ] **Step 6: Commit**

```bash
chmod +x .github/scripts/check-adr-numbering.sh .github/scripts/check-adr-numbering.test.sh
git add .github/scripts/check-adr-numbering.sh .github/scripts/check-adr-numbering.test.sh
git commit -m "ci: add check-adr-numbering guardrail detecting duplicate ADR numbers

New doc-governance bash script: each ADR-NNN may be defined in only one
heading across docs/superpowers/specs, matching both ## and ### levels
(a ###-only scan is exactly what hid the ADR-001/002 duplicates). Strips
code fences like the sibling scripts. Companion .test.sh covers distinct,
cross-file dup, mixed-level dup, fenced-example, and same-file dup cases.

Refs #348

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Wire the detector into the doc-governance CI job

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add the script to the guardrail step**

In `.github/workflows/ci.yml`, in the `doc-governance` job's `run:` block, add a line after the `check-changelog-header.sh` line (keep the `|| rc=1` aggregation):

```yaml
          bash .github/scripts/check-changelog-header.sh || rc=1
          bash .github/scripts/check-adr-numbering.sh || rc=1
          exit $rc
```

- [ ] **Step 2: Add "ADR numbering" to the job name**

Same job, change:

```yaml
    name: Doc governance (links, map, glossary, test dimensions, ADR status, changelog header)
```
to:
```yaml
    name: Doc governance (links, map, glossary, test dimensions, ADR status, changelog header, ADR numbering)
```

- [ ] **Step 3: Verify the whole doc-governance suite passes locally**

Run:
```bash
rc=0
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status check-changelog-header check-adr-numbering; do
  bash ".github/scripts/$s.sh" || rc=1
done
echo "aggregate rc=$rc"
```
Expected: every script prints its `✓` success line and `aggregate rc=0`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: wire check-adr-numbering into the doc-governance job

Runs the duplicate-ADR-number detector on every pull request alongside
the other six doc-governance guardrails (same rc aggregation). Updates
the job name to list it.

Refs #348

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Document the guardrail (ADR-TEMPLATE reminder + CONTRIBUTING §8)

**Files:**
- Modify: `docs/superpowers/ADR-TEMPLATE.md`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Add the reminder to ADR-TEMPLATE.md**

In `docs/superpowers/ADR-TEMPLATE.md`, the top blockquote currently reads:

```markdown
> ADR đánh **số toàn cục, tăng dần** (số mới nhất: xem spec gần nhất). Giữ đúng **7 mục, đúng thứ tự**.
```

Replace that line with:

```markdown
> ADR đánh **số toàn cục, tăng dần** (số mới nhất: xem spec gần nhất). **Trùng số bị CI bắt** (`check-adr-numbering`, ADR-046) — nhưng vẫn kiểm **nhánh/PR đang mở** (không chỉ `develop`) trước khi đặt số, vì số của nhánh chưa merge là vô hình với `develop`. Giữ đúng **7 mục, đúng thứ tự**.
```

- [ ] **Step 2: Add a §8 paragraph to CONTRIBUTING.md**

In `CONTRIBUTING.md`, section 8, immediately after the `**CI guardrail header changelog (#339):**` paragraph (the last guardrail paragraph), add:

```markdown
**CI guardrail chống trùng số ADR (ADR-046):** script thứ 7 của job `doc-governance` (`check-adr-numbering.sh`, native bash fail-loud) đối chiếu mọi dòng định nghĩa ADR trong `docs/superpowers/specs/*.md` — heading `## ADR-NNN` **hoặc** `### ADR-NNN` (bắt cả hai cấp; chỉ `###` sẽ bỏ sót) — và **đỏ** nếu một số `ADR-NNN` xuất hiện ở >1 heading (cùng file hoặc khác file). Bỏ code fence nên ví dụ minh hoạ không tính. Bắt cả trùng đang tồn tại lẫn va chạm giữa hai nhánh song song khi nhánh sau đồng bộ `develop` (single-merger renumber nhánh gộp sau — ADR-007). Việc "đặt đúng số kế tiếp" vẫn cần kiểm nhánh/PR đang mở thủ công (số chưa merge vô hình với `develop`). Chi tiết + lý do: ADR-046 trong `docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md`.
```

- [ ] **Step 3: Verify the new CONTRIBUTING link resolves (doc-links guardrail)**

Run: `bash .github/scripts/check-doc-links.sh`
Expected: `✓` success line (the referenced spec path exists). ADR-TEMPLATE.md and CONTRIBUTING.md are meta files — no version bump (per ADR-002 / the doc-version hook applies only to versioned `docs/` files).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/ADR-TEMPLATE.md CONTRIBUTING.md
git commit -m "docs: document the ADR-numbering guardrail (ADR-046)

Adds a reminder in ADR-TEMPLATE (duplicates are now CI-caught, but still
check open branches/PRs before picking a number) and a CONTRIBUTING section
8 paragraph describing the check-adr-numbering guardrail. Meta files, not
versioned.

Refs #348

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Final verification, push, PR, and issue update

**Files:** none (verification + integration).

- [ ] **Step 1: Full local verification**

Run:
```bash
bash .github/scripts/check-adr-numbering.test.sh
rc=0
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status check-changelog-header check-adr-numbering; do
  bash ".github/scripts/$s.sh" || rc=1
done
echo "aggregate rc=$rc"
```
Expected: companion test `✓ all cases passed`; every guardrail `✓`; `aggregate rc=0`.

- [ ] **Step 2: Confirm no duplicate ADR numbers remain anywhere**

Run:
```bash
for f in docs/superpowers/specs/*.md; do
  grep -oE '^#{2,3} ADR-[0-9]{3}' "$f" | grep -oE 'ADR-[0-9]{3}'
done | sort | uniq -d
```
Expected: no output (no number repeats).

- [ ] **Step 3: Review the full diff**

Run: `git log --oneline develop..HEAD` and `git diff develop --stat`
Expected: 5 commits (spec + cleanup + detector + wiring + docs); files touched match the File Structure section. No app/code files, no unrelated changes.

- [ ] **Step 4: Push the branch**

Run: `git push -u origin ci/adr-numbering-collision-guardrail`
(The branch was cut from the latest `develop` this session, so the branch-behind-base hook is a no-op. If the hook blocks, integrate `develop` first then re-push.)

- [ ] **Step 5: Open the PR (base develop, squash later by merger)**

```bash
gh pr create --base develop --head ci/adr-numbering-collision-guardrail \
  --title "ci: guardrail against duplicate ADR numbers + clean up existing dups (#348)" \
  --body "$(cat <<'EOF'
## What

Implements ADR-046 ([spec](docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md)) for #348.

- **Detector (A):** new `.github/scripts/check-adr-numbering.sh` (7th `doc-governance` script) fails if any `ADR-NNN` is defined in more than one spec heading, matching **both** `##` and `###` levels — a `###`-only scan is exactly what hid the ADR-001/002 duplicates. Code fences ignored. Companion `.test.sh` included.
- **Cleanup (B):** renumbered the `app-version-reporting` ADR block `001..004 → 042..045` (the cheapest set — referenced only internally; blast radius outside the file = 0).
- **Docs:** ADR-TEMPLATE reminder + CONTRIBUTING §8 paragraph.

Parallel-branch collisions are caught at the merge gate via the existing branch-behind-base hook + single-merger (ADR-007); no number registry (rejected as YAGNI).

**Number choice (dogfood):** `develop` max = ADR-035; open draft PR #347 reserves 036..041; cleanup took 042..045; this spec's ADR = 046.

**Beyond the issue:** #348 documented ADR-003/004; this PR also found and fixed ADR-001/002 (same root cause).

## Test plan

- [x] `bash .github/scripts/check-adr-numbering.test.sh` — all cases pass (distinct, cross-file dup, mixed `##`/`###` dup, fenced-example ignored, same-file dup)
- [x] All 7 `doc-governance` scripts green whole-tree locally
- [x] No duplicate ADR numbers remain (`uniq -d` over all spec headings = empty)
- [ ] CI green on this PR

Closes #348
EOF
)"
```

- [ ] **Step 6: Monitor CI and report pass/fail**

After the PR is created, the PostToolUse hook follows CI. Confirm `gh pr checks <PR#>` is green (especially the `doc-governance` job) and report the result. If red, diagnose and fix before handing off.

- [ ] **Step 7: Post a progress comment on the issue (not a closing comment)**

Add a comment to #348 linking the spec + PR and noting the ADR-001/002 discovery folded into the fix. (The mechanical close comment fires post-merge via the close-traceability workflow; this is just a progress note so a pre-merge comment is not the last line — add the human reconcile comment after merge.)

```bash
gh issue comment 348 --body "Design + implementation up for review: spec \`docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md\` (ADR-046), PR #<PR>. Scope A+B in one PR (triaged 1.2.0, no priority-high). Scan found ADR-001/002 are duplicated too (beyond the 003/004 this issue documented) — same root cause, folded into the same renumber (app-version-reporting 001..004 → 042..045). Guardrail \`check-adr-numbering.sh\` catches both levels (## and ###)."
```

---

## Self-Review

**Spec coverage:**
- ADR-046 decision 1 (detector, both levels, 7th script, fences) → Task 2 + Task 3. ✓
- decision 2 (companion test cases) → Task 2 Step 1. ✓
- decision 3 (renumber 001..004 → 042..045 + refs + version/changelog) → Task 1. ✓
- decision 4 (merge-gate, no registry) → documented in Task 4 CONTRIBUTING paragraph + PR body; no code needed. ✓
- decision 5 (ADR-TEMPLATE reminder) → Task 4 Step 1. ✓
- Spec "Tệp sửa" CONTRIBUTING §8 → Task 4 Step 2. ✓
- Truy vết (Closes #348, discovery note) → Task 5 Steps 5/7. ✓

**Placeholder scan:** no TBD/TODO; every code/edit step shows exact content. ✓

**Consistency:** script name `check-adr-numbering.sh` and message `Duplicate ADR number  ADR-NNN` (two spaces, matching the sibling style and the test needles) are identical across the test (Task 2 Step 1), script (Task 2 Step 3), and verification needles. Renumber targets 042..045 consistent with spec and PR body. ✓
