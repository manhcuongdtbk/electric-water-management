# Tổng hợp thiết kế hệ thống quản lý điện nước nội bộ

> Phiên bản: **1.4.0**
> Ngày: 14/05/2026
> Mục đích: Nguồn sự thật duy nhất cho toàn bộ hệ thống. Tạo từ v1.2.0 + các quyết định đã chốt trong lịch sử chat. Thay thế cả v1.2.0 lẫn v1.3.0 (nháp, đã rút lại).
> Quy ước: Mục nào thêm mới so với v1.2.0 được đánh dấu **[MỚI]**.

---

## Phần 1 — Nghiệp vụ

### 1.1. Cấu trúc 3 cấp

**Cấp 1 — Sư đoàn:**
- Thiết lập ban đầu: đơn giá điện, tỷ lệ tiết kiệm của Bộ, tỷ lệ công cộng dùng chung Sư đoàn, bảng định mức cấp bậc.
- Tạo khu vực, gán đơn vị vào khu vực, chỉ định đơn vị quản lý khu vực.
- Quản lý tài khoản toàn hệ thống, mở khóa tháng cũ, xem nhật ký.
- Có toàn quyền thao tác với mọi thứ trong mọi khu vực (nhưng thực tế ủy quyền nhập liệu hàng tháng cho cấp 2).

**Cấp 2 — Đơn vị (13 đơn vị trực thuộc):**
- Mỗi đơn vị tự quản lý bên trong: khai báo đầu mối, công tơ, quân số.
- Nhập liệu hàng tháng: chỉ số công tơ, soát quân số.
- Cấu hình: tỷ lệ công cộng dùng chung của đơn vị, cột "Khác".
- Bảng thu tiền là của riêng đơn vị.
- Nếu được chỉ định là đơn vị quản lý khu vực: thêm quyền nhập số công tơ tổng, nhập chỉ số trạm bơm, quản lý trạm bơm, gán phân bổ bơm nước cho nhóm đối tượng trong khu vực.

**Cấp 3 — Đầu mối (3 loại, xem mục 1.2).**

---

### 1.2. Các loại đầu mối

Đầu mối phân biệt bằng 2 tiêu chí: có công tơ hay không, có quân số hay không.

| Loại | Có công tơ | Có quân số | Bảng thu tiền | Nhận bơm nước | Ví dụ |
|---|---|---|---|---|---|
| Đầu mối sinh hoạt | Có | Có (> 0) | Có | Có (nếu được gán) | Ban Tác huấn, Tổ xe |
| Đầu mối công cộng | Có | Không (= 0) | Không | Không | Đèn đường, Hội trường |
| Đầu mối ngoài biên chế | Không | Có (nhập tay) | Không | Có (nếu được gán) | Thợ xây |

Cần có trường phân loại tường minh trên model đầu mối (không phân biệt bằng quân số hoặc loại công tơ).

Đầu mối có thể gộp theo **khối** để hiển thị có cấu trúc trên bảng tổng hợp (ví dụ: "Phòng Tham mưu", "Phòng Chính trị").

---

### 1.3. Các loại công tơ

Công tơ phân biệt theo 2 trục: **thuộc đâu** (đầu mối hay trạm bơm) và **có tham gia tổn hao hay không**.

| Loại | Thuộc | Tổn hao | Đo điện | Bảng thu tiền |
|---|---|---|---|---|
| Công tơ sinh hoạt | Đầu mối | Có | Điện sinh hoạt | Có (nếu đầu mối có quân số > 0) |
| Công tơ sinh hoạt không tổn hao | Đầu mối | Không | Điện sinh hoạt | Có |
| Công tơ công cộng | Đầu mối | Có | Điện công cộng | Không |
| Công tơ bơm nước | Trạm bơm | Có | Điện bơm nước | Không |

Ghi chú: Trong thực tế hiện tại chỉ có công tơ sinh hoạt mới có trường hợp "không tổn hao" (đặt tại trạm biến áp). Schema hỗ trợ đánh dấu "không tổn hao" trên bất kỳ công tơ nào — đề phòng tương lai.

