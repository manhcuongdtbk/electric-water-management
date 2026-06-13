# ADR Status Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ADR status self-consistent and machine-enforced — one source of truth (inline per-ADR `**Trạng thái:**`), `merge = Accepted`, a `doc-governance` guardrail enforcing it, and a whole-tree backfill of the stale `Proposed`/`draft` specs.

**Architecture:** A native-bash fail-loud guardrail (`check-adr-status.sh`, ADR-024/030 lineage) runs as the 5th script of the `doc-governance` job. R1: a spec's YAML frontmatter must not contain a `status:` key. R2: an inline `**Trạng thái:** Proposed` line (after stripping code fences + inline-code) must carry a `#<issue>` deferred-marker. A one-shot backfill script normalizes all 16 stale specs (drop frontmatter `status:`, flip `Proposed`→`Accepted`, bump version, add changelog entry) so the guardrail is green whole-tree.

**Tech Stack:** Bash, awk/sed, GitHub Actions.

**Spec:** [`docs/superpowers/specs/2026-06-13-trang-thai-adr-lifecycle-design.md`](../specs/2026-06-13-trang-thai-adr-lifecycle-design.md) (ADR-033).

**Branch:** `feature/adr-status-lifecycle` ← `develop` (already created). PR base `develop`, squash.

**Facts gathered (2026-06-13):**
- **16 specs** carry a frontmatter `status:` (15 `draft`, 1 `approved`); these are the backfill set. The new ADR-033 spec is already convention-clean and is NOT in the set.
- **36** inline `- **Trạng thái:** Proposed` lines across those 16. **None** are genuinely deferred (verified: no `Proposed` line contains chờ/hoãn/defer) → all flip to `Accepted`.
- All 16 have a changelog header matching `(Lịch sử thay đổi|Changelog)`.
- `bin/docker rspec` is unaffected (no `app/` or `spec/` changes).

---

### Task 1: Companion test for the guardrail (write the test first)

**Files:**
- Create: `.github/scripts/check-adr-status.test.sh`

- [ ] **Step 1: Write the failing companion test**

Create `.github/scripts/check-adr-status.test.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Test cho check-adr-status.sh (ADR-033). Dựng fixture spec tạm rồi kiểm exit code
# + thông báo cho R1/R2. Chạy tay: bash .github/scripts/check-adr-status.test.sh
# KHÔNG wire vào CI (giữ bề mặt CI nhỏ); là test người-chạy cho guardrail.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-adr-status.sh"
fails=0

# mk <spec-body> → in ra thư mục specs fixture chứa 1 file design.md
mk() {
  local tmp; tmp="$(mktemp -d)"
  printf '%s\n' "$1" > "$tmp/fixture-design.md"
  printf '%s' "$tmp"
}

# assert <label> <expected-exit> <spec-body> [needle]
assert() {
  local label="$1" expected="$2" body="$3" needle="${4:-}"
  local tmp out rc
  tmp="$(mk "$body")"
  out="$(bash "$SCRIPT" "$tmp" 2>&1)"; rc=$?
  if [[ "$rc" -ne "$expected" ]]; then
    echo "✗ $label — expected exit $expected, got $rc"; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  elif [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
    echo "✗ $label — output missing \"$needle\""; echo "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "✓ $label"
  fi
  rm -rf "$tmp"
}

CLEAN_FM=$'---\ntitle: x\nversion: 0.1.0\ndate: 2026-06-13\n---'

# 1. PASS: clean spec — no frontmatter status, ADR Accepted.
assert "pass: accepted, no fm status" 0 \
  "$CLEAN_FM"$'\n# X\n- **Trạng thái:** Accepted · 2026-06-13'

# 2. FAIL R1: frontmatter has a status: key.
assert "fail: R1 frontmatter status" 1 \
  $'---\ntitle: x\nversion: 0.1.0\nstatus: draft (chờ duyệt)\n---'$'\n- **Trạng thái:** Accepted · 2026-06-13' \
  "R1 frontmatter"

# 3. FAIL R2: inline Proposed without a #issue marker.
assert "fail: R2 undeferred proposed" 1 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Proposed · 2026-06-13' \
  "R2 undeferred"

# 4. PASS: Proposed WITH a deferred-marker #issue.
assert "pass: deferred proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Proposed (chờ quyết #42)'

# 5. PASS: '**Trạng thái khách:**' is a different field, never flagged.
assert "pass: trang thai khach ignored" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái khách:** Proposed — nghiệm thu sau'

# 6. PASS: a prose mention of Proposed wrapped in backticks (inline-code stripped).
assert "pass: backticked prose proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Accepted · 2026-06-13\nVí dụ: `**Trạng thái:** Proposed` chỉ là minh hoạ.'

# 7. PASS: Proposed inside a fenced code block is ignored.
assert "pass: fenced proposed" 0 \
  "$CLEAN_FM"$'\n- **Trạng thái:** Accepted · 2026-06-13\n```\n- **Trạng thái:** Proposed\n```'

echo "----"
if [[ "$fails" -gt 0 ]]; then echo "✗ $fails case(s) failed"; exit 1; fi
echo "✓ all cases passed"
```

