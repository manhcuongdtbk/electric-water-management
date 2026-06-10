# Document-Governance CI Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a CI job that machine-enforces #310's document-governance rules — no dead internal links, the document map stays complete, and the 6 abbreviations + 11 jargon terms keep their `docs/THUAT_NGU.md` definitions (Issue #313, ADR-024).

**Architecture:** Three native bash scripts in `.github/scripts/` + one data file, run by a new always-on `doc-governance` job in `.github/workflows/ci.yml`. All checks read the current repo state (no diff). Hard-fail (exit 1) on violations, fail-loud on internal errors, portable bash (`while read`, no `mapfile`). Matches the existing CI-script pattern (`detect-code-changes.sh`).

**Tech Stack:** bash, grep/sed (GNU on ubuntu CI; logic kept portable to macOS bash 3.2 for local testing). No Ruby/Postgres.

**Spec:** `docs/superpowers/specs/2026-06-11-guardrail-quan-tri-tai-lieu-design.md` (ADR-024, already committed on this branch).

**Conventions:** Vietnamese docs/comments, English commits (Conventional Commits). Scripts/data/workflow are code → NOT versioned. `docs/BAN_DO_TAI_LIEU.md` and `docs/HUONG_DAN_SDLC.md` are versioned `docs/` files → bump version + changelog in the same commit. Branch `feature/doc-governance-guardrails` ← `develop` (already cut). Do NOT push/PR until Task 8.

**Note on the local shell:** the dev machine is macOS (bash 3.2, zsh default). Run each script explicitly with `bash .github/scripts/<name>.sh` when verifying locally.

---

### Task 1: Add the un-classified ADR template to the document map

The doc-map check (Task 4) flags `docs/superpowers/ADR-TEMPLATE.md` — it exists but is not covered by the `docs/superpowers/specs/*` / `plans/*` globs. Classify it (it is the canonical ADR authoring template) so the map is complete.

**Files:**
- Modify: `docs/BAN_DO_TAI_LIEU.md` (canonical table + version header + changelog)

- [ ] **Step 1: Add the row to the `### canonical` table**

In `docs/BAN_DO_TAI_LIEU.md`, in the `### canonical` table, add this row immediately after the `docs/BAN_DO_TAI_LIEU.md` row:
```
| `docs/superpowers/ADR-TEMPLATE.md` | Mẫu ADR chuẩn (7 mục, đánh số toàn cục) để viết quyết định mới trong spec | Người + AI |
```

- [ ] **Step 2: Bump version header**

Replace:
```
> **Phiên bản:** 1.0.0
```
With:
```
> **Phiên bản:** 1.1.0
```

- [ ] **Step 3: Add a changelog entry**

In the `## Lịch sử thay đổi` list, insert this as the FIRST bullet, above the `- **1.0.0 (10/06/2026):**` line:
```
- **1.1.0 (11/06/2026):** Thêm `docs/superpowers/ADR-TEMPLATE.md` vào nhóm canonical (mẫu ADR). Phát hiện khi dựng guardrail ADR-024 (Issue #313).
```

- [ ] **Step 4: Verify the file is now covered**

Run:
```
grep -c 'ADR-TEMPLATE.md' docs/BAN_DO_TAI_LIEU.md
```
Expected: `1` (or more) — the path now appears in the map.

- [ ] **Step 5: Commit**

```bash
git add docs/BAN_DO_TAI_LIEU.md
git commit -m "docs: classify ADR-TEMPLATE.md in the document map

Surfaced by the ADR-024 doc-map guardrail: the file was uncovered by the
specs/plans globs. Bump BAN_DO_TAI_LIEU 1.0.0 -> 1.1.0. Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Create the glossary-terms data file

**Files:**
- Create: `.github/dictionaries/glossary-terms.txt`

- [ ] **Step 1: Write the file with exactly this content**

```
# Thuật ngữ canonical phải LUÔN có định nghĩa trong docs/THUAT_NGU.md (ADR-024).
# check-glossary-definitions.sh sẽ đỏ nếu một mục dưới đây mất hàng định nghĩa.
# Dòng bắt đầu bằng # là comment. Mỗi dòng một thuật ngữ (so khớp không phân biệt hoa/thường).

# Viết tắt được phép (mục 1 của THUAT_NGU.md)
CI
ADR
CRUD
UI
SDLC
SemVer

