# P1 — Nền tài liệu & quy ước: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lập `AGENTS.md` ở gốc repo làm **nguồn canonical** cho mọi quy ước (dùng chung người + mọi công cụ AI), biến `CLAUDE.md` thành một dòng `@import`, và thêm `CONTRIBUTING.md` (quy trình cho người) — đúng ADR-002.

**Architecture:** Di trú nội dung **bền** từ `CLAUDE.md` hiện tại sang `AGENTS.md` (giữ AGENTS.md ngắn gọn, mệnh lệnh, trỏ tới spec/ADR cho chi tiết). `CLAUDE.md` chỉ còn dòng `@AGENTS.md` (Claude Code import — KHÔNG symlink, an toàn Windows). `CONTRIBUTING.md` mô tả quy trình cho người (Git Flow, Conventional Commits, pair local bằng VS Code Dev Tunnels) và trỏ về AGENTS.md + specs. Vì đổi file canonical, phải cập nhật coupling: `bin/prepare-delivery` (xóa thêm AGENTS.md + CONTRIBUTING.md khỏi bản giao khách — theo quyết định của chủ dự án) và README + KIEN_THUC_DOCKER cho nhất quán.

**Tech Stack:** Tài liệu Markdown (tiếng Việt cho tài liệu/giao diện; code/commit tiếng Anh). Không thay đổi code ứng dụng → **không cần `bin/docker rspec`**; kiểm thử = kiểm tra cấu trúc file + `bash -n` cho script. Cú pháp `@import` của Claude Code đã xác nhận: `@path` (đường dẫn tương đối, giải theo vị trí file chứa nó; AGENTS.md ở gốc repo cùng cấp CLAUDE.md → giải đúng; độ sâu tối đa 4 hop).

**Nguồn (đọc trước khi thực hiện):**
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-001 (mô hình), **ADR-002 (chiến lược tài liệu/tri thức — quyết định nền của P1)**.
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — ADR-003..011 (release; được CONTRIBUTING.md trỏ tới).

---

## File Structure

| File | Trách nhiệm | Thao tác |
|---|---|---|
| `AGENTS.md` | Nguồn **canonical** quy ước code + quy trình; ngắn gọn, trỏ tới docs/specs | **Create** |
| `CLAUDE.md` | Chỉ còn dòng `@AGENTS.md` để Claude Code đọc cùng nội dung | **Overwrite** (rút từ ~10KB → vài dòng) |
| `CONTRIBUTING.md` | Quy trình cho **người**: Git Flow, Conventional Commits, pair local Dev Tunnels | **Create** |
| `README.md` | Bảng "Tài liệu": trỏ canonical sang AGENTS.md + thêm CONTRIBUTING.md | **Modify** (dòng 121) |
| `bin/prepare-delivery` | Xóa thêm AGENTS.md + CONTRIBUTING.md + tham chiếu README khỏi bản giao khách | **Modify** (dòng 57 + bước 4) |
| `docs/KIEN_THUC_DOCKER.md` | Câu mô tả file dev bị strip: thêm AGENTS.md, CONTRIBUTING.md; bump version | **Modify** (header + dòng ~309) |

**Quy ước chung khi thực hiện:**
- Tài liệu/giao diện tiếng Việt 100%; code/commit/PR tiếng Anh; **tuyệt đối không viết tắt** (ngoại lệ phổ biến: CRUD, UI; các tên chuẩn riêng giữ nguyên: Git Flow, SemVer, Conventional Commits, VS Code, Dev Tunnels, ADR, CI). Viết "pull request" thay vì "PR".
- Đang ở worktree, nhánh `claude/focused-faraday-eed6ed` (không phải `main`). Commit trực tiếp lên nhánh này được. **KHÔNG push remote, KHÔNG merge khi chưa được chủ dự án duyệt** — dừng lại trình diện trước.
- Commit message tiếng Anh, theo Conventional Commits, kết bằng dòng:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Mỗi lệnh chạy lâu (>2 phút) phải hỏi trước. **KHÔNG chạy `bin/prepare-delivery` thật** trong khi thực hiện plan (nó clone repo + rewrite git history + tạo thư mục anh em — nặng & ngoài phạm vi); chỉ kiểm cú pháp bằng `bash -n`.

---

## Task 1: Tạo AGENTS.md (canonical) + biến CLAUDE.md thành `@import`

Đây là một thay đổi nguyên tử: AGENTS.md ra đời và CLAUDE.md chuyển sang import cùng lúc, để không tồn tại trạng thái trùng lặp nội dung trên `main`.

**Files:**
- Create: `AGENTS.md`
- Overwrite: `CLAUDE.md`

- [ ] **Step 1: Viết `AGENTS.md` với nội dung canonical đầy đủ**

