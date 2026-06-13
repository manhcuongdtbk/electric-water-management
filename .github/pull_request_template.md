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
- [ ] AGENTS conventions reviewed (CONTRIBUTING §8): i18n via `t(...)`, no abbreviations outside `docs/THUAT_NGU.md`, BigDecimal for money/electricity, six-role test coverage.
- [ ] If any `docs/` document changed: its version and changelog were bumped in this pull request (ADR-002). Root meta files (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`) are NOT versioned.
- [ ] Conventional Commits used; merge method matches CONTRIBUTING §2 (squash for `feature`/`fix`; non-changelog title prefix for `release`/`hotfix`/merge-back).