# Jargon đã định nghĩa (#310 / ADR-023)
distill
merge-back
rollback
release candidate
reslot
supersede
anchor
fail-open
fail-safe
path filter
grooming
```

- [ ] **Step 2: Verify it has 17 term lines (non-comment, non-blank)**

Run:
```
grep -vE '^\s*#|^\s*$' .github/dictionaries/glossary-terms.txt | wc -l | tr -d ' '
```
Expected: `17`

- [ ] **Step 3: Commit**

```bash
git add .github/dictionaries/glossary-terms.txt
git commit -m "ci: add glossary-terms list for doc-governance guardrail

The 6 allowed abbreviations + 11 defined jargon terms that must keep a
definition in docs/THUAT_NGU.md (ADR-024). Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Create the dead-link checker

**Files:**
- Create: `.github/scripts/check-doc-links.sh`

- [ ] **Step 1: Write the file with exactly this content**

```bash
#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mọi markdown link nội bộ trong docs/ +
# file meta gốc phải trỏ tới FILE tồn tại. Bắt drift do đổi tên/xóa file (pattern
# "trỏ về" của ADR-023 dựa vào link sống). Bỏ code fence + inline code trước khi
# quét (plan/spec nhúng link ví dụ trong khối code). v1 KHÔNG ép anchor #slug.
# FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

list_docs() {
  find docs -type f -name '*.md'
  for f in README.md AGENTS.md CONTRIBUTING.md CLAUDE.md; do
    [[ -f "$f" ]] && echo "$f"
  done
}

violations=0
while IFS= read -r f; do
  dir="$(dirname "$f")"
  incode=0
  lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    case "$raw" in
      '```'* | '~~~'*) incode=$((1 - incode)); continue ;;  # toggle khối code
    esac
    (( incode )) && continue
    line="$(printf '%s' "$raw" | sed 's/`[^`]*`//g')"        # bỏ inline code
    while IFS= read -r target; do
      [[ -z "$target" ]] && continue
      url="${target%%#*}"   # bỏ #anchor (không ép ở v1)
      url="${url%% *}"      # bỏ phần "title" sau khoảng trắng
      [[ -z "$url" ]] && continue
      case "$url" in
        http://* | https://* | mailto:* | tel:*) continue ;;  # link ngoài
      esac
      if [[ ! -e "$dir/$url" ]]; then
        echo "LINK HỎNG  $f:$lineno  → $url"
        violations=$((violations + 1))
      fi
    done < <(printf '%s\n' "$line" | grep -oE '\]\([^) ]+' | sed -E 's/^\]\(//')
  done < "$f"
done < <(list_docs | sort -u)

if (( violations > 0 )); then
  echo "FAIL (check-doc-links): $violations link nội bộ hỏng."
  exit 1
fi
echo "OK (check-doc-links): link nội bộ đều sống."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .github/scripts/check-doc-links.sh
```

- [ ] **Step 3: Verify it PASSES on the current repo**

Run:
```
bash .github/scripts/check-doc-links.sh; echo "exit=$?"
```
Expected: ends with `OK (check-doc-links): link nội bộ đều sống.` and `exit=0`.

- [ ] **Step 4: Verify it FAILS on an injected broken link, then revert**

```bash
printf '\n[broken](./khong-ton-tai-xyz.md)\n' >> docs/THUAT_NGU.md
bash .github/scripts/check-doc-links.sh; echo "exit=$?"   # expect: LINK HỎNG ... and exit=1
git checkout -- docs/THUAT_NGU.md
```
Expected: prints a `LINK HỎNG docs/THUAT_NGU.md:...` line and `exit=1`; after `git checkout`, the file is restored.

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/check-doc-links.sh
git commit -m "ci: add dead internal-link checker for docs (ADR-024)

Strips code fences/inline code, then fails on any internal markdown link
whose file target does not exist. Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Create the document-map completeness checker

**Files:**
- Create: `.github/scripts/check-doc-map.sh`

- [ ] **Step 1: Write the file with exactly this content**

```bash
#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mọi tài liệu (docs/**/*.md + file meta
# gốc) phải được docs/BAN_DO_TAI_LIEU.md phủ (đường dẫn chính xác hoặc glob tiền
# tố như docs/superpowers/specs/*); và mọi đường dẫn (file *.md hoặc glob */*)
# liệt kê trong bản đồ phải tồn tại. Bắt: file mới chưa phân loại, đường dẫn ma.
# FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

