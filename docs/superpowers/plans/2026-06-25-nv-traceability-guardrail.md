# NV traceability guardrail — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement CI guardrail that ensures every `NV-...` anchor in canonical `V2_XAC_NHAN_NGHIEP_VU.md` has at least one test covering it (ADR-065, Issue #441).

**Architecture:** 1 bash script added to `doc-governance` job (same fail-loud pattern as existing 12 scripts). Source of truth: `<a id="NV-xxx">` anchors in canonical doc. Test coverage: `NV-xxx` tags in `it` descriptions (like CHIEU pattern) + `demo_nv` metadata in demo specs. Deferred: `.github/nv-test-deferred.txt`.

**Tech Stack:** Bash (portable, macOS 3.2 compatible), grep/awk. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md` (ADR-065)

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `.github/scripts/check-nv-traceability.sh` | Cross-reference NV anchors in canonical vs tests |
| Create | `.github/scripts/check-nv-traceability.test.sh` | Fixture-based manual tests |
| Create | `.github/nv-test-deferred.txt` | List of NV anchors deferred with gate issue |
| Modify | test files (5 anchors, ≥1 test each) | Add `NV-xxx:` prefix to `it` descriptions |
| Modify | `.github/workflows/ci.yml` | Add script to `doc-governance` job |
| Modify | `docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md` | Bump version |
| Modify | `CONTRIBUTING.md` | Add guardrail entry to mục 8 |

---

### Task 1: Script `check-nv-traceability.sh` + deferred file + test

**Files:**
- Create: `.github/scripts/check-nv-traceability.sh`
- Create: `.github/scripts/check-nv-traceability.test.sh`
- Create: `.github/nv-test-deferred.txt`

**What the script does:**

Extract `NV-...` anchors from canonical doc (`<a id="NV-xxx">`). Check 4 rules:

1. **R1 — Required has test:** Each NV anchor not in deferred file must have ≥1 match in `spec/` (either `it "NV-xxx` in `it` descriptions OR `NV-xxx` in `demo_nv` metadata).
2. **R2 — Deferred has gate:** Each line in deferred file must contain `#<number>`.
3. **R3 — Orphan test tag:** Any `NV-xxx` tag found in test `it` descriptions that doesn't match an anchor in canonical → violation (typo/stale).
4. **R4 — Orphan deferred:** Any NV-xxx in deferred file that doesn't exist as anchor in canonical → violation (stale deferred).

**Grep patterns:**
- Anchors in canonical: `<a id="NV-[a-z0-9-]+"` → extract `NV-xxx`
- Tags in tests: `it ["']NV-[a-z0-9-]+` OR `demo_nv.*NV-[a-z0-9-]+` → extract `NV-xxx`
- Deferred: lines matching `NV-[a-z0-9-]+` in `.github/nv-test-deferred.txt`

**Deferred file format:** One NV anchor per line, followed by `#<issue>`:
```
# NV anchors deferred from test coverage (gate: linked issue).
# Remove line when test is added.
```

Initially empty (all 5 anchors will get test tags in Task 2).

**Script accepts positional args:** `$1` = canonical doc, `$2` = tests dir, `$3` = deferred file.

**Test cases:**
1. PASS: all anchors have tests, no deferred
2. FAIL R1: anchor without test and not deferred
3. PASS: anchor deferred with #issue
4. FAIL R2: deferred without #issue
5. FAIL R3: orphan NV tag in test
6. FAIL R4: orphan deferred
7. PASS: anchor covered via demo_nv metadata

