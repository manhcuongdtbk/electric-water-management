# P2 — Git Flow + CI tĩnh tối thiểu: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dựng Git Flow thực tế (tạo nhánh `develop`, đặt làm default trên GitHub) và một workflow CI **tĩnh tối thiểu** trên GitHub Actions chạy trên mọi pull request: `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, và **branch-source guard** — đúng ADR-003, ADR-007, ADR-011.

**Architecture:** P2 chỉ dựng tập kiểm tra **không cần Postgres, không cần trình duyệt, không cần boot app** (tách rõ với mảnh "CI spec chi tiết" lo phần chạy test). Workflow một file `.github/workflows/ci.yml` với 3 job độc lập (mỗi job hiện trạng thái đỏ/xanh riêng): `ruby-checks` (rubocop + brakeman + bundler-audit trong một lần cài gem, không cache — cache để dành mảnh CI spec), `commitlint` (Node + npx, không thêm dependency vào repo ngoài một file config nhỏ), `branch-source-guard` (bash thuần, tách thành script để test được). Vì bật lint/security trên codebase chưa từng soi, P2 **grandfather** vi phạm hiện có (`.rubocop_todo.yml`, `config/brakeman.ignore`, ignore trong `config/bundler-audit.yml`) để lần CI đầu **xanh** và chỉ chặn vi phạm **mới** — **không sửa code ứng dụng** (P2 giữ test-free).

**Tech Stack:** GitHub Actions (`actions/checkout@v4`, `ruby/setup-ruby@v1`, `actions/setup-node@v4`), Ruby 3.4.3, `rubocop-rails-omakase`, `brakeman`, `bundler-audit` (đã có trong `Gemfile`), `@commitlint/cli` + `@commitlint/config-conventional` (chạy qua `npx`, không commit `node_modules`), bash thuần cho branch-source guard. Kiểm thử local: chạy thật ba công cụ trong container dev (`bin/docker exec app …`), `actionlint` (qua `docker run rhysd/actionlint`) cho YAML, và chạy script guard với biến môi trường giả lập. **Không đổi code ứng dụng → không cần `bin/docker rspec`.**

**Nguồn (đọc trước khi thực hiện):**
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — **ADR-003 (Git Flow), ADR-007 (enforce free-first), ADR-011 (nội dung CI)**, mục Backlog.
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-002 (quy ước version/changelog tài liệu).
- `AGENTS.md` + `CONTRIBUTING.md` — quy ước + quy trình Git Flow đã ghi.

