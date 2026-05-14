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
- Vietnamese number format: UI dùng dấu chấm phân cách hàng nghìn, dấu phẩy thập phân (ví dụ 2.336,4). CSV giữ raw numbers.
- Cross-zone scoping: tất cả controller phải dùng `accessible_by(current_ability).find(params[:id])` — KHÔNG dùng `Model.find(params[:id])` trực tiếp
- `paper_trail` cho mọi model có nhập liệu
- LockablePeriod concern: khi kỳ bị khóa, 7 controllers chặn data entry (nhưng cho phép recalculate)

### Test
- RSpec + FactoryBot + Shoulda Matchers
- Engine tính toán là ưu tiên test cao nhất
- Chạy `bundle exec rspec` sau mỗi thay đổi logic
- **KHÔNG cần chạy rubocop local** — CI đã cover

### Git
- Branch naming: `m1/feature-name`, `m2/feature-name` (theo milestone)
- Commit nhỏ, mỗi commit làm 1 việc rõ ràng

## Cấu trúc nghiệp vụ

### 3 cấp tổ chức
- Cấp 1: Sư đoàn (1 đơn vị) — không có đầu mối, không có công tơ, chỉ quản lý và cấu hình
- Cấp 2: 13 đơn vị trực thuộc — bắt buộc thuộc 1 khu vực (validation unit_must_have_zone)
- Cấp 3: Đầu mối (3 loại, xem bên dưới)

### Khu vực (Zone)
Vùng vật lý mà các đơn vị cấp 2 chia sẻ hạ tầng điện và nước. Mỗi khu vực gồm:
- Công tơ tổng (MainMeter) — hiện tại 1, tương lai có thể nhiều hơn. CRUD nested trong Zone show page.
- Trạm bơm nước (PumpStation) — có thể nhiều trạm, mỗi trạm có nhiều công tơ
- Đơn vị cấp 2 (Organization) — có thể nhiều đơn vị cùng chia sẻ
- Đơn vị quản lý khu vực (manager_organization) — 1 đơn vị cấp 2 được chỉ định nhập liệu hàng tháng

Trường hợp đơn vị có hạ tầng riêng = khu vực chỉ chứa 1 đơn vị.

Zone có CRUD UI đầy đủ (ZonesController). Zone show hiển thị: thông tin zone + bảng công tơ tổng (thêm/sửa/xóa) + danh sách đơn vị thuộc khu vực.

### Đầu mối — 3 loại (contact_point_type / WorkGroup)
- `residential` (sinh hoạt) — có công tơ, có quân số > 0, có dòng trong bảng thu tiền
- `communal` (công cộng) — có công tơ, quân số = 0, không có dòng trong bảng thu tiền
- WorkGroup (ngoài biên chế) — model riêng, có quân số nhập tay, không có công tơ, không có dòng trong bảng thu tiền, chỉ nhận bơm nước. **Thuộc đơn vị cấp 2** (owner_organization phải là unit). admin_unit manage own, commander read own, admin_level1 manage all.

Đầu mối có thể gộp theo khối (group_name) để hiển thị có cấu trúc.

### Công tơ (Meter) — 3 loại + 1 thuộc tính
meter_type enum:
- `normal` — công tơ sinh hoạt, thuộc đầu mối, đo điện sinh hoạt
- `public_meter` — công tơ công cộng, thuộc đầu mối, đo điện công cộng
- `pump_station` — công tơ bơm nước, thuộc trạm bơm (contact_point = nil), đo điện bơm nước

no_loss boolean (default: false):
- Đánh dấu công tơ không tổn hao (đặt tại trạm biến áp)
- Áp dụng cho bất kỳ loại nào, nhưng thực tế hiện tại chỉ có công tơ sinh hoạt

### 3 loại điện
- **Điện sinh hoạt** — đo bằng công tơ sinh hoạt, cộng vào tổng sử dụng điện
- **Điện bơm nước** — đo bằng công tơ bơm nước, phân bổ cho nhóm đối tượng rồi cộng vào tổng sử dụng điện
- **Điện công cộng** — đo bằng công tơ công cộng, tính khoản trừ công cộng (trừ khỏi tiêu chuẩn)

