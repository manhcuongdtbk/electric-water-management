# P3 — release-please (bản phát hành chính thức): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tự động hoá **bản phát hành chính thức** bằng release-please trên `main` (tự tính version + soạn `CHANGELOG.md` + cập nhật `version.txt` + mở Release PR có cổng người duyệt → merge thì tự tag `vX.Y.Z` + tạo GitHub Release) — đúng ADR-008. Phần rc/UAT để dành P4.

**Architecture:** release-please chạy bằng GitHub Actions khi có push vào `main`, đọc Conventional Commits kể từ tag gần nhất. Vì default branch là `develop` nên BẮT BUỘC đặt `target-branch: main`. Dùng release-type `simple` (quản version trong `.release-please-manifest.json` + cập nhật file text `version.txt`), tag tiền tố `v` (khớp `v1.0.1`). Vì Release PR của bot đi từ nhánh `release-please--branches/main` vào `main`, phải mở rộng branch-source guard (P2) cho phép `release-please--*`. release-please ghi `CHANGELOG.md`/`version.txt` lên `main`, nên sau mỗi release phải đồng bộ `main` → `develop` (gộp vào merge-back).

**Tech Stack:** GitHub Actions (`googleapis/release-please-action@v4`), release-please config dạng manifest (`release-please-config.json` + `.release-please-manifest.json`), `version.txt`, bash (sửa guard P2). Kiểm thử local: `actionlint` cho workflow, validate JSON, chạy lại test guard (thêm 1 case), tuỳ chọn `release-please ... --dry-run`. **Không đụng code app → không cần `bin/docker rspec`.**

**Nguồn (đọc trước khi thực hiện):**
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — **ADR-003 (Git Flow), ADR-004 (SemVer + rc), ADR-008 (release-please)**, mục Backlog.
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-002 (version/changelog tài liệu).
- `.github/scripts/check-branch-source.sh` + `.github/workflows/ci.yml` (P2, đang sống trên `develop`).
- release-please docs: <https://github.com/googleapis/release-please/blob/main/docs/customizing.md>, <https://github.com/googleapis/release-please-action>.