---

### 1.4. Các loại điện

Lưu ý: "loại điện" là khái niệm trừu tượng (phân loại theo mục đích sử dụng), khác với "loại công tơ" ở mục 1.3 (thiết bị đo vật lý). Ví dụ: "điện công cộng" là loại điện dùng cho hạ tầng chung; "công tơ công cộng" là thiết bị đo điện công cộng.

| Loại điện | Đo bằng | Vai trò trong bảng thu tiền |
|---|---|---|
| Điện sinh hoạt | Công tơ sinh hoạt + công tơ sinh hoạt không tổn hao | Cộng vào "tổng sử dụng điện" của đầu mối |
| Điện bơm nước | Công tơ bơm nước | Phân bổ cho nhóm đối tượng → cộng vào "tổng sử dụng điện" |
| Điện công cộng | Công tơ công cộng | Tính khoản trừ "công cộng" → trừ khỏi tiêu chuẩn |

Khi nói "sử dụng điện" nói chung = sử dụng điện sinh hoạt + sử dụng điện bơm nước. Điện công cộng không nằm trong "sử dụng" — nó là khoản trừ.

---

### 1.5. Khu vực

Khu vực là vùng vật lý mà các đơn vị cấp 2 chia sẻ hạ tầng điện và nước. Mỗi khu vực gồm:

- **Công tơ tổng** — thuộc khu vực, đo tổng điện lực cấp cho khu vực. Hiện tại mỗi khu vực có 1, tương lai có thể nhiều hơn. Khi có nhiều hơn 1, engine tổng hợp số điện lực từ tất cả công tơ tổng trong khu vực.
- **Trạm bơm nước** — có thể nhiều trạm, mỗi trạm có nhiều công tơ.
- **Đơn vị cấp 2** — có thể nhiều đơn vị cùng chia sẻ.
- **Đơn vị quản lý khu vực** — 1 đơn vị cấp 2 được chỉ định, chịu trách nhiệm nhập liệu khu vực hàng tháng.

Trường hợp đơn vị có hạ tầng riêng (không chia sẻ) = khu vực chỉ chứa 1 đơn vị, đơn vị đó cũng là đơn vị quản lý.

Quản trị viên cấp 1 tạo khu vực và thiết lập ban đầu. Sau đó quản trị viên đơn vị quản lý khu vực tự nhập liệu hàng tháng. Quản trị viên cấp 1 vẫn có quyền thao tác bất cứ lúc nào.

**[MỚI]** Đơn vị cấp 2 bắt buộc phải thuộc 1 khu vực (validation `unit_must_have_zone`).

---

### 1.6. Tổn hao

Tính trên toàn khu vực:
- A = tổng số điện lực tất cả công tơ tổng trong khu vực − tổng sử dụng điện tất cả công tơ không tổn hao trong khu vực
- B = tổng sử dụng điện tất cả công tơ có tổn hao trong khu vực (bao gồm công tơ sinh hoạt, công tơ công cộng, công tơ bơm nước)
- C = A − B (tổng tổn hao toàn khu vực)
- Tổn hao phân bổ cho từng công tơ = C × (sử dụng điện công tơ đó ÷ B)

Quản trị viên đơn vị thấy kết quả tổn hao phân bổ cho các công tơ của đơn vị mình trong Bảng tổng hợp, tại cột "Tổn hao".

**[MỚI]** Khi supply < consumption (C < 0), engine clamp tổn hao về 0 và trả cảnh báo `:negative_loss`. Bảng tổng hợp F11 hiển thị banner cảnh báo.

---

### 1.7. Phân bổ bơm nước

Tổng sử dụng điện bơm nước toàn khu vực (gọi là D) = Σ(sử dụng điện của công tơ bơm nước X + tổn hao công tơ bơm nước X), với X là từng công tơ bơm nước trong khu vực.

Phân bổ cho các **nhóm đối tượng**. Có 4 loại:

| Loại nhóm đối tượng | Quân số | Sau khi nhận bơm nước |
|---|---|---|
| Đơn vị | Tổng quân số tất cả đầu mối trong đơn vị | Chia tiếp xuống từng đầu mối theo quân số |
| Nhóm đầu mối | Tổng quân số các đầu mối thành viên | Chia tiếp xuống đầu mối thành viên theo quân số |
| Đầu mối lẻ | Quân số đầu mối đó | Nhận trực tiếp |
| Đầu mối ngoài biên chế | Quân số nhập tay | Nhận trực tiếp |

Mỗi nhóm đối tượng nhận bơm nước theo 1 trong 2 cách:
- **Tỷ lệ cố định** (ví dụ 30%) → nhận D × tỷ lệ
- **Theo quân số** (không có tỷ lệ cố định) → chia phần còn lại (D − tổng phần cố định) theo quân số

Nhiều nhóm có thể có tỷ lệ cố định đồng thời. Tổng tỷ lệ cố định không vượt 100%. **[MỚI]** Validation ở model, tính trên toàn khu vực (cross tất cả trạm bơm trong khu vực).

---

### 1.8. Vai trò

| Vai trò | Quyền |
|---|---|
| Quản trị viên cấp 1 | Thiết lập ban đầu (đơn giá, tỷ lệ, định mức). Tạo khu vực, gán đơn vị, chỉ định đơn vị quản lý. Quản lý tài khoản. Mở khóa tháng cũ. Nhật ký. Toàn quyền thao tác mọi khu vực. **[MỚI]** Ngoại trừ: không sửa cấu hình công cộng/khác của đơn vị (do quản trị viên đơn vị tự quản), không truy cập sao lưu (chỉ kỹ thuật). |
| Quản trị viên đơn vị | Khai báo đầu mối, công tơ, quân số, đầu mối ngoài biên chế. Nhập chỉ số công tơ hàng tháng. Cấu hình công cộng đơn vị, cột "Khác". Nếu là đơn vị quản lý khu vực: nhập số công tơ tổng, quản lý trạm bơm, nhập chỉ số trạm bơm, gán phân bổ bơm nước. |
| Chỉ huy đơn vị | Chỉ xem, không thao tác. |
| Kỹ thuật | Quản lý tài khoản, nhật ký, sao lưu & phục hồi. |

---

### 1.9. Bảng tổng hợp

- Tính riêng cho từng đơn vị cấp 2.
- Mỗi dòng = 1 đầu mối sinh hoạt (có quân số > 0).
- Đầu mối công cộng không có dòng (quân số = 0).
- Đầu mối ngoài biên chế không có dòng (không có công tơ).
- Gộp đầu mối theo khối để hiển thị có cấu trúc (nếu đầu mối được gán khối).
- **[MỚI]** Có cột "Khối" hiển thị `group_name` của đầu mối. Sắp xếp theo `group_name` alphabetical (NULLS LAST), sau đó theo `name` alphabetical.
- **[MỚI]** UI (HTML) và CSV export có cùng cấu trúc 28 cột, cùng thứ tự:
  STT, Khối, Đầu mối, R1-R7 kW (7 cột), Tổng quân số, Sinh hoạt, Bơm nước tiêu chuẩn, Tổng tiêu chuẩn, Tiết kiệm, Tổn hao, CC Sư đoàn, CC Đơn vị, Khác, Tổng trừ, Tiêu chuẩn còn lại, Sử dụng công tơ, Bơm nước thực tế, Tổng sử dụng, Thừa kW, Thiếu kW, Thành tiền thừa, Thành tiền thiếu.

---

### 1.10. Khóa kỳ [MỚI]

- Quản trị viên cấp 1 khóa/mở khóa kỳ tính toán.
- Khi kỳ bị khóa: không sửa được chỉ số công tơ, quân số, cấu hình, điện lực. Không tạo/sửa/xóa được đầu mối, công tơ (ảnh hưởng mọi kỳ).
- Tính toán lại (recalculate) vẫn được phép khi kỳ bị khóa (idempotent computation, không phải data entry).