- [ ] **Step 1:** Write `.github/nv-test-deferred.txt` (empty with header comment)
- [ ] **Step 2:** Write `.github/scripts/check-nv-traceability.sh`
- [ ] **Step 3:** Make executable, run against real repo (will FAIL because tests don't have NV tags yet — expected)
- [ ] **Step 4:** Write `.github/scripts/check-nv-traceability.test.sh`
- [ ] **Step 5:** Run test script — all assertions pass
- [ ] **Step 6:** Commit script + deferred file + test

```bash
git add .github/scripts/check-nv-traceability.sh .github/scripts/check-nv-traceability.test.sh .github/nv-test-deferred.txt
git commit -m "ci: add check-nv-traceability guardrail script (ADR-065, #441)

Refs #441"
```

---

### Task 2: Add NV tags to existing tests (migration)

**Files to modify:** Add `NV-xxx:` prefix to ONE representative `it` description per anchor.

**Which test to tag per NV anchor:**

| NV anchor | Test file | Why this test |
|---|---|---|
| `NV-cot-khac-he-so-don-vi` | `spec/services/summary_calculator_spec.rb` | Core engine test for unit_coefficient calculation |
| `NV-hien-thi-chi-tiet-ton-hao` | `spec/services/calculation_orchestrator_spec.rb` | Integration test that verifies loss snapshot written |
| `NV-phan-bo-bom-theo-tram` | `spec/services/pump_allocation_calculator_spec.rb` | Core engine test for per-station pump allocation |
| `NV-nhat-ky-he-thong` | `spec/requests/audit_logs_spec.rb` | Request test for audit log viewing |
| `NV-sao-luu-phuc-hoi` | `spec/requests/backups_spec.rb` | Request test for backup CRUD |

For each: find ONE specific `it` block, prepend `NV-xxx: ` to the description string. Example:
```ruby
# Before:
it "calculates unit_coefficient correctly" do
# After:
it "NV-cot-khac-he-so-don-vi: calculates unit_coefficient correctly" do
```

- [ ] **Step 1:** Add NV tag to each of the 5 test files (find the right `it` block, prepend tag)
- [ ] **Step 2:** Run `bin/docker rspec` for tagged files to verify tests still pass
- [ ] **Step 3:** Run `check-nv-traceability.sh` — should now PASS
- [ ] **Step 4:** Commit

```bash
git add spec/services/summary_calculator_spec.rb spec/services/calculation_orchestrator_spec.rb spec/services/pump_allocation_calculator_spec.rb spec/requests/audit_logs_spec.rb spec/requests/backups_spec.rb
git commit -m "test: add NV-... traceability tags to existing tests (ADR-065, #441)

Tag 5 representative tests with NV anchor references so CI
check-nv-traceability.sh can cross-reference canonical requirements
with test coverage.

Refs #441"
```

---

### Task 3: Wire into CI + update docs

**Files:**
- Modify: `.github/workflows/ci.yml` — add script to `doc-governance` job
- Modify: `CONTRIBUTING.md` — add guardrail entry to mục 8
- Modify: `docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md` — bump version

- [ ] **Step 1:** Add to `doc-governance` job after the last `check-` line:
```yaml
          bash .github/scripts/check-nv-traceability.sh || rc=1
```
Update job name to include "NV traceability".

- [ ] **Step 2:** Add entry to CONTRIBUTING.md mục 8, after the doc-code sync guardrail entry:

```
**CI guardrail truy vết yêu cầu NV (ADR-065):** script trong job `doc-governance` (`check-nv-traceability.sh`, native bash fail-loud) đối chiếu anchor `NV-...` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` với tag `NV-...` trong mô tả `it` của test (`spec/`). Đỏ nếu: anchor required thiếu test (R1); dòng DEFERRED trong `.github/nv-test-deferred.txt` thiếu `#<số>` (R2); tag NV trong test không khớp anchor nào (orphan, R3); dòng DEFERRED tham chiếu anchor không tồn tại (R4). Song song pattern CHIEU (ADR-030). Chi tiết + lý do: ADR-065 trong `docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md`.
```

- [ ] **Step 3:** Bump spec version to 0.2.0, add changelog entry.

- [ ] **Step 4:** Run all guardrails locally to verify

```bash
bash .github/scripts/check-nv-traceability.sh
```

- [ ] **Step 5:** Commit

```bash
git add .github/workflows/ci.yml CONTRIBUTING.md docs/superpowers/specs/2026-06-25-nv-traceability-guardrail-design.md
git commit -m "ci: wire NV traceability guardrail into doc-governance (ADR-065, #441)

Refs #441"
```