MAP="docs/BAN_DO_TAI_LIEU.md"
[[ -f "$MAP" ]] || { echo "FAIL (check-doc-map): không thấy $MAP"; exit 1; }

list_docs() {
  find docs -type f -name '*.md'
  for f in README.md AGENTS.md CONTRIBUTING.md CLAUDE.md; do
    [[ -f "$f" ]] && echo "$f"
  done
}

# Token đường dẫn liệt kê trong bản đồ: nội dung backtick dạng *.md hoặc */* sạch.
list_map_paths() {
  grep -oE '`[^`]+`' "$MAP" | tr -d '`' \
    | grep -E '^[A-Za-z0-9._/-]+\.md$|^[A-Za-z0-9._/-]+/\*$' | sort -u
}

violations=0

# (1) Completeness: mỗi file thực tế phải được phủ.
while IFS= read -r f; do
  covered=0
  while IFS= read -r p; do
    if [[ "$p" == "$f" ]]; then covered=1; break; fi
    if [[ "$p" == */\* ]]; then
      prefix="${p%\*}"   # "docs/superpowers/specs/"
      case "$f" in "$prefix"*) covered=1; break ;; esac
    fi
  done < <(list_map_paths)
  if (( ! covered )); then
    echo "CHƯA PHÂN LOẠI  $f  (thêm vào $MAP)"
    violations=$((violations + 1))
  fi
done < <(list_docs | sort -u)

# (2) No-ghost: mỗi đường dẫn liệt kê phải tồn tại.
while IFS= read -r p; do
  if [[ "$p" == */\* ]]; then
    d="${p%/\*}"
    [[ -d "$d" ]] || { echo "ĐƯỜNG DẪN MA (thư mục)  $p"; violations=$((violations + 1)); }
  else
    [[ -e "$p" ]] || { echo "ĐƯỜNG DẪN MA (file)  $p"; violations=$((violations + 1)); }
  fi
done < <(list_map_paths)

if (( violations > 0 )); then
  echo "FAIL (check-doc-map): $violations vấn đề bản đồ tài liệu."
  exit 1
fi
echo "OK (check-doc-map): bản đồ tài liệu khớp thực tế."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .github/scripts/check-doc-map.sh
```

- [ ] **Step 3: Verify it PASSES on the current repo** (Task 1 already classified ADR-TEMPLATE.md)

Run:
```
bash .github/scripts/check-doc-map.sh; echo "exit=$?"
```
Expected: `OK (check-doc-map): bản đồ tài liệu khớp thực tế.` and `exit=0`.

- [ ] **Step 4: Verify it FAILS on a new un-classified doc, then remove it**

```bash
echo "# tạm" > docs/zz_khong_phan_loai.md
bash .github/scripts/check-doc-map.sh; echo "exit=$?"   # expect: CHƯA PHÂN LOẠI ... and exit=1
rm -f docs/zz_khong_phan_loai.md
```
Expected: prints `CHƯA PHÂN LOẠI docs/zz_khong_phan_loai.md ...` and `exit=1`; after `rm`, the temp file is gone.

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/check-doc-map.sh
git commit -m "ci: add document-map completeness checker (ADR-024)

Fails when a docs/ file is not classified in BAN_DO_TAI_LIEU.md, or when
the map lists a path that does not exist. Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Create the glossary definition-retention checker

**Files:**
- Create: `.github/scripts/check-glossary-definitions.sh`

- [ ] **Step 1: Write the file with exactly this content**

```bash
#!/usr/bin/env bash
# Guardrail quản trị tài liệu (ADR-024): mỗi thuật ngữ trong
# .github/dictionaries/glossary-terms.txt (6 viết tắt + 11 jargon) phải còn một
# hàng định nghĩa trong docs/THUAT_NGU.md (đầu cell bảng là thuật ngữ đó, có/không
# in đậm). Chống xóa định nghĩa âm thầm. KHÔNG quét prose (bất khả thi cho tiếng
# Việt — xem ADR-024). FAIL-LOUD: vi phạm → exit 1.
set -uo pipefail

GLOSSARY="docs/THUAT_NGU.md"
TERMS_FILE=".github/dictionaries/glossary-terms.txt"
for p in "$GLOSSARY" "$TERMS_FILE"; do
  [[ -f "$p" ]] || { echo "FAIL (check-glossary-definitions): thiếu $p"; exit 1; }
