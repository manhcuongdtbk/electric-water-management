# Các chiều kiểm thử — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Phiên bản:** 0.1.0 (bản nháp — chưa duyệt)
> **Ngày:** 23/05/2026
> **Tính chất:** Định nghĩa không gian kiểm thử. Mỗi chiều là một biến độc lập tạo code path khác nhau trong hệ thống. Giao điểm giữa các chiều là nơi bug dễ xảy ra nhất.
> **Nguồn:** Audit toàn bộ codebase, đối chiếu 4 tài liệu, 1129+ test cases hiện có.

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

Hệ thống có 4 enum values trong database nhưng 6 vai trò thực tế:

| Ký hiệu | Vai trò | Cách xác định | Phạm vi |
|---|---|---|---|
| SA | Quản trị viên hệ thống | `role == "system_admin"` | Toàn hệ thống |
| UA-ZM | Quản trị viên đơn vị quản lý khu vực | `role == "unit_admin"` + `Zone.kept.exists?(manager_unit_id: unit_id)` | Đơn vị mình + khu vực mình quản lý |
| UA | Quản trị viên đơn vị | `role == "unit_admin"` + không quản lý khu vực | Chỉ đơn vị mình |
| CMD-ZM | Chỉ huy đơn vị quản lý khu vực | `role == "commander"` + `Zone.kept.exists?(manager_unit_id: unit_id)` | Chỉ xem, phạm vi như UA-ZM |
| CMD | Chỉ huy đơn vị | `role == "commander"` + không quản lý khu vực | Chỉ xem, phạm vi như UA |
| TECH | Kỹ thuật viên | `role == "technician"` | Tài khoản, sao lưu, nhật ký. Không thấy dữ liệu nghiệp vụ |

UA-ZM và CMD-ZM không phải role riêng trong database. Xác định qua `current_zone_manager?` (dùng `Zone.kept` — khớp Ability). Zone đã xóa → user mất vai trò zone-manager.

### Chiều 3 — Trang và thao tác

14 trang, mỗi trang có tập thao tác riêng:

| Nhóm | Trang | Thao tác chính | Guard |
|---|---|---|---|
| Xem kết quả | Tổng quan (/dashboard) | Xem | BusinessRoleRequired |
| Xem kết quả | Bảng tính tiền (/billing) | Xem, recalculate, xuất Excel | BusinessRoleRequired |
| Xem kết quả | Tra cứu lịch sử (/history) | Xem, so sánh 2 kỳ, xem theo khoảng | BusinessRoleRequired |
| Nhập liệu | Nhập số điện lực (/electricity_supply) | Xem, sửa | PeriodGuard |
| Nhập liệu | Chỉ số đầu mối (/meter_entries) | Xem, sửa | PeriodGuard |
| Nhập liệu | Chỉ số bơm nước (/pump_entries) | Xem, sửa | PeriodGuard |
| Khai báo | Đầu mối (/contact_points) | CRUD | PeriodGuard + StructureChangeGuard |
| Khai báo | Khối (/blocks) | CRUD | PeriodGuard + StructureChangeGuard |
| Khai báo | Nhóm (/groups) | CRUD | PeriodGuard + StructureChangeGuard |
| Khai báo | Cấu hình đơn vị (/unit_config) | Xem, sửa | PeriodGuard |
| Thiết lập | Khu vực (/zones) | CRUD | PeriodGuard + StructureChangeGuard |
| Thiết lập | Đơn vị (/units) | CRUD | PeriodGuard + StructureChangeGuard |
| Thiết lập | Phân bổ bơm nước (/pump_allocations) | CRUD | PeriodGuard |
| Thiết lập | Đơn giá điện (/pricing) | Mở/đóng/mở lại kỳ | Không có guard (quản lý kỳ) |
| Thiết lập | Nhóm cấp bậc (/ranks) | CRUD | PeriodGuard + StructureChangeGuard |
| Hệ thống | Tài khoản (/users) | CRUD | Không có PeriodGuard |
| Hệ thống | Nhật ký (/audit_logs) | Xem | Không có PeriodGuard |
| Hệ thống | Sao lưu (/backups) | CRUD | Không có PeriodGuard |

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

| Kỳ đang mở | Kỳ đang xem | Data hiển thị | Recalculate | Dropdown zone/unit | Sửa được |
|---|---|---|---|---|---|
| N (mới nhất) | N | Data kỳ N | Có | `zone_filter_scope` (auto-detect) | Có (billing không sửa trực tiếp, nhưng recalculate hoạt động) |
| N (mới nhất) | N-2 (đóng) | Data kỳ N-2 | Không (kỳ N-2 đóng) | `with_discarded` (cần hiện entity đã xóa) | Không |
| Không có | N-2 (đóng) | Data kỳ N-2 | Không | `with_discarded` | Không |
| N-2 (cũ mở lại) | N-2 | Data kỳ N-2 | Có | `with_discarded` | Sửa data per kỳ |
| N-2 (cũ mở lại) | N-1 (đóng) | Data kỳ N-1 | Không (kỳ N-1 đóng) | `with_discarded` | Không |

Chiều này chỉ ảnh hưởng billing và history (các trang khác luôn hiện kỳ đang mở hoặc không có period selector).

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

Cùng 1 entity trong cùng 1 kỳ, data ban đầu có thể đến từ 3 đường khác nhau:

| Đường | Khi nào xảy ra | reading_start | personnel_entries | other_deductions |
|---|---|---|---|---|
| Kế thừa (PeriodService snapshot) | Mở kỳ mới, entity đã tồn tại từ kỳ trước | = reading_end kỳ trước | Copy count từ kỳ trước | Copy type + value từ kỳ trước |
| Tạo giữa kỳ (after_create callback) | Tạo entity khi kỳ đang mở | = 0 | Từ form tạo (cho mỗi rank hiện có) | fixed, 0 |
| Kỳ đầu tiên (PeriodService defaults) | Kỳ đầu tiên của hệ thống, chưa có kỳ trước | User nhập tay (cả start và end) | Từ form tạo | fixed, 0 |

Kịch bản quan trọng:
- Rank mới thêm giữa kỳ → entity kế thừa có N personnel_entries, entity tạo giữa kỳ có N+1 (after_create tạo cho rank mới)
- Entity tạo giữa kỳ có reading_start = 0 → sử dụng = reading_end - 0 = reading_end (có thể rất lớn nếu công tơ không mới lắp)
- Đóng kỳ cũ sau khi sửa → cảnh báo mismatch reading_end vs reading_start kỳ kế tiếp

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

## Giao điểm nguy hiểm

Không phải mọi tổ hợp 12 chiều đều cần test. Các giao điểm sau là nơi bug dễ xảy ra nhất:

### Nhóm 1: Kỳ × Vai trò × Entity state

Giao điểm giữa chiều 1, 2, 4 — "ai thấy gì khi entity đã xóa ở kỳ khác":

- Tạo CP ở kỳ N-1 → đóng → mở kỳ N → xóa CP → mở lại kỳ N-1 → 6 vai trò thấy gì?
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

## Lịch sử thay đổi

### v0.1.0 (23/05/2026)

- Bản nháp đầu tiên: 12 chiều kiểm thử + 6 nhóm giao điểm nguy hiểm.
- Nguồn: audit codebase session 23/05/2026 (7 PRs: #206-#211).