---

### 1.11. Thuật ngữ

| Thuật ngữ | Ý nghĩa |
|---|---|
| Công tơ tổng | Công tơ đo tổng điện lực cấp cho khu vực (theo file tháng 02: "Số sử dụng toàn đơn vị theo công tơ tổng điện lực") |
| Khu vực | Vùng chia sẻ hạ tầng điện và nước (công tơ tổng + trạm bơm + đơn vị) |
| Khối | Nhóm đầu mối để hiển thị có cấu trúc (Phòng Tham mưu, Phòng Chính trị...) |
| Nhóm đối tượng | Đối tượng nhận phân bổ bơm nước (4 loại) |
| Đơn vị quản lý khu vực | Đơn vị cấp 2 được chỉ định nhập liệu cho khu vực |
| Điện sinh hoạt | Điện dùng cho sinh hoạt cá nhân, đo bằng công tơ sinh hoạt |
| Điện bơm nước | Điện dùng cho bơm nước, đo bằng công tơ bơm nước |
| Điện công cộng | Điện dùng cho hạ tầng chung, đo bằng công tơ công cộng |
| Tổng sử dụng điện | Sử dụng điện sinh hoạt + sử dụng điện bơm nước (không bao gồm điện công cộng) |

---

### 1.12. Sidebar [MỚI]

**Nguyên tắc sắp xếp:**
- Nhóm sắp xếp theo tần suất sử dụng: xem kết quả (hàng ngày) → nhập liệu (hàng tháng) → khai báo (khi cần) → thiết lập (1 lần) → hệ thống (khi cần).
- Trong mỗi nhóm, sắp xếp theo dependency: mục trên cần làm trước mục dưới.
- Quy tắc đặt tên: không "Quản lý", không "Danh sách". Sidebar item = heading trang = breadcrumb = flash.

**XEM KẾT QUẢ:**

| Tên | Chức năng |
|---|---|
| Tổng quan | Dashboard tổng hợp |
| Bảng tổng hợp | F11 bảng thu tiền per đơn vị |
| Tra cứu lịch sử | F13 tra cứu + so sánh cùng kỳ |

**NHẬP LIỆU HÀNG THÁNG:**

| Tên | Chức năng | Lý do thứ tự |
|---|---|---|
| Nhập số điện lực | F05 | A trong công thức tổn hao cần số này |
| Chỉ số đầu mối | F06 | B cần tổng sử dụng công tơ |
| Chỉ số bơm nước | Chỉ số trạm bơm | B cần sử dụng công tơ bơm nước |
| Soát lại quân số | F07 | Xác nhận quân số trước khi chốt tháng |

**KHAI BÁO:**

| Tên | Chức năng | Lý do thứ tự |
|---|---|---|
| Đầu mối | F01 | Nhóm đầu mối cần chọn đầu mối thành viên |
| Đầu mối ngoài biên chế | WorkGroup CRUD | Không phụ thuộc đầu mối |
| Trạm bơm nước | PumpStation CRUD | Tạo trước phân bổ bơm nước |
| Nhóm đầu mối | ContactPointGroup CRUD | Cần đầu mối đã tồn tại |
| Cấu hình | F04 | Không phụ thuộc |

**THIẾT LẬP:**

| Tên | Chức năng | Lý do thứ tự |
|---|---|---|
| Đơn vị | Organization CRUD | Khu vực cần gán đơn vị |
| Khu vực | Zone CRUD | Cần chỉ định đơn vị quản lý |
| Đơn giá điện | F20 | Không phụ thuộc |
| Định mức cấp bậc | F21 | Không phụ thuộc |

**HỆ THỐNG:**

| Tên | Chức năng |
|---|---|
| Tài khoản | F15 quản lý người dùng |
| Nhật ký hoạt động | F19 audit log |
| Sao lưu dữ liệu | Backup & restore |

**Sidebar per role (suy ra từ quyền mục 1.8):**

