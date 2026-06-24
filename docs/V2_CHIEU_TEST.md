# Các chiều kiểm thử — Hệ thống quản lý điện nước nội bộ (Hệ thống v2)

> **Phiên bản:** 1.5.3
> **Ngày:** 24/06/2026
> **Tính chất:** Định nghĩa không gian kiểm thử. Mỗi chiều là một biến độc lập tạo code path khác nhau trong hệ thống. Giao điểm giữa các chiều là nơi bug dễ xảy ra nhất.
> **Nguồn:** Audit toàn bộ codebase, đối chiếu 4 tài liệu, 1378 test cases.

---

## 12 chiều kiểm thử

### Chiều 1 — Trạng thái kỳ (hệ thống)

Hệ thống luôn ở đúng 1 trong 3 trạng thái, quyết định ai được làm gì:

| Trạng thái | Điều kiện | Dữ liệu nghiệp vụ | Cấu trúc (zone, unit, CP, meter, block, group, rank) |
|---|---|---|---|
| A: Không có kỳ mở | Tất cả kỳ đã đóng, hoặc chưa có kỳ nào | Chỉ đọc. PeriodGuard chặn mọi tạo/sửa/xóa | Chỉ đọc |
| B: Kỳ mới nhất đang mở | Kỳ mở có year/month lớn nhất | Tạo/sửa/xóa được | Tạo/sửa/xóa được |
| C: Kỳ cũ mở lại | Kỳ mở KHÔNG phải kỳ mới nhất | Sửa data per kỳ được | StructureChangeGuard chặn mọi thay đổi cấu trúc |

Quy tắc xuyên suốt: chỉ có đúng 1 kỳ mở tại 1 thời điểm (database partial unique index).

### Chiều 2 — Vai trò

Hệ thống có 5 enum values trong database nhưng 7 vai trò thực tế:

| Ký hiệu | Vai trò | Cách xác định | Phạm vi |
|---|---|---|---|
| SA | Quản trị viên hệ thống | `role == "system_admin"` | Toàn hệ thống |
| DC | Chỉ huy Sư đoàn | `role == "division_commander"` | Toàn hệ thống, chỉ xem + tính toán lại |
| UA-ZM | Quản trị viên đơn vị quản lý khu vực | `role == "unit_admin"` + `Zone.kept.exists?(manager_unit_id: unit_id)` | Đơn vị mình + khu vực mình quản lý |
| UA | Quản trị viên đơn vị | `role == "unit_admin"` + không quản lý khu vực | Chỉ đơn vị mình |
| CMD-ZM | Chỉ huy đơn vị quản lý khu vực | `role == "commander"` + `Zone.kept.exists?(manager_unit_id: unit_id)` | Chỉ xem, phạm vi như UA-ZM |
| CMD | Chỉ huy đơn vị | `role == "commander"` + không quản lý khu vực | Chỉ xem, phạm vi như UA |
| TECH | Kỹ thuật viên | `role == "technician"` | Tài khoản, sao lưu, nhật ký. Không thấy dữ liệu nghiệp vụ |

DC là enum riêng trong database (`division_commander`), không thuộc đơn vị, không có biến thể zone-manager. Scope toàn hệ thống, chỉ xem — tương tự SA nhưng không có quyền tạo/sửa/xóa. Có quyền tính toán lại (giống SA và UA/UA-ZM; CMD/CMD-ZM không có quyền này).

UA-ZM và CMD-ZM không phải role riêng trong database. Xác định qua `current_zone_manager?` (dùng `Zone.kept` — khớp Ability). Zone đã xóa → user mất vai trò zone-manager.

### Chiều 3 — Trang và thao tác

18 trang, mỗi trang có tập thao tác và lớp bảo vệ riêng. Mọi trang đều có ít nhất 1 lớp kiểm soát truy cập:

| Nhóm | Trang | Thao tác | Kiểm soát truy cập | SA | DC | UA-ZM | UA | CMD-ZM | CMD | TECH |
|---|---|---|---|---|---|---|---|---|---|---|
| Xem kết quả | Tổng quan (/dashboard) | Xem | BusinessRoleRequired | Xem | Xem | Xem | Xem | Xem | Xem | Chặn |
| Xem kết quả | Bảng tính tiền (/billing) | Xem, recalculate, Excel | BusinessRoleRequired + authorize! | Xem+Tính+Excel | Xem+Tính+Excel | Xem+Tính+Excel | Xem+Tính+Excel | Xem+Excel | Xem+Excel | Chặn |
| Xem kết quả | Tra cứu lịch sử (/history) | Xem, so sánh | BusinessRoleRequired | Xem | Xem | Xem | Xem | Xem | Xem | Chặn |
| Nhập liệu | Nhập số điện lực (/electricity_supply) | Xem, sửa | BusinessRoleRequired + PeriodGuard + authorize! | Sửa | Xem (disabled) | Sửa | Chặn | Xem (disabled) | Chặn | Chặn |
| Nhập liệu | Chỉ số đầu mối (/meter_entries) | Xem, sửa, search, filter | BusinessRoleRequired + PeriodGuard (qua MeterReadingEntry) | Sửa + filter zone/unit + cột zone/unit | Xem (disabled) | Sửa | Sửa | Xem (disabled) | Xem (disabled) | Chặn |
| Nhập liệu | Chỉ số bơm nước (/pump_entries) | Xem, sửa, search, filter | BusinessRoleRequired + PeriodGuard (qua MeterReadingEntry) | Sửa + filter zone + cột zone (không có unit — bơm nước luôn thuộc khu vực) | Xem (disabled) | Sửa | Trống | Xem (disabled) | Trống | Chặn |
| Khai báo | Đầu mối (/contact_points) | CRUD | BusinessRoleRequired + PeriodGuard + StructureChangeGuard | CRUD | Xem | CRUD (đơn vị+khu vực) | CRUD (đơn vị) | Xem (đơn vị+khu vực) | Xem (đơn vị) | Chặn |
| Khai báo | Khối (/blocks) | CRUD | BusinessRoleRequired + PeriodGuard + StructureChangeGuard | CRUD | Xem | CRUD (đơn vị) | CRUD (đơn vị) | Xem (đơn vị) | Xem (đơn vị) | Chặn |
| Khai báo | Nhóm (/groups) | CRUD | BusinessRoleRequired + PeriodGuard + StructureChangeGuard | CRUD | Xem | CRUD (đơn vị) | CRUD (đơn vị) | Xem (đơn vị) | Xem (đơn vị) | Chặn |
| Khai báo | Cấu hình đơn vị (/unit_config) | Xem, sửa | BusinessRoleRequired + PeriodGuard | Sửa | Xem (disabled) | Sửa (đơn vị+khu vực OD) | Sửa (đơn vị) | Xem (disabled) | Xem (disabled) | Chặn |
| Thiết lập | Khu vực (/zones) | CRUD | SettingsAccessGuard (require_system_admin!) + PeriodGuard + StructureChangeGuard | CRUD | Xem | Chặn | Chặn | Chặn | Chặn | Chặn |
| Thiết lập | Đơn vị (/units) | CRUD | SettingsAccessGuard (require_system_admin!) + PeriodGuard + StructureChangeGuard | CRUD | Xem | Chặn | Chặn | Chặn | Chặn | Chặn |
| Thiết lập | Phân bổ bơm nước (/pump_allocations) | CRUD | SettingsAccessGuard (require_system_admin_or_zone_manager!) + PeriodGuard | CRUD | Xem | CRUD (khu vực) | Chặn | Xem (khu vực) | Chặn | Chặn |
| Thiết lập | Đơn giá điện (/pricing) | Mở/đóng/mở lại kỳ | SettingsAccessGuard (require_system_admin!) + authorize! | Toàn quyền | Xem | Chặn | Chặn | Chặn | Chặn | Chặn |
| Thiết lập | Nhóm cấp bậc (/ranks) | CRUD | SettingsAccessGuard (require_system_admin!) + PeriodGuard + StructureChangeGuard | CRUD | Xem | Chặn | Chặn | Chặn | Chặn | Chặn |
| Hệ thống | Tài khoản (/users) | CRUD | SettingsAccessGuard (require_account_manager!) + authorize! (CanCanCan) | CRUD (trừ TECH) | Chặn | Chặn | Chặn | Chặn | Chặn | CRUD (tất cả) |
| Hệ thống | Nhật ký (/audit_logs) | Xem | authorize!(:read, PaperTrail::Version) | Xem | Xem | Chặn | Chặn | Chặn | Chặn | Xem |
| Hệ thống | Sao lưu (/backups) | CRUD | authorize!(:manage, Backup) | Chặn | Chặn | Chặn | Chặn | Chặn | Chặn | CRUD |