Tổng sử dụng điện = sử dụng điện sinh hoạt + sử dụng điện bơm nước (không bao gồm điện công cộng).

### 4 vai trò người dùng
- `admin_level1` — quản trị viên cấp 1: thiết lập ban đầu (đơn giá, tỷ lệ, định mức), tạo khu vực, gán đơn vị, chỉ định đơn vị quản lý, quản lý tài khoản, mở khóa tháng cũ, nhật ký. Toàn quyền thao tác mọi khu vực. Ngoại trừ: không sửa cấu hình công cộng/khác của đơn vị (cannot update_unit_config), không truy cập sao lưu (cannot manage backup).
- `admin_unit` — quản trị viên đơn vị: khai báo đầu mối/công tơ/quân số/đầu mối ngoài biên chế, nhập chỉ số công tơ hàng tháng, cấu hình công cộng đơn vị và cột Khác. Nếu là đơn vị quản lý khu vực: nhập số công tơ tổng, quản lý trạm bơm, nhập chỉ số trạm bơm, gán phân bổ bơm nước.
- `commander` — chỉ huy đơn vị (chỉ xem, không thao tác)
- `tech` — đội kỹ thuật (quản lý tài khoản, nhật ký, sao lưu & phục hồi)

### Engine tính toán — tách 3, điều phối bởi CalculationOrchestrator

```
CalculationOrchestrator (app/services/calculation_orchestrator.rb)
  ├── LossCalculator (app/services/loss_calculator.rb)
  ├── PumpAllocationCalculator (app/services/pump_allocation_calculator.rb)
  └── SummaryCalculator (app/services/summary_calculator.rb)
```

**CalculationOrchestrator:**
- Public interface: `CalculationOrchestrator.new(organization:, monthly_period:).call`
- Wire 3 services tuần tự: Loss → Pump → Summary → persist MonthlyCalculation
- Không chứa business logic — chỉ orchestration + persist

**LossCalculator (engine tính tổn hao):**
- Tính trên toàn khu vực (Zone)
- A = tổng số điện lực tất cả MainMeter trong zone − tổng sử dụng công tơ no_loss trong zone
- B = tổng sử dụng tất cả công tơ có tổn hao trong zone (normal + public_meter + pump_station)
- C = A − B (tổng tổn hao toàn khu vực). Nếu C < 0 → clamp về 0, thêm warning :negative_loss.
- Phân bổ: mỗi công tơ có tổn hao nhận = C × (sử dụng công tơ / B)

**PumpAllocationCalculator (engine tính bơm nước):**
- Zone-wide, nhận `loss_calculator:` injected để share memoization
- D = Σ(sử dụng điện công tơ bơm nước X + tổn hao công tơ bơm nước X)
- Nhóm đối tượng có tỷ lệ cố định → nhận D × tỷ lệ
- Phần còn lại chia theo quân số
- Organization/ContactPointGroup → chia tiếp xuống đầu mối theo quân số
- Output: `{allocations_by_cp, allocations_by_assignment, total_pool_kw}`

**SummaryCalculator (engine tổng hợp):**
- Nhận `loss_results:` + `pump_results:` injected (plain Hashes)
- Per contact_point: tiêu chuẩn, sử dụng, khoản trừ, chênh lệch, thành tiền
- Method: `compute(contact_points)` → Array<Hash>
- DB lưu 22 data columns. UI/CSV split over_under_kw → surplus_kw + deficit_kw và total_amount → surplus_amount + deficit_amount → hiển thị 28 cột.

### Nhóm đối tượng nhận bơm nước — 4 loại (PumpStationAssignment, polymorphic)
- Organization (đơn vị) — quân số = tổng quân số đầu mối, chia tiếp xuống đầu mối theo quân số
- ContactPointGroup (nhóm đầu mối) — quân số = tổng quân số đầu mối thành viên, chia tiếp xuống thành viên theo quân số
- ContactPoint (đầu mối lẻ) — quân số = quân số đầu mối đó, nhận trực tiếp
- WorkGroup (ngoài biên chế) — quân số nhập tay, nhận trực tiếp