| Mục | admin_level1 | admin_unit | commander | tech |
|---|---|---|---|---|
| **XEM KẾT QUẢ** | | | | |
| Tổng quan | ✓ | ✓ | ✓ | ✗ |
| Bảng tổng hợp | ✓ | ✓ | ✓ | ✗ |
| Tra cứu lịch sử | ✓ | ✓ | ✓ | ✗ |
| **NHẬP LIỆU** | | | | |
| Nhập số điện lực | ✓ | ✓ (zone-manager) | ✗ | ✗ |
| Chỉ số đầu mối | ✓ | ✓ | ✗ | ✗ |
| Chỉ số bơm nước | ✓ | ✓ (zone-manager) | ✗ | ✗ |
| Soát lại quân số | ✓ | ✓ | ✗ | ✗ |
| **KHAI BÁO** | | | | |
| Đầu mối | ✓ | ✓ | ✓ (xem) | ✗ |
| Đầu mối ngoài biên chế | ✓ | ✓ | ✓ (xem) | ✗ |
| Trạm bơm nước | ✓ | ✓ (zone-manager) | ✗ | ✗ |
| Nhóm đầu mối | ✓ | ✓ | ✓ (xem) | ✗ |
| Cấu hình | ✓ (xem) | ✓ | ✗ | ✗ |
| **THIẾT LẬP** | | | | |
| Đơn vị | ✓ | ✗ | ✗ | ✗ |
| Khu vực | ✓ | ✓ (zone-manager, xem) | ✓ (xem) | ✗ |
| Đơn giá điện | ✓ | ✗ | ✗ | ✗ |
| Định mức cấp bậc | ✓ | ✗ | ✗ | ✗ |
| **HỆ THỐNG** | | | | |
| Tài khoản | ✓ | ✗ | ✗ | ✓ |
| Nhật ký hoạt động | ✓ | ✗ | ✗ | ✓ |
| Sao lưu dữ liệu | ✗ | ✗ | ✗ | ✓ |

---

## Phần 2 — Code

### 2.1. Schema

Ghi tất cả tables và cột quan trọng. Mọi table đều có `id` (auto-increment PK) + `created_at` + `updated_at` (ẩn, không liệt kê).

