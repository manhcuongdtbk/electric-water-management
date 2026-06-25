## Summary

<!-- What does this change do, and why? -->

## Linked change

<!-- Required for feature/fix work: the GitHub Issue this implements. -->
Refs #

## Traceability checklist

- [ ] Links its change Issue (`Refs #N`, or `Closes #N` if it fully resolves it). *(feature/fix work)*
- [ ] If a business requirement is affected: `docs/V2_XAC_NHAN_NGHIEP_VU.md` is updated and the requirement has a stable anchor `<a id="NV-..."></a>`.
- [ ] The design spec's `## Truy vết` section links the requirement (`NV-...`) and the covering test(s).
- [ ] If the change implements a feature spec with test dimensions: the spec has a `## Truy vết chiều test` table and every dimension maps to a test (`CHIEU-<slug>:`) or `DEFERRED #issue` (ADR-030).
- [ ] Tests cover the changed behaviour (`bin/docker rspec`).
- [ ] Customer-facing change (`customer-facing` label, applied at triage): a demo spec under `spec/demo/` was drafted/updated alongside the code (`rails g demo:spec <feature>`), with Vietnamese captions from the `NV-...` criteria and a human reviewing the video (ADR-040/050/051). The design spec declares it as a deliverable — `customer_facing: true` frontmatter + `## Truy vết demo` (or `DEFERRED #issue`), enforced by `check-demo-deliverable.sh` (ADR-052).
- [ ] Demo quality (ADR-059): I watched the recording **as a clueless customer** and checked it against the six-point "demo tốt" checklist (show-don't-tell · right customer story · result-not-mechanics · honest about the medium · enough journey-not-everything · stable), comparing against the golden example `spec/demo/cot_khac_he_so_don_vi_demo_spec.rb` (TN1). Below, I note what I reviewed. *(customer-facing work)*
- [ ] AGENTS conventions reviewed (CONTRIBUTING §8): i18n via `t(...)`, no abbreviations outside `docs/THUAT_NGU.md`, BigDecimal for money/electricity, seven-role test coverage.
- [ ] No fact duplication: content added to docs describes behavior and points to the canonical source, not reproducing facts from another file or code (ADR-023).
- [ ] If code simplifies or skips a spec requirement: a `> **Simplified (PR #NNN, date):** ...` blockquote was added to the spec in this same PR (ADR-063).
- [ ] If any `docs/` document changed: its version and changelog were bumped in this pull request (ADR-002). Root meta files (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`) are NOT versioned.
- [ ] Conventional Commits used; merge method matches CONTRIBUTING §2 (squash for `feature`/`fix`; non-changelog title prefix for `release`/`hotfix`/merge-back).
