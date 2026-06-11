# Tiếp nhận & ưu tiên công việc (Backlog #4) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện thực Backlog #4 — quy ước ưu tiên backlog bằng một nhãn cờ `priority-high` trên nền `milestone = version đích`, nhịp ad-hoc, và một cổng release-readiness kiểm được — **chỉ bằng tài liệu + quy ước, 0 thay đổi code**.

**Architecture:** Đây là mảnh SDLC thuần *tài liệu/quy ước*. Spec thiết kế (ADR-019..020) đã được viết + commit ở mức `0.1.0`. Phần còn lại: thêm mục hướng dẫn cho người (`CONTRIBUTING.md` §11), pointer canonical (`AGENTS.md`), đánh dấu Backlog #4 ✅ + bump version ở release spec, rồi bump spec #4 lên `0.2.0` ("Đã hiện thực"). Nhãn `priority-high` **tạo lười** (chỉ ghi lệnh `gh label create`, không tạo ngay — khớp cách #3 xử lý `severity-critical`).

**Tech Stack:** Markdown; quy ước ADR-002 (file `docs/` có version + changelog; file meta gốc KHÔNG versioned); GitHub Issues/labels/milestones; `gh` CLI; Git Flow (nhánh từ `develop`, squash-merge pull request vào `develop`).

**Ghi chú trạng thái khi viết plan:** spec `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md` đã tồn tại ở `0.1.0` (commit `docs(sdlc): add Backlog #4 …`). Release spec đang ở `0.10.0`. Các đoạn văn bản gốc cần khớp đã được nhúng nguyên trong từng task dưới đây.

---

## File Structure

