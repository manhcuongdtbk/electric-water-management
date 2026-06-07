# CI test-runs (CI spec chi tiết) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the deferred test-running half of CI — on every pull request, run `rspec` (model/request + 12 system specs via headless Chrome), a schema-drift check, and `rails zeitwerk:check` — by extending the existing static `.github/workflows/ci.yml`.

**Architecture:** One new `tests` job on a native `ubuntu-latest` runner with a `postgres:16-alpine` service container; Chrome resolved through Selenium Manager (forced via non-existent `CHROMIUM_BINARY`/`CHROMEDRIVER_BINARY` so the existing `system_test_config.rb` fallback path is used — no app/test code change). Gem caching turned on for the new job and the existing static job. Purely additive workflow + documentation cross-references; nothing in the app or test suite changes.

**Tech Stack:** GitHub Actions, `ruby/setup-ruby@v1`, PostgreSQL 16 service container, RSpec + Capybara + Selenium (selenium-webdriver 4.44, Selenium Manager), Ruby 3.4.3, Rails 8.

**Design source:** `docs/superpowers/specs/2026-06-07-ci-spec-design.md` (ADR-012). Parent: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-011, Backlog #1).

**Conventions (AGENTS.md):** documentation/UI in Vietnamese; commits in English (Conventional Commits); no abbreviations except CI/ADR/CRUD/UI. Branch from `develop`, squash-merge the feature PR into `develop`. End commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. **Do NOT push or merge without the owner's approval.**

---

## File Structure

- **Modify** `.github/workflows/ci.yml` — header comment refresh; flip `ruby-checks` to cached gems; add the `tests` job. *(The workflow is the deliverable.)*
- **Modify** `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — add a "Triển khai (P5)" pointer to ADR-012 inside ADR-011; bump version `0.5.0 → 0.6.0` + changelog entry (per ADR-002).
- **Modify** `CONTRIBUTING.md` — §8 "Trạng thái tự động hoá": move test-CI from "còn ở giai đoạn sau" into "đã chạy". *(Root meta file → no version bump per ADR-002.)*
- **Modify** `AGENTS.md` — one concise line in "Quy trình làm việc" noting CI re-runs the full suite on pull requests (without replacing local `bin/docker rspec`). *(Root meta → no version bump.)*

There is **no unit test** for a CI workflow. Verification for config tasks is `actionlint` (syntax/semantics) plus a final review; the real end-to-end proof is the **first pull-request run** on GitHub (needs Chrome + Postgres on the runner) — done only after the owner approves the push.

---

## Task 1: Extend `.github/workflows/ci.yml` (header + cache + `tests` job)

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read the current workflow**

Run: `cat .github/workflows/ci.yml`
Purpose: confirm the exact current text before editing (the strings below are the P2 baseline on `develop`).

- [ ] **Step 2: Refresh the header comment**

Replace the top comment block. Find:

```yaml
name: CI

# P2 — minimal STATIC CI (ADR-007, ADR-011). Only checks that need NO Postgres,
# NO browser, and NO app boot. Test runs (rspec incl. system specs, schema-drift,
# zeitwerk:check) plus runner/cache/headless tuning are deferred to the "CI spec"
# piece (Backlog in quy-trinh-release-design.md). Per ADR-007 this CI only SHOWS
# status (a private repo has no free branch protection) — single-merger discipline
# enforces the rules.
```

Replace with:

```yaml
name: CI

# CI on pull requests (ADR-007, ADR-011, ADR-012). Two tiers:
#   - STATIC checks (no Postgres / no browser / no app boot): rubocop, brakeman,
#     bundler-audit, commitlint, branch-source guard.
#   - TEST runs (Postgres service container + headless Chrome): rspec incl. system
#     specs, a schema-drift check, and zeitwerk:check — see the `tests` job and
#     docs/superpowers/specs/2026-06-07-ci-spec-design.md (ADR-012).
# Per ADR-007 this CI only SHOWS status (a private repo has no free branch
# protection) — single-merger discipline enforces the rules.
```

- [ ] **Step 3: Flip the `ruby-checks` job to cached gems**

Find:

```yaml
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version # setup-ruby accepts the filename as a special value
          bundler-cache: false # caching deferred to the "CI spec" piece
      - name: Install gems (no cache — cache tuning belongs to the CI-spec piece)
        run: bundle install --jobs 4
      - name: rubocop
```

Replace with:

```yaml
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version # setup-ruby accepts the filename as a special value
          bundler-cache: true # gem cache enabled by the CI-spec piece (ADR-012)
      - name: rubocop