```ruby
# Zone (khu vực)
# - id
# - name
# - manager_organization_id (FK → organizations)

# MainMeter belongs_to :zone (công tơ tổng)
# - id
# - name
# - zone_id (FK → zones)

# PumpStation belongs_to :zone (trạm bơm)
# - id
# - name
# - zone_id (FK → zones)

# Organization belongs_to :zone (đơn vị)
# - id
# - name
# - level (enum: division/unit)
# - parent_id (FK → organizations, self-referential)
# - zone_id (FK → zones, nullable — nil cho division)
# - validation: unit_must_have_zone [MỚI]

# ContactPoint (đầu mối)
# - id
# - organization_id (FK → organizations)
# - name
# - group_name (khối — nullable)
# - contact_point_type (enum: residential, communal)

# WorkGroup (đầu mối ngoài biên chế) — model riêng
# - id
# - owner_organization_id (FK → organizations, phải là unit) [MỚI: đổi từ division sang unit]
# - name
# - personnel_count (quân số nhập tay)

# ContactPointGroup (nhóm đầu mối — dùng cho phân bổ bơm nước)
# - id
# - name
# - organization_id (FK → organizations)

# ContactPointGroupMembership
# - id
# - contact_point_group_id (FK)
# - contact_point_id (FK)

# PumpStationAssignment (polymorphic)
# - id
# - pump_station_id (FK)
# - assignable_type (Organization / ContactPoint / WorkGroup / ContactPointGroup)
# - assignable_id
# - fixed_pump_percentage (decimal, nullable)
# - validation: tổng fixed ≤ 100% per zone (cross tất cả pump_stations trong zone)

# Meter (công tơ đầu mối hoặc trạm bơm)
# - id
# - name
# - contact_point_id (FK, nullable — nil cho bơm nước)
# - pump_station_id (FK, nullable — nil cho đầu mối)
# - organization_id (FK — đơn vị sở hữu, dùng cho scoping)
# - meter_type (enum: normal, public_meter, pump_station)
# - no_loss (boolean, default: false)

# Personnel (quân số per đầu mối per kỳ)
# - id
# - contact_point_id (FK)
# - monthly_period_id (FK)
# - rank1_count – rank7_count (7 cột integer)
# - reviewed_at (datetime, nullable)

# RankQuota (định mức 7 nhóm cấp bậc)
# - id
# - rank_group (enum)
# - rank_name
# - quota_kw (decimal)

# MonthlyPeriod (kỳ tính toán)
# - id
# - year
# - month
# - unit_price (decimal)
# - locked (boolean, default: false) [MỚI]
# - locked_at (datetime, nullable) [MỚI]
# - locked_by_id (FK → users, nullable) [MỚI]

# MeterReading (chỉ số công tơ per kỳ)
# - id
# - meter_id (FK)
# - monthly_period_id (FK)
# - reading_start (decimal)
# - reading_end (decimal)
# - consumption (decimal, computed)

# MainMeterReading (chỉ số công tơ tổng per kỳ)
# - id
# - main_meter_id (FK)
# - monthly_period_id (FK)
# - electricity_supply_kw (decimal)

# MonthlyCalculation (kết quả tính toán per đầu mối per kỳ — 22 data columns)
# - id
# - contact_point_id (FK)
# - monthly_period_id (FK)
# - total_personnel, rank1_kw–rank7_kw
# - water_pump_standard_kw, water_pump_actual_kw
# - total_standard_kw, total_usage_kw, total_deduction_kw
# - remaining_standard_kw, meter_usage_kw
# - over_under_kw
# - savings_deduction_kw, loss_deduction_kw
# - division_public_deduction_kw, unit_public_deduction_kw, other_deduction_kw
# - unit_price, total_amount

# UnitConfig (cấu hình per đơn vị per kỳ)
# - id
# - organization_id (FK)
# - monthly_period_id (FK)
# - savings_rate, division_public_rate, unit_public_rate
# - other_deduction_type, other_deduction_value

# ContactPointOtherDeduction (cột "Khác" per đầu mối per kỳ)
# - id
# - contact_point_id (FK)
# - monthly_period_id (FK)
# - other_type, other_value
```

### 2.2. Quyền (ability)

```ruby
# admin_level1:
#   - :manage, :all (toàn quyền)
#   - Ngoại trừ: cannot :update_unit_config [MỚI]
#   - Ngoại trừ: cannot :manage, Backup [MỚI]

# admin_unit:
#   - Zone: đọc zone trong managed_zone_ids
#   - MainMeter: đọc (own org zone) + manage (managed zones)
#   - MainMeterReading: manage (managed zones)
#   - PumpStation: manage (managed zones)
#   - PumpStationAssignment: manage (managed zones)
#   - ContactPoint, Meter, Personnel: CRUD trong đơn vị mình
#   - ContactPointGroup: CRUD trong đơn vị mình
#   - WorkGroup: CRUD trong đơn vị mình
#   - MonthlyCalculation: read + recalculate (own org)
#   - UnitConfig: read + update_unit_config (own org)

# commander:
#   - Đọc: ContactPoint, Meter, Personnel, WorkGroup, ContactPointGroup,
#           MonthlyCalculation, UnitConfig, Zone (own org)
#   - Không sửa bất cứ gì

# tech:
#   - manage User
#   - read audit_log
#   - manage Backup
```

### 2.3. Engine — tách 3, điều phối bởi CalculationOrchestrator

```
CalculationOrchestrator (app/services/calculation_orchestrator.rb)
  ├── LossCalculator (app/services/loss_calculator.rb)
  ├── PumpAllocationCalculator (app/services/pump_allocation_calculator.rb)
  └── SummaryCalculator (app/services/summary_calculator.rb)
```