- [ ] **Step 2: Run it, verify it fails (script absent)**

Run: `bash .github/scripts/check-adr-status.test.sh`
Expected: every case errors (script missing), ending `✗ N case(s) failed`.

- [ ] **Step 3: Commit**

```bash
git add .github/scripts/check-adr-status.test.sh
git commit -m "test: companion test for the ADR-status guardrail (ADR-033)

Refs #339

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Implement the guardrail script

**Files:**
- Create: `.github/scripts/check-adr-status.sh`

- [ ] **Step 1: Write the script**

Create `.github/scripts/check-adr-status.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Guardrail trạng thái ADR (ADR-033): docs/superpowers/specs/*.md —
#   R1: khối frontmatter YAML (giữa cặp '---' đầu file) KHÔNG có key `status:`
#       (một nguồn sự thật = inline per-ADR `**Trạng thái:**`).
#   R2: dòng ADR `**Trạng thái:** Proposed` phải kèm deferred-marker `#<số>`. Bỏ
#       code fence + span inline-code (`...`) trước khi soi (giống check-doc-links.sh)
#       để ví dụ prose bọc backtick không báo nhầm. KHÔNG đụng `**Trạng thái khách:**`.
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

  # R2: strip code fences + inline-code, then flag ADR Proposed lines lacking #<digits>.
  incode=0; lineno=0
  while IFS= read -r raw; do
    lineno=$((lineno + 1))
    case "$raw" in '```'*|'~~~'*) incode=$((1 - incode)); continue ;; esac
    (( incode )) && continue
    line="$(printf '%s' "$raw" | sed 's/`[^`]*`//g')"
    case "$line" in *'**Trạng thái:**'*) : ;; *) continue ;; esac
    after="${line#*'**Trạng thái:**'}"
    case "$after" in *Proposed*) : ;; *) continue ;; esac
    if ! printf '%s' "$after" | grep -qE '#[0-9]+'; then
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
```

- [ ] **Step 2: Run the companion test, verify all pass**

Run: `bash .github/scripts/check-adr-status.test.sh`
Expected: every line `✓ …`, ending `✓ all cases passed`. If any case fails, fix the script (not the test) and re-run.

- [ ] **Step 3: Run on the real tree — expect RED (pre-backfill)**

Run: `bash .github/scripts/check-adr-status.sh; echo "exit=$?"`
Expected: **RED** — many `✗ R1 frontmatter status:` (16 specs) and `✗ R2 undeferred Proposed` (36 lines), `exit=1`. This is expected; Task 3 (backfill) makes it green. Confirm the new ADR-033 spec is NOT among the violators.

- [ ] **Step 4: Commit**

```bash
git add .github/scripts/check-adr-status.sh
git commit -m "feat: ADR-status guardrail script (ADR-033)

Refs #339

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Backfill the 16 stale specs

**Files:**
- Modify: all `docs/superpowers/specs/*.md` that have a frontmatter `status:` (16 files).

- [ ] **Step 1: Run the backfill script**

Run this exactly (it edits in place; the diff review in Step 2 is the safety gate):

```bash
bash -c '
set -uo pipefail
today="2026-06-13"
changed=0
for f in docs/superpowers/specs/*.md; do
  # only specs that have a frontmatter status: key
  awk "NR==1&&\$0==\"---\"{i=1;next} i&&\$0==\"---\"{exit} i&&/^status:/{s=1} END{exit !s}" "$f" || continue

  cur="$(awk "NR==1&&\$0==\"---\"{i=1;next} i&&\$0==\"---\"{exit} i&&/^version:/{print \$2}" "$f")"
  IFS=. read -r MA MI PA <<< "$cur"; new="$MA.$MI.$((PA+1))"
  entry="- **${new} (${today}):** Theo ADR-033 (#339): bỏ field frontmatter \`status:\` (nguồn duy nhất = inline \`**Trạng thái:**\`); lật trạng thái các ADR đã merge sang \`Accepted\`."

  awk -v newver="$new" -v entry="$entry" "
    BEGIN{infm=0; chl=0; skipblank=0}
    NR==1 && \$0==\"---\" {infm=1; print; next}
    infm && \$0==\"---\" {infm=0; print; next}
    infm && /^status:/ {next}
    infm && /^version:/ {print \"version: \" newver; next}
    skipblank==1 {skipblank=0; if (\$0 ~ /^[[:space:]]*\$/) next}
    !chl && \$0 ~ /^#+[[:space:]].*(Lịch sử thay đổi|Changelog)/ {print; print \"\"; print entry; chl=1; skipblank=1; next}
    /^- \\*\\*Trạng thái:\\*\\* Proposed/ && \$0 !~ /#[0-9]/ {sub(/Proposed/, \"Accepted\"); print; next}
    {print}
  " "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  changed=$((changed+1))
  echo "backfilled: $f  ($cur -> $new)"
done
echo "TOTAL backfilled: $changed"
'
```
Expected: `backfilled: …` for 16 files, `TOTAL backfilled: 16`.

- [ ] **Step 2: Review the full diff (this is the safety gate — not a blind sed)**

Run: `git diff --stat docs/superpowers/specs/` then `git diff docs/superpowers/specs/`
Verify, for every changed spec:
- the frontmatter `status:` line is **removed**;
- every `- **Trạng thái:** Proposed` became `- **Trạng thái:** Accepted` (date + notes intact);
- the `version:` bumped by one patch level;
- exactly one new changelog entry appears under the changelog header;
- **no other content changed**, and no line that should stay `Proposed` (deferred) was flipped (there are none, per the facts, but confirm).

If anything looks off, `git checkout -- docs/superpowers/specs/` and fix the script before re-running.

- [ ] **Step 3: Run the guardrail on the real tree — expect GREEN**

Run: `bash .github/scripts/check-adr-status.sh; echo "exit=$?"`
Expected: `✓ check-adr-status: ADR status conforms …`, `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/
git commit -m "docs: normalize ADR status to Accepted, drop frontmatter status (ADR-033)

Backfill the 16 specs that were stuck at draft/Proposed after merge:
remove the undocumented frontmatter status: field and set each merged
ADR's inline Trạng thái to Accepted, per ADR-033. Each spec gets a patch
version bump + changelog entry.

Refs #339

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Wire the guardrail into the `doc-governance` CI job

**Files:**
- Modify: `.github/workflows/ci.yml` (the `doc-governance` job's run block)

- [ ] **Step 1: Add the script to the aggregation block**

In `.github/workflows/ci.yml`, find the `doc-governance` job's run block (the lines that call `check-doc-links.sh`, `check-doc-map.sh`, `check-glossary-definitions.sh`, `check-test-dimensions.sh` with `|| rc=1`). Add one line after the `check-test-dimensions.sh` line:

```yaml
          bash .github/scripts/check-adr-status.sh || rc=1
```

Also update the job `name:` to mention it. Change:
```yaml
    name: Doc governance (links, map, glossary, test dimensions)
```
to:
```yaml
    name: Doc governance (links, map, glossary, test dimensions, ADR status)
```

- [ ] **Step 2: Verify the aggregation block runs all five green locally**

Run:
```bash
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status; do
  echo "=== $s ==="; bash .github/scripts/$s.sh; echo "exit=$?"
done
```
Expected: all five `✓ …` with `exit=0`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run the ADR-status guardrail in doc-governance (ADR-033)

Refs #339

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Update ADR-TEMPLATE and CONTRIBUTING §8

**Files:**
- Modify: `docs/superpowers/ADR-TEMPLATE.md` (status-line guidance)
- Modify: `CONTRIBUTING.md` (§8 — new guardrail paragraph)

- [ ] **Step 1: Update the ADR template status guidance**

In `docs/superpowers/ADR-TEMPLATE.md`, replace the status line:

Old:
```
- **Trạng thái:** Proposed · YYYY-MM-DD  <!-- Proposed → Accepted → (Superseded by ADR-XXX) -->
```
New:
```
- **Trạng thái:** Accepted · YYYY-MM-DD  <!-- Merge = Accepted: ghi Accepted ngay trong PR (ADR-033). Proposed CHỈ khi cố ý hoãn: `Proposed (chờ quyết #<issue>)`. Superseded by ADR-XXX khi bị thay. Frontmatter spec KHÔNG mang `status:` — nguồn duy nhất là dòng này. -->
```

- [ ] **Step 2: Add the §8 guardrail paragraph in CONTRIBUTING.md**

In `CONTRIBUTING.md`, immediately after the ADR-033... wait, after the ADR-032 paragraph in §8 (the one ending `…ADR-032 trong \`docs/superpowers/specs/2026-06-13-guardrail-i18n-view-design.md\`.`), add a blank line then:

```
**CI guardrail trạng thái ADR (ADR-033):** script thứ 5 của job `doc-governance` (`check-adr-status.sh`, native bash fail-loud) ép quy ước trạng thái ADR trên `docs/superpowers/specs/*.md`: **R1** — frontmatter **không** mang field `status:` (nguồn duy nhất là dòng inline `**Trạng thái:**` per-ADR); **R2** — dòng `**Trạng thái:** Proposed` phải kèm deferred-marker `#<issue>`, nếu không → đỏ. Quy ước: **merge = Accepted** (tác giả ghi `Accepted · <ngày>` ngay trong pull request — merge là hành động duyệt, ADR-007); `Proposed (chờ quyết #<issue>)` chỉ khi cố ý hoãn. Script bỏ code fence + inline-code trước khi soi nên ví dụ prose (bọc backtick) không báo nhầm; không đụng `**Trạng thái khách:**`. Chi tiết + lý do: ADR-033 trong `docs/superpowers/specs/2026-06-13-trang-thai-adr-lifecycle-design.md`.
```

- [ ] **Step 3: Verify doc-governance still green (links/map after edits)**

Run:
```bash
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status; do bash .github/scripts/$s.sh; done
```
Expected: all five `✓ …`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/ADR-TEMPLATE.md CONTRIBUTING.md
git commit -m "docs: document the ADR-status convention in template and CONTRIBUTING (ADR-033)

Refs #339

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Live red/green verification + full local suite

No commit in this task.

- [ ] **Step 1: R1 red — add a frontmatter status to a spec, expect red**

```bash
f=docs/superpowers/specs/2026-06-13-truy-vet-chieu-test-design.md
perl -CSD -i -pe 'print "status: draft (chờ duyệt)\n" if $.==4 && !$done++' "$f"   # insert into frontmatter
bash .github/scripts/check-adr-status.sh; echo "exit=$?"
```
Expected: `✗ R1 frontmatter status:  …truy-vet-chieu-test…`, `exit=1`. Then revert: `git checkout -- "$f"`.

- [ ] **Step 2: R2 red — set an ADR to undeferred Proposed, expect red**

```bash
f=docs/superpowers/specs/2026-06-13-truy-vet-chieu-test-design.md
perl -CSD -i -pe 's/\*\*Trạng thái:\*\* Accepted/**Trạng thái:** Proposed/ if !$d++' "$f"
bash .github/scripts/check-adr-status.sh; echo "exit=$?"
```
Expected: `✗ R2 undeferred Proposed  …`, `exit=1`. Then revert: `git checkout -- "$f"`.

- [ ] **Step 3: Green again + full doc-governance suite**

```bash
git checkout -- docs/superpowers/specs/
bash .github/scripts/check-adr-status.test.sh | tail -1
for s in check-doc-links check-doc-map check-glossary-definitions check-test-dimensions check-adr-status; do bash .github/scripts/$s.sh; done
git status
```
Expected: companion `✓ all cases passed`; all five guardrails `✓`; working tree clean (only the committed changes).

---

### Task 7: Push and open the PR

- [ ] **Step 1: Confirm branch not behind develop**

```bash
git fetch origin develop --quiet
echo "behind by: $(git rev-list --count HEAD..origin/develop)"
```
Expected: `behind by: 0` (if not 0, integrate develop first, then re-verify Task 6 Step 3).

- [ ] **Step 2: Push**

```bash
git push -u origin feature/adr-status-lifecycle
```

- [ ] **Step 3: Open the PR (base develop, Closes #339)**

```bash
gh pr create --base develop --title "feat: ADR status lifecycle + guardrail (ADR-033)" --body "$(cat <<'EOF'
## What

Settles #339. ADR status had two unmaintained indicators — a frontmatter `status:` (15/17 specs stuck at `draft`) and an inline per-ADR `**Trạng thái:**` (36 lines stuck at `Proposed`) — because flipping them needed a manual follow-up nobody made. This makes the inline per-ADR field the single source of truth, defines `merge = Accepted`, machine-enforces it, and backfills the stale specs.

## Convention (ADR-033)

- Single source of truth = inline per-ADR `**Trạng thái:**` (`Proposed → Accepted → Superseded`). The frontmatter `status:` field is removed.
- **Merge = Accepted** — authors write `Accepted · <date>` in the introducing PR (merging is the acceptance act, ADR-007). `Proposed` is reserved for a deferred ADR, written `Proposed (chờ quyết #<issue>)`.

## Enforcement

`.github/scripts/check-adr-status.sh` — 5th `doc-governance` script (native bash, fail-loud):
- **R1:** no frontmatter `status:` key.
- **R2:** inline `**Trạng thái:** Proposed` must carry a `#<issue>` marker.
Code fences + inline-code are stripped first, so prose examples (and the ADR-033 spec itself) don't false-trigger; `**Trạng thái khách:**` is untouched.

## Backfill

The 16 specs with a frontmatter `status:` are normalized in one commit: drop the field, flip all 36 `Proposed`→`Accepted` (none were genuinely deferred), patch version bump + changelog entry each. Guardrail is green whole-tree (no baseline).

## Verification

- Companion `check-adr-status.test.sh`: 7 cases (clean→green; R1 frontmatter→red; R2 undeferred Proposed→red; deferred Proposed→green; `Trạng thái khách`→green; backticked prose→green; fenced→green).
- Live tree: red on injected R1/R2 violations, green after revert; all five doc-governance scripts green.

## Docs

- Spec/ADR-033: `docs/superpowers/specs/2026-06-13-trang-thai-adr-lifecycle-design.md` (dogfoods the convention).
- Plan: `docs/superpowers/plans/2026-06-13-trang-thai-adr-lifecycle.md`
- `docs/superpowers/ADR-TEMPLATE.md` + `CONTRIBUTING.md` §8 updated.

Closes #339
EOF
)"
```

- [ ] **Step 4: Monitor CI and report**

After the PR is created, run `gh pr checks <number> --watch` (the `gh-pr-monitor` hook also prompts this), then report pass/fail. Do **not** merge — that is the owner's gate.

---

## Self-review notes

- **Spec coverage:** R1+R2 guardrail (Tasks 1–2) ✓; code-fence/inline-code stripping so prose doesn't false-trigger (Task 2 + test cases 6–7) ✓; `**Trạng thái khách:**` excluded (test case 5) ✓; deferred-marker escape (test case 4) ✓; whole-tree CI wiring (Task 4) ✓; backfill 16 specs drop-status + flip + bump + changelog (Task 3) ✓; ADR-TEMPLATE + CONTRIBUTING §8 (Task 5) ✓; merge=Accepted documented (Task 5) ✓; live red/green (Task 6) ✓; Closes #339 (Task 7) ✓; dogfood (the ADR-033 spec already excluded from backfill) ✓.
- **Naming consistency:** `check-adr-status.sh` / `check-adr-status.test.sh` / job `doc-governance` / rules `R1`/`R2` used identically across tasks.
- **No placeholders:** every script, YAML edit, doc text, and command is concrete.
- **Backfill caveat honored:** Task 3 Step 2 is an explicit diff-review gate (not a blind sed); the facts confirm no genuine deferrals, but the review re-checks.