Tạo file `AGENTS.md` ở gốc repo (cùng cấp `CLAUDE.md`) với chính xác nội dung sau. Nội dung di trú **nguyên văn** các phần bền từ CLAUDE.md cũ (Nguyên tắc viết, Tài liệu nguồn, Stack, Development environment, Ngôn ngữ, Quy ước đặt tên, Quy tắc code, Quy trình làm việc); thay bảng "Environments" cũ (đang được ADR-005 đổi, đã có ở README) bằng pointer; thêm phần "Quy trình phát hành & SDLC" và "Tài liệu liên quan".

````markdown
# AGENTS.md — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Nguồn canonical** cho mọi quy ước của dự án (code + quy trình), dùng chung cho cả người và mọi công cụ AI (Claude Code, Cursor, Copilot, Codex, Gemini, VS Code…).
>
> - **Công cụ AI khác** đọc trực tiếp file này.
> - **Claude Code** đọc qua `CLAUDE.md` (chỉ chứa dòng `@AGENTS.md`).
> - **Người mới tham gia:** đọc thêm `CONTRIBUTING.md` (quy trình làm việc) và các spec trong `docs/superpowers/specs/`.
> - **Giữ file này NGẮN GỌN, mệnh lệnh.** Chi tiết và lý do nằm ở `docs/` — ở đây chỉ nêu quy ước rồi trỏ tới. Đừng nhồi chi tiết SDLC/release vào đây (theo ADR-002).

## Nguyên tắc viết

Tuyệt đối không viết tắt, không rút gọn — áp dụng mọi nơi: tài liệu, code (tên biến, method, cột, i18n, commit message), giao diện, giao tiếp. Ngoại trừ thuật ngữ phổ biến ai cũng hiểu ngay: CRUD, UI.

## Tài liệu nguồn (đọc trước khi làm bất cứ gì)

Thứ tự ưu tiên:

1. `docs/V2_XAC_NHAN_NGHIEP_VU.md` — nghiệp vụ, nguồn sự thật duy nhất
2. `docs/V2_THIET_KE_HE_THONG.md` — thiết kế hệ thống, nguồn sự thật cho implementation
3. `docs/V2_HANH_VI_HE_THONG.md` — hành vi runtime: 6 vai trò, 3 trạng thái kỳ, dữ liệu xuyên kỳ, nguyên tắc `.kept`/`.with_discarded`. **Đọc mục 7 trước khi dùng `.kept` trong query.**
4. `docs/V2_CHIEU_TEST.md` — 12 chiều kiểm thử, input/output specifications, giao điểm nguy hiểm. Đọc trước khi viết test.

Khi code mâu thuẫn với thiết kế → sửa code. Khi thiết kế mâu thuẫn với nghiệp vụ → báo lỗi, không tự sửa.

## Stack kỹ thuật

Rails 8, PostgreSQL, Tailwind, Hotwire (Turbo + Stimulus), Devise, CanCanCan, PaperTrail, Discard, Pagy, caxlsx + caxlsx_rails, RSpec + Capybara.

## Môi trường & cách chạy (development)

Development chạy hoàn toàn trong Docker (3 containers: postgres, app, nginx). Khi cần verify UI hoặc chạy app, dùng `preview_start` với server name `docker-dev` (cấu hình trong `.claude/launch.json`). Không chạy `docker compose` thủ công — để preview quản lý process.

Mỗi git worktree dùng bộ cổng host riêng do `bin/docker` tự gán (postgres + nginx), nên nhiều worktree (và project gốc) chạy song song không đụng nhau — không tự đặt cổng hay chạy `docker compose` tay. `preview_start docker-dev` tự trỏ đúng app của worktree hiện tại (autoPort), kể cả khi mở nhiều session.

`bin/docker` là shortcut cho các lệnh Docker development:

- Chạy test: `bin/docker rspec` (hoặc `bin/docker rspec spec/models`)
- Rails console: `bin/docker console`
- Xem logs: `bin/docker logs`
- Mở shell: `bin/docker bash` (hoặc `bin/docker bash postgres`)
- Trạng thái: `bin/docker ps`
- Dọn rác worktree: `bin/docker nuke` (xóa container + network + volume + image của worktree; chạy TRƯỚC `git worktree remove` để tránh orphan; KHÔNG xóa dữ liệu DB)
- Chia sẻ dữ liệu dev giữa worktree: `bin/docker dump-dev [tên]` / `bin/docker load-dev [tên]` (snapshot dùng chung), hoặc `bin/docker up --shared-db=<cổng>` (DB sống chung). Chỉ giữa các worktree cùng schema