**Quy ước chung khi thực hiện:**
- Tài liệu/giao diện tiếng Việt; code/commit/pull request title + description tiếng Anh; comment trong workflow + JSON config tiếng Anh (đồng nhất với `ci.yml` sau khi P2 đã chuyển sang tiếng Anh); **tuyệt đối không viết tắt** (ngoại lệ: CRUD, UI; tên chuẩn giữ nguyên: Git Flow, SemVer, CI, ADR, release-please, GitHub Actions). Viết "pull request" thay vì "PR".
- Commit theo Conventional Commits; **kết mỗi commit bằng** `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Vị trí thực thi:** làm trong worktree này, cập nhật về **`develop` mới nhất** (đã có #279 bump puma + #280 fix leo thang quyền), tạo nhánh `feature/p3-release-please`. P3 chỉ là config/docs → **không cần Docker, không cần rspec**.
- **KHÔNG push remote / mở pull request khi chưa được chủ dự án duyệt** — làm xong Task 1–4 (local) rồi DỪNG (Task 5), trình diện; Task 6 (remote) chỉ chạy sau khi được duyệt.
- **Quyết định đặt tên file version:** dùng `version.txt` (release-please `simple` quản sạch, nội dung chỉ là số). Tên `VERSION` sẽ cần annotation `x-release-please-version` nhúng trong file (làm bẩn file, script khó đọc) — nên chọn `version.txt`. Nếu chủ dự án nhất quyết tên `VERSION`, đổi sang dùng `extra-files` generic + annotation (ghi rõ ở Task 1).

---

## File Structure

| File | Trách nhiệm | Thao tác |
|---|---|---|
| `release-please-config.json` | Cấu hình release-please: release-type `simple`, tag tiền tố `v`, mục changelog, gói gốc `.` | **Create** |
| `.release-please-manifest.json` | Mỏ neo version hiện tại (`{".": "1.0.1"}`) để tính bản kế tiếp | **Create** |
| `version.txt` | Số version dạng text (`1.0.1`), release-please tự cập nhật mỗi release | **Create** |
| `.github/workflows/release-please.yml` | Workflow chạy release-please khi push vào `main` (`target-branch: main`) | **Create** |
| `.github/scripts/check-branch-source.sh` | Mở rộng guard: cho phép nhánh `release-please--*` vào `main` | **Modify** |
| `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` | ADR-008 thêm ghi chú triển khai P3; bump 0.3.0 → 0.4.0 + changelog | **Modify** |
| `CONTRIBUTING.md` | Mục 6 (phát hành) + mục 8 (trạng thái tự động hoá): release-please đã cấu hình | **Modify** |

> Plan trong `docs/superpowers/plans/` **không** versioned (ADR-002). P3 là *implementation* của ADR-008 — không tạo spec thiết kế mới; tinh chỉnh nhỏ ghi vào release spec (Task 4).

---

## Task 0: Chuẩn bị nhánh (local, không cần duyệt)

**Files:** không (thao tác git).

- [ ] **Step 1: Cập nhật develop mới nhất + tạo nhánh P3**

```bash
cd /Users/cuong/Desktop/projects/botfi/electric-water-management/.claude/worktrees/nostalgic-pasteur-55e5e1
git fetch origin
git checkout develop
git pull --ff-only origin develop
git checkout -b feature/p3-release-please
git log --oneline -3
```

Expected: nhánh hiện tại là `feature/p3-release-please`, đỉnh là merge #280 (`27abcc8` hoặc mới hơn).

---

## Task 1: Cấu hình release-please (config + manifest + version.txt)

**Files:**
- Create: `release-please-config.json`
- Create: `.release-please-manifest.json`
- Create: `version.txt`

- [ ] **Step 1: Tạo `release-please-config.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-v-in-tag": true,
  "include-component-in-tag": false,
  "packages": {
    ".": {
      "package-name": "electric-water-management"
    }
  },
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance Improvements" },
    { "type": "build", "section": "Dependencies" },
    { "type": "refactor", "section": "Code Refactoring" },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Miscellaneous", "hidden": true },
    { "type": "ci", "section": "Continuous Integration", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "style", "section": "Styles", "hidden": true }
  ]
}
```

- [ ] **Step 2: Tạo `.release-please-manifest.json`** (mỏ neo version đã phát hành)

```json
{
  ".": "1.0.1"
}
```

- [ ] **Step 3: Tạo `version.txt`** (release-please `simple` tự cập nhật file này)

```
1.0.1
```

- [ ] **Step 4: Validate JSON hợp lệ**

```bash
node -e "JSON.parse(require('fs').readFileSync('release-please-config.json','utf8')); JSON.parse(require('fs').readFileSync('.release-please-manifest.json','utf8')); console.log('JSON OK')"
cat version.txt
```

Expected: in `JSON OK` và `1.0.1`.

- [ ] **Step 5: Commit**

```bash
git add release-please-config.json .release-please-manifest.json version.txt
git commit -m "$(cat <<'EOF'
ci: add release-please config, manifest, and version.txt

Manifest-driven release-please (simple release type, v-prefixed tags).
Manifest is anchored at the current released version 1.0.1; version.txt
holds a plain, script-readable version number that release-please updates
on each release. Changelog surfaces feat/fix/perf/build/refactor (ADR-008).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Workflow release-please

**Files:**
- Create: `.github/workflows/release-please.yml`

- [ ] **Step 1: Tạo workflow**

```yaml
name: release-please

# P3 — release automation (ADR-008). Runs on pushes to `main` (final releases
# only; rc/UAT deferred to P4). Maintains a human-gated Release PR that bumps the
# version, updates CHANGELOG.md + version.txt, and on merge tags vX.Y.Z + creates
# the GitHub Release. Uses the default GITHUB_TOKEN (free); the Release PR it opens
# does not re-trigger other workflows — fine, it only edits changelog/version.
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          # Default branch is `develop`; releases live on `main`, so target it explicitly.
          target-branch: main
```

- [ ] **Step 2: Lint YAML bằng actionlint**

```bash
docker run --rm -v "$PWD":/repo --workdir /repo rhysd/actionlint:latest -color && echo "actionlint: CLEAN"
```