### Chiều 4 — Trạng thái entity (kept / discarded)

Soft delete (discard) tạo ra sự phân biệt giữa entity "còn tồn tại" và "đã xóa":

| Trạng thái | `.kept` thấy | `.with_discarded` thấy | Ảnh hưởng |
|---|---|---|---|
| Kept (discarded_at = null) | Có | Có | Hiển thị bình thường, tham gia tính toán, xuất hiện trong dropdown |
| Discarded (discarded_at có giá trị) | Không | Có | Không hiện trên CRUD index, không hiện trong dropdown tạo mới, NHƯNG data kỳ cũ vẫn hiện khi xem lại |

Các entity có soft delete: Zone, Unit, ContactPoint, Meter, MainMeter, Block, Group.

Khi discard entity ở kỳ đang mở:
- Data per kỳ đang mở bị hard delete (cleanup callbacks)
- Data kỳ cũ giữ nguyên
- Kỳ mới (mở sau) không copy entity đã discard (PeriodService dùng `.kept`)

Kịch bản xuyên kỳ quan trọng nhất: tạo entity ở kỳ N-1 → đóng → mở kỳ N → xóa entity → xem lại kỳ N-1 → entity phải hiện trong data nhưng không hiện trong dropdown tạo mới.

### Chiều 5 — Loại đầu mối

4 loại đầu mối, mỗi loại có data structure, cleanup, và vai trò trong tính toán khác nhau:

| Loại | Có công tơ | Có quân số | Trên bảng tính tiền | Tham gia tính toán | Cleanup khi xóa |
|---|---|---|---|---|---|
| Sinh hoạt (residential) | Có | Có (personnel_entries per rank) | Có | Tiêu chuẩn + sử dụng + tổn hao + bơm nước | meter_readings + personnel_entries + other_deductions + pump_allocations |
| Công cộng (public) | Có | Không | Không | Tổn hao (tham gia mẫu số B) | meter_readings |
| Bơm nước (water_pump) | Có | Không | Không | Tổn hao + nguồn điện bơm nước | meter_readings |
| Ngoài biên chế (non_establishment) | Không | Có (personnel_count tổng) | Không | Nhận phân bổ bơm nước | non_establishment_snapshots + pump_allocations |

Test loại này đúng không đảm bảo loại kia đúng vì cleanup callbacks, trang nhập liệu, và engine xử lý mỗi loại khác nhau.

### Chiều 6 — Thuộc về (đơn vị / khu vực trực tiếp)

Contact point sinh hoạt và công cộng có thể thuộc đơn vị hoặc thuộc khu vực trực tiếp:

| Thuộc về | unit_id | zone_id | Ai quản lý | Filter zone | Billing |
|---|---|---|---|---|---|
| Đơn vị | Có | Null (lấy zone qua unit.zone_id) | UA/UA-ZM của đơn vị đó | `units.zone_id = :zid` | Có giá trị cột Đơn vị |
| Khu vực trực tiếp | Null | Có | UA-ZM của khu vực đó (hoặc SA) | `contact_points.zone_id = :zid` | Cột Đơn vị trống |

Contact point bơm nước và ngoài biên chế luôn thuộc khu vực trực tiếp.

Chiều này ảnh hưởng:
- Zone filter dùng OR: `contact_points.zone_id = :zid OR units.zone_id = :zid`
- Billing cột Đơn vị: trống cho CP thuộc khu vực trực tiếp
- Phân bổ bơm nước: đơn vị nhận rồi chia xuống CP, nhưng CP thuộc khu vực nhận trực tiếp
- Engine SummaryCalculator: CP thuộc khu vực không có unit_config → công cộng đơn vị = 0

### Chiều 7 — Kỳ đang xem ≠ kỳ đang mở

Billing và history có dropdown chọn kỳ để xem. Kỳ đang xem (context hiển thị) độc lập với kỳ đang mở (trạng thái hệ thống):

| Kỳ đang mở | Kỳ đang xem | Data hiển thị | Recalculate | Sửa được |
|---|---|---|---|---|
| N (mới nhất) | N | Data kỳ N | Có | Có (recalculate hoạt động) |
| N (mới nhất) | N-2 (đóng) | Data kỳ N-2 | Không (kỳ N-2 đóng) | Không |
| Không có | N-2 (đóng) | Data kỳ N-2 | Không | Không |
| N-2 (cũ mở lại) | N-2 | Data kỳ N-2 | Có | Sửa data per kỳ |
| N-2 (cũ mở lại) | N-1 (đóng) | Data kỳ N-1 | Không (kỳ N-1 đóng) | Không |

**Dropdown kỳ (tất cả role):** Mọi role truy cập billing đều có dropdown chọn kỳ (`@available_periods`). SA, UA-ZM, UA, CMD-ZM, CMD đều có thể xem data kỳ cũ bất kỳ. Vì vậy chiều 7 ảnh hưởng tất cả role, không chỉ SA.