> **Ba môi trường (Development / Nghiệm thu + Mốc trên Railway / Production Mini PC offline) và mô hình phát hành:** xem `README.md` (tổng quan, lệnh, môi trường) và `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-005 môi trường & promotion). Không lặp lại chi tiết ở đây.

## Ngôn ngữ

- Code (tên biến, method, cột, model, controller, test): tiếng Anh
- Git commits, pull request titles, pull request descriptions: tiếng Anh
- i18n (config/locales/vi.yml): tiếng Việt 100%
- Giao diện: tiếng Việt 100%
- Tên trong code sát nghiệp vụ nhất có thể, dịch sang tiếng Anh

## Quy ước đặt tên (nghiệp vụ → code)

| Nghiệp vụ | Tên bảng | Tên model |
|---|---|---|
| Khu vực | zones | Zone |
| Đơn vị | units | Unit |
| Đầu mối | contact_points | ContactPoint |
| Khối | blocks | Block |
| Nhóm | groups | Group |
| Công tơ | meters | Meter |
| Công tơ tổng | main_meters | MainMeter |
| Kỳ tính toán | periods | Period |
| Nhóm cấp bậc | ranks | Rank |

## Quy tắc code

- Decimal: dùng PostgreSQL numeric, Ruby BigDecimal. Không dùng float cho tiền và điện.
- Làm tròn: ROUND_HALF_UP (5 → làm tròn lên). Ruby: `BigDecimal#round(2, :half_up)`. Không dùng ROUND_HALF_EVEN. Chỉ làm tròn khi hiển thị và xuất Excel, không làm tròn giữa tính toán.
- Soft delete: dùng gem discard. **Không mặc định dùng `.kept` ở mọi nơi.** Xem `docs/V2_HANH_VI_HE_THONG.md` mục 7 để biết khi nào dùng `.kept`, khi nào không. Tóm tắt: query hiển thị data per kỳ (billing, meter_entries, dashboard,...) KHÔNG dùng `.kept` — data per kỳ tự lọc. Form dropdown, CRUD index, model callbacks, PeriodService snapshot dùng `.kept`.
- Optimistic locking: bảng nhập liệu có cột `lock_version`.
- Phân quyền: dùng `accessible_by(current_ability)` trong mọi controller. Không dùng `Model.find(params[:id])` trực tiếp. Mọi trang cấu hình/hệ thống phải có page-level authorize (không chỉ dựa vào `can :read` của Ability). **Design issue đã fix:** concern `SettingsAccessGuard` thêm page-level guard chặn truy cập trực tiếp qua URL các trang /zones, /units, /pricing, /pump_allocations, /ranks, /users theo vai trò (chỉ SA; SA hoặc zone-manager cho /zones và /pump_allocations; SA hoặc TECH cho /users). Đồng thời `ability.rb` đã thu hẹp `can :read, Zone` chỉ còn khu vực do đơn vị quản lý (trước đây mở rộng cho mọi zone `discarded_at: nil`). `can :read, Unit/Period/Rank` giữ nguyên để phục vụ form và billing.
- Vai trò: hệ thống có 6 vai trò thực tế (không phải 4 enum). Xem `docs/V2_HANH_VI_HE_THONG.md` mục 1. Mọi trang phải test cả 6 vai trò.
- Xóa entity: cleanup data kỳ đang mở (hard delete), giữ nguyên data kỳ cũ. Xem `docs/V2_HANH_VI_HE_THONG.md` mục 5.
- Kỳ tính toán: mọi thao tác mở kỳ mới và tính toán phải nằm trong ActiveRecord transaction. Mọi thay đổi dữ liệu nghiệp vụ cần kỳ mở (PeriodGuard). Thay đổi cấu trúc chỉ khi kỳ mới nhất mở (StructureChangeGuard). Xem `docs/V2_HANH_VI_HE_THONG.md` mục 3.
- Role check: dùng `current_user.system_admin?` thay vì `current_user.role == "system_admin"`.
- Trang index: dùng `_list_toolbar` partial cho search, filter dropdowns, per_page, total count. Mỗi trang có `per_page_storage_key` riêng. Filter dropdown cho SA only (zone/unit ẩn cho non-SA). Zone/unit filter dùng `ZoneUnitFilterable` concern (`apply_sa_zone_filter`, `apply_sa_zone_unit_filter`, hoặc `apply_sa_zone_unit_filter_with_direct_zone` cho scope joining contact_points có thể thuộc zone trực tiếp hoặc qua unit).
- Search: dùng `apply_search(scope, columns:)` từ `ListSortable` concern. Hỗ trợ 1 cột (`columns: "blocks.name"`) hoặc nhiều cột OR (`columns: %w[users.username users.display_name]`). Không tự viết ILIKE inline — `apply_search` đã sanitize ký tự đặc biệt.
- Zone-manager check: luôn dùng `Zone.kept.where(manager_unit_id:)` hoặc `current_zone_manager?` (dùng `.kept`). Không dùng `Zone.where(manager_unit_id:)` — zone đã xóa không được coi là đang quản lý. Phải khớp Ability class.
- Data scoping cho non-SA: dùng `accessible_by(current_ability)` (Ability là nguồn sự thật duy nhất). Không tự build scope kiểm tra `unit_id`/`zone_id` — dễ diverge với Ability. `resolve_current_user_zone_unit` từ `ZoneUnitFilterable` dùng cho display logic (ẩn/hiện cột, set `@zone`/`@unit`), không dùng cho data scoping.
- Ẩn/hiện cột Khu vực + Đơn vị: 3 trường hợp khác nhau. CRUD index: `show_zone_unit = current_user.system_admin?` (chỉ SA thấy cross-zone/unit). Billing: `@show_zone_column = @zone.nil?` (SA chọn zone → ẩn cột zone vì thừa, non-SA dựa vào `resolve_current_user_zone_unit`). History: luôn hiện cả 2 cột (so sánh kỳ cần context đầy đủ).
- Dropdown khu vực/đơn vị khi xem kỳ cũ: trang xem data lịch sử (billing, history) dùng `with_discarded` vì cần hiện entity đã xóa. Trang quản lý/nhập liệu (CRUD, meter_entries) dùng `zone_filter_scope`/`unit_filter_scope` từ `ZoneUnitFilterable` (auto-detect `reopened_old_period?`).
- Commander trên mọi trang: sidebar hiện cùng trang với unit_admin cùng variant (CMD khớp UA, CMD-ZM khớp UA-ZM). View dùng `can_edit = can?(:update, ...)` để disable input và ẩn nút Lưu. Mọi trang nhập liệu và cấu hình phải có guard này.
- Validation: không dùng HTML5 validation. Dùng JavaScript (Stimulus) validate realtime + server-side validate (model). Thông báo lỗi tiếng Việt.
- Timezone: Asia/Ho_Chi_Minh. Database lưu UTC.
- Encoding: UTF-8.

