# Tổng hợp thiết kế hệ thống quản lý điện nước nội bộ

> Phiên bản: **1.2.0**
> Ngày: 12/05/2026
> Mục đích: Tổng hợp toàn bộ hiểu biết về hệ thống sau khi rà soát thiết kế, để vợ review và chốt trước khi implement.

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

---

### 1.6. Tổn hao

Tính trên toàn khu vực:
- A = tổng số điện lực tất cả công tơ tổng trong khu vực − tổng sử dụng điện tất cả công tơ không tổn hao trong khu vực
- B = tổng sử dụng điện tất cả công tơ có tổn hao trong khu vực (bao gồm công tơ sinh hoạt, công tơ công cộng, công tơ bơm nước)
- C = A − B (tổng tổn hao toàn khu vực)
- Tổn hao phân bổ cho từng công tơ = C × (sử dụng điện công tơ đó ÷ B)

Quản trị viên đơn vị thấy kết quả tổn hao phân bổ cho các công tơ của đơn vị mình trong Bảng tổng hợp, tại cột "Tổn hao".

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

Nhiều nhóm có thể có tỷ lệ cố định đồng thời. Tổng tỷ lệ cố định không vượt 100%.

---

### 1.8. Vai trò

| Vai trò | Quyền |
|---|---|
| Quản trị viên cấp 1 | Thiết lập ban đầu (đơn giá, tỷ lệ, định mức). Tạo khu vực, gán đơn vị, chỉ định đơn vị quản lý. Quản lý tài khoản. Mở khóa tháng cũ. Nhật ký. Toàn quyền thao tác mọi khu vực. |
| Quản trị viên đơn vị | Khai báo đầu mối, công tơ, quân số, đầu mối ngoài biên chế. Nhập chỉ số công tơ hàng tháng. Cấu hình công cộng đơn vị, cột "Khác". Nếu là đơn vị quản lý khu vực: nhập số công tơ tổng, quản lý trạm bơm, nhập chỉ số trạm bơm, gán phân bổ bơm nước. |
| Chỉ huy đơn vị | Chỉ xem, không thao tác. |
| Kỹ thuật | Quản lý tài khoản, nhật ký, sao lưu. |

---

### 1.9. Bảng thu tiền

- Tính riêng cho từng đơn vị cấp 2.
- Mỗi dòng = 1 đầu mối sinh hoạt (có quân số > 0).
- Đầu mối công cộng không có dòng (quân số = 0).
- Đầu mối ngoài biên chế không có dòng (không có công tơ).
- Gộp đầu mối theo khối để hiển thị có cấu trúc (nếu đầu mối được gán khối).

---

### 1.10. Thuật ngữ

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

## Phần 2 — Code

### 2.1. Thay đổi so với code hiện tại

| Hạng mục | Hiện tại | Cần đổi |
|---|---|---|
| `MainMeter` vừa là công tơ tổng vừa đóng vai khu vực | Tách `Zone` (khu vực) + `MainMeter belongs_to :zone` |
| `PumpStation` không gắn khu vực | `PumpStation belongs_to :zone` |
| `Organization belongs_to :main_meter` | `Organization belongs_to :zone` |
| Chưa có đơn vị quản lý khu vực | `Zone` thêm `manager_organization_id` |
| `PumpStationAssignment` polymorphic 3 loại | Thêm loại thứ 4: `ContactPointGroup` |
| Chưa có model nhóm đầu mối | Thêm `ContactPointGroup` + `ContactPointGroupMembership` |
| `ContactPoint` không có trường phân loại | Thêm `contact_point_type` enum: `residential`, `communal` |
| `Meter` gộp `no_loss` vào `meter_type` enum | Tách `no_loss` boolean riêng, `meter_type` enum: `normal`, `public_meter`, `pump_station` |
| Công tơ tổng, trạm bơm: `admin_level1` only | `admin_level1` + `admin_unit` (nếu là đơn vị quản lý khu vực) |
| Phân bổ bơm nước: `admin_level1` only | `admin_level1` + `admin_unit` (nếu là đơn vị quản lý khu vực) |
| Thuật ngữ UI: "Khu vực đồng hồ tổng" | "Khu vực" |
| Thuật ngữ UI: "Nhóm" (nhóm đầu mối hiển thị) | "Khối" (nếu khách yêu cầu — tech debt nhỏ) |
| Engine: 1 `CalculationEngine` làm tất cả | Tách 3: `LossCalculator`, `PumpAllocationCalculator`, `SummaryCalculator` |
| Engine tổn hao lấy số từ 1 `MainMeter` | Tổng hợp từ tất cả `MainMeter` trong `Zone` |
| Validate tổng `fixed_pump_percentage` ≤ 100% per zone | Kiểm tra, thêm nếu thiếu |
| F11 chưa gộp đầu mối theo khối | Thêm hiển thị đầu mối theo khối (nếu được gán khối) |

### 2.2. Schema mới