**Dropdown zone/unit (chỉ SA):** SA có thêm dropdown chọn zone/unit trên billing. Dropdown luôn dùng `with_discarded` vì SA cần chọn được zone/unit đã xóa khi xem data kỳ cũ. Non-SA không có dropdown zone/unit — zone/unit lấy từ `current_user.unit` (belongs_to association, luôn trả record kể cả discarded).

Chiều này ảnh hưởng billing và history cho tất cả role (các trang khác luôn hiện kỳ đang mở hoặc không có period selector).

Kịch bản nguy hiểm: SA mở lại kỳ cũ N-2, nhưng trên billing chọn xem kỳ N-1. `current_period` trả N-2 (đang mở) nhưng UI hiện data N-1. Recalculate phải disabled vì N-1 đóng.

### Chiều 8 — Trạng thái tính toán

Calculations không tự động cập nhật. Phải bấm "Tính toán lại" để engine chạy:

| Trạng thái | Billing hiển thị | Dashboard hiển thị | Nguyên nhân |
|---|---|---|---|
| Chưa tính lần nào | Bảng trống (không có hàng data) | deficit/surplus = 0 | Kỳ mới mở, chưa ai bấm tính |
| Đã tính, data đúng | Kết quả chính xác | Số liệu có nghĩa | Tính sau khi tất cả đơn vị nhập xong |
| Stale (data thay đổi sau khi tính) | Kết quả cũ, không phản ánh data mới | Số liệu cũ | UA sửa meter_readings nhưng chưa tính lại |

Kịch bản nguy hiểm: SA xuất Excel khi calculations stale → file Excel có số liệu sai. Hoặc UA-ZM xem billing, thấy kết quả cũ → tưởng UA chưa nhập liệu.

### Chiều 9 — Mức độ đầy đủ dữ liệu

Engine tính toán dùng data từ nhiều nguồn. Thiếu nguồn nào → kết quả sai và cần cảnh báo:

| Thiếu gì | Ảnh hưởng tính toán | Cảnh báo |
|---|---|---|
| Đơn vị chưa nhập chỉ số công tơ | Tổn hao sai (B thiếu sử dụng) | "Đơn vị X chưa nhập chỉ số" |
| Chưa nhập số điện lực (main_meter_reading) | Tổn hao = 0 (A = 0) | "Chưa nhập số điện lực khu vực X" |
| Chưa cấu hình phân bổ bơm nước | Bơm nước = 0 | Không cảnh báo (hợp lệ — khu vực không có trạm bơm) |
| Khu vực chưa có đầu mối | Bỏ qua, không tính | Không cảnh báo (engine skip) |
| Tất cả công tơ đều không tổn hao (B = 0) | Tổn hao = 0, clamp | "Không có công tơ có tổn hao" |
| Tổng công tơ con > công tơ tổng (C < 0) | Tổn hao = 0, clamp | "Tổng công tơ con lớn hơn công tơ tổng" |

Chiều này giao với vai trò: SA thấy cảnh báo toàn hệ thống, UA chỉ thấy cảnh báo khu vực mình.

### Chiều 10 — Vị trí phân cấp của đầu mối

Đầu mối sinh hoạt có thể nằm ở 5 vị trí trong cấu trúc hiển thị:

| Vị trí | block_id | group_id | Cột Khối | Cột Nhóm | Cột Đơn vị |
|---|---|---|---|---|---|
| Trực tiếp đơn vị | null | null | Trống | Trống | Có |
| Trong khối, không nhóm | có | null | Merge | Trống | Có |
| Trong nhóm trực tiếp (không khối) | null | có | Trống | Merge | Có |
| Trong nhóm trong khối | có | có | Merge | Merge | Có |
| Thuộc khu vực trực tiếp | null | null | Trống | Trống | Trống |

Chiều này ảnh hưởng:
- Billing table: rowspan/merge logic cho 4 cột (Khu vực, Đơn vị, Khối, Nhóm)
- Excel export: cùng merge logic — sai cell merge = file Excel vỡ layout
- Sort order: `NULLS LAST` cho block/group
- Xóa khối/nhóm cascade: CP di chuyển lên cấp trên (vị trí 4 → xóa nhóm → thành vị trí 2, xóa khối → thành vị trí 1)

### Chiều 11 — Cách entity nhận data cho kỳ

Cùng 1 entity trong cùng 1 kỳ, data ban đầu có thể đến từ 3 đường khác nhau. Áp dụng cho TẤT CẢ data per kỳ:

| Data per kỳ | Kế thừa (mở kỳ mới, entity đã tồn tại) | Tạo giữa kỳ (after_create callback) | Kỳ đầu tiên (defaults) |
|---|---|---|---|
| meter_readings.reading_start | = reading_end kỳ trước (editable) | = 0 (editable) | User nhập tay |
| meter_readings.no_loss | = meters.no_loss (giá trị hiện tại) | = meters.no_loss | = meters.no_loss |
| personnel_entries | Copy count từ kỳ trước (match by rank position) | Từ form tạo (cho mỗi rank hiện có) | Từ form tạo |
| other_deductions | Copy type + value từ kỳ trước | fixed, 0 | fixed, 0 |
| unit_configs | Copy unit_public_rate từ kỳ trước | unit_public_rate = 0% | unit_public_rate = 0% |
| non_establishment_snapshots | Copy personnel_count từ kỳ trước (hoặc contact_point.personnel_count) | = contact_point.personnel_count | = contact_point.personnel_count |
| pump_allocations | Copy coefficient + fixed_percentage từ kỳ trước | Không tự tạo (user thêm thủ công) | Không tự tạo |
| main_meter_readings | **KHÔNG kế thừa** — nhập mới mỗi kỳ | Không tự tạo (user nhập trên /electricity_supply) | Không tự tạo |
| ranks | Copy name + quota + position từ kỳ trước | Không áp dụng (rank là cấu hình chung, không per entity) | 7 ranks mặc định (570, 440, 305, 130, 210, 110, 24) |

Kịch bản quan trọng:
- Rank mới thêm giữa kỳ → entity kế thừa có N personnel_entries, entity tạo giữa kỳ có N+1 (after_create tạo cho rank mới)
- Entity tạo giữa kỳ có reading_start = 0 → sử dụng = reading_end - 0 = reading_end (có thể rất lớn nếu công tơ không mới lắp)
- Đơn vị mới tạo giữa kỳ → unit_config tự tạo với unit_public_rate = 0%, other_deductions của các CP trong đơn vị mới cũng = 0
- Đóng kỳ cũ sau khi sửa → cảnh báo mismatch reading_end vs reading_start kỳ kế tiếp
- main_meter_readings không kế thừa → mỗi kỳ mới, /electricity_supply hiện "Chưa nhập" cho tất cả main_meters

### Chiều 12 — Định dạng output (HTML vs Excel)

Billing có 2 format output, code path hoàn toàn khác nhau:

| Khía cạnh | HTML (ERB + Tailwind) | Excel (caxlsx) |
|---|---|---|
| Giá trị tính toán | Render từ calculations table | Render từ calculations table |
| Tổng quân số | Helper cộng | **Excel formula `=SUM(...)`** |
| Tổng tiêu chuẩn | Giá trị | **Formula `=residential + water_pump`** |
| Tổng trừ | Giá trị | **Formula `=SUM(savings:other)`** |
| Tiêu chuẩn còn lại | Giá trị | **Formula `=total_std - total_deduction`** |
| Thành tiền | Giá trị | **Formula `=kw * unit_price`** |
| Hàng tổng | Helper | **Formula `=SUM(column_range)`** |
| Merge/rowspan | ERB rowspan attribute | Cell merge `merge_cells` |
| Số cột | Dynamic (28/29/30 theo role + filter) | Phải dynamic theo cùng logic |
| Định dạng số | `number_to_vi` helper | Excel `num_fmt` |

Excel formulas reference cell positions (column index). Khi số cột thay đổi theo role (SA 30 cột, UA 28 cột), column index phải thay đổi theo. Nếu formula reference sai cell → Excel sai mà HTML đúng.

---

## Input → expected output

Mỗi test case = input + expected output. Output gồm 2 phần:

- **Backend**: DB state, redirect, flash message, session
- **Hiển thị**: thứ user thực sự nhìn thấy trên màn hình

Cả 2 phần đều phải verify. Backend đúng nhưng hiển thị sai = bug. Hiển thị đúng nhưng backend sai = bug.

### Expected output hiển thị (áp dụng mọi trang)

Mỗi trang khi render phải verify các output hiển thị sau:

| Output hiển thị | Chi tiết | Ví dụ sai |
|---|---|---|
| Cột hiển thị | Đúng số cột theo role + filter. Billing: SA 30 cột, UA-ZM 29, UA 28. CRUD: SA có Khu vực + Đơn vị, non-SA không có | SA chọn zone → cột Khu vực phải ẩn. Nếu vẫn hiện = bug |
| Nội dung ô | Data đúng từ DB, số format tiếng Việt (dấu chấm nghìn, dấu phẩy thập phân), kW 2 chữ số thập phân, tiền 0 chữ số, làm tròn ROUND_HALF_UP | Hiện "96578.38" thay vì "96.578,38" = bug |
| Merge/rowspan | Khối/Nhóm/Đơn vị/Khu vực merge đúng theo vị trí phân cấp (chiều 10). Các dòng cùng giá trị liên tiếp merge thành 1 ô | CP thuộc khu vực trực tiếp: cột Đơn vị phải trống (không hiện text "—" hay placeholder) |
| Hàng tổng | Tổng tính trên kết quả đã filter (không phải toàn bộ DB). Mọi trang có danh sách số liệu phải có hàng tổng | Filter zone → hàng tổng chỉ cộng records trong zone đó |
| Nút và link | Hiện/ẩn đúng theo `can?()`. Thêm, Sửa, Xóa, Tính toán lại, Xuất Excel | CMD thấy nút Xóa = bug. UA thấy Tính toán lại = đúng |
| Input state | CMD: tất cả input disabled + ẩn nút Lưu. Kỳ cũ mở lại: field cấu trúc disabled, field data per kỳ enabled. reading_start editable mọi kỳ (pre-filled từ kỳ trước nhưng sửa được) | CMD thấy input enabled = bug |
| Dropdown options | Đúng per role. Zone/unit dropdown: SA thấy tất cả, non-SA không thấy. Loại CP: UA 2 loại (sinh hoạt, công cộng), UA-ZM/SA 4 loại. Kỳ cũ: dropdown hiện entity đã xóa (`with_discarded`) | UA thấy dropdown loại "bơm nước" = bug (chỉ UA-ZM/SA mới thấy) |
| Cảnh báo | Billing: cảnh báo thiếu dữ liệu ("Đơn vị X chưa nhập"), tổn hao bất thường. Dashboard: cảnh báo tương tự. Hiện đúng per role (SA thấy toàn hệ thống, UA thấy khu vực mình) | SA không thấy cảnh báo khi đơn vị chưa nhập = bug |
| Sidebar | Đúng items per role (chiều 3 bảng quyền). TECH: 3 items. SA: 17 items. DC: 16 items (tất cả trừ Tài khoản và Sao lưu, chỉ xem). UA: 8 items. UA-ZM: 11 items. CMD: 8 items (khớp UA). CMD-ZM: 11 items (khớp UA-ZM). CMD/DC thấy cùng trang nhưng chỉ xem (inputs disabled, nút ẩn) | CMD thấy nút Sửa/Xóa trên trang chỉ xem = bug |
| Trạng thái rỗng | "Không có bản ghi" khi danh sách trống. Billing chưa tính: bảng trống (không phải lỗi 500) | Billing chưa tính lần nào → lỗi 500 = bug |
| Thông tin kỳ | Hiện kỳ đang mở ("Kỳ tháng 5/2026 đang mở"). Khi không có kỳ mở: "Không có kỳ đang mở" + trang nhập liệu disable mọi ô | Không hiện thông báo kỳ = user không biết trạng thái |
| Pagination info | "Hiển thị X-Y / Z bản ghi". Z = `@total_count` (sau filter). Per page dropdown giữ giá trị đã chọn | Z hiện tổng toàn DB thay vì tổng sau filter = bug |
| Hover highlight | Hover dòng → highlight dòng đó. Mọi trang danh sách | — |

### R (Read/List) — trang danh sách

5 loại input chung cho mọi trang danh sách (nghiệp vụ mục 19):

| Input | Param | Expected output |
|---|---|---|
| Tìm kiếm text | `q` = "Ban" | Danh sách chỉ chứa records match "Ban". `@total_count` thay đổi. Ô search giữ text "Ban". Hàng tổng tính trên kết quả filtered |
| Tìm kiếm ký tự đặc biệt | `q` = "100%" | `%` match literal — chỉ tìm "100%", không match "1000". Tương tự `_` match literal |
| Tìm kiếm rỗng | `q` = "" hoặc nil | Trả toàn bộ records, không filter |
| Sắp xếp | `sort` = "name", `dir` = "asc" | Danh sách sắp xếp A→Z. Header cột có indicator hướng. Params sort+dir preserved khi paginate |
| Sort không hợp lệ | `sort` = "hacked_column" | Bỏ qua, dùng sort mặc định. Không SQL injection |
| Chọn filter | `zone_id` = 1 | Danh sách chỉ chứa records thuộc zone 1. `@total_count` thay đổi. Dropdown giữ giá trị đã chọn |
| Đổi filter | Zone 1 → Zone 2 | Danh sách đổi sang zone 2. Unit dropdown reset (cascade). Search text giữ nguyên |
| Xóa bộ lọc | Click "Xóa bộ lọc" | Tất cả filter reset, search reset, sort reset. Danh sách hiện toàn bộ |
| Filter + search | `zone_id` = 1, `q` = "Ban" | Kết hợp cả 2: chỉ records thuộc zone 1 VÀ match "Ban" |
| Per page | `per_page` = 10 | Hiện tối đa 10 dòng. Pagination hiện đúng số trang. Per page dropdown giữ giá trị 10 |
| Per page ngoài danh sách | `per_page` = 999 | Fallback về giá trị mặc định (25) |
| Trang cuối | `page` = last | Hiện dòng cuối. Nút "Trang sau" disabled hoặc ẩn |