## Quy trình làm việc

- Đọc thiết kế trước khi code. Không tự sáng tạo thêm field, model, hay logic ngoài thiết kế.
- Chạy `bin/docker rspec` sau mỗi thay đổi.
- Test phải cover mọi output của trang (data, cảnh báo, filter, buttons), không chỉ output chính. Xem `docs/V2_HANH_VI_HE_THONG.md` mục 8.
- System specs (type: :system) dùng Capybara + headless Chrome cho behavior cần browser (JS interaction, auto-submit, cascade filter). Shared examples nằm trong `spec/support/shared_examples/system/`.
- Request specs test server-side logic (data scoping, column display, sort, CRUD, role-based access). Không trùng lặp với system spec.
- Test tạo nhiều unit trong cùng zone: dùng `let!` (không dùng `let`) để đảm bảo thứ tự tạo. Unit đầu tiên tự động thành zone manager (auto-assign callback). Nếu test cần unit cụ thể là zone manager, set `zone.update!(manager_unit_id: unit.id)` tường minh — không dựa vào thứ tự auto-assign.
- Audit/review phải theo luồng nghiệp vụ end-to-end (tạo → xóa → đóng kỳ → mở kỳ mới → xem), không theo file.
- Không chạy rubocop locally (CI cover).
- Không tự mở rộng scope. Nếu thấy thiếu gì trong thiết kế → dừng lại, báo lỗi.

## Quy trình phát hành & SDLC (trỏ tới spec)