```ruby
# Zone (khu vực)
# - id
# - name
# - manager_organization_id (FK → organizations)

# MainMeter belongs_to :zone
# - id
# - zone_id
# - (các cột chỉ số đầu kỳ, cuối kỳ, sử dụng theo kỳ)

# PumpStation belongs_to :zone
# - id
# - zone_id
# - name

# Organization belongs_to :zone
# - id
# - zone_id
# - name
# - parent_id (cấp 1 / cấp 2)

# ContactPoint (đầu mối)
# - id
# - organization_id
# - name
# - group_name (khối — nullable)
# - contact_point_type enum: residential (sinh hoạt), communal (công cộng)

# WorkGroup (đầu mối ngoài biên chế) — model riêng, không gộp vào ContactPoint
# - id
# - organization_id
# - name
# - personnel_count (quân số nhập tay)

# ContactPointGroup (nhóm đầu mối)
# - id
# - name
# - organization_id

# ContactPointGroupMembership
# - contact_point_group_id
# - contact_point_id

# PumpStationAssignment
# - pump_station_id
# - assignable_type (Organization / ContactPoint / WorkGroup / ContactPointGroup)
# - assignable_id
# - fixed_pump_percentage (decimal, nullable)

# Meter (công tơ)
# - id
# - contact_point_id (nullable — nil cho công tơ bơm nước)
# - pump_station_id (nullable — nil cho công tơ đầu mối)
# - meter_type enum: normal (sinh hoạt), public_meter (công cộng), pump_station (bơm nước)
# - no_loss boolean (default: false) — đánh dấu công tơ không tổn hao, áp dụng cho bất kỳ loại nào
```

### 2.3. Quyền (ability)

```ruby
# admin_level1:
#   - Zone: CRUD tất cả
#   - MainMeter: CRUD tất cả
#   - PumpStation: CRUD tất cả
#   - PumpStationAssignment: CRUD tất cả
#   - Organization: CRUD tất cả
#   - ContactPoint, Meter, Personnel, WorkGroup: CRUD tất cả
#   - ContactPointGroup: CRUD tất cả

# admin_unit:
#   - Zone: đọc zone của đơn vị mình
#   - MainMeter: đọc/sửa nếu zone.manager_organization == đơn vị mình
#   - PumpStation: CRUD nếu zone.manager_organization == đơn vị mình
#   - PumpStationAssignment: CRUD nếu zone.manager_organization == đơn vị mình
#   - ContactPoint, Meter, Personnel: CRUD trong đơn vị mình
#   - ContactPointGroup: CRUD trong đơn vị mình
#   - WorkGroup (đầu mối ngoài biên chế): CRUD trong đơn vị mình

# commander: đọc tất cả trong đơn vị mình, không sửa

# tech: quản lý tài khoản, nhật ký, sao lưu
```

### 2.4. Engine (tách 3)

```
LossCalculator (engine tính tổn hao):
  Input: zone_id, period_id
  1. A = tổng số điện lực tất cả MainMeter trong zone − tổng sử dụng công tơ no_loss trong zone
  2. B = tổng sử dụng tất cả công tơ có tổn hao trong zone (normal + public_meter + pump_station)
  3. C = A − B (tổng tổn hao toàn khu vực)
  4. Phân bổ: mỗi công tơ có tổn hao nhận = C × (sử dụng công tơ / B)
  Output: hash { meter_id => loss_amount }

PumpAllocationCalculator (engine tính bơm nước):
  Input: zone_id, period_id, loss_results (từ LossCalculator)
  1. D = Σ(sử dụng điện công tơ bơm nước X + tổn hao công tơ bơm nước X)
     D là tổng pool bơm nước toàn khu vực.
  2. Các nhóm đối tượng có tỷ lệ cố định → nhận D × tỷ lệ
  3. Phần còn lại (D − tổng phần cố định) chia theo quân số
  4. Organization/ContactPointGroup → chia tiếp xuống đầu mối theo quân số
  Output: hash { contact_point_id => pump_amount }

SummaryCalculator (engine tổng hợp):
  Input: zone_id, period_id, loss_results, pump_results
  Per contact_point (đầu mối sinh hoạt):
    - Tiêu chuẩn = tổng (quân số × định mức) + (tổng quân số × 9,45 bơm nước tiêu chuẩn)
    - Sử dụng điện sinh hoạt = tổng (cuối kỳ − đầu kỳ) công tơ sinh hoạt + công tơ sinh hoạt không tổn hao
    - Sử dụng điện bơm nước = pump_results[contact_point_id]
    - Tổng sử dụng điện = sử dụng điện sinh hoạt + sử dụng điện bơm nước
    - Các khoản trừ: tiết kiệm, tổn hao, công cộng Sư đoàn, công cộng đơn vị, khác
    - Tiêu chuẩn còn lại = tiêu chuẩn − các khoản trừ
    - Chênh lệch = tổng sử dụng điện − tiêu chuẩn còn lại
    - Thành tiền = chênh lệch × đơn giá
  Output: bảng 22 cột per contact_point
```
