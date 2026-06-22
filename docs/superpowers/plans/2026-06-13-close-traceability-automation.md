# Close-Traceability Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a pull request carrying `Closes/Fixes/Resolves #N` merges, mechanically post a standardized "đã ship gì" comment to each referenced issue and copy the pull request's milestone to the issue when the issue has none — judgment content stays manual (ADR-035).

**Architecture:** A new GitHub Actions workflow listens on `pull_request: types: [closed]`, gated `if: github.event.pull_request.merged == true`. It runs one bash script (`post-close-traceability.sh`) that parses closing keywords from the pull request body, then per issue copies the milestone (copy-only, never overwrite/block) and posts an idempotent comment (hidden marker guards re-runs). Pure helper functions (`extract_issue_numbers`, `render_comment`, `comment_marker`) are sourced and unit-tested offline by a companion `.test.sh`; the `gh` I/O lives in `main`, guarded so sourcing does not touch the network.

**Tech Stack:** GitHub Actions, bash (`set -uo pipefail`, fail-loud per ADR-024), GitHub CLI (`gh`, preinstalled on runners), `GITHUB_TOKEN`.

---

## File Structure

- **Create** `.github/scripts/post-close-traceability.sh` — pure helpers (`comment_marker`, `extract_issue_numbers`, `render_comment`) + `main` orchestrator (`gh` I/O), with a `BASH_SOURCE` guard so the test can source it without running `main`.
- **Create** `.github/scripts/post-close-traceability.test.sh` — human-run companion; sources the script, asserts the pure helpers; no network/`gh`.
- **Create** `.github/workflows/close-traceability.yml` — workflow on `pull_request: closed`, gated `merged`, passes pull request fields via env, runs the script.
- **Modify** `CONTRIBUTING.md` §8 (after the ADR-033 paragraph, ~line 150) — one automation-status note. Meta file, NOT versioned.

The spec (`docs/superpowers/specs/2026-06-13-close-traceability-automation-design.md`) is already written and committed (ADR-035). No further doc-version bump is needed unless the spec changes.

Each task is self-contained and ends in a commit. Conventional Commits, English; commit type `ci` (script/workflow) and `docs` (CONTRIBUTING note).

---

### Task 1: Pure helpers (TDD) — script skeleton + companion test

**Files:**
- Create: `.github/scripts/post-close-traceability.sh`
- Test: `.github/scripts/post-close-traceability.test.sh`

- [ ] **Step 1: Write the failing companion test**

Create `.github/scripts/post-close-traceability.test.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash .github/scripts/post-close-traceability.test.sh`
Expected: FAIL — `source` errors because `.github/scripts/post-close-traceability.sh` does not exist yet (`No such file or directory`).

- [ ] **Step 3: Write the script with the pure helpers (no `main` yet)**

Create `.github/scripts/post-close-traceability.sh`:

```bash
#!/usr/bin/env bash
# Tự động khép dấu vết khi đóng issue (ADR-035). Chạy hậu-merge từ workflow
# close-traceability.yml. Parse closing-keyword trong body PR → mỗi issue:
# (1) copy milestone PR→issue khi issue chưa có (copy-only, không ghi đè/chặn);
# (2) post comment kết cơ học idempotent (marker ẩn). Phán đoán để người/AI.
# Bash thuần FAIL-LOUD. Comment tiếng Việt (issue thread); echo/log tiếng Anh.
set -uo pipefail

# --- Pure helpers (test offline; no gh/network) -------------------------------

# Marker ẩn để idempotency: một comment kết / một PR / một issue.
comment_marker() { printf '<!-- auto-close-traceability:pr-%s -->' "$1"; }

# Body PR → số issue có closing-keyword GitHub, một dòng/số, theo thứ tự xuất
# hiện, đã khử trùng. Chỉ khớp keyword + #<số> (Refs/#trần không tính).
extract_issue_numbers() {
  printf '%s\n' "$1" \
    | grep -ioE '(close[sd]?|fix(es|ed)?|resolve[sd]?)[[:space:]]+#[0-9]+' \
    | grep -oE '[0-9]+' \
    | awk '!seen[$0]++'
}

# Các field → markdown comment kết (kèm marker). milestone_display đã sẵn sàng
# hiển thị (giá trị hoặc "— (chưa gán, chờ triage)").
render_comment() {
  local pr="$1" title="$2" short="$3" full="$4" base="$5" merged="$6" milestone="$7"
  cat <<EOF
$(comment_marker "$pr")
## Khép dấu vết (tự động) — đã merge

- **Pull request:** #${pr} — ${title}
- **Merge commit:** \`${short}\` (\`${full}\`)
- **Nhánh đích:** \`${base}\`
- **Thời điểm merge:** ${merged} (Asia/Ho_Chi_Minh)
- **Milestone:** ${milestone}

> Comment cơ học (ADR-035): xác nhận "đã ship gì". Phần nhận định (sai khác
> plan, caveat, chiều test đã phủ) do người/AI bổ sung khi có nuance.
EOF
}
```