Input đặc thù per trang:

| Trang | Input | Expected output |
|---|---|---|
| Bảng tính tiền (/billing) | Chọn kỳ (`period_id`) | Page reload với data kỳ đó. Period dropdown giữ giá trị. Tất cả filter/search reset |
| Bảng tính tiền (/billing) | Dropdown zone/unit (SA only) | Data filtered. Cột Khu vực ẩn khi chọn zone. Cột Đơn vị ẩn khi chọn unit |
| Tra cứu lịch sử (/history) | Chọn kỳ A + kỳ B (compare) | Bảng so sánh 2 cột + cột chênh lệch. CP chỉ có ở 1 kỳ → cột kỳ thiếu trống + ghi chú |
| Tra cứu lịch sử (/history) | Chọn khoảng (range) | Danh sách tổng quan per kỳ trong khoảng |
| Đầu mối (/contact_points) | Lọc theo loại (`type`) | Danh sách chỉ chứa loại đó. Dropdown loại hiển thị đúng per role (UA: 2 loại, UA-ZM/SA: 4 loại) |
| Nhật ký (/audit_logs) | Filter event + item_type + whodunnit + date range | Kết hợp tất cả filter. Kết quả chỉ chứa records match tất cả điều kiện |

### Tương tác giữa các input (cascade, conditional, dynamic)

Nhiều trang dùng chung pattern tương tác input. Sửa 1 chỗ phải test tất cả trang dùng chung pattern đó.

**Cascade dropdown (parent → child):**

| Pattern | Stimulus controller | Trang |
|---|---|---|
| Zone → Unit (index filter) | `reset_child_select` + `auto_submit` (qua `_list_toolbar`) | billing (SA), contact_points (SA), blocks (SA), groups (SA), users (SA), unit_config (SA) |
| Zone → Unit/CP (form) | `pump_allocation_form` | pump_allocations form |
| Unit → Block (form) | `scoped_block_select` | groups form (SA) |

Expected output cascade:
- Chọn parent → child dropdown chỉ hiện items thuộc parent
- Đổi parent → child reset về "Tất cả" / blank
- Chọn child mà chưa chọn parent → auto-select parent
- Page auto-submit sau mỗi thay đổi (index) hoặc giữ form state (form)
- Nguyên tắc này phải nhất quán trên mọi trang dùng chung pattern

**Toggle hiện/ẩn field:**

| Pattern | Stimulus controller | Trang |
|---|---|---|
| Đơn vị / Khu vực ownership | `contact_point_assignment` | contact_points form residential + public (SA và UA-ZM) |
| Role → Unit field | `role_unit_toggle` | users form |
| Target: đơn vị / đầu mối | `pump_allocation_form` | pump_allocations form |
| Allocation: phần trăm cố định / hệ số | `pump_allocation_form` | pump_allocations form |

Expected output toggle:
- Chọn option A → fields A hiện, fields B ẩn
- Chọn option B → ngược lại
- Fields ẩn không gửi lên server (hoặc server bỏ qua)
- Đổi toggle không được mất data đã nhập ở fields khác

**Dynamic form elements:**

| Pattern | Stimulus controller | Trang |
|---|---|---|
| Thêm/xóa công tơ (nested) | `nested_meters` | contact_points form (residential, public, water_pump) |
| Chọn loại đầu mối → redirect form | `type_redirect` | contact_points new |

Expected output dynamic:
- Thêm meter → field mới xuất hiện với name + no_loss
- Xóa meter → field biến mất (đánh dấu _destroy, không biến mất ngay nếu chưa submit)
- Submit → meters tạo/xóa đúng trong DB
- Chọn loại → redirect sang form đúng loại, giữ data đã nhập (nếu có)

**Auto-submit khi input thay đổi:**

| Pattern | Stimulus controller | Trang |
|---|---|---|
| Filter dropdown change → submit | `auto_submit` | Mọi index page qua `_list_toolbar` |
| Per page change → submit | `per_page` | Mọi index page |
| Period selector change → submit | `auto_submit` | billing, history, pricing |

Expected output auto-submit:
- Đổi dropdown → form auto-submit → page reload với data mới
- Giá trị dropdown đã chọn giữ nguyên sau reload
- Các input khác (search, sort) giữ nguyên hoặc reset tùy design (filter giữ search, period reset filter)

**Conditional field theo giá trị data:**

| Pattern | Cách xử lý | Trang |
|---|---|---|
| reading_end < reading_start → hiện manual_usage + note | View template (không dùng Stimulus) | meter_entries, pump_entries |
| Other deduction type (fixed/coefficient) → ý nghĩa giá trị khác | View template | unit_config |

Expected output conditional:
- reading_end < reading_start → hiện thêm 2 field (manual_usage bắt buộc, note tùy chọn). Engine dùng manual_usage thay vì end - start
- reading_end ≥ reading_start → ẩn manual_usage + note. Engine dùng end - start
- Other deduction fixed → giá trị là kW tuyệt đối. Coefficient → giá trị nhân với quân số đầu mối

### C (Create) — form tạo mới

Ngoài output backend dưới đây, mỗi thao tác tạo phải verify cả output hiển thị (xem bảng "Expected output hiển thị" ở trên): record mới hiện trên danh sách sau redirect, flash message hiện đúng tiếng Việt, sidebar/nút/cột không thay đổi sai.

| Input | Expected output thành công | Expected output thất bại |
|---|---|---|
| Field bắt buộc đầy đủ (name, type, zone/unit) | Redirect index + flash "đã tạo" + record trong DB + data per kỳ tạo đúng (meter_readings, personnel_entries, other_deductions, unit_configs theo chiều 11) | — |
| Field bắt buộc thiếu (name trống) | — | Re-render form + lỗi tiếng Việt dưới field + data đã nhập giữ nguyên + không tạo record |
| Nested meters (tạo CP kèm ≥ 1 meter) | Redirect + CP và meters đều trong DB + meter_readings tạo cho kỳ đang mở | — |
| Không có meter (residential/public/water_pump) | — | Re-render form + lỗi "phải có ít nhất 1 công tơ" |
| Personnel counts (residential, tổng ≥ 1) | Redirect + personnel_entries tạo cho mỗi rank trong kỳ đang mở | — |
| Personnel tổng = 0 | — | Re-render form + lỗi "tổng quân số phải ≥ 1" |
| Giá trị biên (0, 100%, âm) | Theo ràng buộc mục 24 nghiệp vụ: ≥ 0 cho readings, > 0 cho unit_price/quota, cho phép âm cho other_deduction | Lỗi validation tiếng Việt tương ứng |
| Tên trùng trong cùng phạm vi | — | Re-render form + lỗi "đã tồn tại" |
| Field tùy chọn bỏ trống (block_id, group_id, no_loss) | Giá trị mặc định (no_loss = false, block/group = null) | — |