done

violations=0
while IFS= read -r term; do
  term="${term%%#*}"                                              # bỏ comment
  term="$(printf '%s' "$term" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"  # trim
  [[ -z "$term" ]] && continue
  # Hàng bảng có đầu cell là thuật ngữ (có/không **đậm**), không phân biệt hoa/thường.
  # vd: "| CI | ..."  hoặc  "| **Distill** (..) | ..."
  if ! grep -qiE "^\|[[:space:]]*\*{0,2}${term}([^[:alnum:]]|$)" "$GLOSSARY"; then
    echo "MẤT ĐỊNH NGHĨA  '$term'  không còn hàng trong $GLOSSARY"
    violations=$((violations + 1))
  fi
done < "$TERMS_FILE"

if (( violations > 0 )); then
  echo "FAIL (check-glossary-definitions): $violations thuật ngữ mất định nghĩa."
  exit 1
fi
echo "OK (check-glossary-definitions): các thuật ngữ canonical đều còn định nghĩa."
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .github/scripts/check-glossary-definitions.sh
```

- [ ] **Step 3: Verify it PASSES on the current repo**

Run:
```
bash .github/scripts/check-glossary-definitions.sh; echo "exit=$?"
```
Expected: `OK (check-glossary-definitions): các thuật ngữ canonical đều còn định nghĩa.` and `exit=0`.

- [ ] **Step 4: Verify it FAILS when a definition is removed, then restore**

```bash
sed -i.bak '/^| \*\*Grooming\*\*/d' docs/THUAT_NGU.md
bash .github/scripts/check-glossary-definitions.sh; echo "exit=$?"   # expect: MẤT ĐỊNH NGHĨA 'grooming' and exit=1
mv docs/THUAT_NGU.md.bak docs/THUAT_NGU.md
```
Expected: prints `MẤT ĐỊNH NGHĨA 'grooming' ...` and `exit=1`; after `mv`, the file is restored (and `git status` shows it clean).

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/check-glossary-definitions.sh
git commit -m "ci: add glossary definition-retention checker (ADR-024)

Fails if any listed abbreviation/jargon loses its definition row in
docs/THUAT_NGU.md. Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Wire the `doc-governance` job into CI

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add the job**

In `.github/workflows/ci.yml`, under `jobs:`, insert this job immediately after the `branch-source-guard:` job block (before the `tests:` job). Keep two-space indentation consistent with the other jobs:
```yaml
  doc-governance:
    name: Doc governance (links, map, glossary definitions)
    runs-on: ubuntu-latest
    # Chạy LUÔN trên mọi pull request (KHÔNG gate qua `changes`): guardrail tài
    # liệu cần nhất đúng lúc pull request chỉ sửa tài liệu (ADR-024).
    steps:
      - uses: actions/checkout@v6
      - name: Document-governance guardrails (ADR-024)
        run: |
          status=0
          bash .github/scripts/check-doc-links.sh || status=1
          bash .github/scripts/check-doc-map.sh || status=1
          bash .github/scripts/check-glossary-definitions.sh || status=1
          exit $status
```

- [ ] **Step 2: Verify the workflow YAML is well-formed**

Run:
```
python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); print('jobs:', ', '.join(d['jobs']))"
```
Expected: a line listing the jobs including `doc-governance` (e.g. `jobs: changes, ruby-checks, commitlint, branch-source-guard, doc-governance, tests`). No YAML error.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run doc-governance guardrails on every pull request (ADR-024)

A new always-on job runs the link / map / glossary-definition checks.
Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Point the human docs at the new guardrail

**Files:**
- Modify: `CONTRIBUTING.md` (mục 8 — meta, NOT versioned)
- Modify: `docs/HUONG_DAN_SDLC.md` (§5 lookup row + version bump + changelog)

- [ ] **Step 1: Add a paragraph to `CONTRIBUTING.md` mục 8**

In `CONTRIBUTING.md`, in `## 8. Trạng thái tự động hoá`, add this as a new paragraph at the end of that section (before `## 9.`):
```
**CI guardrail quản trị tài liệu (ADR-024):** một job `doc-governance` chạy trên **mọi** pull request, kiểm: link nội bộ chết, bản đồ tài liệu (`docs/BAN_DO_TAI_LIEU.md`) phủ đủ và không có đường dẫn ma, và 6 viết tắt + 11 jargon còn định nghĩa trong `docs/THUAT_NGU.md`. Đỏ nếu vi phạm (fail-loud). Không quét prose tìm viết tắt mới (bất khả thi cho tiếng Việt) — việc đó vẫn thuộc review người. Chi tiết: ADR-024 trong `docs/superpowers/specs/2026-06-11-guardrail-quan-tri-tai-lieu-design.md`.
```