**CalculationOrchestrator:**
- Constructor: `new(organization:, monthly_period:)`
- Public: `call` (compute + persist MonthlyCalculation), `compute` (chỉ tính), `warnings`
- Flow: LossCalculator → PumpAllocationCalculator → SummaryCalculator → persist

**LossCalculator:**
- Constructor: `new(zone:, monthly_period:)`
- Public: `call`, `pump_loss_share(pump_station)`, `warnings`
- Logic:
  1. A = tổng số điện lực tất cả MainMeter trong zone − tổng sử dụng công tơ no_loss trong zone
  2. B = tổng sử dụng tất cả công tơ có tổn hao trong zone (normal + public_meter + pump_station)
  3. C = A − B (tổng tổn hao toàn khu vực). **[MỚI]** Nếu C < 0 → clamp về 0, thêm warning `:negative_loss`.
  4. Phân bổ: mỗi công tơ có tổn hao nhận = C × (sử dụng công tơ đó ÷ B)
- Output Hash: `{ total_zone_loss, loss_pool_consumption_in_zone, loss_pool_consumption_by_cp, zone_supply_kw, warnings }`

**PumpAllocationCalculator:**
- Constructor: `new(zone:, monthly_period:, loss_calculator:)` — inject object để share memoization
- Public: `call`
- Logic:
  1. D = Σ(sử dụng điện của công tơ bơm nước X + tổn hao công tơ bơm nước X), với X là từng công tơ bơm nước trong khu vực. D là tổng pool bơm nước toàn khu vực.
  2. Các nhóm đối tượng có tỷ lệ cố định → nhận D × tỷ lệ
  3. Phần còn lại (D − tổng phần cố định) chia theo quân số
  4. Organization/ContactPointGroup → chia tiếp xuống đầu mối theo quân số
- Output Hash: `{ allocations_by_cp, allocations_by_assignment, total_pool_kw }`

**SummaryCalculator:**
- Constructor: `new(organization:, monthly_period:, loss_results:, pump_results:)` — nhận plain Hashes
- Public: `compute(contact_points)` → Array<Hash>
- Per contact_point (đầu mối sinh hoạt):
  - Tiêu chuẩn = tổng (quân số × định mức) + (tổng quân số × 9,45 bơm nước tiêu chuẩn)
  - Sử dụng điện sinh hoạt = tổng (cuối kỳ − đầu kỳ) công tơ sinh hoạt + công tơ sinh hoạt không tổn hao
  - Sử dụng điện bơm nước = pump_results[contact_point_id]
  - Tổng sử dụng điện = sử dụng điện sinh hoạt + sử dụng điện bơm nước
  - Các khoản trừ: tiết kiệm, tổn hao, công cộng Sư đoàn, công cộng đơn vị, khác
  - Tiêu chuẩn còn lại = tiêu chuẩn − các khoản trừ
  - Chênh lệch = tổng sử dụng điện − tiêu chuẩn còn lại
  - Thành tiền = chênh lệch × đơn giá
- **[MỚI]** DB lưu 22 data columns. UI/CSV split `over_under_kw` → `surplus_kw` + `deficit_kw` và `total_amount` → `surplus_amount` + `deficit_amount` → hiển thị 28 cột.

### 2.4. Quy ước code

- `decimal` (PostgreSQL numeric, Ruby BigDecimal) cho tất cả cột tiền/kW — không dùng float
- Không làm tròn số ở bất cứ đâu trong engine
- Vietnamese number format: UI dùng dấu chấm phân cách hàng nghìn, dấu phẩy thập phân (ví dụ 2.336,4). CSV giữ raw numbers.
- Cross-zone scoping: tất cả controller phải dùng `accessible_by(current_ability).find(params[:id])` — không dùng `Model.find(params[:id])` trực tiếp
- LockablePeriod concern áp dụng cho các controllers liên quan nhập liệu [MỚI]
- Commit messages và PR titles/descriptions bằng tiếng Anh
- I18n: UI tiếng Việt (config/locales/vi.yml), code tiếng Anh