```

(This removes the now-redundant manual `Install gems` step — `bundler-cache: true` runs `bundle install` itself.)

- [ ] **Step 4: Append the `tests` job**

Add this job at the end of the file, after the `branch-source-guard` job (keep the existing 2-space job indentation):

```yaml

  tests:
    name: Tests (rspec incl. system specs, zeitwerk, schema drift)
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine # matches compose.yml
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_HOST: localhost
      DATABASE_PORT: 5432
      DATABASE_USERNAME: postgres
      ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD: postgres
      # Force the Selenium Manager path: these paths do not exist, so the
      # File.exist? guards in spec/support/system_test_config.rb both fail and
      # Selenium Manager resolves the runner's pre-installed Google Chrome plus a
      # version-matched chromedriver. No app/test code change needed.
      CHROMIUM_BINARY: /nonexistent/chromium
      CHROMEDRIVER_BINARY: /nonexistent/chromedriver
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version
          bundler-cache: true
      - name: Set up test database and check for schema drift
        if: ${{ !cancelled() }}
        # Fresh DB + migrate must reproduce the committed db/schema.rb byte-for-byte.
        run: |
          bin/rails db:create db:migrate
          git diff --exit-code db/schema.rb
      - name: Zeitwerk check (autoloading)
        if: ${{ !cancelled() }}
        run: bin/rails zeitwerk:check
      - name: rspec (model, request, and system specs with headless Chrome)
        if: ${{ !cancelled() }}
        run: bundle exec rspec
```

- [ ] **Step 5: Lint the workflow with actionlint**

Run (macOS; install once if missing):

```bash
brew list actionlint >/dev/null 2>&1 || brew install actionlint
actionlint .github/workflows/ci.yml
```

Expected: no output, exit code 0 (actionlint prints nothing on success).
Fallback if Homebrew is unavailable: `docker run --rm -v "$(pwd):/repo" --workdir /repo rhysd/actionlint:latest -color` (standalone container, unrelated to the project's compose setup).

If actionlint reports an error, fix the YAML and re-run until clean.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run tests (rspec, system specs, schema drift, zeitwerk) on pull requests

Add a tests job to ci.yml on a native ubuntu-latest runner with a
postgres:16-alpine service container. It checks schema drift (fresh db:migrate
leaves db/schema.rb unchanged), runs zeitwerk:check, and runs the full rspec
suite including the 12 system specs. System specs use the runner's pre-installed
Google Chrome via Selenium Manager (forced through non-existent CHROMIUM_BINARY/
CHROMEDRIVER_BINARY so the existing system_test_config.rb fallback is used).
Enable gem caching here and on the existing ruby-checks job. Implements ADR-012;
ADR-011 deferred this.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Point ADR-011 at ADR-012 and bump the release spec

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`

- [ ] **Step 1: Add a "Triển khai (P5)" note inside ADR-011**

In ADR-011, find the line:

```markdown
- **Điều kiện xem lại:** thời gian CI quá lâu → tách system spec / cache.
```

Insert this bullet immediately **above** it (so it sits after the "Phân kỳ triển khai" bullet):

```markdown
- **Triển khai (P5, chốt 2026-06-07):** phần **chạy test** (`rspec` gồm system spec, kiểm schema không lệch, `zeitwerk:check`) cùng runner/cache/headless đã hiện thực ở mảnh "CI spec chi tiết" — xem **ADR-012** trong [`2026-06-07-ci-spec-design.md`](2026-06-07-ci-spec-design.md): runner native `ubuntu-latest` + service container `postgres:16-alpine` + Chrome qua Selenium Manager; một job `tests` gộp schema-drift + zeitwerk + rspec; bật cache gem (đổi luôn job tĩnh sang cache).
```

- [ ] **Step 2: Bump the version in the frontmatter**

Find `version: 0.5.0` in the YAML frontmatter and change it to `version: 0.6.0`.

- [ ] **Step 3: Add the changelog entry**

In the `## Changelog` section, add this as the new top entry (above the `0.5.0` line):

```markdown
- **0.6.0 (2026-06-07):** ADR-011 thêm ghi chú "Triển khai (P5)" trỏ tới ADR-012 (`2026-06-07-ci-spec-design.md`) — phần chạy test trên CI (rspec/system + kiểm schema không lệch + zeitwerk; runner native + service container Postgres + Chrome qua Selenium Manager; bật cache gem) đã hiện thực.
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
git commit -m "docs(release): point ADR-011 at ADR-012 (CI test runs landed)

Add a P5 implementation note to ADR-011 cross-referencing the new CI spec
(ADR-012), and bump the release spec to 0.6.0 with a changelog entry per ADR-002.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Update CONTRIBUTING §8 and AGENTS.md

**Files:**
- Modify: `CONTRIBUTING.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Move test-CI into "đã chạy" in CONTRIBUTING §8**

In `CONTRIBUTING.md`, find this paragraph (the second bullet block of §8 ends with the release-please paragraph; insert a new paragraph after the P2 static-CI paragraph). Find:

```markdown
**CI tĩnh đã chạy trên mọi pull request (P2):** `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, và **branch-source guard** (chặn pull request đích `main` đến từ nhánh không phải `release/*`/`hotfix/*`). Theo ADR-007, CI chỉ **hiện trạng thái** đỏ/xanh — chưa khoá cứng ở server (repo private không có branch protection miễn phí); kỷ luật một người merge giữ luật.
```

Insert this paragraph immediately **after** it:

```markdown
**CI chạy test đã chạy trên mọi pull request (mảnh "CI spec chi tiết"):** một job `tests` chạy `rspec` (gồm 12 system spec điều khiển headless Chrome), kiểm `db/schema.rb` không lệch, và `rails zeitwerk:check` — trên runner native `ubuntu-latest` + service container Postgres, Chrome qua Selenium Manager. Vẫn theo ADR-007 (chỉ hiện trạng thái). Chi tiết: ADR-012 trong `docs/superpowers/specs/2026-06-07-ci-spec-design.md`.
```

- [ ] **Step 2: Trim the "còn ở các giai đoạn sau" paragraph**

In the same §8, find:

```markdown
**Còn ở các giai đoạn sau:** chạy test trên CI (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng tinh chỉnh runner/cache/headless là **mảnh "CI spec chi tiết"** (Backlog #1 trong release spec); môi trường Railway Nghiệm thu + Mốc + bản rc (P4). Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.
```

Replace with (drops the now-done CI item, keeps Railway/P4 + the discipline note):

```markdown
**Còn ở các giai đoạn sau:** môi trường Railway Nghiệm thu + Mốc + bản rc (P4); các mảnh SDLC còn lại trong Backlog của release spec. Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.
```

- [ ] **Step 3: Add the AGENTS.md note**

In `AGENTS.md`, in the "## Quy trình làm việc" section, find:

```markdown
- Không chạy rubocop locally (CI cover).
```

Insert this bullet immediately **after** it:

```markdown
- CI chạy lại toàn bộ test (rspec gồm system spec), kiểm schema không lệch và `zeitwerk:check` trên mỗi pull request (ADR-012) — **không thay** cho `bin/docker rspec` cục bộ sau mỗi thay đổi.
```

- [ ] **Step 4: Commit**

```bash
git add CONTRIBUTING.md AGENTS.md
git commit -m "docs: record test-running CI in automation status

Update CONTRIBUTING §8 to list the test-CI job as live and trim the deferred
list to Railway/P4. Add a one-line AGENTS.md note that CI re-runs the full suite
on pull requests without replacing local bin/docker rspec.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Local verification and handoff gate

**Files:** none (verification only).

- [ ] **Step 1: Re-lint the final workflow**

Run: `actionlint .github/workflows/ci.yml`
Expected: no output, exit 0.

- [ ] **Step 2: Sanity-check the test suite still passes locally (baseline)**

No app/test code changed, but confirm the suite is green before the first CI run so any CI failure is clearly environmental, not pre-existing.

Run: `bin/docker rspec`
Expected: all examples pass (0 failures). If the docker dev environment is not up, this may take a while — if it exceeds a couple of minutes or needs the stack started, ask the owner first (per the long-running-commands convention) rather than blocking.

- [ ] **Step 3: Review the full diff**

Run: `git diff develop...HEAD --stat && git log --oneline develop..HEAD`
Confirm: only `.github/workflows/ci.yml`, the two specs, `CONTRIBUTING.md`, and `AGENTS.md` changed (plus the already-committed ADR-012 spec). No app or `spec/` source touched.

- [ ] **Step 4: STOP — present to the owner, do not push**

Summarize the change and the verification results. The real end-to-end validation is the **first pull-request run** on GitHub (system specs need Chrome + Postgres on the runner), and per project rules **the owner must approve before pushing the branch / opening the PR**. The `tests` job's Chrome line is the most likely thing to need a tweak after that first run — watch the `system specs` step in the run log and adjust if Selenium Manager misbehaves.

---

## Self-Review (author checklist — completed)

**1. Spec coverage:** rspec incl. system specs → Task 1 Step 4 (`bundle exec rspec`). Schema-drift → Task 1 Step 4 (`db:create db:migrate` + `git diff --exit-code`). zeitwerk:check → Task 1 Step 4. Native runner + Postgres service container + Chrome via Selenium Manager → Task 1 Step 4. Caching on (new job + existing job) → Task 1 Steps 3–4. New spec ADR-012 → already committed in brainstorming (e6d8abc). ADR-011 pointer + bump → Task 2. CONTRIBUTING §8 → Task 3. AGENTS.md note → Task 3. actionlint + first-PR-run verification → Task 1 Step 5, Task 4. No `config/ci.rb` change, no retry gem, no job split — correctly absent (Non-Goals). All spec requirements mapped.

**2. Placeholder scan:** none — every step has exact paths, full code/YAML, and exact commands.

**3. Type consistency:** the env var names (`CHROMIUM_BINARY`, `CHROMEDRIVER_BINARY`, `DATABASE_HOST/PORT/USERNAME`, `ELECTRIC_WATER_MANAGEMENT_DATABASE_PASSWORD`) match `system_test_config.rb` and `config/database.yml` exactly; `postgres:16-alpine` matches `compose.yml`; job/step names are internally consistent.