### U (Update) — cập nhật

Ngoài output backend dưới đây, mỗi thao tác cập nhật phải verify cả output hiển thị: giá trị mới hiện đúng sau redirect, form lỗi hiện validation message tiếng Việt dưới field sai + giữ data đã nhập ở field đúng.

| Input | Expected output thành công | Expected output thất bại |
|---|---|---|
| Field mutable (name, block_id, group_id, no_loss) | Redirect + flash "đã cập nhật" + DB thay đổi + kỳ đang mở cập nhật snapshot nếu cần (meter_readings.no_loss) | — |
| Field immutable (contact_point_type, unit.zone_id) | Redirect + flash "đã cập nhật" + field immutable KHÔNG đổi trong DB (server bỏ qua) | — |
| lock_version cũ (concurrent edit) | — | Flash "dữ liệu đã bị thay đổi bởi người khác" + hiện data mới nhất + user xem lại rồi quyết định |
| Batch update thành công (meter_entries: N readings) | Redirect + flash "đã lưu" + TẤT CẢ N records cập nhật trong DB | — |
| Batch update 1 record lỗi | — | Rollback TẤT CẢ (transaction) + flash lỗi chỉ rõ record nào sai + re-render form với data mới nhất |
| Kỳ cũ mở lại: sửa data per kỳ (reading_end, quân số) | Redirect + DB cập nhật cho kỳ cũ đó, không ảnh hưởng kỳ khác | — |
| Kỳ cũ mở lại: sửa cấu trúc (tên, tạo/xóa entity) | — | StructureChangeGuard chặn + flash "đang mở kỳ cũ, chỉ cho phép sửa số liệu" |

### D (Delete) — xóa

Ngoài output backend dưới đây, mỗi thao tác xóa phải verify cả output hiển thị: record biến mất khỏi danh sách sau redirect, flash message đúng (thành công hoặc lỗi tiếng Việt), entity con bị ảnh hưởng hiện đúng vị trí mới (cascade).

| Input | Expected output thành công | Expected output thất bại |
|---|---|---|
| Xóa entity bình thường | Redirect index + flash "đã xóa" + entity discarded + data kỳ mở hard delete + data kỳ cũ nguyên | — |
| Xóa công tơ cuối cùng | — | Flash "phải có ít nhất 1 công tơ" + không xóa |
| Xóa đơn vị có đầu mối | — | Flash "phải xóa hết đầu mối trước" + không xóa |
| Xóa đơn vị có tài khoản | — | Flash "phải xóa hết tài khoản trước" + không xóa |
| Xóa khu vực có đơn vị | — | Flash "phải xóa hết đơn vị trước" + không xóa |
| Xóa rank đang có quân số > 0 | — | Flash "phải chuyển hết quân số trước" + không xóa |
| Xóa tài khoản mặc định | — | Flash lỗi + không xóa |
| Tự xóa mình | — | Flash lỗi + không xóa |
| Xóa khối có nhóm/CP | Redirect + khối discarded + nhóm.block_id = null, CP.block_id = null (lên đơn vị) | — |
| Xóa nhóm có CP | Redirect + nhóm discarded + CP.group_id = null (lên khối nếu có, hoặc lên đơn vị) | — |
| Xóa đơn vị quản lý khu vực | Redirect + flash cảnh báo + zones.manager_unit_id = null | — |
| Xóa CP có pump_allocation kỳ mở | Redirect + CP discarded + pump_allocation kỳ mở bị xóa + pump_allocation kỳ cũ giữ nguyên | — |

### Thao tác đặc biệt (không phải CRUD)

| Input | Expected output thành công | Expected output thất bại |
|---|---|---|
| Recalculate (SA/UA/UA-ZM) | Redirect billing + flash "đã tính toán" + calculations cập nhật cho toàn zone + warnings nếu data thiếu | — |
| Recalculate (CMD) | — | Redirect + flash "không có quyền" |
| Recalculate kỳ đóng | — | Redirect + flash "kỳ đã đóng" |
| Xuất Excel | File xlsx download + data khớp HTML + formulas đúng + merge đúng + số cột đúng theo role (SA 30, UA-ZM 29, UA 28) | — |
| Mở kỳ mới (SA) | Redirect + period mới (closed=false) + auto year/month + snapshot kế thừa đầy đủ (chiều 11) + kỳ trước vẫn nguyên | — |
| Mở kỳ mới khi có kỳ đang mở | — | Flash "phải đóng kỳ hiện tại trước" |
| Đóng kỳ (SA) | Redirect + period.closed = true + cảnh báo mismatch reading_end nếu có | — |
| Mở lại kỳ cũ (SA) | Redirect + period cũ.closed = false + StructureChangeGuard active | — |
| Mở lại kỳ cũ khi có kỳ đang mở | — | Flash "phải đóng kỳ hiện tại trước" |
| Backup (TECH) | Redirect + file backup tạo + flash "đã tạo" | — |
| Backup khi đã 3 bản | — | Flash "đã đạt tối đa" |
| Restore (TECH) | Redirect + DB khôi phục về bản backup + flash "đã khôi phục" | — |
| Reset mật khẩu (SA/TECH) | Redirect + mật khẩu mới set + force_password_change = true | — |
| Đổi mật khẩu hợp lệ | Redirect + mật khẩu đổi + force_password_change = false | — |
| Đổi mật khẩu không đủ phức tạp | — | Re-render form + lỗi "phải có ít nhất 1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt" |

---

## Giao điểm nguy hiểm

Không phải mọi tổ hợp 12 chiều đều cần test. Các giao điểm sau là nơi bug dễ xảy ra nhất:

### Nhóm 1: Kỳ × Vai trò × Entity state

Giao điểm giữa chiều 1, 2, 4 — "ai thấy gì khi entity đã xóa ở kỳ khác":

- Tạo CP ở kỳ N-1 → đóng → mở kỳ N → xóa CP → mở lại kỳ N-1 → 7 vai trò thấy gì?
- SA xem billing kỳ N-1: CP đã xóa phải hiện (data per kỳ còn)
- UA xem billing kỳ N: CP đã xóa không hiện (data kỳ N đã cleanup)
- SA dropdown zone/unit kỳ N-1: phải hiện zone/unit đã xóa (`with_discarded`)

### Nhóm 2: Kỳ × Loại đầu mối × Cleanup

Giao điểm giữa chiều 1, 5 — "xóa từng loại đầu mối cleanup đúng data":