- **Mô hình phát triển + chiến lược tài liệu/tri thức:** `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` (ADR-001, ADR-002).
- **Quy trình phát hành** (Git Flow, SemVer + release candidate, release-please, môi trường, nội dung CI): `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-003..011).
- **Quy trình cho người** (thao tác Git Flow, Conventional Commits, pair local bằng VS Code Dev Tunnels): `CONTRIBUTING.md`.

> Tóm tắt một dòng (chi tiết & lý do ở các spec trên — đừng lặp lại ở đây): nhánh theo **Git Flow** (`main` / `develop` / `feature/*` / `release/*` / `hotfix/*`); version theo **SemVer** kèm hậu tố `-rc.N` cho bản chờ nghiệm thu; commit theo **Conventional Commits** (tiếng Anh).

## Tài liệu liên quan

- `README.md` — tổng quan, cài đặt, lệnh thường dùng, môi trường.
- `CONTRIBUTING.md` — quy trình đóng góp cho người.
- `docs/` — nghiệp vụ, thiết kế, hành vi, kiểm thử, Docker, deploy.
- `docs/superpowers/specs/` — spec + ADR (quyết định kèm lý do); `docs/superpowers/plans/` — plan triển khai.
````

- [ ] **Step 2: Kiểm tra AGENTS.md tồn tại + đủ các phần chính**

Run:
```bash
test -f AGENTS.md && grep -c '^## ' AGENTS.md && grep -n 'Quy trình phát hành & SDLC\|Quy tắc code\|Nguyên tắc viết' AGENTS.md
```
Expected: file tồn tại; đếm `## ` ≥ 9; tìm thấy cả 3 tiêu đề. Nếu thiếu → bổ sung.

- [ ] **Step 3: Ghi đè `CLAUDE.md` thành dòng import**

Overwrite toàn bộ `CLAUDE.md` (đang ~10KB) bằng đúng nội dung sau:

````markdown
@AGENTS.md

> Quy ước canonical của dự án nằm ở `AGENTS.md`. Dòng `@AGENTS.md` ở trên để Claude Code đọc đúng nội dung đó (cú pháp import của Claude Code — KHÔNG dùng symlink để an toàn cho Windows). **Đừng thêm quy ước vào file này — sửa `AGENTS.md`.**
````

- [ ] **Step 4: Kiểm tra CLAUDE.md đã rút gọn và import đúng**

Run:
```bash
head -1 CLAUDE.md && echo "---" && wc -l CLAUDE.md
```
Expected: dòng đầu chính xác là `@AGENTS.md`; tổng số dòng ≤ 5.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md CLAUDE.md
git commit -m "docs(sdlc): make AGENTS.md the canonical conventions source

Migrate durable conventions from CLAUDE.md into AGENTS.md (cross-tool
canonical per ADR-002) and reduce CLAUDE.md to a single @AGENTS.md import
so Claude Code reads the same content without a Windows-unsafe symlink.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Tạo CONTRIBUTING.md (quy trình cho người)

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Viết `CONTRIBUTING.md`**

Tạo file `CONTRIBUTING.md` ở gốc repo với chính xác nội dung sau:

`````markdown
# Hướng dẫn đóng góp (CONTRIBUTING)

Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` (nguồn canonical). Quyết định kèm lý do nằm trong `docs/superpowers/specs/`.

> Mọi quy ước viết (tuyệt đối không viết tắt), ngôn ngữ (tài liệu/giao diện tiếng Việt; code/commit tiếng Anh) theo `AGENTS.md`.

## 1. Trước khi bắt đầu

- Đọc `AGENTS.md` (quy ước) và tài liệu nguồn trong `docs/` (nghiệp vụ, thiết kế, hành vi, kiểm thử).
- Cài đặt và chạy: xem `README.md` (Docker + git worktree). **Luôn làm việc trong một git worktree riêng + Docker** — cho cả người lẫn AI.

## 2. Mô hình nhánh — Git Flow

Theo ADR-003 (xem `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` để biết lý do và sơ đồ đầy đủ).

- `main` — chỉ chứa bản đã phát hành; mỗi commit trên `main` đều có tag version tương ứng.
- `develop` — nhánh tích hợp công việc đang làm.
- `feature/*` — cắt từ `develop`, làm xong merge ngược về `develop`.
- `release/*` — cắt từ `develop` khi đủ nội dung; deploy môi trường Nghiệm thu; gắn tag release candidate `X.Y.Z-rc.N`.
- `hotfix/*` — cắt từ `main` khi production lỗi gấp.
- **Merge-back bắt buộc:** sau khi `release/*` hoặc `hotfix/*` hoàn tất, phải merge ngược về `develop` để bản vá không bị mất.
- **Cổng nhánh:** pull request đích `main` chỉ được đến từ `release/*` hoặc `hotfix/*` (branch-source guard sẽ ép ở CI — xem ADR-011).

## 3. Conventional Commits (commit message tiếng Anh)

- Định dạng: `type(scope): subject` — ví dụ `feat(billing): ...`.
- `type` thường dùng: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`.
- Liên hệ SemVer (ADR-004): `feat` → tăng MINOR; `fix` → tăng PATCH; có `BREAKING CHANGE:` trong body hoặc `type!` → tăng MAJOR.
- release-please dựa vào commit message để tự bump version + sinh changelog (ADR-008) → viết commit nghiêm túc, đúng `type`.
- Ví dụ:

```text
feat(billing): add cross-period comparison column
fix(meter): guard against stale lock_version on concurrent update
docs(sdlc): add CONTRIBUTING and canonical AGENTS files
```

- Nếu làm cùng AI, kết commit bằng dòng đồng tác giả theo quy ước repo:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## 4. Luồng làm một thay đổi

1. Tạo worktree + nhánh `feature/<việc>` từ `develop` (xem `README.md` để biết lệnh worktree + cổng Docker).
2. Code và test: `bin/docker rspec` (test phải cover mọi output của trang — xem `AGENTS.md`).
3. Chạy review AI local **trước khi push**: `/code-review` (ADR-009; dùng Claude sẵn có, không tốn thêm).
4. Mở pull request đích `develop` (với `feature/*`). CI xanh + chủ dự án duyệt → merge.
5. Pull request đích `main` chỉ đến từ `release/*` hoặc `hotfix/*`.

## 5. Pair lập trình / cùng test app đang chạy local — VS Code Dev Tunnels

Theo ADR-010.

- Trong VS Code hoặc Cursor: chạy app local (`bin/docker up`), mở tab **Ports**, chọn **Forward a Port** cho cổng nginx mà `bin/docker` gán cho worktree.
- Đặt visibility **Private** (mặc định) → người trong team đăng nhập GitHub để truy cập. **Không** để Public khi có dữ liệu thật.
- Dự phòng (cần URL ngoài editor hoặc không muốn bắt đăng nhập GitHub): **Cloudflare Tunnel**.
- Người không phải dev (ví dụ khách nghiệm thu): dùng **môi trường Nghiệm thu trên Railway** thay vì tunnel.

## 6. Phát hành

Quy trình đầy đủ + checklist: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.

Tóm tắt: đủ nội dung → `release/*` → deploy Nghiệm thu (`-rc.N`) → khách nghiệm thu → release-please tạo Release pull request → merge `main` + tag `X.Y.Z` → giao bản xuống production Mini PC + cập nhật môi trường Mốc → **merge-back về `develop`**.

## 7. Giao bản cho khách

- Dùng `bin/prepare-delivery` để tạo bản sạch trước khi ship: script xóa các file dev nội bộ (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.claude/`) và dọn git history. **KHÔNG** ship source code trực tiếp từ repo này.
- Chi tiết deploy production: `docs/HUONG_DAN_DEPLOY.md` và `docs/KIEN_THUC_DOCKER.md`.

## 8. Trạng thái tự động hoá

Một số guardrail (CI: `rspec`/`rubocop`/`brakeman`/`commitlint`/branch-guard; release-please; môi trường Railway Nghiệm thu + Mốc) sẽ được triển khai ở các giai đoạn sau của chuẩn hoá SDLC (P2–P4). Hiện tại các quy ước ở mục 2–3 được giữ bằng kỷ luật + review thủ công; xem mục Backlog trong release spec.

## Tài liệu liên quan

- `AGENTS.md` — quy ước canonical (code + quy trình).
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-001 (mô hình phát triển), ADR-002 (chiến lược tài liệu/tri thức).
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — ADR-003..011 (quy trình phát hành).
- `README.md` — cài đặt, lệnh thường dùng, môi trường.
`````

- [ ] **Step 2: Kiểm tra CONTRIBUTING.md đủ các mục yêu cầu**

Run:
```bash
test -f CONTRIBUTING.md && grep -n 'Git Flow\|Conventional Commits\|Dev Tunnels\|prepare-delivery' CONTRIBUTING.md
```
Expected: file tồn tại; tìm thấy cả 4 cụm từ (Git Flow, Conventional Commits, Dev Tunnels, prepare-delivery).

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs(sdlc): add CONTRIBUTING guide for human workflow

Document Git Flow, Conventional Commits, and local pairing via VS Code
Dev Tunnels (ADR-003, ADR-004, ADR-008, ADR-010), pointing back to
AGENTS.md and the SDLC specs.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Cập nhật README.md (bảng Tài liệu trỏ canonical)

**Files:**
- Modify: `README.md:121`

- [ ] **Step 1: Đọc vùng bảng "Tài liệu" để xác nhận dòng cần sửa**

Run: `sed -n '110,122p' README.md`
Expected: thấy dòng `| `CLAUDE.md` | Quy tắc code, convention |` (dòng 121).

- [ ] **Step 2: Thay dòng CLAUDE.md bằng hai dòng (AGENTS.md + CONTRIBUTING.md)**

Edit `README.md`:

old_string:
```
| `CLAUDE.md` | Quy tắc code, convention |
```
new_string:
```
| `AGENTS.md` | Quy ước code và quy trình — nguồn canonical (Claude Code đọc qua `CLAUDE.md` `@import`) |
| `CONTRIBUTING.md` | Quy trình đóng góp cho người (Git Flow, Conventional Commits, pair local) |
```

- [ ] **Step 3: Kiểm tra README đã trỏ đúng**

Run:
```bash
grep -n 'AGENTS\.md\|CONTRIBUTING\.md' README.md
```
Expected: thấy hai dòng mới trong bảng Tài liệu.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: point README docs table to canonical AGENTS.md

Replace the CLAUDE.md row with AGENTS.md (canonical conventions) and add
a CONTRIBUTING.md row.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Cập nhật bin/prepare-delivery (strip AGENTS.md + CONTRIBUTING.md)

Quyết định của chủ dự án: bản giao khách **xóa cả AGENTS.md và CONTRIBUTING.md** (coi là tài liệu dev/quy trình nội bộ, giống CLAUDE.md). Vì đây là coupling theo tên file do việc đổi canonical gây ra, phải cập nhật cùng P1 để conventions không lọt vào bản giao khách.

**Files:**
- Modify: `bin/prepare-delivery:57` (bước 3 — `rm`) và bước 4 (các lệnh `sed` trên README)

- [ ] **Step 1: Đọc lại 2 vùng cần sửa**

Run: `sed -n '55,65p' bin/prepare-delivery`
Expected: thấy `rm -rf .claude CLAUDE.md` và các dòng `sed ... README.md` / `... V2_THIET_KE_HE_THONG.md`.

- [ ] **Step 2: Thêm AGENTS.md + CONTRIBUTING.md vào lệnh `rm`**

Edit `bin/prepare-delivery`:

old_string:
```
rm -rf .claude CLAUDE.md
```
new_string:
```
rm -rf .claude CLAUDE.md AGENTS.md CONTRIBUTING.md
```

- [ ] **Step 3: Strip thêm tham chiếu AGENTS.md / CONTRIBUTING.md khỏi README trong bản giao**

Edit `bin/prepare-delivery`:

old_string:
```
sed -i '' '/CLAUDE\.md/d' README.md
```
new_string:
```
sed -i '' '/CLAUDE\.md/d' README.md
sed -i '' '/AGENTS\.md/d' README.md
sed -i '' '/CONTRIBUTING\.md/d' README.md
```

(Lưu ý: dòng bảng "Tài liệu" của AGENTS.md có chứa cả chuỗi `CLAUDE.md` nên sẽ bị `sed` đầu tiên xoá; hai `sed` thêm vào bảo đảm mọi tham chiếu khác — kể cả dòng CONTRIBUTING.md — cũng bị xoá trong bản giao.)

- [ ] **Step 4: Kiểm tra cú pháp script (KHÔNG chạy thật)**

Run:
```bash
bash -n bin/prepare-delivery && grep -n 'rm -rf .claude\|sed -i .. ./AGENTS\|sed -i .. ./CONTRIBUTING\|sed -i .. ./CLAUDE' bin/prepare-delivery
```
Expected: `bash -n` không in lỗi (exit 0); thấy dòng `rm -rf .claude CLAUDE.md AGENTS.md CONTRIBUTING.md` và 3 dòng `sed` xoá tham chiếu (CLAUDE/AGENTS/CONTRIBUTING) trên README.

- [ ] **Step 5: Commit**

```bash
git add bin/prepare-delivery
git commit -m "build: strip AGENTS.md and CONTRIBUTING.md from delivery build

Now that canonical conventions live in AGENTS.md, the customer delivery
build must remove it (and CONTRIBUTING.md) the same way it removes
CLAUDE.md, plus their README references, so internal conventions do not
leak into the shipped source.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Cập nhật docs/KIEN_THUC_DOCKER.md (mô tả file dev bị strip)

**Files:**
- Modify: `docs/KIEN_THUC_DOCKER.md` (header version + câu mô tả gần dòng 309)

- [ ] **Step 1: Đọc 2 vùng cần sửa**

Run:
```bash
sed -n '1,6p' docs/KIEN_THUC_DOCKER.md && echo "---" && grep -n 'Source code gốc chứa file phát triển' docs/KIEN_THUC_DOCKER.md
```
Expected: thấy `> **Phiên bản:** 1.8.0`, `> **Ngày:** 31/05/2026`, và câu chứa `(CLAUDE.md, .claude/)`.

- [ ] **Step 2: Thêm AGENTS.md + CONTRIBUTING.md vào danh sách file dev**

Edit `docs/KIEN_THUC_DOCKER.md`:

old_string:
```
(CLAUDE.md, .claude/)
```
new_string:
```
(CLAUDE.md, AGENTS.md, CONTRIBUTING.md, .claude/)
```

- [ ] **Step 3: Bump version + ngày của tài liệu**

File này có dòng phiên bản nhưng không có mục Changelog riêng → cập nhật tại chỗ. Edit `docs/KIEN_THUC_DOCKER.md`:

old_string:
```
> **Phiên bản:** 1.8.0
> **Ngày:** 31/05/2026
```
new_string:
```
> **Phiên bản:** 1.8.1
> **Ngày:** 07/06/2026
```

- [ ] **Step 4: Kiểm tra**

Run:
```bash
grep -n 'AGENTS.md, CONTRIBUTING.md' docs/KIEN_THUC_DOCKER.md && head -4 docs/KIEN_THUC_DOCKER.md
```
Expected: thấy danh sách file dev đã cập nhật; phiên bản `1.8.1`, ngày `07/06/2026`.

- [ ] **Step 5: Commit**

```bash
git add docs/KIEN_THUC_DOCKER.md
git commit -m "docs(docker): note AGENTS.md and CONTRIBUTING.md as stripped dev files

Keep the delivery description in sync with bin/prepare-delivery; bump
document version to 1.8.1.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: Kiểm tra nhất quán toàn cục (không commit code, chỉ verify)

**Files:** không sửa file; chỉ chạy kiểm tra.

- [ ] **Step 1: CLAUDE.md đúng là file import; AGENTS.md + CONTRIBUTING.md tồn tại**

Run:
```bash
head -1 CLAUDE.md && test -f AGENTS.md && test -f CONTRIBUTING.md && echo "OK files"
```
Expected: dòng đầu CLAUDE.md là `@AGENTS.md`; in `OK files`.

- [ ] **Step 2: Không còn tham chiếu CLAUDE.md "mồ côi" ngoài ý muốn**

Run:
```bash
grep -rIn 'CLAUDE\.md' --include='*.md' . | grep -v '\.claude/worktrees' | grep -v 'docs/superpowers/specs' | grep -v 'docs/superpowers/plans'
```
Expected: chỉ còn các tham chiếu **cố ý hợp lệ** (CLAUDE.md vẫn tồn tại như file import nên các trích dẫn prose trong `docs/V2_*` vẫn đúng): dòng import trong `CLAUDE.md`, ghi chú trong `AGENTS.md`/`CONTRIBUTING.md`, các trích dẫn `(CLAUDE.md)` trong `docs/V2_THIET_KE_HE_THONG.md` và `docs/V2_KICH_BAN_TEST.md`, và dòng mô tả trong `docs/KIEN_THUC_DOCKER.md`. **Không** được có tham chiếu nào ngụ ý CLAUDE.md là nơi chứa quy ước canonical (README đã chuyển sang AGENTS.md). Nếu có → sửa.

- [ ] **Step 3: prepare-delivery sẽ strip đủ 4 thứ**

Run:
```bash
bash -n bin/prepare-delivery && grep -c 'AGENTS.md\|CONTRIBUTING.md' bin/prepare-delivery
```
Expected: `bash -n` exit 0; đếm ≥ 3 (1 trong `rm`, 2 trong các `sed`).

- [ ] **Step 4: Không có thay đổi code ứng dụng → bỏ qua rspec**

Xác nhận `git status`/`git log` chỉ chạm tài liệu + script delivery, không chạm `app/`, `spec/`, `config/`, `db/`. Nếu đúng → **không cần** `bin/docker rspec` (docs-only). Nếu phát hiện đã lỡ chạm code app → dừng, báo, và chạy `bin/docker rspec`.

Run:
```bash
git diff --stat main...HEAD
```
Expected: chỉ liệt kê `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`, `bin/prepare-delivery`, `docs/KIEN_THUC_DOCKER.md`, và file plan này.

---

## Self-Review (đã chạy khi viết plan)

**1. Spec coverage (ADR-002, 4 lớp + 3 deliverable P1):**
- Lớp 2 "AGENTS.md canonical, ngắn gọn, trỏ chi tiết" → Task 1 (di trú nội dung bền + pointer SDLC + ghi chú giữ ngắn).
- "CLAUDE.md chỉ một dòng `@AGENTS.md`, không symlink" → Task 1 Step 3 (đã xác nhận cú pháp `@import`, đường dẫn tương đối, an toàn Windows).
- "CONTRIBUTING.md cho người: Git Flow + Conventional Commits + pair Dev Tunnels, trỏ về AGENTS.md + docs" → Task 2 (mục 2, 3, 5 + Tài liệu liên quan).
- Lớp 1 "Guardrails tự động" → ngoài P1 (P2–P4); CONTRIBUTING mục 8 nêu trạng thái → không khẳng định sai hiện trạng.
- Coupling đổi canonical (prepare-delivery, README, KIEN_THUC_DOCKER) → Task 3, 4, 5 (đã hỏi & chốt với chủ dự án: strip cả hai).

**2. Placeholder scan:** Không có "TBD/TODO/implement later". Mọi nội dung file viết đầy đủ; mọi lệnh có expected output.

**3. Type/string consistency:** Đường dẫn `@AGENTS.md`, tên file (`AGENTS.md`, `CONTRIBUTING.md`, `bin/prepare-delivery`, `docs/KIEN_THUC_DOCKER.md`) nhất quán giữa các task. Dòng commit co-author đồng nhất. README row AGENTS.md cố ý chứa chuỗi `CLAUDE.md` để `sed` cũ vẫn xoá được trong bản giao (đã giải thích ở Task 4).

**4. Quy ước:** Tài liệu tiếng Việt, commit tiếng Anh, không viết tắt (dùng "pull request", không "PR"); các tên chuẩn (Git Flow, SemVer, Conventional Commits, Dev Tunnels, ADR, CI) giữ nguyên theo specs.