- [ ] **Step 2: Update the `Quản trị tài liệu` row in `docs/HUONG_DAN_SDLC.md` §5**

Replace the existing row:
```
| Quản trị tài liệu | Mỗi fact một nơi canonical, nơi khác trỏ về; sửa đừng "append mù"; thuật ngữ ở `THUAT_NGU.md`, loại tài liệu ở `BAN_DO_TAI_LIEU.md` | [THUAT_NGU](THUAT_NGU.md) · [BAN_DO_TAI_LIEU](BAN_DO_TAI_LIEU.md) · [ADR-023](superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md) |
```
With:
```
| Quản trị tài liệu | Mỗi fact một nơi canonical, nơi khác trỏ về; sửa đừng "append mù"; thuật ngữ ở `THUAT_NGU.md`, loại tài liệu ở `BAN_DO_TAI_LIEU.md`; CI tự kiểm link/bản đồ/định nghĩa (ADR-024) | [THUAT_NGU](THUAT_NGU.md) · [BAN_DO_TAI_LIEU](BAN_DO_TAI_LIEU.md) · [ADR-023](superpowers/specs/2026-06-10-quan-tri-tai-lieu-design.md) · [ADR-024](superpowers/specs/2026-06-11-guardrail-quan-tri-tai-lieu-design.md) |
```

- [ ] **Step 3: Bump `docs/HUONG_DAN_SDLC.md` version**

Replace:
```
> **Phiên bản:** 1.1.0
> **Ngày:** 10/06/2026
```
With:
```
> **Phiên bản:** 1.2.0
> **Ngày:** 11/06/2026
```

- [ ] **Step 4: Add a changelog entry**

In `docs/HUONG_DAN_SDLC.md` `## Lịch sử thay đổi`, insert this as the FIRST bullet, above the `- **1.1.0 (10/06/2026):**` line:
```
- **1.2.0 (11/06/2026):** §5 thêm guardrail tự động (ADR-024) vào dòng "Quản trị tài liệu" — CI kiểm link chết / bản đồ tài liệu / giữ định nghĩa thuật ngữ. Issue #313.
```

- [ ] **Step 5: Verify the new links resolve and version is bumped**

Run:
```
bash .github/scripts/check-doc-links.sh; echo "exit=$?"
grep -n 'Phiên bản:' docs/HUONG_DAN_SDLC.md | head -1
```
Expected: link checker `OK` + `exit=0` (the new `ADR-024` link target exists); version line shows `1.2.0`.

- [ ] **Step 6: Commit**

```bash
git add CONTRIBUTING.md docs/HUONG_DAN_SDLC.md
git commit -m "docs(sdlc): document the doc-governance CI guardrail (ADR-024)

CONTRIBUTING §8 + HUONG_DAN_SDLC §5 point at the new job. Bump
HUONG_DAN_SDLC 1.1.0 -> 1.2.0. Refs #313

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Run all checks together, push, open the pull request

**Files:** none (verification + git)

- [ ] **Step 1: Run all three guardrails together (simulate the CI job)**

Run:
```bash
status=0
bash .github/scripts/check-doc-links.sh || status=1
bash .github/scripts/check-doc-map.sh || status=1
bash .github/scripts/check-glossary-definitions.sh || status=1
echo "aggregate exit=$status"
```
Expected: three `OK (...)` lines and `aggregate exit=0`.

- [ ] **Step 2: Review the full diff against `develop`**

Run: `git fetch origin develop && git diff --stat origin/develop...HEAD`
Expected files: `docs/superpowers/specs/2026-06-11-guardrail-quan-tri-tai-lieu-design.md`, `docs/superpowers/plans/2026-06-11-guardrail-quan-tri-tai-lieu.md`, `docs/BAN_DO_TAI_LIEU.md`, `.github/dictionaries/glossary-terms.txt`, `.github/scripts/check-doc-links.sh`, `.github/scripts/check-doc-map.sh`, `.github/scripts/check-glossary-definitions.sh`, `.github/workflows/ci.yml`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`.