- Xóa residential: phải xóa meter_readings + personnel_entries + other_deductions + pump_allocations cho kỳ đang mở
- Xóa public: phải xóa meter_readings cho kỳ đang mở
- Xóa water_pump: phải xóa meter_readings cho kỳ đang mở
- Xóa non_establishment: phải xóa non_establishment_snapshots + pump_allocations cho kỳ đang mở
- Tất cả: data kỳ cũ giữ nguyên

### Nhóm 3: Vai trò × Thuộc về × Trang

Giao điểm giữa chiều 2, 6, 3 — "role nào thấy CP nào trên trang nào":

- UA: chỉ thấy CP thuộc đơn vị mình trên mọi trang
- UA-ZM: thấy CP đơn vị mình + CP thuộc khu vực trên billing, meter_entries, unit_config
- CMD-ZM: như UA-ZM nhưng disabled
- SA: thấy tất cả, filter theo dropdown

### Nhóm 4: Kỳ đang xem × Trạng thái tính toán × Vai trò

Giao điểm giữa chiều 7, 8, 2 — "xem kỳ nào, data tính chưa, ai xem":

- SA xem kỳ cũ chưa từng tính → billing trống, không có số liệu
- UA-ZM xem kỳ đang mở, data stale → số liệu cũ, tưởng chưa nhập
- SA xuất Excel khi stale → file sai

### Nhóm 5: Vị trí phân cấp × Định dạng output

Giao điểm giữa chiều 10, 12 — "merge/rowspan đúng cho mọi vị trí CP":

- CP trực tiếp đơn vị + CP trong nhóm trong khối → HTML rowspan đúng? Excel merge đúng?
- CP thuộc khu vực (cột Đơn vị trống) + CP thuộc đơn vị trong cùng zone → merge Khu vực đúng?
- SA (30 cột) vs UA (28 cột) → Excel formula column index đúng cho cả 2?

### Nhóm 6: Cách nhận data × Kỳ × Loại đầu mối

Giao điểm giữa chiều 11, 1, 5 — "entity mới tạo giữa kỳ có đúng data":

- Tạo residential giữa kỳ → reading_start = 0, personnel từ form, other_deduction = 0
- Tạo water_pump giữa kỳ → reading_start = 0, tham gia tổn hao ngay
- Thêm rank mới giữa kỳ → personnel_entries tạo cho tất cả residential (count = 0)
- Mở kỳ mới sau đó → entity kế thừa đúng từ kỳ trước

---

## Chiều test bổ sung — milestone 1.2.0 (3 tính năng)

> Chiều/giá trị test đích cho 3 tính năng 1.2.0. **Trạng thái:** cả ba — cột "Khác" hệ số đơn vị (TN1), phân bổ bơm theo trạm (TN2) và hiển thị chi tiết tổn hao (TN3) — **đã triển khai** (merge vào `develop`). Danh sách đầy đủ ở từng spec; phần này chốt chiều mới để spec test bám theo.
>
> Từ ADR-030, chiều test per-tính-năng được khai chính thức ở bảng `## Truy vết chiều test` (anchor `CHIEU-<slug>`) của từng spec và CI đối chiếu với test; mục này giữ vai trò catalog 12 chiều khái niệm + trỏ tới spec, không phải nơi theo dõi trạng thái triển khai.

### Cột "Khác" dạng hệ số (đơn vị) — mở rộng chiều "cách nhập khoản trừ Khác" (đã triển khai)

Giá trị mới của chiều: `fixed` · `coefficient` · **`unit_coefficient`**. Test: hệ số dương/âm; khớp ví dụ 74 người/bếp 8 người → −132; quân số đổi tự tính lại; đơn vị một đầu mối (tổng − chính nó = 0); đầu mối zone-direct bị chặn (request) + ẩn option (system); kế thừa kỳ; 7 vai trò (ai sửa được cột Khác). Spec: [`superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md`](superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md).

### Phân bổ bơm theo trạm — mở rộng chiều "phân bổ bơm nước" + giao điểm Kỳ (đã triển khai)

Chiều mới: cơ chế phân bổ (`per_station` true/false theo cờ kỳ) × loại đối tượng nhận (đơn vị/khối/nhóm/đầu mối). Test: kỳ cũ gộp khu vực không đổi (regression); kỳ mới Σ per-trạm = D khu vực; 4 loại recipient chia đúng; ràng buộc per-trạm (Σ% ≤ 100, thiếu recipient hệ số, Σ quân số×hệ số = 0); trạm chưa cấu hình → cảnh báo; chuyển tiếp kỳ đầu trống; recipient đã xóa khi xem kỳ cũ (`.with_discarded`); 7 vai trò + zone-manager cấu hình. Spec: [`superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md`](superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md).

### Hiển thị chi tiết tổn hao — mở rộng giao điểm "Trạng thái tính toán" (Nhóm 4) (đã triển khai)

Test: chưa tính → 2 cột + A/B/C trống; sau tính → khớp `LossCalculator`; sửa chỉ số sau tính → giữ giá trị cũ; trường hợp đặc biệt C<0 / B=0 / khu vực trống; A/B/C theo zone đang chọn; công tơ `no_loss` → loss = 0; 7 vai trò (2 cột read-only). Spec: [`superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`](superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md).

---

## Lịch sử thay đổi

### v1.5.3 (24/06/2026)

- Chiều 3 ma trận: pump_entries SA sửa "filter zone/unit + cột zone/unit" → "filter zone + cột zone (không có unit — bơm nước luôn thuộc khu vực)". Bơm nước (`water_pump`) luôn có `unit_id: nil` (`validate_water_pump_constraints`), nên unit filter/cột vô nghĩa. meter_entries giữ nguyên zone/unit (sinh hoạt + công cộng có thể thuộc đơn vị). Issue #456.

### v1.5.2 (23/06/2026)

- Chiều 2 DC description: sửa "giống các loại chỉ huy khác" → "giống SA và UA/UA-ZM; CMD/CMD-ZM không có quyền này" — CMD không có recalculate (ability.rb).

### v1.5.1 (23/06/2026)

- Expected output hiển thị — Sidebar: thêm DC (16 items, chỉ xem) vào danh sách sidebar count per role.

### v1.5.0 (22/06/2026)

- Chiều 2: đổi "4 enum values... 6 vai trò" → "5 enum values... 7 vai trò". Thêm DC (Chỉ huy Sư đoàn, `division_commander`) vào bảng vai trò và ghi chú giải thích.
- Chiều 3: thêm cột DC vào ma trận quyền 7 role × 18 trang. DC xem toàn hệ thống (read-only), có tính toán lại trên billing, chặn trên /users và /backups.
- Giao điểm nguy hiểm và chiều test bổ sung 1.2.0: đổi "6 vai trò" → "7 vai trò" (5 chỗ).
- Lịch sử v0.2.0: ghi rõ "6 role (chưa có DC)" để phân biệt với trạng thái hiện tại.

### v1.4.2 (21/06/2026)

