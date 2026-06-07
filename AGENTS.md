# AGENTS.md — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Nguồn canonical** cho mọi quy ước của dự án (code + quy trình), dùng chung cho cả người và mọi công cụ AI (Claude Code, Cursor, Copilot, Codex, Gemini, VS Code…).
>
> - **Công cụ AI khác** đọc trực tiếp file này.
> - **Claude Code** đọc qua `CLAUDE.md` (qua dòng `@AGENTS.md`).
> - **Người mới tham gia:** đọc thêm `CONTRIBUTING.md` (quy trình làm việc) và các spec trong `docs/superpowers/specs/`.
> - **Giữ file này NGẮN GỌN, mệnh lệnh.** Chi tiết và lý do nằm ở `docs/` — ở đây chỉ nêu quy ước rồi trỏ tới. Đừng nhồi chi tiết quy trình phát triển/phát hành vào đây (theo ADR-002).

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

## Môi trường và cách chạy (phát triển)

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

> **Ba môi trường (Development / Nghiệm thu + Mốc trên Railway / Production Mini PC offline) và mô hình phát hành:** xem `README.md` (tổng quan, lệnh, môi trường) và `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-005 môi trường và promotion). Không lặp lại chi tiết ở đây.

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

## Thuật ngữ: "environment" (application environment vs Rails environment)

Có HAI khái niệm "environment" khác nhau — khi nói/viết phải nói rõ kẻo nhầm:

- **Application environment** (môi trường ứng dụng / nơi triển khai): nhãn tiếng Anh do ops đặt qua biến `APPLICATION_ENVIRONMENT_LABEL` (ví dụ `Acceptance`, `Mirror`, `Production` trên Mini PC). Truy cập qua `SystemInfo.application_environment`; key JSON `/version` là `application_environment`. Đây là cái phân biệt hai môi trường Railway gần giống hệt và là cái hiển thị ở sidebar/đăng nhập/log/Excel.
- **Rails environment**: `Rails.env` (`development` / `test` / `production`) — chế độ runtime của framework. Key JSON `/version` là `rails_environment`.

Hai cái CÓ THỂ khác nhau (ví dụ Nghiệm thu và Mốc đều `rails_environment=production` nhưng `application_environment` khác). Mặc định trong dự án, "environment/môi trường" không kèm bổ nghĩa ở UI/log = **application environment**; còn nói tới Rails thì luôn gọi rõ `Rails.env`. Chi tiết: spec `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md`.

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
- Version và lịch sử thay đổi tài liệu: file meta ở gốc repo (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`) KHÔNG có version/changelog riêng (theo dõi qua git history). Tài liệu trong `docs/` (có `Phiên bản:` + `## Lịch sử thay đổi`) thì khi sửa PHẢI bump version và thêm entry trong cùng commit. Chi tiết và lý do: ADR-002 trong `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md`.
- Không tự mở rộng scope. Nếu thấy thiếu gì trong thiết kế → dừng lại, báo lỗi.

## Quy trình phát triển và phát hành (trỏ tới spec)

- **Mô hình phát triển + chiến lược tài liệu/tri thức:** `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` (ADR-001, ADR-002).
- **Quy trình phát hành** (Git Flow, SemVer + release candidate, release-please, môi trường, nội dung CI): `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` (ADR-003..011).
- **Quy trình cho người** (thao tác Git Flow, Conventional Commits, pair local bằng VS Code Dev Tunnels): `CONTRIBUTING.md`.

> Tóm tắt một dòng (chi tiết và lý do ở các spec trên — đừng lặp lại ở đây): nhánh theo **Git Flow** (`main` / `develop` / `feature/*` / `release/*` / `hotfix/*`); version theo **SemVer** kèm hậu tố `-rc.N` cho bản chờ nghiệm thu; commit theo **Conventional Commits** (tiếng Anh).

## Tài liệu liên quan

- `README.md` — tổng quan, cài đặt, lệnh thường dùng, môi trường.
- `CONTRIBUTING.md` — quy trình đóng góp cho người.
- `docs/` — nghiệp vụ, thiết kế, hành vi, kiểm thử, Docker, deploy.
- `docs/superpowers/specs/` — spec + ADR (quyết định kèm lý do); `docs/superpowers/plans/` — plan triển khai.
