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
- Model validation luôn có, không tin user input
- Dùng `decimal` cho tất cả cột liên quan tiền và kW — **không dùng float**
- Không làm tròn số ở bất cứ đâu trong engine tính toán
- Scope dữ liệu theo `current_user.organization` — mỗi đơn vị chỉ thấy dữ liệu mình
- `paper_trail` cho mọi model có nhập liệu

### Test
- RSpec + FactoryBot + Shoulda Matchers
- Engine tính toán là ưu tiên test cao nhất — test từng cột với dữ liệu thật từ file Excel khách
- Chạy `bundle exec rspec` sau mỗi thay đổi logic
- **KHÔNG cần chạy rubocop local** — CI đã cover

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

### Engine tính toán — bảng 24 cột
DB lưu 22 cột (`over_under_kw` + `total_amount` signed), view tách thành 24 cột (Thừa/Thiếu riêng).

- 7 nhóm cấp bậc — tên và định mức lấy từ `rank_quotas` trong DB (admin_level1 sửa được qua F21)
- Bơm nước 2 khái niệm:
  - **Tiêu chuẩn**: 9,45 kW/người/tháng (cố định theo nghị định)
  - **Sử dụng thực tế**: phân bổ từ trạm bơm theo mô hình fixed/variable (xem mục dưới)
- 4 khoản trừ: Tiết kiệm (%), Tổn hao (phân bổ theo tỷ lệ meter_consumption — trừ khỏi tiêu chuẩn), Công cộng (2 cấp: Sư đoàn + đơn vị), Khác
- Tổn hao nằm trong "Số phải trừ" (trừ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng)
- Công tơ `no_loss` (vị trí không tổn hao): loại khỏi loss pool + trừ khỏi supply khi tính tổn hao
- Đơn giá thay đổi hàng tháng

### Phân bổ bơm nước thực tế — mô hình fixed/variable (PR#72)
- `pump_station_assignments` gán trạm bơm cho organization, có cột `fixed_pump_percentage` (decimal 5,2, nullable)
- Organization có `fixed_pump_percentage` (ví dụ 30%) → nhận `tổng_bơm × percentage / 100`, KHÔNG chia theo quân số
- Organization có `fixed_pump_percentage = nil` → chia phần còn lại theo quân số
- Quân số của org cố định KHÔNG cộng vào tổng quân số chia phần còn lại
- `fixed_pump_percentage = 0` → coi là cố định (nhận 0 kW), không tham gia pool variable
- Tất cả nil → 100% chia theo quân số (backward compatible với logic trước PR#72)
- Trong nội bộ mỗi org (dù fixed hay variable), kW chia cho contact_points theo quân số
- Ví dụ tháng 02: tổng bơm 6420 kW, 30% cho "Chỉ huy Sư đoàn + nhà khách" = 1926 kW, 70% còn lại cho 557 người
- UI: `/pump_stations` — admin_level1 only

### Database schema chính
organizations, users, contact_points, meters (meter_type: normal/public/pump/no_loss), personnel, rank_quotas (cột: rank_name, quota_kw, effective_from), monthly_periods, meter_readings, monthly_calculations, unit_configs, pump_stations, pump_station_assignments (cột: fixed_pump_percentage — decimal nullable), contact_point_other_deductions

### Routes & controllers
- `root` → `dashboard#show` (Dashboard + F12 báo cáo tổng hợp: tháng/quý/năm)
- `history#show` → F13 tra cứu lịch sử + so sánh cùng kỳ
- `monthly_summaries#show` → F11 bảng 24 cột (+ CSV export)
- CSV export: `respond_to format.csv` trên dashboard, history, monthly_summaries
- `audit_logs#index` → F19 nhật ký thay đổi (PaperTrail::Version, tech + admin_level1)
- `monthly_periods#index/edit/update` → F20 đơn giá điện (admin_level1 sửa)
- `rank_quotas#index/edit/update` → F21 định mức cấp bậc (admin_level1 sửa)
- `pump_stations#index` + `pump_station_assignments#edit/update` → Phân bổ trạm bơm (admin_level1 only)
- `backups#index/create/restore/destroy_file` → Sao lưu & phục hồi (tech only, admin_level1 explicit cannot)

## Milestones
- M1–M5: DONE — F01–F21 đầy đủ + Docker production + 836 specs tại M5
- M6: ĐANG LÀM — Bàn giao — fix bug + pump 30/70 + test + nghiệm thu (891 specs)

## File tham chiếu nghiệp vụ
- `docs/SCOPE_DOCUMENT_v3_0_3.html` — phạm vi dự án đầy đủ (21 chức năng F01–F21)
- `docs/XAC_NHAN_NGHIEP_VU_v5_3_0.html` — nghiệp vụ đã xác nhận
- `docs/PROJECT_ROADMAP_v3_1.md` — lộ trình chi tiết từng milestone
- `test/fixtures/files/bang_tinh_thang_02.xlsx` — dữ liệu thật để test engine tính toán