**Quy ước chung khi thực hiện:**
- Tài liệu/giao diện tiếng Việt 100%; code/commit message/pull request title + description tiếng Anh; **tuyệt đối không viết tắt** (ngoại lệ phổ biến: CRUD, UI; tên chuẩn giữ nguyên: Git Flow, SemVer, Conventional Commits, CI, ADR, GitHub Actions, rubocop, brakeman). Viết "pull request" thay vì "PR".
- Commit theo Conventional Commits; **kết mỗi commit bằng** dòng `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Đang ở worktree, nhánh `claude/nostalgic-pasteur-55e5e1` (cắt từ `main`). Commit trực tiếp lên nhánh này được. **KHÔNG push remote, KHÔNG tạo nhánh `develop` trên remote, KHÔNG đổi default branch, KHÔNG mở pull request khi chưa được chủ dự án duyệt** — làm xong toàn bộ Task 1–8 (local) rồi DỪNG, trình diện; Task 9 (remote) chỉ chạy sau khi được duyệt.
- Container dev: dùng `preview_start docker-dev` (agent) hoặc `bin/docker up` chạy nền (người) để có container; sau đó chạy công cụ qua `bin/docker exec app <lệnh>`. Lần đầu build image có thể lâu — nếu >2 phút, báo trước.

---

## File Structure

| File | Trách nhiệm | Thao tác |
|---|---|---|
| `.github/workflows/ci.yml` | Workflow CI tĩnh: 3 job (ruby-checks, commitlint, branch-source-guard) chạy trên pull request | **Create** |
| `.github/scripts/check-branch-source.sh` | Branch-source guard (bash thuần, tách ra để test được): chặn pull request đích `main` không đến từ `release/*`/`hotfix/*` | **Create** |
| `commitlint.config.mjs` | Cấu hình Conventional Commits cho commitlint (mở rộng config-conventional; tắt giới hạn dòng body/footer) | **Create** |
| `.rubocop_todo.yml` | Baseline grandfather vi phạm rubocop hiện có (chỉ tạo nếu có vi phạm) | **Create** (có điều kiện) |
| `.rubocop.yml` | Thêm `inherit_from: .rubocop_todo.yml` nếu có baseline | **Modify** (có điều kiện) |
| `config/brakeman.ignore` | Baseline grandfather cảnh báo brakeman hiện có (chỉ tạo nếu có cảnh báo) | **Create** (có điều kiện) |
| `config/bundler-audit.yml` | Thêm advisory cần bỏ qua (chỉ khi có CVE thật, kèm lý do) | **Modify** (có điều kiện) |
| `CONTRIBUTING.md` | Mục 8 "Trạng thái tự động hoá": phản ánh CI tĩnh đã chạy sau P2 | **Modify** (mục 8) |
| `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` | ADR-011 thêm "Phân kỳ triển khai"; Backlog #1 làm rõ; bump 0.2.0 → 0.3.0 + changelog | **Modify** |

> Lưu ý phạm vi: plan này là **implementation** của các ADR đã duyệt (003/007/011) — không tạo spec thiết kế mới. Thiết kế nằm ở các ADR đó + phần tinh chỉnh nhỏ trong release spec (Task 8). Plan trong `docs/superpowers/plans/` **không** versioned (ADR-002 chỉ versioned `docs/` knowledge docs + `superpowers/specs/*`).

---

## Task 1: Cấu hình commitlint (Conventional Commits)

**Files:**
- Create: `commitlint.config.mjs`

- [ ] **Step 1: Tạo file cấu hình**

```javascript
// Cấu hình Conventional Commits cho commitlint (ADR-011, ADR-008).
// Mở rộng bộ luật chuẩn config-conventional. CI chạy qua `npx` nên KHÔNG cần
// package.json / node_modules trong repo — chỉ file config nhỏ này.
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Tắt giới hạn độ dài dòng body/footer để không báo sai với URL dài trong
    // body hoặc trailer "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>".
    'body-max-line-length': [0, 'always'],
    'footer-max-line-length': [0, 'always'],
  },
};
```

- [ ] **Step 2: Kiểm tra cấu hình hợp lệ (load được + giải `extends`)**

Chạy (host có Node, hoặc trong container có Node):

```bash
npx --yes -p @commitlint/cli -p @commitlint/config-conventional commitlint --print-config --config commitlint.config.mjs >/dev/null && echo "OK: commitlint config hợp lệ"
```

Expected: in ra `OK: commitlint config hợp lệ` (lệnh không lỗi nghĩa là config + config-conventional giải được). Nếu host không có Node, bỏ qua bước này — job `commitlint` trên pull request (Task 3) sẽ xác thực; ghi chú lại là đã bỏ qua.

- [ ] **Step 3: Commit**

```bash
git add commitlint.config.mjs
git commit -m "$(cat <<'EOF'
ci: add commitlint config for Conventional Commits

Extends @commitlint/config-conventional; disables body/footer line-length
so long URLs and the Co-Authored-By trailer do not false-fail. Run via npx
in CI, no package.json committed (ADR-011).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Branch-source guard (bash script + test local)

**Files:**
- Create: `.github/scripts/check-branch-source.sh`

- [ ] **Step 1: Tạo script guard**

```bash
#!/usr/bin/env bash
# Branch-source guard (ADR-003, ADR-011): chặn pull request đích `main` đến từ
# nhánh KHÔNG phải release/* hoặc hotfix/*. Bash thuần, không dependency.
#
# Đọc hai biến môi trường (CI truyền từ github.base_ref / github.head_ref):
#   BASE_REF  — nhánh đích của pull request
#   HEAD_REF  — nhánh nguồn của pull request
#
# Quy ước thoát: 0 = hợp lệ (hoặc không áp dụng); 1 = vi phạm luật Git Flow.
set -euo pipefail

base="${BASE_REF:-}"
head="${HEAD_REF:-}"

if [ "$base" != "main" ]; then
  echo "✓ Pull request đích '${base:-<rỗng>}' (không phải main) — branch-source guard bỏ qua."
  exit 0
fi

case "$head" in
  release/* | hotfix/*)
    echo "✓ Pull request đích main đến từ '$head' — hợp lệ (Git Flow)."
    exit 0
    ;;
  *)
    echo "✗ Pull request đích main chỉ được đến từ release/* hoặc hotfix/* (ADR-003)."
    echo "  Nguồn hiện tại: '${head:-<rỗng>}'."
    echo "  → Đổi đích sang 'develop', hoặc cắt nhánh release/* | hotfix/* theo Git Flow."
    exit 1
    ;;
esac
```

- [ ] **Step 2: Cho script quyền chạy + kiểm tra cú pháp**

```bash
chmod +x .github/scripts/check-branch-source.sh
bash -n .github/scripts/check-branch-source.sh && echo "OK: cú pháp bash hợp lệ"
```

Expected: `OK: cú pháp bash hợp lệ`.

- [ ] **Step 3: Test logic guard với 5 trường hợp (đây là kiểm thử hành vi của script)**

```bash
run() { BASE_REF="$1" HEAD_REF="$2" bash .github/scripts/check-branch-source.sh >/dev/null 2>&1; echo "base=$1 head=$2 -> exit=$?"; }
run develop feature/x      # mong đợi exit=0 (đích không phải main)
run main release/1.1       # mong đợi exit=0 (release/*)
run main hotfix/1.0.2      # mong đợi exit=0 (hotfix/*)
run main feature/favicon   # mong đợi exit=1 (nguồn sai)
run main develop           # mong đợi exit=1 (nguồn sai)
```

Expected (đúng từng dòng):

```
base=develop head=feature/x -> exit=0
base=main head=release/1.1 -> exit=0
base=main head=hotfix/1.0.2 -> exit=0
base=main head=feature/favicon -> exit=1
base=main head=develop -> exit=1
```

Nếu bất kỳ dòng nào sai exit code → dừng, sửa script (Step 1) rồi chạy lại Step 3.

- [ ] **Step 4: Commit**

```bash
git add .github/scripts/check-branch-source.sh
git commit -m "$(cat <<'EOF'
ci: add native branch-source guard script

Fails a pull request targeting main whose source is not release/* or
hotfix/* (ADR-003). Pure bash, no dependency; reads BASE_REF/HEAD_REF so it
is unit-testable locally. Verified against the five base/head cases.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Workflow CI tĩnh

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Tạo workflow**

```yaml
name: CI

# P2 — CI TĨNH tối thiểu (ADR-007, ADR-011). Chỉ các kiểm tra KHÔNG cần Postgres,
# trình duyệt, hay boot app. Phần chạy test (rspec gồm system spec, kiểm schema
# không lệch, zeitwerk:check) + runner/cache/headless để dành mảnh "CI spec chi
# tiết" (Backlog trong quy-trinh-release-design.md). Theo ADR-007, CI chỉ HIỆN
# trạng thái (repo private không có branch protection miễn phí) — kỷ luật một
# người merge giữ luật.
on:
  pull_request:
    types: [opened, synchronize, reopened, edited]

# Hủy run cũ khi có thay đổi mới trên cùng pull request (tiết kiệm phút Actions).
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ruby-checks:
    name: Ruby tĩnh (rubocop, brakeman, bundler-audit)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: .ruby-version # setup-ruby chấp nhận tên file như giá trị đặc biệt
          bundler-cache: false # Cache để dành mảnh "CI spec chi tiết"
      - name: Cài gem (không cache — tinh chỉnh cache thuộc mảnh CI spec)
        run: bundle install --jobs 4
      - name: rubocop
        if: ${{ !cancelled() }}
        run: bundle exec rubocop --no-server --format progress
      - name: brakeman
        if: ${{ !cancelled() }}
        run: bundle exec brakeman --exit-on-warn --no-progress --quiet
      - name: bundler-audit
        if: ${{ !cancelled() }}
        run: bundle exec bundler-audit check --update

  commitlint:
    name: Conventional Commits (commitlint)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Cần đủ lịch sử để lint dải commit của pull request
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: commitlint
        run: >
          npx --yes
          -p @commitlint/cli
          -p @commitlint/config-conventional
          commitlint
          --from ${{ github.event.pull_request.base.sha }}
          --to ${{ github.event.pull_request.head.sha }}

  branch-source-guard:
    name: Branch-source guard (Git Flow)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Kiểm tra nguồn pull request đích main
        env:
          BASE_REF: ${{ github.base_ref }}
          HEAD_REF: ${{ github.head_ref }}
        run: bash .github/scripts/check-branch-source.sh
```

- [ ] **Step 2: Lint YAML workflow bằng actionlint**

```bash
docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:latest -color
```

Expected: không in lỗi, thoát 0. (Nếu không có mạng để kéo image `rhysd/actionlint`, bỏ qua và ghi chú; lần chạy thật trên pull request ở Task 9 sẽ phát hiện lỗi YAML.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: add minimal static CI workflow on pull requests

Three independent jobs (ADR-011, static-only scope per ADR-011 phasing):
ruby-checks (rubocop + brakeman --exit-on-warn + bundler-audit, one
uncached bundle install), commitlint via npx, and the branch-source guard.
No Postgres/browser/app-boot; test runs deferred to the CI spec piece.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Baseline rubocop (grandfather, không sửa code app)

**Files:**
- Create: `.rubocop_todo.yml` (có điều kiện)
- Modify: `.rubocop.yml` (có điều kiện)

- [ ] **Step 1: Đảm bảo container dev đang chạy**

Agent: `preview_start docker-dev`. Người: `bin/docker up` (chạy nền). Kiểm tra:

```bash
bin/docker ps
```

Expected: thấy container app + postgres `Up`.

- [ ] **Step 2: Chạy rubocop để đo vi phạm hiện có**

```bash
bin/docker exec app bundle exec rubocop --no-server --format progress
```

Expected: một trong hai —
- `no offenses detected` → codebase sạch. **Bỏ qua Step 3–4**, không tạo baseline; ghi chú "rubocop sạch, không cần `.rubocop_todo.yml`". Sang Step 5 (không có gì để commit ở task này → bỏ qua Task 4 commit).
- `N offenses detected` → sang Step 3.

- [ ] **Step 3: Sinh baseline grandfather (chỉ khi có vi phạm)**

```bash
bin/docker exec app bundle exec rubocop --no-server --auto-gen-config
```

Lệnh này tạo `.rubocop_todo.yml` (liệt kê cop + file được tha) và thêm dòng `inherit_from: .rubocop_todo.yml` vào đầu `.rubocop.yml`. Mở `.rubocop.yml` kiểm tra dòng đầu đúng như sau (nếu rubocop chưa tự thêm thì thêm tay):

```yaml
inherit_from: .rubocop_todo.yml

# Omakase Ruby styling for Rails
inherit_gem: { rubocop-rails-omakase: rubocop.yml }

# Overwrite or add rules to create your own house style
#
# # Use `[a, [b, c]]` not `[ a, [ b, c ] ]`
# Layout/SpaceInsideArrayLiteralBrackets:
#   Enabled: false
```

- [ ] **Step 4: Xác nhận rubocop xanh với baseline**

```bash
bin/docker exec app bundle exec rubocop --no-server --format progress
```

Expected: `no offenses detected` (exit 0). Nếu vẫn còn offense (ví dụ cop không grandfather được vào todo) → dừng, báo chủ dự án (không tự sửa code app — ngoài phạm vi P2).

- [ ] **Step 5: Commit (chỉ khi có baseline)**

```bash
git add .rubocop_todo.yml .rubocop.yml
git commit -m "$(cat <<'EOF'
chore(rubocop): grandfather existing offenses via .rubocop_todo.yml

Introduce rubocop in CI without rewriting application code: baseline the
current offenses so CI is green and only NEW offenses fail. Cleaning the
todo list is backlog follow-up.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Baseline brakeman (grandfather, không sửa code app)

**Files:**
- Create: `config/brakeman.ignore` (có điều kiện)

- [ ] **Step 1: Chạy brakeman để đếm cảnh báo hiện có**

```bash
bin/docker exec app bundle exec brakeman --no-progress --quiet
```

Expected: cuối báo cáo in số cảnh báo (ví dụ `Security Warnings 0`). Brakeman mặc định **thoát 0** dù có cảnh báo (chưa có `--exit-on-warn`), nên lệnh này chỉ để đếm.
- Nếu `0` cảnh báo → CI bước brakeman (`--exit-on-warn`) sẽ xanh sẵn; **bỏ qua Step 2–4**, không tạo `config/brakeman.ignore`. Ghi chú "brakeman sạch".
- Nếu `>0` cảnh báo → sang Step 2.

- [ ] **Step 2: Sinh file ignore grandfather (chỉ khi có cảnh báo)**

`brakeman -I` là **tương tác**. Mở shell trong container rồi chạy:

```bash
bin/docker bash
# trong shell container:
bundle exec brakeman -I
```

Trong menu tương tác: chọn thêm (`a`) **tất cả** cảnh báo hiện có vào danh sách bỏ qua, nhập ghi chú ngắn (ví dụ `Grandfathered in P2; review in backlog`), rồi lưu (`s`) vào đường dẫn mặc định `config/brakeman.ignore` và thoát (`q`). Gõ `exit` để rời shell container.

Kết quả: file `config/brakeman.ignore` (JSON, danh sách fingerprint cảnh báo được tha) xuất hiện ở host (thư mục worktree được mount vào container).

- [ ] **Step 3: Xác nhận brakeman xanh với ignore + chế độ CI**

```bash
bin/docker exec app bundle exec brakeman --exit-on-warn --no-progress --quiet; echo "exit=$?"
```

Expected: `exit=0` (mọi cảnh báo hiện có đã được tha; cảnh báo mới sau này sẽ làm exit khác 0). Nếu `exit=3` → còn cảnh báo chưa tha; lặp lại Step 2.

- [ ] **Step 4: Commit (chỉ khi có ignore)**

```bash
git add config/brakeman.ignore
git commit -m "$(cat <<'EOF'
chore(brakeman): grandfather existing warnings via config/brakeman.ignore

Enable brakeman --exit-on-warn in CI without changing application code:
baseline current warnings so only NEW findings fail. Reviewing the
grandfathered warnings is backlog follow-up.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Baseline bundler-audit (grandfather có lý do, không tự bump gem)

**Files:**
- Modify: `config/bundler-audit.yml` (có điều kiện)

- [ ] **Step 1: Chạy bundler-audit**

```bash
bin/docker exec app bundle exec bundler-audit check --update
```

Expected: `No vulnerabilities found` (exit 0) → **bỏ qua Step 2–3**, không sửa file. Ghi chú "bundler-audit sạch". (File `config/bundler-audit.yml` hiện chỉ có placeholder `CVE-THAT-DOES-NOT-APPLY` — vô hại, giữ nguyên.)
- Nếu liệt kê CVE → sang Step 2.

- [ ] **Step 2: Xử lý CVE (chỉ khi có)**

Với mỗi CVE: nếu **vá được dễ** (bump gem nhỏ, không phá vỡ) → **KHÔNG tự làm** (bump chạm `Gemfile.lock` → cần `bin/docker rspec`, ngoài phạm vi test-free của P2); **dừng, báo chủ dự án** để quyết định bump trong một thay đổi riêng. Nếu CVE **không áp dụng / chấp nhận tạm** → thêm vào `config/bundler-audit.yml` kèm lý do:

```yaml
# Audit all gems listed in the Gemfile for known security problems by running bin/bundler-audit.
# CVEs that are not relevant to the application can be enumerated on the ignore list below.

ignore:
  - CVE-THAT-DOES-NOT-APPLY
  # P2 grandfather: <CVE-id> — <lý do ngắn: không áp dụng / chờ bump ở backlog>.
  - <CVE-id>
```

- [ ] **Step 3: Xác nhận xanh + commit (chỉ khi sửa file)**

```bash
bin/docker exec app bundle exec bundler-audit check --update; echo "exit=$?"
git add config/bundler-audit.yml
git commit -m "$(cat <<'EOF'
chore(bundler-audit): document ignored advisories for CI baseline

Record non-applicable / deferred advisories in config/bundler-audit.yml so
CI is green; gem bumps are tracked as backlog follow-up (kept out of P2 to
stay test-free).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

Expected: `exit=0`.

---

## Task 7: Cập nhật CONTRIBUTING mục 8 (trạng thái tự động hoá)

**Files:**
- Modify: `CONTRIBUTING.md` (mục 8)

- [ ] **Step 1: Thay nội dung mục 8**

Tìm khối hiện tại:

```markdown
## 8. Trạng thái tự động hoá

Một số guardrail (CI: `rspec`/`rubocop`/`brakeman`/`commitlint`/branch-guard; release-please; môi trường Railway Nghiệm thu + Mốc) sẽ được triển khai ở các giai đoạn sau của chuẩn hoá quy trình phát triển (P2–P4). Hiện tại các quy ước ở mục 2–3 được giữ bằng kỷ luật + review thủ công; xem mục Backlog trong release spec.
```

Thay bằng:

```markdown
## 8. Trạng thái tự động hoá

**CI tĩnh đã chạy trên mọi pull request (P2):** `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, và **branch-source guard** (chặn pull request đích `main` đến từ nhánh không phải `release/*`/`hotfix/*`). Theo ADR-007, CI chỉ **hiện trạng thái** đỏ/xanh — chưa khoá cứng ở server (repo private không có branch protection miễn phí); kỷ luật một người merge giữ luật.

**Còn ở các giai đoạn sau:** chạy test trên CI (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng tinh chỉnh runner/cache/headless là **mảnh "CI spec chi tiết"** (Backlog #1 trong release spec); release-please (P3); môi trường Railway Nghiệm thu + Mốc (P4). Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.
```

- [ ] **Step 2: Commit** (`CONTRIBUTING.md` là file meta gốc repo → KHÔNG bump version, theo ADR-002)

```bash
git add CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
docs(contributing): mark static CI live after P2

Update the automation-status section: static CI (rubocop, brakeman,
bundler-audit, commitlint, branch-source guard) now runs on every pull
request; test runs, release-please and Railway remain in later phases.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Ghi ranh giới P2 vào release spec (bump 0.3.0)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`

- [ ] **Step 1: Bump version ở frontmatter**

Đổi `version: 0.2.0` → `version: 0.3.0`.

- [ ] **Step 2: Thêm "Phân kỳ triển khai" vào ADR-011**

Trong `### ADR-011: Nội dung CI`, thêm bullet này NGAY TRƯỚC dòng `- **Điều kiện xem lại:**`:

```markdown
- **Phân kỳ triển khai (chốt 2026-06-07):** P2 chỉ dựng tập **tĩnh, không cần Postgres/trình duyệt/boot app**: `rubocop`, `brakeman`, `bundler-audit`, `commitlint`, branch-source guard (grandfather vi phạm hiện có để lần CI đầu xanh, không sửa code app). Phần **chạy test** (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng runner/cache/headless chuyển sang mảnh **"CI spec chi tiết"** (Backlog #1) — vì cần dựng dịch vụ Postgres + Chrome headless và quyết định runner/cache mà mảnh đó sở hữu. Lý do tách: tập tĩnh ép được ngay, chi phí thấp, giữ P2 gọn + nhanh; chạy test cần thêm hạ tầng.
```

- [ ] **Step 3: Làm rõ Backlog #1**

Tìm dòng trong mục Backlog:

```markdown
1. CI spec (workflow chi tiết, runner, cache, headless browser).
```

Thay bằng:

```markdown
1. CI spec — phần **chạy test trên CI** còn lại sau P2: `rspec` (gồm system spec headless Chrome), kiểm schema không lệch, `rails zeitwerk:check`; cùng runner, cache, trình duyệt headless. (P2 đã dựng tập tĩnh: rubocop/brakeman/bundler-audit/commitlint/branch-source guard — xem ADR-011 "Phân kỳ triển khai".)
```

- [ ] **Step 4: Thêm entry changelog**

Trong `## Changelog`, thêm dòng đầu (trên `- **0.2.0 ...`):

```markdown
- **0.3.0 (2026-06-07):** ADR-011 thêm "Phân kỳ triển khai" chốt ranh giới P2 (tập tĩnh: rubocop/brakeman/bundler-audit/commitlint/branch-source guard) ↔ mảnh "CI spec chi tiết" (rspec/system + schema-drift + zeitwerk + runner/cache/headless); làm rõ Backlog #1 tương ứng.
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
git commit -m "$(cat <<'EOF'
docs(sdlc): record P2 static-CI boundary in release spec

ADR-011: add an implementation-phasing note fixing the P2 (static checks)
vs CI-spec (test runs + runner/cache/headless) boundary; clarify Backlog
#1. Bump 0.2.0 -> 0.3.0 with changelog entry (ADR-002).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: DỪNG — trình diện toàn bộ thay đổi local cho chủ dự án**

Tổng hợp: liệt kê các file đã tạo/sửa + kết quả ba công cụ (sạch hay đã grandfather) + kết quả test guard + actionlint. **Chờ duyệt** trước khi sang Task 9 (mọi thao tác remote).

---

## Task 9: Bootstrap Git Flow trên remote (CHỈ sau khi được duyệt)

**Files:** không (thao tác git/GitHub).

> Toàn bộ task này chỉ chạy **sau khi chủ dự án duyệt** kết quả Task 1–8. Repo: `manhcuongdtbk/electric-water-management`.

- [ ] **Step 1: Tạo nhánh `develop` từ `main` mới nhất và đẩy lên remote**

```bash
git fetch origin
git branch develop origin/main
git push origin develop
```

Expected: nhánh `develop` xuất hiện trên remote, trỏ cùng commit với `origin/main` (hiện `0800606`).

- [ ] **Step 2: Đặt `develop` làm default branch trên GitHub**

```bash
gh api -X PATCH repos/{owner}/{repo} -f default_branch=develop
gh api repos/{owner}/{repo} -q .default_branch
```

Expected: lệnh thứ hai in `develop`.

- [ ] **Step 3: Đẩy nhánh P2 + mở pull request đích `develop`**

```bash
git push -u origin claude/nostalgic-pasteur-55e5e1
gh pr create \
  --base develop \
  --head claude/nostalgic-pasteur-55e5e1 \
  --title "ci: bootstrap Git Flow develop branch and minimal static CI (P2)" \
  --body "$(cat <<'EOF'
## P2 — Git Flow + minimal static CI

Implements ADR-003 (Git Flow), ADR-007 (free-first enforcement) and ADR-011
(CI content), static-only scope per the ADR-011 phasing note.

### What this adds
- `.github/workflows/ci.yml` — three jobs on pull requests: ruby-checks
  (rubocop, brakeman --exit-on-warn, bundler-audit), commitlint (npx,
  config-conventional), branch-source guard.
- `.github/scripts/check-branch-source.sh` — native bash guard: a pull
  request targeting `main` must come from `release/*` or `hotfix/*`.
- `commitlint.config.mjs` — Conventional Commits rules.
- Static-analysis baselines grandfathering existing findings (no app-code
  changes), as applicable.
- CONTRIBUTING section 8 + release spec (ADR-011 phasing, Backlog #1, bump
  0.3.0) updated.

### Scope boundary
Test runs (rspec incl. system specs, schema-drift, zeitwerk:check) and
runner/cache/headless tuning are deferred to the dedicated CI-spec backlog
piece. Enforcement is "show red" only (ADR-007); no server-side branch
protection on this private repo.

### Test plan
- [x] rubocop / brakeman / bundler-audit run green locally (baselines added if needed)
- [x] branch-source guard verified against five base/head cases
- [x] workflow YAML linted with actionlint
- [ ] all three CI jobs green on this pull request
EOF
)"
```

- [ ] **Step 4: Xác nhận CI chạy và xanh trên pull request**

```bash
gh pr checks --watch
```

Expected: ba job `ruby-checks`, `commitlint`, `branch-source-guard` đều `pass`. (branch-source-guard xanh vì pull request này đích `develop`.) Nếu job nào đỏ → đọc log (`gh run view --log-failed`), sửa nguyên nhân ở task tương ứng, commit, đẩy lại; lặp tới khi xanh. Đánh dấu `[x]` dòng cuối Test plan trong mô tả pull request.

- [ ] **Step 5: Dọn nhánh đích main còn treo (heads-up, không bắt buộc)**

```bash
gh pr list --base main --state open
```

Với mỗi pull request đích `main` đến từ `feature/*`/`docs/*`/`fix/*` (không phải `release/*`/`hotfix/*`): đổi đích sang `develop` để khớp Git Flow (nếu không sẽ hiện đỏ ở branch-source guard sau khi workflow lan tới base của chúng).

```bash
gh pr edit <number> --base develop
```

- [ ] **Step 6: DỪNG — chờ chủ dự án review + merge pull request**

Không tự merge. Sau khi chủ dự án merge vào `develop`, P2 hoàn tất; `main` chỉ nhận workflow qua lần release đầu (release/* → main mang theo file workflow trong merge commit).

---

## Self-Review (đã rà)

**1. Spec coverage:**
- ADR-003 (Git Flow: tạo `develop`, default branch) → Task 9 (Step 1–2).
- ADR-007 (free-first, "hiện đỏ") → workflow `on: pull_request` không kèm branch protection; ghi rõ trong comment workflow + CONTRIBUTING mục 8 (Task 7).
- ADR-011 các bước **tĩnh**: rubocop/brakeman/bundler-audit (Task 3 ruby-checks + baseline Task 4–6), commitlint (Task 1 + Task 3), branch-source guard (Task 2 + Task 3). Phần test (rspec/schema-drift/zeitwerk) **cố ý hoãn** → ghi vào ADR-011 phasing + Backlog #1 (Task 8). ✓
- Quy ước version/changelog tài liệu (ADR-002): release spec bump 0.3.0 + changelog (Task 8); CONTRIBUTING không bump (file meta gốc) (Task 7). ✓

**2. Placeholder scan:** Các nhánh "có điều kiện" (baseline) đều kèm lệnh đo cụ thể + tiêu chí bỏ qua; `<CVE-id>` trong Task 6 là chỗ điền giá trị thật do bundler-audit in ra (không phải placeholder logic). Không còn TODO/TBD.

**3. Type/cờ nhất quán:** tên job (`ruby-checks`/`commitlint`/`branch-source-guard`), biến guard (`BASE_REF`/`HEAD_REF`), cờ công cụ (`--no-server`, `--exit-on-warn`, `check --update`, `--from/--to`) khớp giữa script, workflow, và các bước verify. Nhánh `claude/nostalgic-pasteur-55e5e1` và base `develop` nhất quán Task 9.