- [ ] **Step 3: Integrate base if behind, then push (only after project-owner approval)**

Run: `git log --oneline origin/develop ^HEAD` — if non-empty, integrate with `git merge origin/develop` (resolve conflicts) before pushing. Then: `git push -u origin feature/doc-governance-guardrails`.

- [ ] **Step 4: Open the pull request**

```bash
gh pr create --base develop --head feature/doc-governance-guardrails \
  --title "ci: machine-enforce document governance (links, map, glossary) — ADR-024" \
  --body "$(cat <<'EOF'
## Summary
Implements Issue #313 (ADR-024): turns #310's prose document-governance rules into CI guardrails.

A new always-on `doc-governance` job runs three native-bash checks (hard-fail, fail-loud):
- `check-doc-links.sh` — no dead internal markdown links (strips code fences/inline code; file-existence; external + `#anchor` skipped).
- `check-doc-map.sh` — every `docs/**/*.md` + root meta is classified in `docs/BAN_DO_TAI_LIEU.md`, and the map lists no ghost paths.
- `check-glossary-definitions.sh` — the 6 abbreviations + 11 jargon in `.github/dictionaries/glossary-terms.txt` keep their definitions in `docs/THUAT_NGU.md`.

Also: classified the previously-uncovered `docs/superpowers/ADR-TEMPLATE.md` (surfaced by the map check), and pointed `CONTRIBUTING` §8 / `HUONG_DAN_SDLC` §5 at the guardrail.

## Scope / honesty
Enforces only the **mechanical** rules. It does **not** catch *new* undefined abbreviations/jargon (impractical for a Vietnamese corpus — Vietnamese ALL-CAPS + SCREAMING_SNAKE filenames shred under `[A-Z]{2,}`) nor anchor `#slug` validity (deferred). Those stay with human review + the ADR-023 glossary principle. See ADR-024 for the rejected prose-scan approach and evidence.

This PR touches `.github/**`, so CI runs the full suite and the new guardrail self-checks this branch.

Closes #313
EOF
)"
```

- [ ] **Step 5: Monitor CI and report**

Poll the checks (REST is reliable regardless of GraphQL state):
```
sha=$(git rev-parse HEAD)
gh api "repos/manhcuongdtbk/electric-water-management/commits/$sha/check-runs" \
  --jq '.check_runs[] | "\(.name): \(.status) / \(.conclusion // "—")"'
```
Expected eventually: `Doc governance (...)` = success, plus the usual static + (this time, because `.github` changed) `tests` / `ruby-checks` running. Report pass/fail to the project owner.

---

## Self-Review

**Spec coverage** (against `2026-06-11-guardrail-quan-tri-tai-lieu-design.md`):
- `check-doc-links.sh` (code-strip, file-existence, skip external/anchor) → Task 3. ✅
- `check-doc-map.sh` (completeness + no-ghost, glob-aware) → Task 4. ✅
- `check-glossary-definitions.sh` (17 terms keep definitions) → Task 5 + data file Task 2. ✅
- `doc-governance` job, always-on, aggregates → Task 6. ✅
- Data file `.github/dictionaries/glossary-terms.txt` → Task 2. ✅
- Classify ADR-TEMPLATE.md (map gap the checker surfaces) → Task 1. ✅
- Human-doc pointers + version bump → Task 7. ✅
- `Closes #313`, full-CI self-check → Task 8. ✅
- Decisions reflected: hard-fail (each script `exit 1`), fail-loud (missing-file → exit 1), portable bash (`while read`, no `mapfile`), single source (definitions stay in THUAT_NGU; data file only lists terms). ✅

**Placeholder scan:** none — every script/file is shown in full; every verification has an exact command + expected output (each prototyped against the live repo). ✅

**Consistency:** script names identical across spec/plan/CI (`check-doc-links.sh`, `check-doc-map.sh`, `check-glossary-definitions.sh`); data path `.github/dictionaries/glossary-terms.txt` identical in Task 2, Task 5, and the spec; version deltas match real current values (BAN_DO_TAI_LIEU 1.0.0→1.1.0, HUONG_DAN_SDLC 1.1.0→1.2.0). ✅
