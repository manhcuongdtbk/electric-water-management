# Vận hành & bảo trì (SDLC Backlog #3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện thực mảnh #3 của SDLC — quy trình vận hành/bảo trì — bằng cách thêm 1 template Issue báo lỗi, 2 anchor truy vết, một mục CONTRIBUTING, một pointer AGENTS, và đánh dấu Backlog #3 ✅; **không** thay đổi code/test.

**Architecture:** Đặt *lớp quy trình* lên trên các tính năng đã có (sao lưu 3 lớp, nhật ký §20, `/up`+`/version`, Docker) và **mở rộng** luồng thay đổi Hybrid của Mảnh #2 cho lỗi/sự cố. Mọi quyết định đã chốt trong spec `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` (ADR-016..018).

**Tech Stack:** Markdown (tài liệu `docs/` có version + changelog; file meta gốc repo không version — ADR-002), GitHub Issue template (front matter YAML), Git Flow. **Không có code ứng dụng, không có test tự động** trong mảnh này → "verify" = kiểm tra nhất quán bằng `grep` + xác nhận 0 thay đổi code.

---

## Lưu ý chung trước khi thực thi

- **Ngôn ngữ:** tài liệu + template tiếng Việt 100%; commit message + pull request tiếng Anh (Conventional Commits); không viết tắt (trừ CRUD/UI/CI/ADR).
- **Quy ước version:** file `docs/` sửa → bump version + thêm changelog entry **trong cùng commit** (ADR-002). File meta gốc (`AGENTS.md`, `CONTRIBUTING.md`) **không** bump.
- **Đã làm xong trước plan này:** spec `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` đã viết + commit (commit `3013cfe`).
- **Nhánh:** đang ở nhánh worktree (đã fast-forward tới `origin/develop`); pull request đích `develop`. **Không push/merge khi chưa có duyệt của chủ dự án.**
- **File *hot*:** `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` hiện ở **0.9.0** — Task 7 kiểm lại `origin/develop` ngay trước khi tạo pull request và renumber nếu nó đã nhích.

## File Structure

| File | Tạo/Sửa | Trách nhiệm |
|---|---|---|
| `.github/ISSUE_TEMPLATE/bug-report.md` | **Tạo** | Form intake lỗi/sự cố (ADR-018) — hoàn thành phần ADR-015 hoãn. |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Sửa | Thêm 2 anchor `NV-...` (§20, §21) + bump 2.13.0→2.14.0 (ADR-014). |
| `CONTRIBUTING.md` | Sửa | Thêm mục 10 "Vận hành & xử lý sự cố" cho người (meta — không bump). |
| `AGENTS.md` | Sửa | Thêm pointer tới spec #3 (meta — không bump). |
| `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` | Sửa | Backlog #3 → ✅ + bump 0.9.0→0.10.0 + changelog. |
| `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` | Sửa | Mục "Truy vết" Sẽ→Đã hiện thực + bump 0.1.0→0.2.0. |

---

### Task 1: Template Issue báo lỗi / sự cố

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug-report.md`

- [ ] **Step 1: Tạo file template**

Tạo `.github/ISSUE_TEMPLATE/bug-report.md` với đúng nội dung sau (mirror format của `change-request.md`; front matter auto-apply nhãn `bug`):

```markdown
---
name: Báo lỗi / sự cố (bug report)
about: Lỗi hoặc sự cố của hệ thống đã triển khai (gồm lỗi production). Yêu cầu/tính năng mới → dùng template Yêu cầu thay đổi.
title: ""
labels: bug
---

## Người báo
<!-- Khách (đơn vị nào) hay nội bộ? Khách không có GitHub → đội mở Issue thay khách. -->

## Môi trường
<!-- Production (Mini PC) / Acceptance / Development. -->

## Bản đang chạy
<!-- Lấy ở /version (hoặc sidebar). Ví dụ: 1.2.0. -->