- **Modify** `CONTRIBUTING.md` — thêm §11 "Ưu tiên công việc (backlog)"; sửa một câu trỏ cuối §9. *(File meta gốc — KHÔNG bump version.)*
- **Modify** `AGENTS.md` — thêm 1 bullet pointer cho spec #4 trong mục "Quy trình phát triển và phát hành (trỏ tới spec)". *(File meta gốc — KHÔNG bump version.)*
- **Modify** `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — Backlog #4 → ✅; bump `0.10.0 → 0.11.0` + entry changelog. *(File `docs/` — BẮT BUỘC bump version + changelog cùng commit, ADR-002.)*
- **Modify** `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md` — điền "Đã hiện thực"; bump `0.1.0 → 0.2.0` + entry changelog. *(File `docs/` — BẮT BUỘC bump version + changelog.)*
- **KHÔNG sửa** `.github/ISSUE_TEMPLATE/*` (cờ là label áp lúc triage, không phải field template) và **KHÔNG** chạy `gh label create` (tạo lười). **KHÔNG** thay đổi code/test.

---

### Task 1: Thêm `CONTRIBUTING.md` §11 + sửa câu trỏ cuối §9

**Files:**
- Modify: `CONTRIBUTING.md` (chèn §11 ngay TRƯỚC heading `## Tài liệu liên quan`; sửa 1 dòng cuối §9)

- [ ] **Step 1: Sửa câu trỏ cuối mục 9**

Tìm dòng (cuối §9, ngay trước `## 10. Vận hành & xử lý sự cố`):

```markdown
> Tiếp nhận/ưu tiên backlog **không** thuộc mục này (Backlog #4). Lỗi/sự cố production xem mục 10.
```

Thay bằng:

```markdown
> Tiếp nhận/ưu tiên backlog xem **mục 11** (Backlog #4). Lỗi/sự cố production xem mục 10.
```

- [ ] **Step 2: Chèn §11 ngay trước `## Tài liệu liên quan`**

Chèn khối sau (giữ nguyên dòng `## Tài liệu liên quan` ngay sau nó):

```markdown
## 11. Ưu tiên công việc (backlog)

Theo ADR-019..020 (chi tiết + lý do: `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md`). Mục tiêu: từ danh sách Issue đang mở biết **làm cái nào trước** và **khi nào release đủ nội dung để cắt** — không sổ thứ hai, không nghi thức.

### Một backlog

Backlog = **mọi GitHub Issue đang mở** (yêu cầu/thay đổi mục 9, lỗi/sự cố mục 10 — chung một danh sách). Không có file backlog riêng.

### Hai trục ưu tiên

- **`milestone` = version đích** (đã có ở mục 9): Issue dự kiến vào bản phát hành nào.
- **Nhãn `priority-high`**: đánh dấu Issue **phải có** cho milestone của nó. Issue không gắn = nên-có / thường.

### Thứ tự kéo việc (pull)

1. **`severity-critical`** (mục 10) — sự cố nghiêm trọng, vá gấp `hotfix/*`, **ngoài hàng đợi**; **không** kèm `priority-high`.
2. **`priority-high`** theo milestone.
3. Phần còn lại.

### Nhịp

Ad-hoc, **gộp vào bước Phân loại** (mục 9, bước 2): khi triage một Issue, chủ dự án gán milestone + (nếu phải-có) `priority-high`. **Không** họp grooming định kỳ; xem lại cơ hội khi cắt release. Chủ dự án là người quyết ưu tiên.

### Cổng "release đủ nội dung để cắt"

Một milestone **sẵn sàng cắt `release/*`** khi **mọi** Issue `priority-high` của nó đã xong (merged vào `develop`). Việc **không cờ** chưa xong → **reslot** milestone sang bản sau (không chặn release). Kiểm bằng:

```bash
gh issue list --label priority-high --milestone <version> --state open
# rỗng → milestone đủ nội dung phải-có → cắt release/<version>
```

> Nhãn `priority-high` tạo một lần khi lần đầu cần (đội bắt đầu dùng milestone để ưu tiên): `gh label create priority-high --color FBCA04 --description "Phải có cho milestone (ưu tiên kéo việc)"`.

```

- [ ] **Step 3: Kiểm tra kết quả**

Run:
```bash
grep -n "## 11. Ưu tiên công việc (backlog)" CONTRIBUTING.md
grep -n "Tiếp nhận/ưu tiên backlog xem \*\*mục 11\*\*" CONTRIBUTING.md
grep -c "không\*\* thuộc mục này (Backlog #4)" CONTRIBUTING.md   # phải in 0 (câu cũ đã thay)
```
Expected: dòng 1 + 2 tìm thấy; dòng 3 in `0`.

- [ ] **Step 4: KHÔNG commit riêng** — gộp commit ở Task 5 (các thay đổi liên kết nhau; pull request sẽ squash-merge nên một commit doc-edit là đủ sạch).

---

### Task 2: Thêm pointer #4 vào `AGENTS.md`

**Files:**
- Modify: `AGENTS.md` (mục "Quy trình phát triển và phát hành (trỏ tới spec)")

- [ ] **Step 1: Chèn bullet #4 ngay SAU bullet "Vận hành & bảo trì"**

Tìm dòng:

```markdown
- **Vận hành & bảo trì** (giám sát Mini PC offline, chính sách sao lưu/khôi phục, tiếp nhận lỗi/sự cố khách): `docs/superpowers/specs/2026-06-09-van-hanh-bao-tri-design.md` (ADR-016..018) + `CONTRIBUTING.md` mục 10.
```

Chèn ngay sau nó:

```markdown
- **Tiếp nhận & ưu tiên công việc** (một backlog Issue; nhãn `priority-high` trên nền milestone = version đích; cổng release-readiness): `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md` (ADR-019..020) + `CONTRIBUTING.md` mục 11.
```

- [ ] **Step 2: Kiểm tra**

Run:
```bash
grep -n "Tiếp nhận & ưu tiên công việc" AGENTS.md
```
Expected: tìm thấy đúng 1 dòng, nằm giữa bullet "Vận hành & bảo trì" và bullet "Quy trình cho người".

- [ ] **Step 3: KHÔNG commit riêng** — gộp ở Task 5.

---

### Task 3: Đánh dấu Backlog #4 ✅ + bump release spec (0.10.0 → 0.11.0)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (frontmatter `version`; mục `## Backlog`; mục `## Changelog`)

- [ ] **Step 1: Thay dòng Backlog #4**

Tìm dòng:

```markdown
4. Tiếp nhận công việc (issue/backlog, ưu tiên).
```

Thay bằng:

```markdown
4. **✅ Đã hiện thực** (ADR-019..020, [`2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md`](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md)): tiếp nhận & ưu tiên công việc — thừa hưởng intake Issue của #2/#3; nhãn `priority-high` tối thiểu trên nền milestone = version đích (`severity-critical` của #3 nằm ngoài thang); nhịp ad-hoc gộp vào bước phân loại #2; cổng release-readiness (mọi `priority-high` của milestone đã xong, việc không cờ reslot) làm rõ bước "Đủ nội dung → `release/*`"; mục 11 `CONTRIBUTING.md` + pointer `AGENTS.md`.

> **Bốn mảnh SDLC tuần tự đã hoàn tất.** Phần còn lại chỉ là *cải tiến optional* dưới đây (YAGNI cho quy mô hiện tại).
```

- [ ] **Step 2: Bump version frontmatter**

Tìm `version: 0.10.0` (dòng 3) → đổi thành `version: 0.11.0`.

- [ ] **Step 3: Thêm entry changelog (đầu danh sách, trên `0.10.0`)**

Chèn ngay dưới dòng `## Changelog` (thành entry mới nhất):

```markdown
- **0.11.0 (2026-06-09):** Backlog #4 ("Tiếp nhận công việc / ưu tiên") **thiết kế + hiện thực xong** — spec mới [`2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md`](2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md) (ADR-019 cơ chế ưu tiên nhãn `priority-high` trên nền milestone; ADR-020 nhịp ad-hoc + cổng release-readiness); mục 11 `CONTRIBUTING.md` + pointer `AGENTS.md`; Backlog #4 → ✅ (bốn mảnh SDLC tuần tự hoàn tất).
```

- [ ] **Step 4: Kiểm tra**

Run:
```bash
grep -n "^version: 0.11.0" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
grep -n "✅ Đã hiện thực.*ADR-019..020" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
grep -n "0.11.0 (2026-06-09)" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
```
Expected: cả ba tìm thấy.

- [ ] **Step 5: KHÔNG commit riêng** — gộp ở Task 5.

---

### Task 4: Bump spec #4 lên 0.2.0 + điền "Đã hiện thực"

**Files:**
- Modify: `docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md` (frontmatter `version`; mục `## Truy vết` dòng "Đã hiện thực"; mục `## Changelog`)

- [ ] **Step 1: Bump version frontmatter**

`version: 0.1.0` → `version: 0.2.0`. (Giữ `status: draft (chờ duyệt)` — khớp #2/#3 ở 0.2.0.)

- [ ] **Step 2: Thay dòng "Đã hiện thực" trong mục `## Truy vết`**

Tìm dòng:

```markdown
- **Đã hiện thực:** *(điền sau khi hiện thực — bump 0.2.0, giống #2/#3).*
```

Thay bằng:

```markdown
- **Đã hiện thực** (plan [`2026-06-09-tiep-nhan-uu-tien-cong-viec.md`](../plans/2026-06-09-tiep-nhan-uu-tien-cong-viec.md)): mục 11 "Ưu tiên công việc (backlog)" trong `CONTRIBUTING.md` + sửa câu trỏ cuối mục 9; pointer trong `AGENTS.md`; Backlog #4 trong release spec → ✅ + bump version; nhãn `priority-high` (tạo lười — lệnh trong `CONTRIBUTING.md` mục 11). **0 thay đổi code/test.**
```

- [ ] **Step 3: Thêm entry changelog 0.2.0 (đầu danh sách, trên 0.1.0)**

Chèn ngay dưới dòng `## Changelog`:

```markdown
- **0.2.0 (2026-06-09):** Hiện thực xong (xem plan `2026-06-09-tiep-nhan-uu-tien-cong-viec.md`): mục 11 `CONTRIBUTING.md` + sửa câu trỏ mục 9; pointer `AGENTS.md`; Backlog #4 trong release spec → ✅; nhãn `priority-high` (tạo lười). Cập nhật mục "Truy vết" sang trạng thái đã hiện thực.
```

- [ ] **Step 4: Kiểm tra**

Run:
```bash
grep -n "^version: 0.2.0" docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md
grep -n "Đã hiện thực\*\* (plan" docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md
grep -c "điền sau khi hiện thực" docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md  # phải 0
```
Expected: hai dòng đầu tìm thấy; dòng cuối in `0` (placeholder đã thay).

- [ ] **Step 5: KHÔNG commit riêng** — gộp ở Task 5.

---

### Task 5: Verification toàn cục + commit

**Files:** (không sửa mới — chỉ kiểm + commit các thay đổi của Task 1–4 + plan này)

- [ ] **Step 1: Không có thay đổi code/test**

Run:
```bash
git status --porcelain
```
Expected: chỉ liệt kê `CONTRIBUTING.md`, `AGENTS.md`, hai file spec `docs/superpowers/specs/...`, và plan `docs/superpowers/plans/2026-06-09-tiep-nhan-uu-tien-cong-viec.md`. **Không** có file nào trong `app/`, `lib/`, `spec/`, `db/`.

- [ ] **Step 2: Liên kết chéo nhất quán (tên nhãn + tên file)**

Run:
```bash
grep -rn "priority-high" CONTRIBUTING.md AGENTS.md docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md
grep -rn "2026-06-09-tiep-nhan-uu-tien-cong-viec" docs/ AGENTS.md CONTRIBUTING.md
```
Expected: tên nhãn `priority-high` viết **giống hệt** ở mọi nơi (không có `priority:high`/`priority_high`); mọi link tới spec/plan #4 trỏ đúng tên file tồn tại.

- [ ] **Step 3: Hai file `docs/` đã bump version đúng**

Run:
```bash
grep -n "^version:" docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md
```
Expected: release spec `0.11.0`; spec #4 `0.2.0`.

- [ ] **Step 4: Commit (gộp toàn bộ phần hiện thực)**

```bash
git add CONTRIBUTING.md AGENTS.md \
  docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md \
  docs/superpowers/specs/2026-06-09-tiep-nhan-uu-tien-cong-viec-design.md \
  docs/superpowers/plans/2026-06-09-tiep-nhan-uu-tien-cong-viec.md
git commit -F - <<'EOF'
docs(sdlc): implement Backlog #4 intake & prioritization conventions

Add CONTRIBUTING §11 (one backlog; priority-high flag over milestone;
pull order; ad-hoc cadence; release-readiness gate), AGENTS pointer,
mark release Backlog #4 done (bump 0.10.0 -> 0.11.0), and bump the #4
design spec to 0.2.0 with the implementation trace. The priority-high
label is documented for lazy creation (gh label create), not created
now — matching how #3 handled severity-critical. 0 code/test changes.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
git log --oneline -3
```
Expected: commit tạo thành công; `git log` hiện commit này trên commit spec `0.1.0` đã có.

- [ ] **Step 5: (Hook tự chạy) doc-version-bump reminder**

Khi commit, `PostToolUse`/pre-commit reminder có thể nhắc bump version cho file `docs/` — đã xử lý ở Task 3 + Task 4. File meta gốc (`CONTRIBUTING.md`, `AGENTS.md`) **không** versioned (ADR-002) nên bỏ qua nhắc cho hai file đó.

---

## Self-Review (đã chạy khi viết plan)

**1. Spec coverage:**
- ADR-019 (nhãn `priority-high` trên nền milestone; `severity-critical` ngoài thang; thứ tự pull) → CONTRIBUTING §11 "Hai trục ưu tiên" + "Thứ tự kéo việc" (Task 1).
- ADR-020 (nhịp ad-hoc gộp triage; cổng release-readiness; một backlog) → CONTRIBUTING §11 "Nhịp" + "Cổng" + "Một backlog" (Task 1).
- Nhãn tạo lười → lệnh `gh label create` trong §11 (Task 1); **không** tạo ngay (đúng Non-Goal/cách #3).
- Pointer canonical → AGENTS.md (Task 2).
- Backlog #4 ✅ + bump → release spec (Task 3); "Đã hiện thực" + bump → spec #4 (Task 4).
- "0 thay đổi code/test" (Tiêu chí thành công) → verify Task 5 Step 1.
- Không gap.

**2. Placeholder scan:** Không còn `TBD/TODO`. Placeholder "điền sau khi hiện thực" trong spec #4 được **thay** ở Task 4 Step 2 (verify in `0` ở Step 4).

**3. Type/tên nhất quán:** tên nhãn `priority-high` (kebab-case) dùng đồng nhất ở CONTRIBUTING/AGENTS/spec #4/release spec; verify ở Task 5 Step 2. Tên file spec/plan `2026-06-09-tiep-nhan-uu-tien-cong-viec[-design].md` khớp giữa các link.