Mỗi nhóm có fixed_pump_percentage (decimal, nullable):
- Có giá trị → nhận D × tỷ lệ (cố định)
- nil → chia phần còn lại theo quân số
- 0 → cố định nhận 0, không tham gia pool variable
- Tổng tỷ lệ cố định ≤ 100% per zone (validation cross tất cả pump_stations trong zone)

### Database schema chính
zones, organizations, users, contact_points (contact_point_type enum), work_groups, contact_point_groups, contact_point_group_memberships, main_meters, meters (meter_type enum + no_loss boolean), personnel, rank_quotas, monthly_periods (locked + locked_at + locked_by_id), meter_readings, main_meter_readings, monthly_calculations (22 data columns), unit_configs, pump_stations, pump_station_assignments (fixed_pump_percentage decimal nullable, polymorphic assignable), contact_point_other_deductions

### Sidebar — 5 nhóm

| Nhóm | Mục |
|---|---|
| XEM KẾT QUẢ | Tổng quan, Bảng tổng hợp, Tra cứu lịch sử |
| NHẬP LIỆU HÀNG THÁNG | Nhập số điện lực, Chỉ số đầu mối, Chỉ số bơm nước, Soát lại quân số |
| KHAI BÁO | Đầu mối, Đầu mối ngoài biên chế, Trạm bơm nước, Nhóm đầu mối, Cấu hình |
| THIẾT LẬP | Đơn vị, Khu vực, Đơn giá điện, Định mức cấp bậc |
| HỆ THỐNG | Tài khoản, Nhật ký hoạt động, Sao lưu dữ liệu |

Quy tắc: không "Quản lý"/"Danh sách". Sidebar item = heading trang = breadcrumb = flash.

### Routes & controllers
- `root` → `dashboard#show` — Tổng quan (tổng hợp tháng/quý/năm + CSV)
- `history#show` → Tra cứu lịch sử + so sánh cùng kỳ (+ CSV)
- `monthly_summaries#show` → Bảng tổng hợp 28 cột (+ CSV), sort group_name ASC NULLS LAST → name
- `electricity_supplies#show` → Nhập số điện lực (MainMeterReading)
- `meter_readings#show` → Chỉ số đầu mối
- `pump_station_readings#show` → Chỉ số bơm nước
- `personnel_reviews#show` → Soát lại quân số
- `contact_points` → Đầu mối CRUD
- `work_groups` → Đầu mối ngoài biên chế CRUD
- `pump_stations` → Trạm bơm nước CRUD + phân bổ
- `contact_point_groups` → Nhóm đầu mối CRUD
- `unit_configs#show` → Cấu hình (admin_unit sửa, admin_level1 xem)
- `organizations` → Đơn vị CRUD (admin_level1 only)
- `zones` → Khu vực CRUD (show page hiển thị công tơ tổng + đơn vị)
- `zones/:zone_id/main_meters` → Công tơ tổng CRUD nested trong Zone
- `monthly_periods` → Đơn giá điện (admin_level1 sửa)
- `rank_quotas` → Định mức cấp bậc (admin_level1 sửa)
- `users` → Tài khoản (admin_level1 + tech)
- `audit_logs` → Nhật ký hoạt động (admin_level1 + tech)
- `backups` → Sao lưu dữ liệu (tech only)

## Milestones
- M1–M5: DONE — F01–F21 đầy đủ + Docker production
- M6: ĐANG LÀM — Rà soát thiết kế + refactor + test + bàn giao.

## File tham chiếu
- `docs/TONG_HOP_THIET_KE_HE_THONG_v1_4_0.md` — thiết kế hệ thống đã chốt (nguồn sự thật duy nhất)
- `docs/SCOPE_DOCUMENT_v3_0_3.html` — phạm vi dự án (21 chức năng F01–F21)
- `docs/XAC_NHAN_NGHIEP_VU_v5_3_0.html` — nghiệp vụ đã xác nhận