## Bước tái hiện
<!-- 1. ... 2. ... 3. ... Càng cụ thể càng dễ vá. -->

## Kết quả mong đợi và thực tế
<!-- Mong đợi: ... | Thực tế: ... -->

## Mức độ
<!-- Nghiêm trọng (prod không dùng được / sai số tiền / mất hoặc nguy cơ mất dữ liệu → đường hotfix, gắn thêm nhãn severity-critical) HOẶC Thường (vẫn dùng được → luồng phát triển bình thường). -->

## Có đụng dữ liệu hay tiền không?
<!-- Có / Không. Nếu có: mô tả ảnh hưởng (số liệu sai, bản ghi mất...). -->

## Trích nhật ký hệ thống (mục 20) nếu có
<!-- Dán mục liên quan từ trang Nhật ký (audit log). Không dán dữ liệu nhạy cảm thừa. -->

## Ghi chú truy vết
<!-- Điền dần: nhánh hotfix/feature, pull request (Refs #N), spec/anchor NV-... nếu đụng nghiệp vụ, version vá. -->
```

- [ ] **Step 2: Verify front matter hợp lệ + đủ trường ADR-018**

Run: `head -6 .github/ISSUE_TEMPLATE/bug-report.md && grep -c "^## " .github/ISSUE_TEMPLATE/bug-report.md`
Expected: front matter có `name`/`about`/`labels: bug`; số mục `## ` = **9** (Người báo, Môi trường, Bản đang chạy, Bước tái hiện, Kết quả, Mức độ, Đụng dữ liệu/tiền, Trích nhật ký, Ghi chú truy vết).

- [ ] **Step 3: Commit**

```bash
git add .github/ISSUE_TEMPLATE/bug-report.md
git commit -m "feat(ops): add bug/incident Issue template (ADR-018)

Completes the bug-report template deferred from ADR-015 to Backlog #3.
Front matter auto-applies the bug label; triager adds severity-critical
for the hotfix path.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Anchor truy vết §20/§21 + bump tài liệu nghiệp vụ

**Files:**
- Modify: `docs/V2_XAC_NHAN_NGHIEP_VU.md` (header version; heading §20; heading §21; mục 29 Lịch sử thay đổi)

- [ ] **Step 1: Thêm anchor trước heading §20**

Tìm khối (quanh dòng 620-622):

```markdown
---

## 20. Nhật ký hệ thống
```

Thay bằng:

```markdown
---

<a id="NV-nhat-ky-he-thong"></a>
## 20. Nhật ký hệ thống
```

- [ ] **Step 2: Thêm anchor trước heading §21**

Tìm khối (quanh dòng 627-629):

```markdown
---

## 21. Sao lưu và phục hồi
```

Thay bằng:

```markdown
---

<a id="NV-sao-luu-phuc-hoi"></a>
## 21. Sao lưu và phục hồi
```

- [ ] **Step 3: Bump version trong header**

Tìm: `> **Phiên bản:** 2.13.0`
Thay: `> **Phiên bản:** 2.14.0`

- [ ] **Step 4: Thêm entry changelog (đầu mục 29)**

Tìm dòng `## 29. Lịch sử thay đổi` rồi chèn entry mới NGAY TRƯỚC `### v2.13.0 (24/05/2026)`:

```markdown
### v2.14.0 (09/06/2026)

- Nhật ký hệ thống (mục 20) và Sao lưu và phục hồi (mục 21): thêm anchor truy vết `NV-nhat-ky-he-thong` / `NV-sao-luu-phuc-hoi` (ADR-014) để spec vận hành & bảo trì (ADR-016..018) link tới. Không đổi nội dung nghiệp vụ.
```

- [ ] **Step 5: Verify anchor + version**

Run: `grep -n 'NV-nhat-ky-he-thong\|NV-sao-luu-phuc-hoi\|Phiên bản:\|v2.14.0' docs/V2_XAC_NHAN_NGHIEP_VU.md`
Expected: thấy 2 anchor đúng vị trí (trước §20/§21), `Phiên bản: 2.14.0`, entry `v2.14.0`.

- [ ] **Step 6: Commit**

```bash
git add docs/V2_XAC_NHAN_NGHIEP_VU.md
git commit -m "docs(business): add traceability anchors for system log and backup (ADR-014)

Lazy-add NV-nhat-ky-he-thong (section 20) and NV-sao-luu-phuc-hoi
(section 21) so the operations & maintenance spec can link to them.
Content unchanged; bump 2.13.0 -> 2.14.0 per ADR-002.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Mục 10 CONTRIBUTING — Vận hành & xử lý sự cố

**Files:**
- Modify: `CONTRIBUTING.md` (chèn mục 10 giữa cuối mục 9 và `## Tài liệu liên quan`)

- [ ] **Step 1: Chèn mục 10**

Tìm dòng kết mục 9 + heading kế:

```markdown
> Lỗi production + tiếp nhận/ưu tiên backlog **không** thuộc mục này (Backlog #3, #4 của release spec).

## Tài liệu liên quan
```

Thay bằng (chèn mục 10 vào giữa):

```markdown
> Tiếp nhận/ưu tiên backlog **không** thuộc mục này (Backlog #4). Lỗi/sự cố production xem mục 10.

## 10. Vận hành & xử lý sự cố

Theo ADR-016..018 (chi tiết + lý do: `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md`). Đặt *quy trình* lên trên tính năng đã có (sao lưu 3 lớp, nhật ký mục 20, `/up` + `/version`, Docker); how-to thao tác xem `docs/HUONG_DAN_DEPLOY.md` + `docs/KIEN_THUC_DOCKER.md` mục 10.

### Giám sát Mini PC offline (ADR-016)

Không có nhịp định kỳ. Giám sát = **review khi giao phiên bản** + lưới auto-backup nền + tra nhật ký mục 20 theo yêu cầu. Checklist khi giao bản (tại hộp):

- [ ] 3 container `Up` (`docker compose ps`).
- [ ] `/up` xanh; `/version` đúng bản vừa giao.
- [ ] Đĩa còn chỗ (`df -h`, `docker system df`).
- [ ] Cron auto-backup (ổ phụ) có file/log mới.

### Sao lưu & khôi phục (ADR-017)

- **Lớp 3 (auto, ổ phụ, 7 bản) = nguồn cậy chính, bắt buộc.** Lớp 1 (giao diện, 3 bản) = snapshot trước thao tác nguy hiểm. How-to: deploy guide mục Sao lưu.
- **Diễn tập khôi phục mỗi lần giao bản, phía dev/nghiệm thu:** chạy `backups:restore` với một backup sinh ở đó để chứng minh cơ chế của đúng version chạy được. Không diễn tập trên prod; không mang file backup prod ra ngoài.
- **Trên prod:** chỉ khôi phục thật khi sự cố; **luôn tạo backup Lớp 1 trước khi restore**.

### Tiếp nhận lỗi/sự cố (ADR-018)

Lỗi/sự cố là một "thay đổi" — dùng luồng 6 bước mục 9, chỉ khác template + đường vá:

1. **Tiếp nhận** — mở Issue bằng template *Báo lỗi / sự cố* (`.github/ISSUE_TEMPLATE/bug-report.md`); khách báo qua kênh ngoài thì đội mở thay. Nhãn `bug`.
2. **Phân loại mức độ → đường vá:**
   - **Nghiêm trọng** (prod không dùng được / sai số tiền / mất hoặc nguy cơ mất dữ liệu) → gắn thêm nhãn `severity-critical`; vá theo `hotfix/*` ← `main` (mục 2); cân nhắc **rollback tag trước** trên Mini PC làm bước chữa cháy tức thì.
   - **Thường** (vẫn dùng được) → luồng `feature/*` → `develop` → `release/*`, gồn vào bản sau.
3. **Vá + test** — pull request `Refs #N`, test cover lỗi.
4. **Phát hành + giao** — tag (release-please); giao Mini PC + fast-forward `production`.
5. **Đóng + báo khách** — `Closes #N`; báo khách kèm release notes tiếng Việt.

> Nhãn `severity-critical` tạo một lần khi lần đầu cần (production hiện đang hoãn): `gh label create severity-critical --color B60205 --description "Lỗi nghiêm trọng - đường hotfix"`.

## Tài liệu liên quan
```

- [ ] **Step 2: Verify**

Run: `grep -n '## 10. Vận hành\|severity-critical\|backups:restore\|## Tài liệu liên quan' CONTRIBUTING.md`
Expected: mục 10 xuất hiện TRƯỚC `## Tài liệu liên quan`; có nhắc `severity-critical` + `backups:restore`.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: add operations & incident handling guide (section 10, ADR-016..018)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Pointer trong AGENTS.md

**Files:**
- Modify: `AGENTS.md` (mục "Quy trình phát triển và phát hành (trỏ tới spec)", sau bullet Truy vết #2)

- [ ] **Step 1: Thêm bullet pointer**

Tìm bullet của Mảnh #2 (kết thúc bằng `... (ADR-013..015) + CONTRIBUTING.md mục 9.`) và thêm NGAY SAU nó:

```markdown
- **Vận hành & bảo trì** (giám sát Mini PC offline, chính sách sao lưu/khôi phục, tiếp nhận lỗi/sự cố khách): `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` (ADR-016..018) + `CONTRIBUTING.md` mục 10.
```

- [ ] **Step 2: Verify**

Run: `grep -n '2026-06-09-van-hanh-bao-tri-design\|ADR-016..018' AGENTS.md`
Expected: 1 dòng pointer mới.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: point AGENTS to operations & maintenance spec (ADR-016..018)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Đánh dấu Backlog #3 ✅ + bump release spec

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (Backlog mục 3; header version; Changelog)

> **Trước khi sửa:** chạy `git fetch origin develop` rồi `git log origin/develop --oneline -5` — nếu file này đã nhích trên develop (version > 0.9.0), xem Task 7 để renumber lên trên. Mặc định plan này: 0.9.0 → **0.10.0**.

- [ ] **Step 1: Đổi Backlog mục 3 thành ✅**

Tìm: `3. Vận hành / bảo trì (giám sát production offline, backup, tiếp nhận lỗi khách).`
Thay bằng:

```markdown
3. **✅ Đã hiện thực** (ADR-016..018, [`2026-06-09-van-hanh-bao-tri-design.md`](2026-06-09-van-hanh-bao-tri-design.md)): vận hành / bảo trì — giám sát Mini PC offline (review khi giao bản, không nhịp định kỳ; nhật ký mục 20 tra theo yêu cầu); chính sách sao lưu/khôi phục trên tính năng 3 lớp đã có (Lớp 3 off-box bắt buộc; diễn tập khôi phục mỗi bản giao phía dev); tiếp nhận lỗi/sự cố mở rộng luồng Hybrid #2 — template bug-report (`.github/ISSUE_TEMPLATE/bug-report.md`) + mức độ 2 bậc → đường vá + nhãn `severity-critical`; mục 10 `CONTRIBUTING.md` + pointer `AGENTS.md`.
```

- [ ] **Step 2: Bump version header**

Tìm: `version: 0.9.0`
Thay: `version: 0.10.0`

- [ ] **Step 3: Thêm changelog entry (đầu mục `## Changelog`)**

Chèn NGAY TRƯỚC dòng `- **0.9.0 (2026-06-08):**`:

```markdown
- **0.10.0 (2026-06-09):** Backlog #3 ("Vận hành / bảo trì") **thiết kế + hiện thực xong** — spec mới [`2026-06-09-van-hanh-bao-tri-design.md`](2026-06-09-van-hanh-bao-tri-design.md) (ADR-016 giám sát offline; ADR-017 chính sách sao lưu/khôi phục; ADR-018 tiếp nhận lỗi/sự cố mở rộng #2); template `.github/ISSUE_TEMPLATE/bug-report.md` + nhãn `severity-critical`; anchor `NV-nhat-ky-he-thong`/`NV-sao-luu-phuc-hoi` trong tài liệu nghiệp vụ; mục 10 `CONTRIBUTING.md` + pointer `AGENTS.md`; Backlog #3 → ✅.
```

- [ ] **Step 4: Verify**

Run: `grep -n 'version: 0.10.0\|✅ Đã hiện thực.*2026-06-09\|0.10.0 (2026-06-09)' docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`
Expected: 3 khớp (header version, Backlog #3 ✅, changelog entry).

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
git commit -m "docs(sdlc): mark Backlog #3 done in release spec (0.10.0)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Cập nhật spec #3 sang trạng thái đã hiện thực

**Files:**
- Modify: `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` (mục Truy vết; header version; Changelog)

> Mirror đúng pattern Mảnh #2 (spec đó bump 0.1.0→0.2.0 khi hiện thực xong).

- [ ] **Step 1: Đổi dòng "Sẽ hiện thực" thành "Đã hiện thực"**

Tìm trong mục `## Truy vết` dòng bắt đầu `- **Sẽ hiện thực** (xem plan ...`. Thay bằng:

```markdown
- **Đã hiện thực** (plan [`2026-06-09-van-hanh-bao-tri.md`](../plans/2026-06-09-van-hanh-bao-tri.md)): `.github/ISSUE_TEMPLATE/bug-report.md` + nhãn `severity-critical`; anchor `NV-nhat-ky-he-thong`/`NV-sao-luu-phuc-hoi` trong `docs/V2_XAC_NHAN_NGHIEP_VU.md`; mục 10 "Vận hành & xử lý sự cố" trong `CONTRIBUTING.md`; pointer trong `AGENTS.md`; Backlog #3 trong release spec → ✅.
```

- [ ] **Step 2: Bump version header**

Tìm: `version: 0.1.0`
Thay: `version: 0.2.0`

- [ ] **Step 3: Thêm changelog entry (đầu mục `## Changelog`)**

Chèn NGAY TRƯỚC dòng `- **0.1.0 (2026-06-09):**`:

```markdown
- **0.2.0 (2026-06-09):** Hiện thực xong (xem plan `2026-06-09-van-hanh-bao-tri.md`): template `bug-report` + nhãn `severity-critical`; anchor `NV-nhat-ky-he-thong`/`NV-sao-luu-phuc-hoi`; mục 10 `CONTRIBUTING.md`; pointer `AGENTS.md`; Backlog #3 → ✅. Cập nhật mục "Truy vết" sang trạng thái đã hiện thực.
```

- [ ] **Step 4: Verify**

Run: `grep -n 'version: 0.2.0\|Đã hiện thực\|0.2.0 (2026-06-09)' docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md`
Expected: 3 khớp.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md
git commit -m "docs(sdlc): mark operations & maintenance spec implemented (0.2.0)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Kiểm tra nhất quán toàn cục + chuẩn bị pull request

**Files:** (không sửa file mới — chỉ kiểm tra + có thể merge develop)

- [ ] **Step 1: Truy vết hai chiều resolve được**

Run: `grep -rn 'NV-nhat-ky-he-thong\|NV-sao-luu-phuc-hoi' docs/`
Expected: mỗi anchor xuất hiện (a) đúng 1 lần định nghĩa `<a id=...>` trong `V2_XAC_NHAN_NGHIEP_VU.md`, và (b) ít nhất 1 lần tham chiếu trong spec #3 → chiều xuôi grep được.

- [ ] **Step 2: Xác nhận 0 thay đổi code/test**

Run: `git diff --stat $(git merge-base HEAD origin/develop)..HEAD -- 'app/' 'lib/' 'spec/' 'config/' 'db/'`
Expected: **trống** (mảnh này không đụng code/test/migration).

- [ ] **Step 3: Toàn bộ file đã commit, không sót**

Run: `git status --porcelain`
Expected: trống. Và `git log --oneline origin/develop..HEAD` liệt kê đủ các commit Task 1–6 + spec ban đầu.

- [ ] **Step 4: Kiểm va chạm file *hot* trước khi tạo pull request**

```bash
git fetch origin develop
git log --oneline HEAD..origin/develop          # develop có nhích sau khi cắt nhánh không?
gh pr list --state merged --limit 10             # pull request nào vừa merge?
```

- Nếu `HEAD..origin/develop` **trống** → bỏ qua Step 5.
- Nếu develop đã nhích **và** chạm `2026-06-07-quy-trinh-release-design.md` (version > 0.9.0) hoặc `V2_XAC_NHAN_NGHIEP_VU.md` (version > 2.13.0) → làm Step 5.

- [ ] **Step 5: (Chỉ khi có va chạm) Merge develop + renumber lên trên**

```bash
git merge origin/develop        # giải quyết xung đột nếu có
```

- Trong cả hai file hot, **giữ nguyên entry của họ**, đổi version của ta thành số NGAY TRÊN số mới nhất của họ (release spec: nếu họ lên 0.10.0 thì ta thành 0.11.0; business doc: nếu họ lên 2.14.0 thì ta thành 2.15.0), và đặt changelog entry của ta lên đầu. Sửa cả header `version:` lẫn dòng changelog cho khớp.
- Commit merge: `git commit` (message mặc định của merge — sẽ bị squash khi merge pull request).

- [ ] **Step 6: Trình chủ dự án DUYỆT trước khi push**

Tóm tắt cho chủ dự án: `git log --oneline origin/develop..HEAD` + `git diff --stat origin/develop..HEAD`. **KHÔNG `git push` / tạo pull request khi chưa được duyệt** (quy ước dự án + git workflow).

- [ ] **Step 7: (Sau khi duyệt) Push + tạo pull request**

```bash
git push -u origin HEAD
gh pr create --base develop --title "docs(sdlc): operations & maintenance process (Backlog #3, ADR-016..018)" --body "<điền theo pull_request_template.md: Refs spec #3; checklist truy vết>"
```

Trong mô tả pull request, đảm bảo checklist của `pull_request_template.md` được điền: spec "Truy vết" đã cập nhật (anchor `NV-...`), tài liệu `docs/` sửa đã bump version + changelog (V2 2.14.0, release spec 0.10.0, spec #3 0.2.0).

---

## Self-Review (đã chạy khi viết plan)

**1. Spec coverage:** ADR-016 → Task 3 (checklist giám sát) + spec sẵn có. ADR-017 → Task 3 (chính sách backup/restore). ADR-018 → Task 1 (template) + Task 3 (luồng intake) + nhãn `severity-critical` (Task 3 note). Anchor §20/§21 (ADR-014, yêu cầu task) → Task 2. Backlog #3 ✅ + bump release spec → Task 5. AGENTS pointer → Task 4. Spec → đã hiện thực + bump → Task 6. Kiểm tra + pull request → Task 7. **Không có yêu cầu spec nào thiếu task.**

**2. Placeholder scan:** không có TBD/TODO; mọi nội dung file là text hoàn chỉnh copy được. (Mục `<điền theo pull_request_template.md>` ở Task 7 Step 7 là nội dung do chủ dự án/CI duyệt tại thời điểm tạo pull request, không phải code.)

**3. Type/tên nhất quán:** nhãn `severity-critical` (kebab) dùng đồng nhất ở Task 1 note + Task 3 + Task 5/6 changelog. Anchor `NV-nhat-ky-he-thong`/`NV-sao-luu-phuc-hoi` đồng nhất giữa Task 2 (định nghĩa) và spec (tham chiếu). Version: V2 2.14.0, release spec 0.10.0, spec #3 0.2.0 — nhất quán giữa các task.
