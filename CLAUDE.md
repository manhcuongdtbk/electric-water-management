# Phần mềm quản lý điện nước nội bộ (Electric Water Management)

## Dự án là gì
Web app thay thế phần mềm WinForms legacy, quản lý tiêu chuẩn và tiêu thụ điện cho đơn vị quân đội Việt Nam (cấp Sư đoàn, 13 đơn vị trực thuộc). Solo developer, deadline 25/5/2026.

## Tech stack
Rails 8, PostgreSQL, Tailwind (via tailwindcss-rails, không cần Node), Hotwire (Turbo + Stimulus), Devise, CanCanCan, paper_trail, Chartkick, pagy, ransack, RSpec, Docker.

## Quy ước code

### Ngôn ngữ
- Code, tên biến, tên model, comment: **tiếng Anh**
- Giao diện người dùng (view, flash message, label): **tiếng Việt** (dùng I18n, file `config/locales/vi.yml`)
- Commit message: tiếng Anh

### Rails conventions
- Chạy `bin/rubocop` trước khi commit
- Model validation luôn có, không tin user input
- Dùng `decimal` cho tất cả cột liên quan tiền và kW — **không dùng float**
- Không làm tròn số ở bất cứ đâu trong engine tính toán
- Scope dữ liệu theo `current_user.organization` — mỗi đơn vị chỉ thấy dữ liệu mình
- `paper_trail` cho mọi model có nhập liệu

### Test
- RSpec + FactoryBot + Shoulda Matchers
- Engine tính toán (bảng 22 cột) là ưu tiên test cao nhất — test từng cột với dữ liệu thật từ file Excel khách
- Chạy `bundle exec rspec` sau mỗi thay đổi logic

### Git
- Branch naming: `m1/feature-name`, `m2/feature-name` (theo milestone)
- Commit nhỏ, mỗi commit làm 1 việc rõ ràng

## Cấu trúc nghiệp vụ

### 2 cấp tổ chức (phẳng, chỉ dùng parent_id)
- Cấp 1: Sư đoàn (1 đơn vị)
- Cấp 2: 13 đơn vị trực thuộc (Sư đoàn bộ, Trung đoàn 101, 18, 95, Tiểu đoàn 14/15/16/17/18/24/25, Đại đội 26/29)

### 4 vai trò người dùng
- `admin_level1` — quản trị viên cấp 1 (Ban Doanh trại Sư đoàn)
- `admin_unit` — quản trị viên đơn vị (cấp 2)
- `commander` — chỉ huy đơn vị (chỉ xem, không thao tác)
- `tech` — đội kỹ thuật (quản lý tài khoản, nhật ký, sao lưu & phục hồi)

### Engine tính toán — bảng 22 cột
- 7 nhóm cấp bậc: 570 / 440 / 305 / 130 / 210 / 110 / 24 kW
- Bơm nước 2 khái niệm: tiêu chuẩn 9,45 kW/người/tháng (cố định) vs sử dụng thực tế (phân bổ từ trạm bơm theo quân số)
- 4 khoản trừ: Tiết kiệm (%), Tổn hao (phân bổ theo tỷ lệ kW — trừ khỏi tiêu chuẩn), Công cộng (2 cấp: Sư đoàn + đơn vị), Khác
- Tổn hao nằm trong "Số phải trừ" (trừ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng)
- Đơn giá thay đổi hàng tháng

### Database schema chính
organizations, users, contact_points, meters, personnel, rank_quotas (cột: rank_name, quota_kw, effective_from), monthly_periods, meter_readings, monthly_calculations, unit_configs, pump_stations, contact_point_other_deductions

### Routes & controllers
- `root` → `dashboard#show` (Dashboard + F12 báo cáo tổng hợp: tháng/quý/năm)
- `history#show` → F13 tra cứu lịch sử + so sánh cùng kỳ
- `monthly_summaries#show` → F11 bảng 22 cột (+ CSV export)
- CSV export: `respond_to format.csv` trên dashboard, history, monthly_summaries
- `audit_logs#index` → F19 nhật ký thay đổi (PaperTrail::Version, tech + admin_level1)
- `monthly_periods#index/edit/update` → F20 đơn giá điện (admin_level1 sửa)
- `rank_quotas#index/edit/update` → F21 định mức cấp bậc (admin_level1 sửa)
- `backups#index/create/restore/destroy_file` → Sao lưu & phục hồi (tech only, admin_level1 explicit cannot)

## Milestones
- M1 (14/4–23/4): ✅ DONE — DB + CRUD khai báo F01–F04 + Docker dev + RSpec 247 specs
- M2 (21/4–5/5): ✅ DONE — Nhập liệu F05–F07 + Engine F08–F10 + Bảng 22 cột F11 + RSpec 388 specs
- M3 (2/5–9/5): ✅ DONE — Phân quyền Devise F15–F18 + CanCanCan Ability 4 vai trò + RSpec 546 specs
- Pre-M4: ✅ DONE — Bug fix + deploy + import + system specs (688 specs)
- M4: ✅ DONE — Dashboard + F12 báo cáo (tháng/quý/năm) + F13 tra cứu lịch sử + F14 CSV export (771 specs)
- M5 PR1: ✅ DONE — F20 đơn giá + F21 định mức (PR#55, 786 specs)
- M5 PR2: ✅ DONE — F19 nhật ký hoạt động (PR#56, 795 specs)
- M5 PR3: ✅ DONE — Sao lưu & phục hồi + Docker production (PR#58, 836 specs)
- M6 (17/5–25/5): Bàn giao — staging + fix bug + đào tạo + nghiệm thu

## File tham chiếu nghiệp vụ
- `docs/SCOPE_DOCUMENT_v3.html` — phạm vi dự án đầy đủ (21 chức năng F01–F21)
- `docs/XAC_NHAN_NGHIEP_VU_v5.html` — nghiệp vụ đã xác nhận
- `docs/PROJECT_ROADMAP_v3.md` — lộ trình chi tiết từng milestone
- `test/fixtures/files/bang_tinh_thang_02.xlsx` — dữ liệu thật để test engine tính toán