(No `main` and no source-guard yet — Task 2 adds them. With nothing executed at load time, sourcing runs only the function definitions, so the test can call the helpers.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash .github/scripts/post-close-traceability.test.sh`
Expected: PASS — every line `✓ ...`, final `✓ post-close-traceability.test: all pass`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/post-close-traceability.sh .github/scripts/post-close-traceability.test.sh
git commit -m "ci: add close-traceability pure helpers + companion test (#342)"
```

---

### Task 2: Orchestrator `main` + source guard

**Files:**
- Modify: `.github/scripts/post-close-traceability.sh` (append `main` + guard)

- [ ] **Step 1: Append `main` and the `BASH_SOURCE` guard to the script**

Add to the END of `.github/scripts/post-close-traceability.sh`:

```bash
# --- Orchestrator (gh I/O; runs only when executed, not when sourced) ---------

# Xử một issue: copy milestone (copy-only) rồi post comment kết (idempotent).
# Trả 0 nếu OK/skip; 1 nếu có thao tác gh lỗi (để main gộp thành đỏ cuối).
process_issue() {
  local issue="$1"
  local issue_ms
  if ! issue_ms="$(gh issue view "$issue" --json milestone --jq '.milestone.title // ""' 2>/dev/null)"; then
    echo "::warning::Cannot read issue #${issue} (missing or no access); skipping."
    return 1
  fi

  # Lớp 2 — milestone copy-only: chỉ khi PR có milestone và issue chưa có.
  if [[ -n "$PR_MILESTONE" && -z "$issue_ms" ]]; then
    if gh issue edit "$issue" --milestone "$PR_MILESTONE" >/dev/null; then
      issue_ms="$PR_MILESTONE"
      echo "Copied milestone '${PR_MILESTONE}' to issue #${issue}."
    else
      echo "::warning::Failed to copy milestone to issue #${issue}."
      return 1
    fi
  fi

  # Idempotency — bỏ qua nếu issue đã có comment kết của đúng PR này.
  local marker; marker="$(comment_marker "$PR_NUMBER")"
  if gh issue view "$issue" --json comments --jq '.comments[].body' 2>/dev/null | grep -qF "$marker"; then
    echo "Issue #${issue} already has the close-traceability comment for PR #${PR_NUMBER}; skipping."
    return 0
  fi

  local ms_display
  if [[ -n "$issue_ms" ]]; then ms_display="$issue_ms"; else ms_display="— (chưa gán, chờ triage)"; fi

  local body
  body="$(render_comment "$PR_NUMBER" "$PR_TITLE" "$SHORT_SHA" "$MERGE_SHA" "$BASE_REF" "$MERGED_AT_LOCAL" "$ms_display")"
  if gh issue comment "$issue" --body "$body" >/dev/null; then
    echo "Posted close-traceability comment to issue #${issue}."
    return 0
  fi
  echo "::warning::Failed to comment on issue #${issue}."
  return 1
}

main() {
  : "${PR_NUMBER:?PR_NUMBER is required}"
  : "${MERGE_SHA:?MERGE_SHA is required}"
  PR_TITLE="${PR_TITLE:-}"
  PR_BODY="${PR_BODY:-}"
  BASE_REF="${BASE_REF:-}"
  MERGED_AT="${MERGED_AT:-}"
  PR_MILESTONE="${PR_MILESTONE:-}"

  SHORT_SHA="${MERGE_SHA:0:7}"
  # GitHub merged_at is UTC ISO-8601; GNU date on the runner converts the display.
  if [[ -n "$MERGED_AT" ]]; then
    MERGED_AT_LOCAL="$(TZ='Asia/Ho_Chi_Minh' date -d "$MERGED_AT" '+%Y-%m-%d %H:%M' 2>/dev/null || printf '%s' "$MERGED_AT")"
  else
    MERGED_AT_LOCAL="(không rõ)"
  fi

  local issues; issues="$(extract_issue_numbers "$PR_BODY")"
  if [[ -z "$issues" ]]; then
    echo "No closing keywords (Closes/Fixes/Resolves #N) in PR #${PR_NUMBER} body; nothing to do."
    return 0
  fi

  local rc=0
  while IFS= read -r issue; do
    [[ -z "$issue" ]] && continue
    process_issue "$issue" || rc=1
  done <<< "$issues"
  return "$rc"
}

# Chỉ chạy main khi script được EXECUTE (không phải khi companion `source`).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

- [ ] **Step 2: Re-run the companion test to confirm sourcing still does not run `main`**

Run: `bash .github/scripts/post-close-traceability.test.sh`
Expected: PASS — identical to Task 1 Step 4. The guard means `source` defines functions but never calls `main` (so no `PR_NUMBER` errors, no `gh` calls).

- [ ] **Step 3: Smoke-test the guard refuses to run with no env (executed, not sourced)**

Run: `bash .github/scripts/post-close-traceability.sh; echo "exit=$?"`
Expected: FAIL fast — stderr `PR_NUMBER is required` (from the `:?` guard) and `exit=1`. Confirms `main` runs on direct execution and the required-env guard fires.

- [ ] **Step 4: Commit**

```bash
git add .github/scripts/post-close-traceability.sh
git commit -m "ci: add close-traceability orchestrator (milestone copy-only + idempotent comment) (#342)"
```

---

### Task 3: The workflow

**Files:**
- Create: `.github/workflows/close-traceability.yml`

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/close-traceability.yml`:

```yaml
name: close-traceability

# ADR-035: khi một pull request mang Closes/Fixes/Resolves #N được MERGE, post
# comment kết cơ học vào mỗi issue và copy milestone PR→issue khi issue chưa có
# (copy-only — không chặn, không ghi đè). Phần phán đoán để người/AI (ADR-029).
# Điểm ép dời sang PR vì `Closes #N` đóng issue như hệ quả merge (không có sự
# kiện chặn ở issue). Chạy hậu-merge: đỏ chỉ để LỘ lỗi, không chặn được merge
# đã xong. Mọi PR là same-repo (Git Flow, không fork) → GITHUB_TOKEN mặc định
# đủ quyền; KHÔNG dùng pull_request_target (tránh bề mặt bảo mật của event đó).
on:
  pull_request:
    types: [closed]

permissions:
  issues: write
  contents: read
  pull-requests: read

jobs:
  close-traceability:
    name: Post close-traceability comment + reconcile milestone
    runs-on: ubuntu-latest
    if: ${{ github.event.pull_request.merged == true }}
    steps:
      - uses: actions/checkout@v6
      - name: Post close-traceability comment and copy milestone (ADR-035)
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_BODY: ${{ github.event.pull_request.body }}
          MERGE_SHA: ${{ github.event.pull_request.merge_commit_sha }}
          BASE_REF: ${{ github.event.pull_request.base.ref }}
          MERGED_AT: ${{ github.event.pull_request.merged_at }}
          PR_MILESTONE: ${{ github.event.pull_request.milestone.title }}
        run: bash .github/scripts/post-close-traceability.sh
```

- [ ] **Step 2: Validate the YAML parses**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/close-traceability.yml"); puts "ok"'`
Expected: `ok` (no parse error).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/close-traceability.yml
git commit -m "ci: add close-traceability workflow on pull_request closed (#342)"
```

> **Note on first-fire timing (verification limitation):** for `pull_request` events GitHub runs the workflow file from the *base* branch, so a brand-new workflow added in a pull request does NOT fire on that same pull request's own merge. The first real run is the **next** merged pull request that carries a closing keyword. End-to-end behavior is therefore verified by the companion unit test (pure helpers) plus a manual trace here; live confirmation comes on the next qualifying merge. This is expected, not a defect.

---

### Task 4: CONTRIBUTING §8 automation-status note

**Files:**
- Modify: `CONTRIBUTING.md` (insert after the ADR-033 paragraph, ~line 150)

- [ ] **Step 1: Add the note**

In `CONTRIBUTING.md` §8, immediately AFTER the paragraph that begins `**CI guardrail trạng thái ADR (ADR-033):**` (ends `...2026-06-13-trang-thai-adr-lifecycle-design.md`.), insert a blank line then:

```markdown
**Tự động khép dấu vết khi đóng issue (ADR-035):** một workflow `close-traceability.yml` chạy **hậu-merge** trên `pull_request: closed` (gate `merged == true`). Với mỗi closing-keyword `Closes/Fixes/Resolves #N` trong body pull request, script `.github/scripts/post-close-traceability.sh` (a) post một **comment kết cơ học** vào issue — PR#/tiêu đề, merge SHA, nhánh đích, thời điểm merge, dòng milestone — idempotent qua marker ẩn `<!-- auto-close-traceability:pr-N -->`; và (b) **copy milestone PR→issue** khi PR có milestone còn issue chưa (copy-only: KHÔNG chặn, KHÔNG ghi đè, KHÔNG cảnh báo — giữ gate triage ADR-019/020). Phần **phán đoán** (sai khác plan, caveat, chiều test đã phủ) máy KHÔNG sinh — người/AI bổ sung khi có nuance. Điểm ép ở pull request (không ở issue) vì `Closes #N` đóng issue như hệ quả merge. Chi tiết + lý do: ADR-035 trong `docs/superpowers/specs/2026-06-13-close-traceability-automation-design.md`.
```

- [ ] **Step 2: Verify doc-governance still green (link checker covers the new reference)**

Run: `bash .github/scripts/check-doc-links.sh && bash .github/scripts/check-doc-map.sh && bash .github/scripts/check-changelog-header.sh`
Expected: three `✓ ...` lines. (The new spec path is a real file; `CONTRIBUTING.md` is a meta file, NOT versioned, so no version bump.)

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: note close-traceability automation in CONTRIBUTING §8 (ADR-035) (#342)"
```

---

### Task 5: Final verification + push + PR

**Files:** none (verification + integration)

- [ ] **Step 1: Re-run the companion test and all doc guardrails**

Run:
```bash
bash .github/scripts/post-close-traceability.test.sh
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status check-changelog-header; do
  bash ".github/scripts/$s.sh" || echo "FAILED: $s"
done
```
Expected: `✓ post-close-traceability.test: all pass` and six `✓ ...` guardrail lines, no `FAILED:`.

- [ ] **Step 2: Confirm the branch is not behind `develop`, then push**

Run:
```bash
git fetch origin develop
git log --oneline origin/develop ^HEAD   # expect EMPTY (branch not behind)
git push -u origin ci/close-traceability-automation
```
Expected: the `git log` prints nothing (branch contains all of `develop`); push succeeds. If the log is non-empty, integrate `develop` first (per the branch-behind-base rule) before pushing.

- [ ] **Step 3: Open the pull request (base `develop`, squash)**

Run:
```bash
gh pr create --base develop --head ci/close-traceability-automation \
  --title "ci: automate close-traceability on pull request merge (ADR-035)" \
  --body "$(cat <<'EOF'
## Summary

Automates the mechanical "khép dấu vết" step when an issue closes (ADR-035). On `pull_request: closed` + `merged`, a workflow parses `Closes/Fixes/Resolves #N` from the pull request body and, per issue: posts an idempotent close-traceability comment (PR#, merge SHA, base, merged-at, milestone line) and copies the pull request milestone to the issue when the issue has none (copy-only — never block/overwrite, preserving the triage gate). Judgment content stays manual.

## Linked change

Closes #342

## Traceability checklist

- [x] Links its change Issue (`Closes #342`).
- [x] No business requirement affected (tooling/CI only).
- [x] Spec `## Truy vết` links the issue and the test (companion `.test.sh`); no app test dimensions, so no `## Truy vết chiều test` table (ADR-030 N/A).
- [x] Tests cover the changed behaviour (`post-close-traceability.test.sh` pure helpers; orchestration is thin `gh` I/O — first live fire is the next qualifying merge, see plan note).
- [x] AGENTS conventions: echo/log English, comment Vietnamese for the issue-thread comment; no abbreviations outside `docs/THUAT_NGU.md`.
- [x] Spec versioned + changelog bumped in its own commit (ADR-002); `CONTRIBUTING.md` is a meta file (not versioned).
- [x] Conventional Commits; squash into `develop`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
Expected: prints the new pull request URL.

- [ ] **Step 4: Watch CI to green**

Run: `gh pr checks --watch`
Expected: all checks pass. The heavy `tests`/`ruby-checks` jobs skip (docs/CI-only change, ADR-021 path filter); `doc-governance`, `i18n-view-guardrail`, `commitlint`, `branch-source-guard` run and pass. Report pass/fail; do not leave CI unwatched.

- [ ] **Step 5: Update #342 with the pull request link**

Run:
```bash
gh issue comment 342 --body "Implementation: pull request <URL> (base \`develop\`, \`Closes #342\`). Workflow \`close-traceability.yml\` + script \`post-close-traceability.sh\` + companion test + CONTRIBUTING §8 note. First live fire is the next qualifying merge (workflow runs from base branch)."
```
Expected: prints the comment URL.

---

## Notes for the implementer

- **Forward-only.** Do NOT backfill old closed issues — that one-time pass was completed in a prior session.
- **Do not touch `ci.yml`.** This automation listens on a different event (`closed`) and is its own workflow file.
- **Language split (AGENTS.md):** the *posted issue comment* is Vietnamese (team issue thread); all `echo`/`::warning::`/log output is English (technical CI output). Code identifiers/commits/PR title+body are English.
- **No HTML5/extra deps.** Bash + `gh` only; `gh` is preinstalled on `ubuntu-latest`.
- **Merge:** squash into `develop` (Git Flow). Never push to `main`.
