# Truy vết & quản lý thay đổi — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện thực các artifact + tài liệu mà spec truy vết/quản lý thay đổi (ADR-013..015) định nghĩa, để luồng yêu cầu → thiết kế → test → release truy được và lặp lại được.

**Architecture:** Thuần **tài liệu + cấu hình GitHub** — KHÔNG đụng code Rails (`app/`, `spec/`). Thêm 1 template pull request + 1 template Issue change-request + 1 template ADR; thêm mục "Quản lý thay đổi & truy vết" vào `CONTRIBUTING.md`; thêm pointer ngắn ở `AGENTS.md`; chốt Backlog #2 trong release spec. Vì không có code/test thay đổi (đúng ADR-014: 0 churn test), "kiểm thử" ở đây là **parse frontmatter + kiểm link + kiểm whitespace**, không phải RSpec.

**Tech Stack:** Markdown; GitHub Issue/pull request templates (`.github/`); quy ước ADR (Conventional Commits, Git Flow đã có).

**Nguồn sự thật (đọc trước):** `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md` (ADR-013/014/015). Quy ước chung: `AGENTS.md`.

---

## File Structure

| File | Trách nhiệm | Tạo/Sửa |
|---|---|---|
| `.github/pull_request_template.md` | Checklist tự nhắc giữ chuỗi truy vết (Refs #N, Truy vết, test, doc version) | Tạo |
| `.github/ISSUE_TEMPLATE/change-request.md` | Form intake một thay đổi/yêu cầu | Tạo |
| `docs/superpowers/ADR-TEMPLATE.md` | Khung 7 mục của một ADR (dán vào spec) | Tạo |
| `CONTRIBUTING.md` | Mục 9 "Quản lý thay đổi & truy vết" + pointer ở mục 4 | Sửa |
| `AGENTS.md` | 1 bullet pointer tới spec + CONTRIBUTING mục 9 | Sửa |
| `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` | Backlog #2 → ✅ đã hiện thực; bump version | Sửa |
| `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md` | "Sẽ hiện thực" → "đã hiện thực"; bump version | Sửa |

**Quy ước version/changelog (ADR-002) — QUAN TRỌNG, đừng làm sai:**
- File **meta ở gốc repo** (`AGENTS.md`, `CONTRIBUTING.md`, `README.md`, `CLAUDE.md`) **KHÔNG** có version/changelog — **đừng** thêm. Theo dõi qua git history.
- File trong **`docs/`** (gồm 2 spec ở Task 6) **CÓ** version + changelog → sửa thì **bump + thêm entry trong cùng commit**.
- File `.github/*` và `docs/superpowers/ADR-TEMPLATE.md` mới tạo: không cần version riêng.

---

## Task 1: Template pull request (checklist truy vết)

**Files:**
- Create: `.github/pull_request_template.md`

Nội dung tiếng Anh (vì `AGENTS.md`: mô tả pull request bằng tiếng Anh). Checklist dùng mục điều kiện ("If …") để áp được cho cả pull request release/doc-only.

- [ ] **Step 1: Tạo file với đúng nội dung dưới**

```markdown
## Summary

<!-- What does this change do, and why? -->

## Linked change

<!-- Required for feature/fix work: the GitHub Issue this implements. -->
Refs #

## Traceability checklist

- [ ] Links its change Issue (`Refs #N`, or `Closes #N` if it fully resolves it). *(feature/fix work)*
- [ ] If a business requirement is affected: `docs/V2_XAC_NHAN_NGHIEP_VU.md` is updated and the requirement has a stable anchor `<a id="NV-..."></a>`.
- [ ] The design spec's `## Truy vết` section links the requirement (`NV-...`) and the covering test(s).
- [ ] Tests cover the changed behaviour (`bin/docker rspec`).
- [ ] If any `docs/` document changed: its version and changelog were bumped in this pull request (ADR-002). Root meta files (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`) are NOT versioned.
- [ ] Conventional Commits used; merge method matches CONTRIBUTING §2 (squash for `feature`/`fix`; non-changelog title prefix for `release`/`hotfix`/merge-back).
```

- [ ] **Step 2: Kiểm whitespace + file tồn tại**

Run: `git add .github/pull_request_template.md && git diff --cached --check && test -f .github/pull_request_template.md && echo OK`
Expected: in `OK`, không có cảnh báo whitespace.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(github): add pull request template with traceability checklist"
```

---

## Task 2: Template Issue change-request (form intake)

**Files:**
- Create: `.github/ISSUE_TEMPLATE/change-request.md`

Frontmatter GitHub (`name`/`about`/`title`/`labels`) tự gắn nhãn `change-request`. Thân form tiếng Việt (intake nghiệp vụ, gần tài liệu). Không tạo `config.yml` (giữ blank issue cho ghi chú nội bộ — YAGNI).

- [ ] **Step 1: Tạo file với đúng nội dung dưới**

```markdown
---
name: Yêu cầu thay đổi (change request)
about: Một yêu cầu mới hoặc thay đổi hành vi hệ thống (KHÔNG dùng cho lỗi production — xem Backlog #3)
title: ""
labels: change-request
---

## Người yêu cầu
<!-- Khách (đơn vị nào) hay nội bộ? -->

## Mô tả thay đổi
<!-- Cần hệ thống làm khác đi thế nào, và vì sao. -->

## Có đụng nghiệp vụ không?
<!-- Có / Không. Nếu có: mục nào trong docs/V2_XAC_NHAN_NGHIEP_VU.md (sẽ gắn anchor NV-... khi thiết kế). -->

## Mức thay đổi (SemVer dự kiến)
<!-- feat (thêm tính năng → MINOR) / fix (sửa lỗi → PATCH) / breaking (→ MAJOR). Chốt khi phân loại. -->

## Tiêu chí chấp nhận
<!-- Làm sao biết yêu cầu này đã xong: hành vi quan sát được, ví dụ số liệu. -->

## Ghi chú truy vết
<!-- Điền dần khi luồng tiến: spec, pull request, version đích (milestone). -->
```

- [ ] **Step 2: Kiểm frontmatter YAML parse được + whitespace**

Run:
```bash
git add .github/ISSUE_TEMPLATE/change-request.md
ruby -ryaml -e 'c=File.read("'.github/ISSUE_TEMPLATE/change-request.md'"); fm=c[/\A---\n(.*?)\n---\n/m,1]; y=YAML.safe_load(fm); abort("labels sai") unless y["labels"]=="change-request"; puts "frontmatter OK: #{y["name"]}"'
git diff --cached --check && echo OK
```
Expected: in `frontmatter OK: Yêu cầu thay đổi (change request)` và `OK`.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore(github): add change-request issue template"
```

---

## Task 3: Template ADR (khung 7 mục)

**Files:**
- Create: `docs/superpowers/ADR-TEMPLATE.md`

Codify đúng style ADR-001..015 cho ADR-016+. ADR sống **bên trong** spec (mục `## Quyết định (ADR)`), nên file này là khung để dán, không phải spec riêng.

- [ ] **Step 1: Tạo file với đúng nội dung dưới**

```markdown
# Mẫu ADR (Architecture Decision Record)

> Dán khối dưới vào mục `## Quyết định (ADR)` của một spec trong `docs/superpowers/specs/`.
> ADR đánh **số toàn cục, tăng dần** (số mới nhất: xem spec gần nhất). Giữ đúng **7 mục, đúng thứ tự**.
> ADR mới có thể **thay** (supersede) ADR cũ — ghi rõ ở Trạng thái, giữ lịch sử.

### ADR-NNN: <Tiêu đề quyết định, ngắn gọn>
- **Trạng thái:** Proposed · YYYY-MM-DD  <!-- Proposed → Accepted → (Superseded by ADR-XXX) -->
- **Bối cảnh:** <Vấn đề/ràng buộc dẫn tới quyết định. Nêu sự thật, chưa nêu giải pháp.>
- **Quyết định:** <Chọn gì — cụ thể, đủ để thực thi.>
- **Lý do:** <Vì sao lựa chọn này thắng — bám sát Bối cảnh.>
- **Tradeoff:** (+) <được gì> (−) <mất/chấp nhận gì>
- **Phương án đã loại:** <Mỗi phương án + một câu vì sao loại.>
- **Điều kiện xem lại:** <Khi nào nên mở lại quyết định này.>
```

- [ ] **Step 2: Kiểm 7 nhãn mục có đủ + whitespace**

Run:
```bash
git add docs/superpowers/ADR-TEMPLATE.md
for k in "Trạng thái" "Bối cảnh" "Quyết định" "Lý do" "Tradeoff" "Phương án đã loại" "Điều kiện xem lại"; do grep -q "$k" docs/superpowers/ADR-TEMPLATE.md || echo "THIẾU: $k"; done
git diff --cached --check && echo OK
```
Expected: không in dòng `THIẾU:` nào; in `OK`.

- [ ] **Step 3: Commit**

```bash
git commit -m "docs(sdlc): add ADR template"
```

---

## Task 4: CONTRIBUTING.md — mục 9 + pointer ở mục 4

**Files:**
- Modify: `CONTRIBUTING.md` (thay khối mục 4; chèn mục 9 mới ngay trước `## Tài liệu liên quan`)

**Lưu ý ADR-002:** `CONTRIBUTING.md` là file meta gốc → **KHÔNG** bump version/changelog.

- [ ] **Step 1: Thay khối mục 4 để dẫn nhập từ Issue + ghi Refs #N**

Tìm chính xác khối hiện tại:

```markdown
## 4. Luồng làm một thay đổi

1. Tạo worktree + nhánh `feature/<việc>` từ `develop` (xem `README.md` để biết lệnh worktree + cổng Docker).
2. Code và test: `bin/docker rspec` (test phải cover mọi output của trang — xem `AGENTS.md`).
3. Chạy review AI local **trước khi push**: `/code-review` (ADR-009; dùng Claude sẵn có, không tốn thêm).
4. Mở pull request đích `develop` (với `feature/*`). CI xanh + chủ dự án duyệt → merge.
5. Pull request đích `main` chỉ đến từ `release/*` hoặc `hotfix/*`.
```

Thay bằng:

```markdown
## 4. Luồng làm một thay đổi

Mọi thay đổi bắt đầu từ một **GitHub Issue** (luồng đầy đủ + truy vết: xem mục 9). Sau khi đã có Issue `#N`:

1. Tạo worktree + nhánh `feature/<việc>` từ `develop` (xem `README.md` để biết lệnh worktree + cổng Docker).
2. Code và test: `bin/docker rspec` (test phải cover mọi output của trang — xem `AGENTS.md`).
3. Chạy review AI local **trước khi push**: `/code-review` (ADR-009; dùng Claude sẵn có, không tốn thêm).
4. Mở pull request đích `develop` (với `feature/*`); mô tả ghi `Refs #N` (hoặc `Closes #N` nếu giải quyết trọn). CI xanh + chủ dự án duyệt → merge.
5. Pull request đích `main` chỉ đến từ `release/*` hoặc `hotfix/*`.
```

- [ ] **Step 2: Chèn mục 9 mới ngay TRƯỚC dòng `## Tài liệu liên quan`**

Tìm chính xác (giữ nguyên, chèn khối mới vào phía trên nó):

```markdown
## Tài liệu liên quan
```

Chèn khối sau vào ngay trước dòng đó (để lại một dòng trống ngăn cách):

```markdown
## 9. Quản lý thay đổi & truy vết

Theo ADR-013..015 (chi tiết + lý do: `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md`). Mục tiêu: yêu cầu khách **không rơi** và truy được **yêu cầu → thiết kế → test → release**.

### Luồng một thay đổi (6 bước)

1. **Tiếp nhận** — mở **GitHub Issue** bằng template *Yêu cầu thay đổi* (`.github/ISSUE_TEMPLATE/change-request.md`). Yêu cầu đến từ kênh ngoài (lời nói, chat) cũng phải có Issue trước khi vào `feature/*` — đội mở thay khách nếu cần. Số `#N` là mã định danh thay đổi.
2. **Phân loại** — gắn 1 nhãn loại (`change-request` / `enhancement` / `bug`); chốt mức SemVer (`feat`/`fix`/breaking); xác định có đụng nghiệp vụ không. Cần thiết kế → gắn `needs-design`. Gán **milestone = version đích** khi đã biết.
3. **Thiết kế** (nếu cần) — brainstorm → spec trong `docs/superpowers/specs/`; nếu đụng nghiệp vụ, cập nhật `docs/V2_XAC_NHAN_NGHIEP_VU.md` + gắn anchor (xem dưới). Gỡ `needs-design`.
4. **Hiện thực + test** — `feature/*`, pull request `Refs #N`, test cover yêu cầu (mục 4).
5. **Release** — gom vào `release/*` → bản ứng viên (release candidate) → khách nghiệm thu → release-please tag `X.Y.Z` (mục 6).
6. **Đóng** — `Closes #N` khi merge; CHANGELOG tự liệt kê `(#N)`.

**Trạng thái không gắn nhãn tay** — suy ra từ artifact: Issue mở = đang mở; có pull request liên kết = đang làm; merged = xong; có trong CHANGELOG/tag = đã release.

**Khách thấy trạng thái ở mức release** (môi trường Nghiệm thu + release notes tiếng Việt). Khách không truy cập GitHub → đội trả lời "đang ở đâu" từ Issue/milestone list rồi chuyển tiếp.

### Mã định danh yêu cầu (anchor `NV-...`)

- Khi **lần đầu** cần link tới một yêu cầu trong `docs/V2_XAC_NHAN_NGHIEP_VU.md`, thêm `<a id="NV-<slug-chủ-đề>"></a>` ngay trước heading mục/tiểu mục đó. Slug **không dấu, theo chủ đề** (ví dụ `NV-phan-bo-bom-nuoc`), **không buộc vào số mục** (để bền khi tài liệu chèn/đánh số lại).
- Thêm lười (lazy): chỉ gắn anchor cho yêu cầu thực sự được truy vết. Sửa `docs/V2_XAC_NHAN_NGHIEP_VU.md` thì **bump version + changelog** của nó (ADR-002).

### Liên kết truy vết

- Mỗi spec thiết kế kết bằng mục `## Truy vết` trỏ **lên** (yêu cầu `NV-...` + Issue `#N`) và **liệt kê test** cover yêu cầu.
- **Test ↔ yêu cầu:** link ở phía spec/pull request, **không** gắn mã vào code test. Yêu cầu cũ (chưa có design spec) trỏ `docs/V2_KICH_BAN_TEST.md` / `docs/V2_CHIEU_TEST.md`.
- **Truy vết hai chiều bằng grep:** xuôi `grep -rn "NV-<slug>" docs/`; ngược từ `(#N)` trong CHANGELOG/commit → Issue → mô tả gốc.

> Lỗi production + tiếp nhận/ưu tiên backlog **không** thuộc mục này (Backlog #3, #4 của release spec).

```

- [ ] **Step 3: Kiểm cấu trúc không vỡ (mục 5–8 còn nguyên, không trùng heading, link spec đúng)**

Run:
```bash
git add CONTRIBUTING.md
echo "== headings ==" && grep -nE "^## " CONTRIBUTING.md
echo "== mục 9 xuất hiện đúng 1 lần ==" && [ "$(grep -c '^## 9. Quản lý thay đổi' CONTRIBUTING.md)" = "1" ] && echo OK9
echo "== mục 5..8 còn nguyên ==" && for n in 5 6 7 8; do grep -q "^## $n\. " CONTRIBUTING.md && echo "có mục $n"; done
echo "== link spec tồn tại ==" && test -f docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md && echo OKlink
git diff --cached --check && echo OKws
```
Expected: thứ tự heading là `1,2,3,4,5,6,7,8,9,Tài liệu liên quan`; in `OK9`, `có mục 5..8`, `OKlink`, `OKws`.

- [ ] **Step 4: Commit**

```bash
git commit -m "docs(contributing): add change-management & traceability section"
```

---

## Task 5: AGENTS.md — pointer ngắn

**Files:**
- Modify: `AGENTS.md` (thêm 1 bullet trong mục "Quy trình phát triển và phát hành (trỏ tới spec)")

**Lưu ý ADR-002:** `AGENTS.md` là file meta gốc → **KHÔNG** bump version/changelog. Giữ ngắn gọn (chỉ pointer, đừng chép chi tiết).

- [ ] **Step 1: Thêm bullet pointer sau bullet "Quy trình phát hành"**

Tìm chính xác:

```markdown
- **Quy trình phát hành** (Git Flow, SemVer + release candidate, release-please, môi trường, nội dung CI): `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-003..011).
- **Quy trình cho người** (thao tác Git Flow, Conventional Commits, pair local bằng VS Code Dev Tunnels): `CONTRIBUTING.md`.
```

Thay bằng (chèn 1 bullet vào giữa):

```markdown
- **Quy trình phát hành** (Git Flow, SemVer + release candidate, release-please, môi trường, nội dung CI): `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-003..011).
- **Truy vết & quản lý thay đổi** (yêu cầu → thiết kế → test → release; GitHub Issue cho luồng, repo cho dấu vết; anchor `NV-...`; template Issue/pull request/ADR): `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md` (ADR-013..015) + `CONTRIBUTING.md` mục 9.
- **Quy trình cho người** (thao tác Git Flow, Conventional Commits, pair local bằng VS Code Dev Tunnels): `CONTRIBUTING.md`.
```

- [ ] **Step 2: Kiểm bullet xuất hiện đúng 1 lần + link đúng + whitespace**

Run:
```bash
git add AGENTS.md
[ "$(grep -c 'Truy vết & quản lý thay đổi' AGENTS.md)" = "1" ] && echo OK1
grep -q '2026-06-08-truy-vet-quan-ly-thay-doi-design.md' AGENTS.md && echo OKlink
git diff --cached --check && echo OKws
```
Expected: in `OK1`, `OKlink`, `OKws`.

- [ ] **Step 3: Commit**

```bash
git commit -m "docs(agents): point to traceability & change-management spec"
```

---

## Task 6: Chốt trạng thái "đã hiện thực" trong 2 spec (docs/ → bump version)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (Backlog #2 → ✅; bump `0.8.0` → `0.9.0` + changelog)
- Modify: `docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md` (mục "Truy vết": "Sẽ hiện thực" → "Đã hiện thực"; bump `0.1.0` → `0.2.0` + changelog)

Cả hai là file `docs/` → **bắt buộc bump version + changelog** (ADR-002).

- [ ] **Step 1: Release spec — đổi dòng Backlog #2 sang ✅**

Tìm chính xác:

```markdown
2. **🔄 Thiết kế xong, chờ hiện thực** (ADR-013..015, [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)): truy vết / quản lý thay đổi (yêu cầu → thiết kế → test → release). Hybrid (GitHub Issues cho luồng + repo cho dấu vết bền); anchor yêu cầu `NV-...` thêm dần + chuẩn hoá mục "Truy vết" của spec; template Issue change-request + pull request + ADR. Hiện thực (file template + `CONTRIBUTING.md` + `AGENTS.md`) ở plan kế tiếp.
```

Thay bằng:

```markdown
2. **✅ Đã hiện thực** (ADR-013..015, [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)): truy vết / quản lý thay đổi (yêu cầu → thiết kế → test → release). Hybrid (GitHub Issues cho luồng + repo cho dấu vết bền); anchor yêu cầu `NV-...` thêm dần + chuẩn hoá mục "Truy vết" của spec; template Issue change-request (`.github/ISSUE_TEMPLATE/change-request.md`) + pull request (`.github/pull_request_template.md`) + ADR (`docs/superpowers/ADR-TEMPLATE.md`); mục 9 trong `CONTRIBUTING.md` + pointer ở `AGENTS.md`.
```

- [ ] **Step 2: Release spec — bump version `0.8.0` → `0.9.0`**

Tìm `version: 0.8.0` trong frontmatter, đổi thành `version: 0.9.0`.

- [ ] **Step 3: Release spec — thêm entry changelog trên cùng**

Tìm chính xác:

```markdown
## Changelog

- **0.8.0 (2026-06-08):**
```

Chèn entry mới ngay sau `## Changelog` (trên dòng `- **0.8.0`):

```markdown
## Changelog

- **0.9.0 (2026-06-08):** Backlog #2 ("Truy vết / quản lý thay đổi") đánh dấu **đã hiện thực** — template Issue change-request + pull request + ADR; mục 9 `CONTRIBUTING.md`; pointer `AGENTS.md`. Spec: ADR-013..015 trong [`2026-06-08-truy-vet-quan-ly-thay-doi-design.md`](2026-06-08-truy-vet-quan-ly-thay-doi-design.md).
- **0.8.0 (2026-06-08):**
```

- [ ] **Step 4: Spec truy vết — đổi dòng "Sẽ hiện thực" thành "Đã hiện thực"**

Tìm chính xác:

```markdown
- **Sẽ hiện thực ở plan kế tiếp:** `.github/ISSUE_TEMPLATE/change-request.md`, `.github/pull_request_template.md`, template ADR; mục "Quản lý thay đổi" trong `CONTRIBUTING.md`; trỏ ngắn trong `AGENTS.md`; cập nhật Backlog #2 trong release spec.
```

Thay bằng:

```markdown
- **Đã hiện thực** (plan [`2026-06-08-truy-vet-quan-ly-thay-doi.md`](../plans/2026-06-08-truy-vet-quan-ly-thay-doi.md)): `.github/ISSUE_TEMPLATE/change-request.md`, `.github/pull_request_template.md`, `docs/superpowers/ADR-TEMPLATE.md`; mục 9 "Quản lý thay đổi & truy vết" trong `CONTRIBUTING.md`; pointer trong `AGENTS.md`; Backlog #2 trong release spec đã chốt ✅.
```

- [ ] **Step 5: Spec truy vết — bump `0.1.0` → `0.2.0` + changelog**

Đổi `version: 0.1.0` → `version: 0.2.0` trong frontmatter. Rồi tìm:

```markdown
## Changelog

- **0.1.0 (2026-06-08):**
```

Chèn entry mới:

```markdown
## Changelog

- **0.2.0 (2026-06-08):** Hiện thực xong (xem plan `2026-06-08-truy-vet-quan-ly-thay-doi.md`): thêm 3 template (Issue change-request, pull request, ADR), mục 9 `CONTRIBUTING.md`, pointer `AGENTS.md`; cập nhật mục "Truy vết" sang trạng thái đã hiện thực.
- **0.1.0 (2026-06-08):**
```

- [ ] **Step 6: Kiểm version + changelog khớp, link nội bộ resolve**

Run:
```bash
git add docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md
grep -q "version: 0.9.0" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md && echo OKrel
grep -q "version: 0.2.0" docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md && echo OKtv
grep -q "0.9.0 (2026-06-08)" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md && echo OKrellog
grep -q "0.2.0 (2026-06-08)" docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md && echo OKtvlog
test -f docs/superpowers/plans/2026-06-08-truy-vet-quan-ly-thay-doi.md && echo OKplan
git diff --cached --check && echo OKws
```
Expected: in đủ `OKrel OKtv OKrellog OKtvlog OKplan OKws`.

- [ ] **Step 7: Commit**

```bash
git commit -m "docs(sdlc): mark traceability backlog item implemented"
```

---

## Task 7: Verification toàn cục + kết

**Files:** (không sửa — chỉ kiểm)

- [ ] **Step 1: Xác nhận KHÔNG đụng code Rails / test (đúng ADR-014: 0 churn)**

Run: `git diff --name-only origin/develop...HEAD | sort`
Expected: chỉ gồm các file dưới — KHÔNG có file nào trong `app/`, `spec/`, `config/`, `db/`, `lib/`:
```
.github/ISSUE_TEMPLATE/change-request.md
.github/pull_request_template.md
AGENTS.md
CONTRIBUTING.md
docs/superpowers/ADR-TEMPLATE.md
docs/superpowers/plans/2026-06-08-truy-vet-quan-ly-thay-doi.md
docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md
```
(`...-design.md` đã có từ commit brainstorm `6b5e13b`; plan file thêm khi lưu plan.)

- [ ] **Step 2: Kiểm mọi link Markdown nội bộ trong file đã đổi đều resolve**

Run:
```bash
for f in CONTRIBUTING.md AGENTS.md docs/superpowers/specs/2026-06-08-truy-vet-quan-ly-thay-doi-design.md docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md; do
  grep -oE '\(([^)]+\.md)[^)]*\)' "$f" | sed -E 's/^\(([^)#]+).*/\1/' | while read -r rel; do
    case "$rel" in
      http*) continue;;
    esac
    d=$(dirname "$f"); target="$d/$rel"
    [ -f "$target" ] || echo "BROKEN in $f -> $rel"
  done
done
echo "link check done"
```
Expected: chỉ in `link check done`, không có dòng `BROKEN`.

- [ ] **Step 3: KHÔNG chạy `bin/docker rspec`** — không có code Ruby thay đổi (Step 1 đã xác nhận), suite đầy đủ (gồm system spec) chạy >2 phút. Theo quy ước "lệnh dài phải hỏi trước", bỏ qua; CI trên pull request sẽ chạy test như thường lệ.

- [ ] **Step 4: Tự kiểm bằng mắt** — mở `.github/pull_request_template.md` và `.github/ISSUE_TEMPLATE/change-request.md`: nội dung đọc xuôi, tiếng đúng quy ước (pull request tiếng Anh, Issue tiếng Việt). *(Render thật của template chỉ thấy khi mở pull request/Issue trên GitHub — đó là xác nhận end-to-end cuối, làm khi đã được duyệt push.)*

- [ ] **Step 5: Báo cáo & bàn giao** — KHÔNG tự push / mở pull request. Tổng kết các commit + chờ chủ dự án duyệt (theo `feedback_git_workflow`).

---

## Self-Review (đã chạy khi viết plan)

- **Spec coverage:** ADR-013 (luồng Hybrid, nhãn, milestone, lớp khách) → Task 4 mục 9. ADR-014 (anchor `NV-...`, "Truy vết" chuẩn, test↔yêu cầu) → Task 4 mục 9 + Task 1 (PR checklist). ADR-015 (3 template) → Task 1/2/3. Cập nhật Backlog + spec notes → Task 6. Pointer canonical → Task 5.
- **Placeholder scan:** không có TBD/TODO; mọi file có nội dung đầy đủ.
- **Type/identifier consistency:** tên file, nhãn (`change-request`/`enhancement`/`bug`/`needs-design`), slug `NV-<chủ-đề>`, version `0.9.0`/`0.2.0` nhất quán giữa các task.
- **Không đụng code** (Task 7 Step 1 ép kiểm) — khớp tiêu chí "0 thay đổi code/test" của spec.