Expected: không lỗi, thoát 0. (Không có mạng để kéo image thì bỏ qua + ghi chú; lần chạy thật sẽ phát hiện lỗi YAML.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release-please.yml
git commit -m "$(cat <<'EOF'
ci: add release-please workflow for final releases on main

Runs googleapis/release-please-action@v4 on pushes to main, with
target-branch: main (the repository default branch is develop). Opens a
human-gated Release PR; merging it tags vX.Y.Z and creates the GitHub
Release. rc/UAT handling is deferred to P4 (ADR-008).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Mở rộng branch-source guard cho `release-please--*`

**Files:**
- Modify: `.github/scripts/check-branch-source.sh`

Bối cảnh: Release PR của release-please đi từ nhánh `release-please--branches/main` vào `main`. Guard P2 chỉ cho `release/*`/`hotfix/*` → sẽ chặn nhầm. Thêm `release-please--*` vào danh sách hợp lệ.

- [ ] **Step 1: Sửa khối `case` + thông báo**

Tìm:

```bash
case "$head" in
  release/* | hotfix/*)
    echo "✓ Pull request to main from '$head' — allowed (Git Flow)."
    exit 0
    ;;
  *)
    echo "✗ Pull request to main may only come from release/* or hotfix/* (ADR-003)."
    echo "  Current source: '${head:-<empty>}'."
    echo "  → Retarget to 'develop', or branch from release/* | hotfix/* per Git Flow."
    exit 1
    ;;
esac
```

Thay bằng:

```bash
case "$head" in
  release/* | hotfix/* | release-please--*)
    echo "✓ Pull request to main from '$head' — allowed (Git Flow / release-please)."
    exit 0
    ;;
  *)
    echo "✗ Pull request to main may only come from release/*, hotfix/*, or release-please--* (ADR-003, ADR-008)."
    echo "  Current source: '${head:-<empty>}'."
    echo "  → Retarget to 'develop', or branch from release/* | hotfix/* per Git Flow."
    exit 1
    ;;
esac
```

- [ ] **Step 2: Kiểm tra cú pháp + test 6 trường hợp (thêm case release-please)**

```bash
bash -n .github/scripts/check-branch-source.sh && echo "syntax OK"
run() { BASE_REF="$1" HEAD_REF="$2" bash .github/scripts/check-branch-source.sh >/dev/null 2>&1; echo "base=$1 head=$2 -> exit=$?"; }
run develop feature/x
run main release/1.1
run main hotfix/1.0.2
run main release-please--branches/main
run main feature/favicon
run main develop
```

Expected (đúng từng dòng):

```
base=develop head=feature/x -> exit=0
base=main head=release/1.1 -> exit=0
base=main head=hotfix/1.0.2 -> exit=0
base=main head=release-please--branches/main -> exit=0
base=main head=feature/favicon -> exit=1
base=main head=develop -> exit=1
```

Nếu sai bất kỳ dòng nào → sửa Step 1, chạy lại.

- [ ] **Step 3: Commit**

```bash
git add .github/scripts/check-branch-source.sh
git commit -m "$(cat <<'EOF'
ci: allow release-please-- branches as a valid main source in guard

release-please opens its Release PR from release-please--branches/main into
main; the branch-source guard must permit it (alongside release/* and
hotfix/*) or it would falsely fail the Release PR. Verified against six
base/head cases.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Tài liệu (release spec ADR-008 + bump 0.4.0; CONTRIBUTING)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Bump version release spec** — đổi `version: 0.3.0` → `version: 0.4.0`.

- [ ] **Step 2: Thêm ghi chú triển khai vào ADR-008**

Trong `### ADR-008: Release automation — release-please`, thêm bullet này NGAY TRƯỚC dòng `- **Điều kiện xem lại:**`:

```markdown
- **Triển khai (P3, chốt 2026-06-07):** release-please chạy trên `main` lo **bản phát hành chính thức** — release-type `simple`, tag tiền tố `v`, cập nhật `CHANGELOG.md` + `version.txt`, manifest mỏ neo `1.0.1`; đặt `target-branch: main` vì default branch là `develop`. Phần **rc/UAT để dành P4** (chưa có môi trường Nghiệm thu để deploy). Mở rộng branch-source guard cho phép nhánh `release-please--*` vào `main` (Release PR do bot tạo). release-please ghi `CHANGELOG.md`/`version.txt` lên `main` → sau mỗi release phải **đồng bộ `main` → `develop`** (gộp vào merge-back). Dùng `GITHUB_TOKEN` mặc định (miễn phí) — Release PR do bot tạo không tự kích hoạt CI, chấp nhận được vì chỉ sửa changelog/version.
```

- [ ] **Step 3: Thêm entry changelog release spec**

Trong `## Changelog`, thêm dòng đầu (trên `- **0.3.0 ...`):

```markdown
- **0.4.0 (2026-06-07):** ADR-008 thêm ghi chú triển khai P3: release-please trên `main` (final releases, `simple`, `version.txt`, manifest 1.0.1, `target-branch: main`); guard cho phép `release-please--*`; đồng bộ main→develop sau release; rc để dành P4.
```

- [ ] **Step 4: Commit release spec**

```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
git commit -m "$(cat <<'EOF'
docs(sdlc): record P3 release-please rollout in release spec

ADR-008: add an implementation note (release-please on main for final
releases, simple type + version.txt, target-branch main, guard allowance
for release-please-- branches, main->develop sync after release; rc
deferred to P4). Bump 0.3.0 -> 0.4.0 with changelog entry (ADR-002).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Cập nhật CONTRIBUTING mục 6 (phát hành)**

Tìm:

```markdown
Tóm tắt: đủ nội dung → `release/*` → deploy Nghiệm thu (`-rc.N`) → khách nghiệm thu → release-please tạo Release pull request → merge `main` + tag `X.Y.Z` → giao bản xuống production Mini PC + cập nhật môi trường Mốc → **merge-back về `develop`**.
```

Thay bằng:

```markdown
Tóm tắt: đủ nội dung → `release/*` → deploy Nghiệm thu (`-rc.N`) → khách nghiệm thu → release-please tạo Release pull request → merge `main` + tag `X.Y.Z` → giao bản xuống production Mini PC + cập nhật môi trường Mốc → **merge-back về `develop`**.

release-please đã được cấu hình (P3): khi `release/*`/`hotfix/*` vào `main`, nó tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`); bạn merge Release pull request → tự tag `vX.Y.Z` + tạo GitHub Release. **Lưu ý:** release-please ghi `CHANGELOG.md`/`version.txt` lên `main`, nên khi merge-back nhớ **đồng bộ `main` → `develop`** để develop có các file đó. Ghi chú phát hành cho khách: biên tập tiếng Việt trên GitHub Release trước khi công bố.
```

- [ ] **Step 6: Cập nhật CONTRIBUTING mục 8 (trạng thái tự động hoá)**

Tìm:

```markdown
**Còn ở các giai đoạn sau:** chạy test trên CI (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng tinh chỉnh runner/cache/headless là **mảnh "CI spec chi tiết"** (Backlog #1 trong release spec); release-please (P3); môi trường Railway Nghiệm thu + Mốc (P4). Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.
```

Thay bằng:

```markdown
**release-please đã cấu hình (P3):** workflow `release-please` chạy trên `main` tự mở Release pull request (bump version + `CHANGELOG.md` + `version.txt`), merge thì tự tag + tạo GitHub Release. Phần **rc/UAT để dành P4**.

**Còn ở các giai đoạn sau:** chạy test trên CI (`rspec` gồm system spec, kiểm schema không lệch, `rails zeitwerk:check`) cùng tinh chỉnh runner/cache/headless là **mảnh "CI spec chi tiết"** (Backlog #1 trong release spec); môi trường Railway Nghiệm thu + Mốc + bản rc (P4). Các quy ước ở mục 2–3 ngoài phần CI ép được vẫn giữ bằng kỷ luật + review thủ công.
```

- [ ] **Step 7: Commit CONTRIBUTING**

```bash
git add CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
docs(contributing): note release-please configured after P3

Section 6 + 8: release-please now opens a Release pull request on main
(version + CHANGELOG + version.txt); remember to sync main -> develop on
merge-back. rc/UAT remains in P4.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: DỪNG — trình diện thay đổi local cho chủ dự án

**Files:** không.

- [ ] **Step 1: Tổng hợp + chờ duyệt**

```bash
git log --oneline develop..HEAD
git diff --stat develop..HEAD
```

Liệt kê file đã tạo/sửa + kết quả actionlint + test guard 6 case. **Chờ chủ dự án duyệt** trước khi sang Task 6 (mọi thao tác remote). Nhắc lại quyết định `version.txt` thay cho `VERSION` để chủ dự án xác nhận.

---

## Task 6: Đẩy remote + pull request vào develop (CHỈ sau khi được duyệt)

**Files:** không (git/GitHub). Repo: `manhcuongdtbk/electric-water-management`.

- [ ] **Step 1: Push nhánh P3**

```bash
git push -u origin feature/p3-release-please 2>&1 | tail -3
```

- [ ] **Step 2: (Tuỳ chọn) Dry-run release-please để xem nó đề xuất gì**

```bash
GITHUB_TOKEN="$(gh auth token)" npx --yes release-please release-pr \
  --dry-run \
  --repo-url=https://github.com/manhcuongdtbk/electric-water-management \
  --target-branch=feature/p3-release-please \
  --config-file=release-please-config.json \
  --manifest-file=.release-please-manifest.json 2>&1 | tail -30
```

Expected: release-please đọc config từ nhánh vừa push, đề xuất **1.0.2** (do có `fix(users)` trên develop) và changelog có mục Bug Fixes (fix leo thang quyền) + Dependencies (bump puma). Nếu nó đề xuất version lạ hoặc gộp commit cũ hơn `v1.0.1` → đặt thêm `"bootstrap-sha"` = commit của tag `v1.0.1` (`git rev-list -n 1 v1.0.1`) trong `release-please-config.json` rồi chạy lại. Nếu `version.txt` không nằm trong danh sách file release-please sẽ cập nhật → xem lại release-type `simple` (mục updater), hoặc thêm `version.txt` vào `extra-files` với annotation. Bỏ qua bước này nếu không có mạng/token; lần release thật vẫn xác thực.

- [ ] **Step 3: Mở pull request vào `develop`**

```bash
gh pr create \
  --base develop \
  --head feature/p3-release-please \
  --title "ci: configure release-please for final releases on main (P3)" \
  --body "$(cat <<'EOF'
## P3 — release-please for final releases

Implements ADR-008. release-please runs on `main` and maintains a
human-gated Release PR that bumps the version, updates `CHANGELOG.md` +
`version.txt`, and on merge tags `vX.Y.Z` + creates the GitHub Release.

### What this adds
- `release-please-config.json` + `.release-please-manifest.json` (anchored
  at 1.0.1) + `version.txt` (plain version, release-please-managed).
- `.github/workflows/release-please.yml` — runs on push to main, with
  `target-branch: main` (the repo default branch is `develop`).
- branch-source guard extended to allow `release-please--*` into `main`.
- Release spec (ADR-008 rollout note, bump 0.4.0) + CONTRIBUTING updated.

### Notes
- The version file is `version.txt` (release-please `simple` manages it
  cleanly) rather than `VERSION` (which would need an in-file annotation).
- rc/UAT handling is deferred to P4 (no Nghiệm thu environment yet).
- release-please only activates once these files reach `main` via the first
  `release/*` → `main` merge (that same push triggers it). First proposed
  release will be `1.0.2` (from the merged `fix(users)` security fix).
- The Release PR uses the default GITHUB_TOKEN, so it won't re-trigger CI;
  that's fine (it only edits changelog/version).

### Test plan
- [x] JSON config valid; actionlint clean on the workflow
- [x] branch-source guard verified against six base/head cases (incl. release-please--)
- [ ] static CI green on this pull request
EOF
)"
```

- [ ] **Step 4: Xác nhận CI xanh trên pull request**

```bash
gh pr checks --watch --interval 20
```

Expected: 3 job P2 (`Ruby static checks`, `Conventional Commits`, `Branch-source guard`) đều `pass`. (release-please workflow KHÔNG chạy ở đây vì nó chỉ trigger trên push vào `main`.) Đỏ thì đọc log, sửa, đẩy lại. Đánh dấu `[x]` dòng cuối Test plan.

- [ ] **Step 5: DỪNG — chờ chủ dự án review + merge**

Không tự merge. Sau khi chủ dự án merge `feature/p3-release-please` vào `develop`, P3 hoàn tất. release-please chỉ thực sự hoạt động khi các file này lên `main` qua lần `release/*` → `main` đầu tiên.

---

## Self-Review (đã rà)

**1. Spec coverage:**
- ADR-008 (release-please, Release PR có cổng người duyệt, target main) → Task 1 (config/manifest/version.txt) + Task 2 (workflow `target-branch: main`). ✓
- ADR-004 (SemVer + tag `v`) → `include-v-in-tag: true`, manifest 1.0.1. rc để dành P4 (ghi rõ ADR-008 note + CONTRIBUTING). ✓
- ADR-003 (Git Flow) tương thích guard → Task 3 (cho phép `release-please--*`). ✓
- ADR-002 (version/changelog tài liệu) → release spec bump 0.4.0 + changelog (Task 4). ✓
- Quyết định brainstorm: final-on-main + rc defer (Task 2 + docs); file version (`version.txt`, có ghi chú đổi tên — Task 1 + Task 5); đồng bộ main→develop (CONTRIBUTING + ADR-008 note). ✓

**2. Placeholder scan:** Dry-run (Task 6 Step 2) là tuỳ chọn, kèm tiêu chí kỳ vọng + fallback cụ thể (`bootstrap-sha`, `extra-files`), không phải placeholder. Không còn TODO/TBD.

**3. Nhất quán:** tên file (`release-please-config.json`, `.release-please-manifest.json`, `version.txt`), `target-branch: main`, action `googleapis/release-please-action@v4`, nhánh `feature/p3-release-please`, base `develop` khớp giữa các task. Guard giữ đúng định dạng `case` POSIX đã có ở P2.