- Đổi tên hệ thống trong tiêu đề: "Hệ thống quản lý điện nước nội bộ" (Issue #420).

### v1.4.1 (14/06/2026)

- Cập nhật trạng thái mục "Chiều test bổ sung — milestone 1.2.0": phân bổ bơm theo trạm (TN2) **đã triển khai** (merge vào `develop`) — cả ba tính năng 1.2.0 nay đều đã build. Sửa hai ghi chú "(chưa triển khai)" vốn lỗi thời. Chiều test per-tính-năng vẫn khai canonical ở bảng `## Truy vết chiều test` của spec `2026-06-11-phan-bo-bom-theo-tram-design.md` (lật 8 `CHIEU-phan-bo-tram-*` sang có-test ở phiên 0.3.0 của spec đó).

### v1.4.0 (13/06/2026)

- Thêm ghi chú: chiều test per-tính-năng khai ở bảng `## Truy vết chiều test` (anchor `CHIEU-<slug>`) của từng spec, CI đối chiếu với test (ADR-030, Issue #329). Mục này giữ vai trò catalog 12 chiều khái niệm + trỏ tới spec, không theo dõi trạng thái triển khai (giảm phụ thuộc prose current-state dễ lỗi thời).

### v1.3.1 (12/06/2026)

- Cập nhật trạng thái mục "Chiều test bổ sung — milestone 1.2.0" cho khớp hiện trạng: cột "Khác" hệ số đơn vị (TN1) và hiển thị chi tiết tổn hao (TN3) **đã triển khai** (merge vào `develop`); phân bổ bơm theo trạm (TN2) **chưa**. Sửa ghi chú "(chưa triển khai phiên này)" vốn đã lỗi thời sau khi TN1 + TN3 merge.

### v1.3.0 (11/06/2026)

- Thêm mục "Chiều test bổ sung — milestone 1.2.0": chiều/giá trị test đích cho 3 tính năng (giá trị `unit_coefficient` của cột Khác; cơ chế `per_station` × loại recipient cho phân bổ bơm; mở rộng giao điểm Trạng thái tính toán cho hiển thị tổn hao). Trỏ tới spec ADR-025..027; chưa triển khai. Khớp nghiệp vụ v2.15.0 (Issue #319).

### v1.2.3 (31/05/2026)

- Chiều 3: thắt chặt trang Khu vực (/zones) còn chỉ system_admin (`require_system_admin!`, giống /units). Đơn vị quản lý khu vực (UA-ZM/CMD-ZM) đổi từ "Xem (khu vực mình)" → "Chặn" — nay tất cả vai trò non-SA = "Chặn". /pump_allocations giữ nguyên (vẫn SA hoặc đơn vị quản lý khu vực — zone-manager cần dùng).
- Sidebar expected output: UA-ZM và CMD-ZM giảm từ 12 → 11 mục (bỏ "Khu vực"). SA (17), UA (8), CMD (8), TECH (3) giữ nguyên.

### v1.2.2 (31/05/2026)

- Chiều 3: thắt chặt truy cập các trang thiết lập/hệ thống bằng concern `SettingsAccessGuard` (page-level guard, chặn truy cập trực tiếp qua URL). Cập nhật cột "Kiểm soát truy cập" và các ô vai trò non-SA:
  - /zones, /pump_allocations: chỉ SA hoặc đơn vị quản lý khu vực (`require_system_admin_or_zone_manager!`) — UA và CMD đổi từ "Xem" → "Chặn"; UA-ZM (CRUD/CRUD) và CMD-ZM (Xem) giữ nguyên.
  - /units, /pricing, /ranks: chỉ SA (`require_system_admin!`) — cả bốn vai trò non-SA đổi từ "Xem" → "Chặn".
  - /users: chỉ SA hoặc TECH (`require_account_manager!`) — UA-ZM, UA, CMD-ZM, CMD đổi từ "Xem" → "Chặn"; SA và TECH giữ nguyên.
- `ability.rb` thu hẹp `can :read, Zone` còn khu vực do đơn vị quản lý (trước đây mọi zone `discarded_at: nil`); `can :read, Unit/Period/Rank` giữ nguyên cho form và billing.

### v1.2.1 (31/05/2026)

- Bảng "Toggle hiện/ẩn field": sửa audience của pattern `contact_point_assignment` (radio Đơn vị/Khu vực) từ "SA only" → "SA và UA-ZM". Khớp code (`_form_residential`/`_form_public` hiện radio `unless current_user.unit_id.present? && !current_zone_manager?` → SA và UA-ZM thấy, UA không) và nhất quán với V2_HANH_VI_HE_THONG mục 2.

### v0.2.0 (23/05/2026)

- Chiều 3: sửa đếm 17 → 18 trang. Thêm ma trận quyền 6 role × 18 trang (chưa có DC) thay vì chỉ liệt kê guard.
- Chiều 7: sửa sai "dropdown chỉ SA" → dropdown kỳ cho tất cả role. Tách rõ dropdown kỳ (tất cả) vs dropdown zone/unit (SA only). Sửa sai `zone_filter_scope` → billing SA luôn dùng `with_discarded`.
- Chiều 11: thêm unit_configs, non_establishment_snapshots, pump_allocations, main_meter_readings, ranks — bao phủ TẤT CẢ data per kỳ.
- Thêm section "Input → expected output" với output cả backend và hiển thị.
- Thêm 13 loại output hiển thị (cột, nội dung ô, merge, hàng tổng, nút, input state, dropdown, cảnh báo, sidebar, trạng thái rỗng, thông tin kỳ, pagination, hover).
- Thêm input CRUD (R 12 scenarios, C 9, U 7, D 12, thao tác đặc biệt 13).
- Thêm tương tác input (cascade, toggle, dynamic, auto-submit, conditional) với expected output cho mỗi pattern.
- Thêm cross-reference giữa C/U/D và bảng output hiển thị.

### v1.2.0 (24/05/2026)

- Sidebar expected output: CMD 8 items (khớp UA), CMD-ZM 12 items (khớp UA-ZM). Commander thấy cùng trang với unit_admin, chỉ xem.
- Chiều 3: cập nhật ma trận — commander giờ thấy meter_entries, pump_entries (ZM), electricity_supply (ZM), unit_config trên sidebar.

### v1.1.0 (24/05/2026)

- Chiều 3: meter_entries/pump_entries thêm search, filter zone/unit (SA), cột zone/unit (SA).
- Chiều 11: reading_start editable mọi kỳ (không chỉ kỳ đầu).
- Output hiển thị: reading_start editable, không có cột nhập thủ công.
- Cập nhật test count: 1129 → 1378.

### v0.1.0 (23/05/2026)

- Bản nháp đầu tiên: 12 chiều kiểm thử + 6 nhóm giao điểm nguy hiểm.
- Nguồn: audit codebase session 23/05/2026 (7 PRs: #206-#211).
