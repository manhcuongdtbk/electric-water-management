# Thiết kế hệ thống quản lý điện nội bộ Sư đoàn — Hệ thống v2

> **Phiên bản tài liệu:** 2.9.0
> **Ngày:** 21/05/2026
> **Tính chất:** Tài liệu thiết kế hệ thống v2, nguồn sự thật cho implementation.
> **Nguồn nghiệp vụ:** V2_XAC_NHAN_NGHIEP_VU (phiên bản mới nhất tại thời điểm thiết kế: v2.11.0)

### Nguyên tắc viết

Tuyệt đối không viết tắt, không rút gọn — áp dụng mọi nơi: tài liệu, code (tên biến, method, cột, i18n, commit message), giao diện, giao tiếp. Ngoại trừ thuật ngữ phổ biến ai cũng hiểu ngay: CRUD, UI.

---

## Mục lục

1. [Bảng tính tiền](#bảng-tính-tiền)
2. [Schema](#schema)
3. [Engine tính toán](#engine-tính-toán)
4. [Phân quyền](#phân-quyền)
5. [Kỳ tính toán](#kỳ-tính-toán)
6. [Sidebar và routes](#sidebar-và-routes)
7. [Trang tổng quan](#trang-tổng-quan)
8. [Tra cứu lịch sử](#tra-cứu-lịch-sử)
9. [Xuất Excel](#xuất-excel)
10. [Xóa dữ liệu](#xóa-dữ-liệu)
11. [Luồng thiết lập ban đầu](#luồng-thiết-lập-ban-đầu)
12. [Luồng thao tác hàng tháng](#luồng-thao-tác-hàng-tháng)
13. [Yêu cầu kỹ thuật](#yêu-cầu-kỹ-thuật)

---

## Bảng tính tiền

Bảng tính tiền là kết quả chính của hệ thống. Hiển thị chi tiết từng đầu mối sinh hoạt với đầy đủ quân số, tiêu chuẩn, khoản trừ, sử dụng, kết quả thừa/thiếu và thành tiền.

Bảng tính tiền chỉ hiển thị đầu mối sinh hoạt (residential). Đầu mối công cộng (public), bơm nước (water_pump), ngoài biên chế (non_establishment) không xuất hiện trên bảng — chúng chỉ tham gia engine tính toán (tổn hao, phân bổ bơm nước) rồi kết quả được phân bổ vào đầu mối sinh hoạt.

### Đơn giá

Đơn giá hiển thị phía trên bảng (không phải cột riêng). Cùng 1 giá trị cho tất cả dòng trong cùng kỳ.

### Cấu trúc cột

Bảng có 28 cột khi xem 1 đơn vị, hoặc 30 cột khi xem gộp (thêm cột Khu vực và Đơn vị).

Tên cột tuyệt đối không viết tắt, không rút gọn. Người dùng có thể kéo thay đổi độ rộng cột.

**28 cột chi tiết (trái sang phải):**

| Nhóm | Cột | Ghi chú |
|---|---|---|
| Thông tin đầu mối | Khối | Gộp dọc |
| Thông tin đầu mối | Nhóm | Gộp dọc |
| Thông tin đầu mối | Tên đầu mối | |
| Thông tin đầu mối → Quân số theo nhóm cấp bậc | (7 cột, tên lấy từ dữ liệu nhóm cấp bậc) | Tên đầy đủ, không rút gọn. Hiện tại 7 nhóm, tương lai có thể thay đổi |
| Thông tin đầu mối | Tổng quân số | |
| Tiêu chuẩn | Tiêu chuẩn điện sinh hoạt | |
| Tiêu chuẩn | Tiêu chuẩn điện bơm nước | |
| Tiêu chuẩn | Tổng tiêu chuẩn | |
| Khoản trừ | Tiết kiệm của Bộ | |
| Khoản trừ | Tổn hao | |
| Khoản trừ | Công cộng dùng chung Sư đoàn | |
| Khoản trừ | Công cộng dùng chung đơn vị | |
| Khoản trừ | Khác | Cho phép giá trị âm |
| Khoản trừ | Tổng trừ | |
| (không nhóm) | Tiêu chuẩn còn lại | |
| Sử dụng | Sử dụng điện sinh hoạt | |
| Sử dụng | Sử dụng điện bơm nước | |
| Sử dụng | Tổng sử dụng | |
| Kết quả | Thừa (kW) | Màu xanh |
| Kết quả | Thiếu (kW) | Màu đỏ |
| Kết quả | Thành tiền thừa | Tham khảo, không phải trả tiền |
| Kết quả | Thành tiền thiếu | Phải trả tiền |

**2 cột bổ sung khi xem gộp (nhiều khu vực hoặc nhiều đơn vị):**

| Cột | Vị trí | Ghi chú |
|---|---|---|
| Khu vực | Đầu tiên (trước Khối) | Gộp dọc, nằm trong nhóm Thông tin đầu mối |
| Đơn vị | Thứ hai (sau Khu vực, trước Khối) | Gộp dọc, nằm trong nhóm Thông tin đầu mối |

### Header 3 hàng

Header bảng gồm 3 hàng phân cấp:

```
Hàng 1 (nhóm lớn):
┌─────────────────────────────────────┬───────────┬────────────┬───────────────┬───────────┬───────────┐
│ Thông tin đầu mối                   │ Tiêu chuẩn│ Khoản trừ  │ Tiêu chuẩn   │ Sử dụng   │ Kết quả   │
│                                     │           │            │ còn lại       │           │           │
│                                     │           │            │ (rowspan 3)   │           │           │
├──────────────────┬──────────────────┤           │            │               │           │           │
│ Hàng 2:          │ Quân số theo     │ (các cột  │ (các cột   │               │ (các cột  │ (các cột  │
│ Khu vực          │ nhóm cấp bậc    │  rowspan 2)│  rowspan 2)│               │  rowspan 2)│  rowspan 2)│
│ Đơn vị           │                  │           │            │               │           │           │
│ Khối             │                  │           │            │               │           │           │
│ Nhóm             │                  │           │            │               │           │           │
│ Tên đầu mối      │                  │           │            │               │           │           │
│ Tổng quân số     │                  │           │            │               │           │           │
│ (tất cả rowspan 2)│                 │           │            │               │           │           │
├──────────────────┼──────────────────┤           │            │               │           │           │
│ Hàng 3:          │ Tên 7 nhóm       │           │            │               │           │           │
│ (trống, đã       │ cấp bậc đầy đủ  │           │            │               │           │           │
│  rowspan ở hàng 2)│                 │           │            │               │           │           │
└──────────────────┴──────────────────┴───────────┴────────────┴───────────────┴───────────┴───────────┘
```

### Gộp dọc (merge)

Cấu trúc phân cấp từ trái sang phải: Khu vực → Đơn vị → Khối → Nhóm → Tên đầu mối.

Quy tắc gộp:

- Các dòng cùng giá trị liên tiếp ở cùng cột được gộp thành 1 ô merge dọc (rowspan).
- Đầu mối không thuộc cấp nào → ô cột đó để trống, không có text placeholder.
- Đầu mối sinh hoạt thuộc khu vực (không thuộc đơn vị): gộp thẳng vào ô Khu vực, cột Đơn vị/Khối/Nhóm để trống.
- Đầu mối thuộc đơn vị nhưng không có khối: cột Khối trống.
- Đầu mối thuộc đơn vị nhưng không có nhóm: cột Nhóm trống.
- Đầu mối thuộc nhóm trực tiếp (không có khối): cột Khối trống, cột Nhóm có giá trị.
- Đầu mối thuộc nhóm trong khối: cả cột Khối và Nhóm đều có giá trị.

Minh hoạ gộp (chỉ hiển thị cột Khu vực → Tên đầu mối):

```
┌───────────┬───────────────┬─────────────────┬────────────────┬──────────────────────────┐
│ Khu vực   │ Đơn vị        │ Khối            │ Nhóm           │ Tên đầu mối              │
├───────────┼───────────────┼─────────────────┼────────────────┼──────────────────────────┤
│           │               │                 │                │ Trưởng ban + Quý         │
│           │               │                 │ Ban Tác huấn   ├──────────────────────────┤
│           │               │ Phòng Tham mưu  │                │ Tuấn, Nam, Công          │
│           │               │                 ├────────────────┼──────────────────────────┤
│           │ Trung đoàn 95 │                 │                │ Văn thư                  │
│           │               │                 │                ├──────────────────────────┤
│           │               │                 │                │ Lái xe                   │
│           │               ├─────────────────┼────────────────┼──────────────────────────┤
│           │               │                 │                │ Nhà ở                    │
│           │               │                 │ Tổ xe          ├──────────────────────────┤
│ Khu vực 1 │               │                 │                │ Bếp                      │
│           │               │                 ├────────────────┼──────────────────────────┤
│           │               │                 │                │ Kho vật tư               │
│           ├───────────────┼─────────────────┼────────────────┼──────────────────────────┤
│           │               │                 │                │ Đại đội 1                │
│           │ Tiểu đoàn 14  │                 │                ├──────────────────────────┤
│           │               │                 │                │ Đại đội 2                │
│           ├───────────────┼─────────────────┼────────────────┼──────────────────────────┤
│           │               │                 │                │ Chỉ huy khu vực          │
│           │               │                 │                ├──────────────────────────┤
│           │               │                 │                │ Phó chỉ huy khu vực      │
├───────────┼───────────────┼─────────────────┼────────────────┼──────────────────────────┤
│           │               │ Phòng Chính trị │                │ Chủ nhiệm + Hòa          │
│           │               │                 │                ├──────────────────────────┤
│ Khu vực 2 │ Trung đoàn 18 │                 │                │ Tuyên huấn               │
│           │               ├─────────────────┼────────────────┼──────────────────────────┤
│           │               │                 │                │ Hậu cần                  │
└───────────┴───────────────┴─────────────────┴────────────────┴──────────────────────────┘
```

Lưu ý trong minh hoạ:

- "Chỉ huy khu vực" và "Phó chỉ huy khu vực" là đầu mối sinh hoạt thuộc khu vực — nằm dưới Khu vực 1, cột Đơn vị/Khối/Nhóm đều trống.
- "Kho vật tư" không có khối, không có nhóm — cột Khối và Nhóm trống.
- "Nhà ở" và "Bếp" thuộc nhóm "Tổ xe" nhưng không thuộc khối — cột Khối trống.
- "Văn thư" và "Lái xe" thuộc khối "Phòng Tham mưu" nhưng không thuộc nhóm — cột Nhóm trống.

### Dropdown filter

Bảng có 2 dropdown filter phía trên:

- **Khu vực:** Tất cả khu vực / chọn 1 khu vực cụ thể.
- **Đơn vị:** Tất cả đơn vị / chọn 1 đơn vị cụ thể. Danh sách đơn vị thay đổi theo khu vực đã chọn.

Hành vi cột Khu vực và Đơn vị theo filter:

| Filter | Cột Khu vực | Cột Đơn vị |
|---|---|---|
| Tất cả khu vực, tất cả đơn vị | Hiện, gộp dọc | Hiện, gộp dọc |
| 1 khu vực, tất cả đơn vị | Ẩn | Hiện, gộp dọc |
| 1 khu vực, 1 đơn vị | Ẩn | Ẩn |

Khi chọn đơn vị quản lý khu vực, dữ liệu bao gồm cả đầu mối sinh hoạt thuộc khu vực (theo nghiệp vụ mục 6).

### Thứ tự sắp xếp

Dòng trong bảng tính tiền sắp xếp theo: Khu vực (alphabetical) → Đơn vị (alphabetical, đầu mối thuộc khu vực xếp sau đơn vị cuối cùng) → Khối (alphabetical, NULLS LAST) → Nhóm (alphabetical, NULLS LAST) → Tên đầu mối (alphabetical).

### Hàng tổng

Cuối bảng có 1 hàng tổng duy nhất. Không có hàng tổng phụ theo khu vực hay đơn vị — muốn xem tổng riêng thì dùng dropdown filter.

### Thành phần UI bọc quanh bảng

Ngoài bảng, trang bảng tính tiền còn có:

- Đơn giá hiển thị phía trên bảng.
- Dropdown filter khu vực và đơn vị.
- Nút "Tính toán lại" (nghiệp vụ mục 14).
- Cảnh báo khi thiếu dữ liệu: đơn vị chưa nhập, khu vực thiếu công tơ tổng, trạm bơm chưa có số liệu (nghiệp vụ mục 15).
- Tìm kiếm, sắp xếp, lọc, phân trang, hiển thị tổng số bản ghi, chọn số dòng mỗi trang (nghiệp vụ mục 19).
- Hover highlight dòng.
- Xuất Excel (nghiệp vụ mục 18).

### Mapping filter theo vai trò

| Vai trò | Khu vực | Đơn vị | Dữ liệu |
|---|---|---|---|
| Quản trị viên hệ thống | Chọn tự do | Chọn tự do | Tất cả đầu mối, bao gồm đầu mối thuộc khu vực |
| Quản trị viên đơn vị quản lý khu vực | Cố định (khu vực của mình) | Cố định (đơn vị mình) | Đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực |
| Chỉ huy đơn vị quản lý khu vực | Cố định (khu vực của mình) | Cố định (đơn vị mình) | Giống quản trị viên đơn vị quản lý khu vực, chỉ xem |
| Quản trị viên đơn vị | Cố định (khu vực của mình) | Cố định (đơn vị mình) | Chỉ đầu mối đơn vị mình |
| Chỉ huy đơn vị | Cố định (khu vực của mình) | Cố định (đơn vị mình) | Giống quản trị viên đơn vị, chỉ xem |

---

## Schema

### Quy ước đặt tên

Tên trong code sát nghiệp vụ nhất có thể, dịch sang tiếng Anh. Không đặt tên khác, không sáng tạo thêm.

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

### Soft delete

Dùng gem **discard**. Các bảng có soft delete: zones, contact_points, meters, units, blocks, groups, main_meters. Thêm cột `discarded_at` (datetime, nullable, indexed).

> **Quyết định soft delete thay vì hard delete + restrict:** Nghiệp vụ cho phép "xóa đầu mối, dữ liệu kỳ cũ giữ nguyên." Hard delete → foreign key từ meter_readings, calculations, pump_allocations kỳ cũ trỏ tới bản ghi không tồn tại → lỗi khi mở kỳ cũ. Soft delete → foreign key luôn hợp lệ, dữ liệu kỳ cũ truy cập được.
> **Tradeoff:** Mọi query phải dùng scope `.kept` (discard) để filter bản ghi đã xóa. Discard không dùng default_scope (khác paranoia) nên phải gọi tường minh — an toàn hơn nhưng dễ quên. Giải quyết: convention ghi rõ trong CLAUDE.md.

> **Quyết định dùng discard thay vì paranoia:** Paranoia override destroy + dùng default_scope → hành vi bất ngờ, dependent :destroy cascade xóa luôn association. Discard không override gì, thêm method riêng (discard/undiscard), scope riêng (kept/discarded). Rõ ràng, ít bất ngờ. Paranoia đã deprecated, không khuyến nghị cho dự án mới.

> **Quyết định zones soft delete (v2.3.0):** Ban đầu zones không soft delete (v2.2.0) vì nghiệp vụ yêu cầu xóa hết đơn vị trước khi xóa khu vực. Tuy nhiên zone tham gia trực tiếp vào engine tính toán (tổn hao, bơm nước) — hard delete zone mất main_meter_readings kỳ cũ, vi phạm nguyên tắc "mọi thao tác không ảnh hưởng kỳ cũ." Soft delete zone → zone vẫn tồn tại trong database, main_meters và main_meter_readings kỳ cũ giữ nguyên, tra cứu lịch sử hoạt động đúng.
> **Hệ quả:** Khi discard zone → discard các main_meters thuộc zone đó (before_discard callback). main_meter_readings giữ nguyên (foreign key vẫn hợp lệ vì main_meter chỉ soft delete).

### Nguyên tắc thiết kế

- **Mỗi kỳ có bản sao cấu hình riêng.** Sửa kỳ này tuyệt đối không ảnh hưởng kỳ khác. Mọi dữ liệu có thể thay đổi giữa các kỳ đều phải có period_id.
- **Dữ liệu luôn đúng.** Ưu tiên normalize, không denormalize trừ khi bắt buộc. Chấp nhận query phức tạp hơn (viết 1 method/scope dùng lại) để tránh sync dữ liệu.
- **foreign key constraint ở database.** Không dùng polymorphic association. Dùng nullable foreign key khi cần trỏ tới nhiều loại.
- **Snapshot per kỳ.** Dữ liệu thay đổi giữa các kỳ được copy khi mở kỳ mới. Engine tính toán dùng snapshot, không dùng giá trị hiện tại.

> **Lý do snapshot:** Nghiệp vụ yêu cầu "sửa kỳ này tuyệt đối không ảnh hưởng kỳ khác" và "mở lại kỳ cũ khi có sai sót." Nếu engine dùng giá trị hiện tại (meters.no_loss, contact_points.personnel_count, ranks.quota) → mở kỳ cũ tính lại sẽ dùng giá trị đã thay đổi, cho kết quả khác ban đầu. Snapshot đảm bảo mỗi kỳ dùng đúng giá trị tại thời điểm kỳ đó.
> **Các bảng snapshot:** ranks (period_id), meter_readings.no_loss, non_establishment_snapshots, pump_allocations (period_id).
> **Tradeoff:** Dữ liệu nhân bản: 7 ranks × N kỳ, pump_allocations × N kỳ. Với N nhỏ (vài chục kỳ = vài năm) không ảnh hưởng.

### Bảng chi tiết

Mọi bảng đều có `id` (bigint auto-increment primary key) + `created_at` + `updated_at` (ẩn, không liệt kê).

### Database indexes

Ngoài foreign key index tự động, cần tạo thêm:

| Bảng | Index | Loại | Lý do |
|---|---|---|---|
| periods | ((true)) WHERE closed = false | Partial unique | Đảm bảo chỉ 1 kỳ mở tại 1 thời điểm ở database level, chống race condition. PostgreSQL: `CREATE UNIQUE INDEX idx_periods_only_one_open ON periods ((true)) WHERE closed = false` |
| meter_readings | (meter_id, period_id) | Unique | Mỗi công tơ chỉ có 1 reading per kỳ |
| main_meter_readings | (main_meter_id, period_id) | Unique | Mỗi công tơ tổng chỉ có 1 reading per kỳ |
| personnel_entries | (contact_point_id, period_id, rank_id) | Unique | Mỗi đầu mối + kỳ + rank chỉ có 1 entry |
| non_establishment_snapshots | (contact_point_id, period_id) | Unique | Mỗi đầu mối + kỳ chỉ có 1 snapshot |
| unit_configs | (unit_id, period_id) | Unique | Mỗi đơn vị + kỳ chỉ có 1 config |
| other_deductions | (contact_point_id, period_id) | Unique | Mỗi đầu mối + kỳ chỉ có 1 deduction |
| calculations | (contact_point_id, period_id) | Unique | Mỗi đầu mối + kỳ chỉ có 1 calculation |
| contact_points | (discarded_at) | Regular | Filter soft delete |
| meters | (discarded_at) | Regular | Filter soft delete |
| units | (discarded_at) | Regular | Filter soft delete |
| zones | (discarded_at) | Regular | Filter soft delete |

> **Quyết định partial unique index cho periods.closed:** Model validation "chỉ 1 kỳ open" có race condition — 2 request đồng thời có thể cùng check không có kỳ mở rồi cùng tạo. Partial unique index ở database level chống được race condition.
> **Tradeoff:** PostgreSQL specific (không portable sang database khác). Chấp nhận được vì hệ thống chỉ dùng PostgreSQL.

#### zones (khu vực)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng |
| manager_unit_id | foreign key → units | Nullable. Đơn vị quản lý khu vực. Null khi chưa chỉ định |
| discarded_at | datetime | Nullable. Soft delete (discard) |

#### units (đơn vị)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng |
| zone_id | foreign key → zones | Bắt buộc. Không đổi được sau khi tạo |
| discarded_at | datetime | Nullable. Soft delete (discard) |

Auto-assign đơn vị quản lý khu vực: khi tạo unit mới, nếu zone chưa có manager_unit_id và zone chỉ có đúng 1 unit (unit vừa tạo), hệ thống tự gán zones.manager_unit_id = unit.id. Implement bằng after_create callback trên Unit model.

#### contact_points (đầu mối)

> **Quyết định:** 1 bảng duy nhất cho 4 loại đầu mối (residential, public, water_pump, non_establishment).
> **Lý do:** Nghiệp vụ gọi chung là "đầu mối" với 4 loại. 4 loại chia sẻ nhiều thuộc tính (tên, thuộc đơn vị hoặc khu vực). Tách 4 bảng → code phải query 4 nơi, polymorphic association rối, khó bảo trì.
> **Tradeoff:** Một số cột chỉ dùng cho 1 loại (personnel_count chỉ non_establishment, block_id/group_id chỉ residential) → có cột nullable theo loại. Chấp nhận được vì validation theo loại đã kiểm soát chặt.

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng trong cùng phạm vi. Scope: unique theo (name, unit_id, zone_id, contact_point_type) — cho phép trùng tên giữa loại khác nhau trong cùng đơn vị/khu vực |
| contact_point_type | enum | residential, public, water_pump, non_establishment |
| unit_id | foreign key → units | Nullable. Null khi thuộc khu vực trực tiếp |
| zone_id | foreign key → zones | Nullable. Có giá trị khi thuộc khu vực trực tiếp (unit_id null). Null khi thuộc đơn vị (lấy zone qua unit.zone_id) |
| block_id | foreign key → blocks | Nullable. Chỉ đầu mối sinh hoạt |
| group_id | foreign key → groups | Nullable. Chỉ đầu mối sinh hoạt |
| personnel_count | integer | Nullable. Chỉ ngoài biên chế (1 con số tổng, ≥ 1) |
| discarded_at | datetime | Nullable. Soft delete (discard) |

> **Quyết định zone_id nullable:** Không denormalize (không bắt buộc zone_id cho tất cả). Đầu mối thuộc đơn vị lấy zone qua unit.zone_id.
> **Lý do:** Denormalize → phải sync zone_id khi đổi (dù nghiệp vụ không cho đổi zone đơn vị, vẫn thêm validation chống lệch). Nullable sạch hơn, không cần sync. Query phức tạp hơn chút nhưng viết 1 model method dùng lại.
> **Tradeoff:** Mỗi lần cần zone của đầu mối thuộc đơn vị phải join qua units. Với data nhỏ (vài trăm đầu mối) không ảnh hưởng hiệu năng.

> **Quyết định giữ cả block_id và group_id:** Đầu mối có thể thuộc khối trực tiếp (không qua nhóm) → không lấy khối qua group.block_id được. Phải giữ block_id trên contact_points cho trường hợp này.
> **Tradeoff:** Đầu mối thuộc nhóm trong khối có cả block_id lẫn group_id — block_id thừa (lấy được qua group.block_id). Chấp nhận vì không có cách normalize trường hợp đầu mối trực tiếp trong khối.

Validation theo loại:

| Loại | unit_id | zone_id | công tơ | quân số cấp bậc | personnel_count | khối/nhóm |
|---|---|---|---|---|---|---|
| residential | XOR: đúng 1 trong unit_id hoặc zone_id có giá trị | (xem cột trước) | ≥ 1 | Có (bảng personnel_entries) | Không | Có thể |
| public | XOR: đúng 1 trong unit_id hoặc zone_id có giá trị | (xem cột trước) | ≥ 1 | Không | Không | Không |
| water_pump | Null | Bắt buộc | ≥ 1 | Không | Không | Không |
| non_establishment | Null | Bắt buộc | Không | Không | Bắt buộc ≥ 1 | Không |

Validation XOR cho residential và public: đúng 1 trong unit_id hoặc zone_id phải có giá trị — không cho phép cả 2 cùng null hoặc cả 2 cùng có giá trị.

#### blocks (khối)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng trong cùng đơn vị |
| unit_id | foreign key → units | Bắt buộc |
| discarded_at | datetime | Nullable. Soft delete (discard) |

#### groups (nhóm)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng trong cùng đơn vị |
| unit_id | foreign key → units | Bắt buộc |
| block_id | foreign key → blocks | Nullable. Null = nhóm trực tiếp thuộc đơn vị |
| discarded_at | datetime | Nullable. Soft delete (discard) |

#### meters (công tơ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc, không trùng trong cùng đầu mối |
| contact_point_id | foreign key → contact_points | Bắt buộc |
| no_loss | boolean | Mặc định: false (có tổn hao). Giá trị "hiện tại", dùng làm default khi mở kỳ mới |
| discarded_at | datetime | Nullable. Soft delete (discard) |

Không có cột meter_type — loại công tơ luôn trùng loại đầu mối, lấy qua meter.contact_point.contact_point_type.

> **Quyết định không có meter_type:** Thêm meter_type → thừa dữ liệu, phải validate khớp với contact_point_type, thêm chỗ sai.
> **Tradeoff:** Cần 1 join khi muốn biết loại công tơ. Chấp nhận được vì viết 1 delegate method.

#### main_meters (công tơ tổng)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Bắt buộc |
| zone_id | foreign key → zones | Bắt buộc |
| discarded_at | datetime | Nullable. Soft delete (discard) |

Bảng riêng phòng tương lai nhiều công tơ tổng per khu vực. Hiện tại mỗi khu vực có đúng 1: luồng tạo/sửa khu vực chỉ cho tạo đúng 1 công tơ tổng. Chưa đặt unique constraint trên main_meters.zone_id ở database vì bảng để mở cho tương lai nhiều công tơ tổng.

> **Quyết định bảng riêng thay vì cột trên zones:** Nghiệp vụ v2.6.0 ghi "đúng 1" nhưng tương lai có thể nhiều hơn. Gộp vào zones (1 cột main_meter_name) thì khi cần nhiều phải migration lớn. Bảng riêng linh hoạt hơn.
> **Tradeoff:** Thêm 1 bảng + 1 model cho quan hệ hiện tại 1-1. Chấp nhận được vì chi phí thấp.

#### periods (kỳ tính toán)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| year | integer | Bắt buộc |
| month | integer | Bắt buộc, unique cùng year |
| unit_price | decimal | Bắt buộc, > 0 |
| closed | boolean | Mặc định: true. Chỉ 1 kỳ closed = false tại 1 thời điểm |
| savings_rate | decimal | Tiết kiệm của Bộ. ≥ 0, ≤ 100. Mặc định: 5 |
| division_public_rate | decimal | Công cộng dùng chung Sư đoàn. ≥ 0, ≤ 100. Mặc định: 10 |
| water_pump_standard | decimal | Tiêu chuẩn điện bơm nước kW/người/tháng. > 0. Mặc định: 9,45 |

Ai đóng/mở kỳ, lúc nào: PaperTrail ghi nhật ký, không cần cột riêng.

> **Quyết định cấu hình chung trên periods:** savings_rate, division_public_rate, water_pump_standard luôn gắn 1-1 với kỳ. Tách bảng system_configs riêng → thêm 1 bảng + 1 model + 1 join cho 3 cột, thêm chỗ quên tạo khi mở kỳ mới.
> **Tradeoff:** Bảng periods chứa nhiều cột hơn. Chấp nhận được vì chỉ 3 cột thêm.

> **Quyết định dùng `closed` thay vì `locked` hoặc `open`:** "Đóng/mở" sát ngôn ngữ kế toán, tài chính ("đóng sổ", "mở sổ"). `open` là động từ, không đúng convention cột boolean. `closed` là tính từ (past participle), đúng convention. Mặc định true vì kỳ mới tạo chưa mở.
> **Tradeoff:** Ngược logic so với v1.4.0 (dùng `locked`). Nhưng v2 viết lại hoàn toàn nên không ảnh hưởng.

> **Quyết định PaperTrail cho closed_at/closed_by thay vì cột riêng:** PaperTrail đã ghi ai làm gì lúc nào cho mọi thao tác. Thêm cột riêng → thừa dữ liệu, phải cập nhật, có thể quên cập nhật.
> **Tradeoff:** Query "ai đóng kỳ này" phải tìm trong PaperTrail thay vì đọc 1 cột. Chấp nhận được vì hiếm khi cần.

#### ranks (nhóm cấp bậc — snapshot per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| name | string | Tên đầy đủ nhóm cấp bậc |
| quota | decimal | Định mức kW/người/tháng. > 0 |
| position | integer | Thứ tự hiển thị |
| period_id | foreign key → periods | Bắt buộc |

Mỗi kỳ copy bản sao 7 nhóm cấp bậc. Sửa quota kỳ này không ảnh hưởng kỳ khác.

Thêm nhóm cấp bậc mới khi kỳ đang mở: hệ thống tạo rank mới cho kỳ hiện tại + tự tạo personnel_entries (count = 0) cho tất cả đầu mối sinh hoạt trong kỳ đang mở. Xóa nhóm cấp bậc khi kỳ đang mở: xóa personnel_entries tương ứng trong kỳ hiện tại (sau khi kiểm tra không có đầu mối nào đang có count > 0 cho rank đó).

#### meter_readings (chỉ số công tơ per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| meter_id | foreign key → meters | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng meter_id |
| reading_start | decimal | Số đầu kỳ. ≥ 0 |
| reading_end | decimal | Số cuối kỳ. ≥ 0 |
| manual_usage | decimal | Nullable. Nhập thủ công khi cuối kỳ < đầu kỳ (thay công tơ) |
| manual_usage_note | text | Nullable. Ghi chú kèm manual_usage |
| no_loss | boolean | Snapshot từ meters.no_loss khi mở kỳ |
| lock_version | integer | Mặc định: 0. Optimistic locking |

Sử dụng = manual_usage nếu có, ngược lại = reading_end − reading_start. Tính ở tầng model method, không lưu cột thừa.

#### main_meter_readings (chỉ số công tơ tổng per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| main_meter_id | foreign key → main_meters | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng main_meter_id |
| usage | decimal | Số sử dụng. ≥ 0 |
| lock_version | integer | Mặc định: 0. Optimistic locking |

Công tơ tổng chỉ nhập 1 con số (số sử dụng), không có đầu kỳ/cuối kỳ.

#### personnel_entries (quân số per đầu mối sinh hoạt per nhóm cấp bậc per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| contact_point_id | foreign key → contact_points | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc |
| rank_id | foreign key → ranks | Bắt buộc |
| count | integer | ≥ 0 |
| lock_version | integer | Mặc định: 0. Optimistic locking |

Unique: contact_point_id + period_id + rank_id.

Tổng quân số đầu mối sinh hoạt ≥ 1: validate ở tầng controller/service khi save form tạo hoặc chỉnh sửa đầu mối sinh hoạt (vì personnel_entries.count ≥ 0 cho từng rank, không thể enforce tổng ≥ 1 ở từng entry). Trước khi persist: tính tổng count tất cả entries của đầu mối, nếu < 1 → reject kèm thông báo lỗi.

> **Quyết định bảng dọc thay vì 7 cột cứng (rank1_count..rank7_count):** Nghiệp vụ ghi "tương lai có thể thay đổi" số nhóm cấp bậc. 7 cột cứng → mỗi lần thêm/bớt nhóm phải migration + sửa code mọi nơi dùng rank1..rank7. Bảng dọc → chỉ thêm/bớt dữ liệu, không đụng schema.
> **Tradeoff:** Query tổng quân số cần aggregate thay vì cộng 7 cột. Với data nhỏ (vài trăm đầu mối × 7 nhóm) không ảnh hưởng hiệu năng.

#### non_establishment_snapshots (quân số đầu mối ngoài biên chế per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| contact_point_id | foreign key → contact_points | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng contact_point_id |
| personnel_count | integer | ≥ 1. Snapshot từ contact_points.personnel_count khi mở kỳ |
| lock_version | integer | Mặc định: 0. Optimistic locking |

#### unit_configs (cấu hình per đơn vị per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| unit_id | foreign key → units | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng unit_id |
| unit_public_rate | decimal | Công cộng dùng chung đơn vị. ≥ 0, ≤ 100. Mặc định: 0 |
| lock_version | integer | Mặc định: 0. Optimistic locking |

#### other_deductions (khoản trừ "Khác" per đầu mối per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| contact_point_id | foreign key → contact_points | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng contact_point_id |
| other_type | enum | fixed (số cụ thể) hoặc coefficient (hệ số). Mặc định: fixed |
| other_value | decimal | Giá trị. Mặc định: 0. Cho phép âm |
| lock_version | integer | Mặc định: 0. Optimistic locking |

#### pump_allocations (phân bổ bơm nước — snapshot per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| zone_id | foreign key → zones | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc |
| unit_id | foreign key → units | Nullable |
| contact_point_id | foreign key → contact_points | Nullable |
| fixed_percentage | decimal | Nullable. Có = phần trăm cố định. Null = theo hệ số |
| coefficient | decimal | ≥ 0. Mặc định: 1. Hệ số nhân quân số |
| lock_version | integer | Mặc định: 0. Optimistic locking |

Validation: đúng 1 trong unit_id hoặc contact_point_id có giá trị.

> **Quyết định 2 foreign key nullable thay vì polymorphic (assignable_type + assignable_id):** Polymorphic không có foreign key constraint ở database → dữ liệu có thể trỏ tới bản ghi không tồn tại. 2 foreign key nullable có foreign key constraint, database bảo vệ tham chiếu.
> **Tradeoff:** Phải validation "đúng 1 cột có giá trị" ở model. Viết 1 lần, đơn giản hơn rủi ro dữ liệu bẩn từ polymorphic.

#### calculations (kết quả tính toán per đầu mối sinh hoạt per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| contact_point_id | foreign key → contact_points | Bắt buộc |
| period_id | foreign key → periods | Bắt buộc, unique cùng contact_point_id |
| total_personnel | integer | Tổng quân số |
| residential_standard | decimal | Tiêu chuẩn điện sinh hoạt |
| water_pump_standard | decimal | Tiêu chuẩn điện bơm nước |
| total_standard | decimal | Tổng tiêu chuẩn |
| savings_deduction | decimal | Tiết kiệm của Bộ |
| loss_deduction | decimal | Tổn hao |
| division_public_deduction | decimal | Công cộng dùng chung Sư đoàn |
| unit_public_deduction | decimal | Công cộng dùng chung đơn vị |
| other_deduction | decimal | Khác |
| total_deduction | decimal | Tổng trừ |
| remaining_standard | decimal | Tiêu chuẩn còn lại |
| residential_usage | decimal | Sử dụng điện sinh hoạt |
| water_pump_usage | decimal | Sử dụng điện bơm nước |
| total_usage | decimal | Tổng sử dụng |
| surplus | decimal | Thừa (kW). 0 nếu thiếu |
| deficit | decimal | Thiếu (kW). 0 nếu thừa |
| surplus_amount | decimal | Thành tiền thừa |
| deficit_amount | decimal | Thành tiền thiếu |
| calculated_at | datetime | Thời điểm tính toán |

#### users (tài khoản)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| username | string | Bắt buộc, unique. Đăng nhập bằng username |
| encrypted_password | string | Devise quản lý |
| display_name | string | Bắt buộc. Tên hiển thị |
| role | enum | technician, system_admin, unit_admin, commander |
| unit_id | foreign key → units | Nullable. Bắt buộc nếu role = unit_admin hoặc commander |
| force_password_change | boolean | Mặc định: true. Đổi mật khẩu lần đầu đăng nhập |
| default_account | boolean | Mặc định: false. True cho 2 tài khoản mặc định (không cho xóa) |

Đơn vị quản lý khu vực không phải flag trên user — xác định qua zones.manager_unit_id. User có role = unit_admin, thuộc unit là manager_unit của zone → tự động có thêm quyền khu vực. Logic ở tầng ability.

---

## Engine tính toán

### Cấu trúc

3 service tuần tự, điều phối bởi 1 orchestrator:

```
CalculationOrchestrator
  ├── LossCalculator        (tổn hao — tính trên toàn khu vực)
  ├── PumpAllocationCalculator  (bơm nước — tính trên toàn khu vực)
  └── SummaryCalculator     (tổng hợp — tính per đầu mối sinh hoạt)
```

Thứ tự bắt buộc: tổn hao → bơm nước → tổng hợp. Bơm nước cần kết quả tổn hao. Tổng hợp cần kết quả cả hai.

### Quy ước chung

- Toàn bộ tính toán dùng `decimal` (PostgreSQL numeric, Ruby BigDecimal). Không dùng float.
- Không làm tròn trong quá trình tính toán. Chỉ làm tròn khi hiển thị và xuất Excel.
- "Sử dụng công tơ" = `meter_readings.manual_usage` nếu có, ngược lại `reading_end − reading_start`. Tính ở model method.
- `no_loss` lấy từ `meter_readings.no_loss` (snapshot per kỳ), không phải `meters.no_loss`.
- Quân số đầu mối sinh hoạt lấy từ `personnel_entries` (per kỳ).
- Quân số đầu mối ngoài biên chế lấy từ `non_establishment_snapshots` (per kỳ).
- Định mức cấp bậc lấy từ `ranks` (per kỳ).
- "Tất cả công tơ trong zone" = công tơ của đầu mối có zone_id = zone (thuộc khu vực trực tiếp) + công tơ của đầu mối có unit_id thuộc đơn vị trong zone (thuộc đơn vị). Vì contact_points.zone_id nullable, phải query cả 2 đường. Nên viết 1 scope `Meter.in_zone(zone)` hoặc `ContactPoint.in_zone(zone)` dùng lại trong cả 3 calculator.
- Engine dùng `.with_discarded` khi query zones, units, contact_points, meters, main_meters — để tính toán lại kỳ cũ vẫn thấy thực thể đã xóa (soft delete). Dữ liệu per kỳ (meter_readings, personnel_entries, calculations...) dùng period_id nên luôn tìm đúng, không cần `.with_discarded`.
- **Ngoại lệ — kỳ đang mở:** thực thể đã xóa ở kỳ đang mở bị loại khỏi tính toán. Engine lọc công tơ theo `meter_reading` của kỳ nên thực thể đã cleanup dữ liệu tự động bị skip; `PumpAllocationCalculator` loại thêm `pump_allocations` có đơn vị/đầu mối đã xóa (kỳ đã đóng vẫn tính bình thường).

### Bước 1: Tổn hao (LossCalculator)

Input: zone, period.

```
A = tổng usage các main_meter_readings trong zone
    − tổng sử dụng các công tơ có no_loss = true trong zone

B = tổng sử dụng các công tơ có no_loss = false trong zone
    (sinh hoạt + công cộng + bơm nước)

C = A − B (tổng tổn hao khu vực)

Tổn hao công tơ X = sử dụng công tơ X × C ÷ B
Tổn hao đầu mối = tổng tổn hao các công tơ trong đầu mối đó
```

"Sử dụng" ở đây là sử dụng thô (từ meter_readings), chưa cộng tổn hao.

Edge cases:

- C < 0 → clamp C về 0, trả cảnh báo "tổng công tơ con lớn hơn công tơ tổng"
- B = 0 (tất cả công tơ đều không tổn hao) → clamp về 0, trả cảnh báo "không có công tơ có tổn hao"
- Khu vực chưa có đầu mối (B = 0 vì chưa có công tơ) → không tính, trả cảnh báo "khu vực chưa có đầu mối"

Output: hash chứa tổn hao per công tơ, tổn hao per đầu mối, tổng tổn hao khu vực, warnings.

### Bước 2: Bơm nước (PumpAllocationCalculator)

Input: zone, period, loss_results (từ bước 1).

```
D = tổng điện bơm nước toàn khu vực
  = tổng (sử dụng thô công tơ bơm nước + tổn hao công tơ bơm nước)
```

Tổn hao công tơ bơm nước lấy từ loss_results.

Phân bổ cho các đối tượng trong `pump_allocations` (snapshot per kỳ):

```
Bước 1 — phần trăm cố định:
  Đối tượng có fixed_percentage → nhận D × fixed_percentage ÷ 100

Bước 2 — phần còn lại theo hệ số nhân quân số:
  Phần còn lại = D − tổng phần cố định
  Mỗi đối tượng: trọng số = quân số × coefficient
  Đối tượng nhận = phần còn lại × trọng số ÷ tổng trọng số
```

Quân số đối tượng:

- Đơn vị (unit_id): tổng quân số tất cả đầu mối sinh hoạt thuộc đơn vị (từ personnel_entries)
- Đầu mối sinh hoạt thuộc khu vực (contact_point_id, type = residential): quân số từ personnel_entries
- Đầu mối ngoài biên chế (contact_point_id, type = non_establishment): quân số từ non_establishment_snapshots

Từ đơn vị xuống đầu mối:

```
Đơn vị nhận X kW → mỗi đầu mối sinh hoạt trong đơn vị nhận:
  X ÷ tổng quân số đơn vị × quân số đầu mối
```

Edge cases:

- Tổng fixed_percentage > 100% → không cho phép (validation trên pump_allocations)
- Tổng fixed_percentage = 100% → toàn bộ phân bổ theo phần trăm, bỏ qua hệ số
- Tổng fixed_percentage < 100% nhưng không có đối tượng nhận hệ số → không cho phép (validation)
- Tất cả đối tượng nhận hệ số có coefficient × quân số = 0 → không cho phép (validation)
- Không có trạm bơm trong khu vực → bơm nước = 0, bỏ qua phân bổ

Output: hash chứa phân bổ bơm nước per đầu mối, tổng D, warnings.

### Bước 3: Tổng hợp (SummaryCalculator)

Input: zone, period, loss_results (từ bước 1), pump_results (từ bước 2).

Tính per đầu mối sinh hoạt:

```
Tiêu chuẩn điện sinh hoạt = tổng (count × quota) từ personnel_entries × ranks
Tiêu chuẩn điện bơm nước = tổng quân số × periods.water_pump_standard
Tổng tiêu chuẩn = tiêu chuẩn điện sinh hoạt + tiêu chuẩn điện bơm nước

5 khoản trừ (cộng lại rồi trừ 1 lần, không trừ tuần tự):
  Tiết kiệm của Bộ = periods.savings_rate × tổng tiêu chuẩn ÷ 100
  Tổn hao = loss_results[đầu mối]
  Công cộng dùng chung Sư đoàn = periods.division_public_rate × tổng tiêu chuẩn ÷ 100
  Công cộng dùng chung đơn vị = unit_configs.unit_public_rate × tổng tiêu chuẩn ÷ 100
  Khác:
    Nếu other_type = fixed → other_value
    Nếu other_type = coefficient → other_value × tổng quân số
Tổng trừ = cộng 5 khoản

Tiêu chuẩn còn lại = tổng tiêu chuẩn − tổng trừ (có thể ra âm — nghiệp vụ cho phép)

Sử dụng điện sinh hoạt = tổng sử dụng thô các công tơ trong đầu mối (không cộng tổn hao)
Sử dụng điện bơm nước = pump_results[đầu mối]
Tổng sử dụng = sử dụng điện sinh hoạt + sử dụng điện bơm nước

Thâm điện = tổng sử dụng − tiêu chuẩn còn lại
  Nếu > 0: deficit = thâm điện, surplus = 0
  Nếu ≤ 0: surplus = |thâm điện|, deficit = 0

Thành tiền = thâm điện × periods.unit_price (cùng đơn giá cho thừa và thiếu)
```

Đầu mối sinh hoạt thuộc khu vực (unit_id null): không có unit_configs (vì unit_configs cần unit_id) → cột "Công cộng dùng chung đơn vị" = 0. Engine xử lý: nếu đầu mối không có unit_id thì unit_public_deduction = 0, không query unit_configs.

Output: lưu vào bảng `calculations`. Ghi `calculated_at`.

### CalculationOrchestrator

Input: zone, period.

Flow:
1. LossCalculator.new(zone:, period:).call → loss_results
2. PumpAllocationCalculator.new(zone:, period:, loss_results:).call → pump_results
3. SummaryCalculator.new(zone:, period:, loss_results:, pump_results:).call → persist calculations

Collect warnings từ cả 3 bước, trả về cho UI hiển thị.

Tính toán lần đầu khi mở bảng tính tiền hoặc trang tổng quan, cache trong bảng calculations. Bấm "Tính toán lại" → gọi orchestrator lại, ghi đè calculations.

Orchestrator luôn tính toàn zone (vì tổn hao và bơm nước tính trên toàn zone). Nếu 1 đơn vị trong zone chưa nhập liệu → engine vẫn chạy với data hiện có, nhưng trả cảnh báo "đơn vị X chưa nhập liệu" hiển thị trên bảng tính tiền và trang tổng quan. Kết quả tổn hao và bơm nước sẽ không chính xác cho đến khi tất cả đơn vị nhập xong — cảnh báo giúp system_admin biết vấn đề ở đâu.

Toàn bộ thao tác tính toán (3 bước + persist calculations) thực hiện trong 1 ActiveRecord transaction. Nếu bất kỳ bước nào lỗi → rollback, giữ calculations cũ (hoặc trống nếu chưa tính lần nào).

Kỳ đã đóng: nút "Tính toán lại" vẫn hiển thị và hoạt động (idempotent computation, không phải data entry). Recalculate dùng snapshot data của kỳ đó, không dùng data hiện tại.

---

## Phân quyền

Dùng gem CanCanCan. 4 vai trò: 3 vai trò nghiệp vụ (system_admin, unit_admin, commander) + 1 vai trò kỹ thuật (technician). Đơn vị quản lý khu vực không phải vai trò riêng — là unit_admin được ủy quyền thêm qua zones.manager_unit_id.

### system_admin (quản trị viên hệ thống)

Quản lý tất cả. Mọi thứ unit_admin làm được, system_admin đều làm được, trên tất cả các đơn vị và khu vực.

| Phạm vi | Quyền |
|---|---|
| zones | CRUD |
| units | CRUD |
| contact_points (mọi loại, mọi đơn vị, mọi khu vực) | CRUD |
| meters | CRUD |
| main_meters | CRUD |
| blocks, groups | CRUD |
| periods (mở/đóng kỳ, đơn giá, savings_rate, division_public_rate, water_pump_standard) | CRUD |
| ranks (nhóm cấp bậc) | CRUD |
| pump_allocations (phân bổ bơm nước) | CRUD |
| meter_readings (mọi đơn vị) | CRUD |
| main_meter_readings | CRUD |
| personnel_entries (mọi đơn vị) | CRUD |
| non_establishment_snapshots | CRUD |
| unit_configs (mọi đơn vị) | CRUD |
| other_deductions (mọi đơn vị) | CRUD |
| calculations | Đọc + tính toán lại |
| Bảng tính tiền | Xem tất cả đơn vị + bảng gộp |
| Tổng quan | Xem tổng quan hệ thống |
| Tra cứu lịch sử | Xem tất cả |
| Tài khoản | Quản lý system_admin, unit_admin, commander (không quản lý technician) |
| Nhật ký | Xem |
| Sao lưu | Không |

### unit_admin (quản trị viên đơn vị)

Quản lý đơn vị mình. "Đơn vị mình" = unit mà user.unit_id trỏ tới.

| Phạm vi | Quyền |
|---|---|
| contact_points (sinh hoạt, công cộng thuộc đơn vị mình) | CRUD |
| meters (thuộc đơn vị mình) | CRUD |
| blocks, groups (thuộc đơn vị mình) | CRUD |
| meter_readings (công tơ thuộc đơn vị mình) | Đọc + Cập nhật (trang nhập chỉ số chỉ cập nhật giá trị; bản ghi tạo/xóa tự động qua vòng đời công tơ và kỳ) |
| personnel_entries (đầu mối thuộc đơn vị mình) | Đọc + Cập nhật (cập nhật quân số qua form đầu mối; bản ghi tạo/xóa tự động qua vòng đời đầu mối và kỳ) |
| unit_configs (đơn vị mình) | Đọc + Cập nhật (trang cấu hình đơn vị chỉ cập nhật tỷ lệ; bản ghi tạo tự động khi mở kỳ, luôn đúng 1 bản ghi/đơn vị/kỳ) |
| other_deductions (đầu mối thuộc đơn vị mình) | Đọc + Cập nhật (trang cấu hình đơn vị chỉ cập nhật kiểu và giá trị; bản ghi tạo/xóa tự động qua vòng đời đầu mối và kỳ) |
| calculations (đơn vị mình) | Đọc + tính toán lại |
| Bảng tính tiền | Xem đơn vị mình |
| Tổng quan | Xem tổng quan đơn vị mình |
| Tra cứu lịch sử | Xem đơn vị mình |

**Ủy quyền khu vực (nếu đơn vị mình là zones.manager_unit_id):**

| Phạm vi | Quyền |
|---|---|
| contact_points (mọi loại, thuộc khu vực mình quản lý) | CRUD |
| meters (thuộc đầu mối khu vực mình quản lý) | CRUD |
| main_meter_readings (khu vực mình quản lý) | CRUD |
| meter_readings (công tơ đầu mối thuộc khu vực, bao gồm bơm nước) | Đọc + Cập nhật (trang nhập chỉ số và chỉ số bơm nước chỉ cập nhật giá trị; bản ghi tạo/xóa tự động qua vòng đời công tơ và kỳ) |
| personnel_entries (đầu mối sinh hoạt thuộc khu vực) | Đọc + Cập nhật (cập nhật quân số qua form đầu mối; bản ghi tạo/xóa tự động qua vòng đời đầu mối và kỳ) |
| non_establishment_snapshots (khu vực mình quản lý) | Đọc + Cập nhật (cập nhật quân số qua form đầu mối ngoài biên chế; bản ghi tạo/xóa tự động qua vòng đời đầu mối và kỳ) |
| other_deductions (đầu mối sinh hoạt thuộc khu vực) | Đọc + Cập nhật (trang cấu hình đơn vị chỉ cập nhật kiểu và giá trị; bản ghi tạo/xóa tự động qua vòng đời đầu mối và kỳ) |
| pump_allocations (khu vực mình quản lý) | CRUD |
| calculations (khu vực mình quản lý) | Đọc + tính toán lại |
| Bảng tính tiền | Xem đơn vị mình + đầu mối sinh hoạt thuộc khu vực |
| main_meters (khu vực mình quản lý) | Chỉ đọc (do quản trị viên hệ thống thiết lập khi tạo khu vực) |

### commander (chỉ huy đơn vị)

Chỉ xem, không thao tác. Xem mọi thứ unit_admin thấy trong đơn vị mình.

| Phạm vi | Quyền |
|---|---|
| Mọi thứ unit_admin thấy | Chỉ đọc |
| Nếu đơn vị quản lý khu vực | Xem tất cả những gì unit_admin zone-manager quản lý: đầu mối khu vực, phân bổ bơm nước, bảng tính tiền bao gồm đầu mối sinh hoạt thuộc khu vực |

### technician (kỹ thuật viên)

Chỉ làm việc kỹ thuật, không xem dữ liệu nghiệp vụ.

| Phạm vi | Quyền |
|---|---|
| Tài khoản (mọi vai trò) | CRUD |
| units | Chỉ đọc (form tạo tài khoản cần dropdown đơn vị để gán cho quản trị viên đơn vị và chỉ huy đơn vị; không có trang riêng hiển thị danh sách đơn vị cho kỹ thuật viên) |
| Nhật ký | Xem |
| Sao lưu và phục hồi | CRUD (tối đa 3 bản) |
| Dữ liệu nghiệp vụ | Không truy cập (ngoại trừ units chỉ đọc nêu trên) |

### Cross-zone scoping

Tất cả controller phải dùng `accessible_by(current_ability)` — không dùng `Model.find(params[:id])` trực tiếp. Đảm bảo unit_admin không thấy dữ liệu đơn vị khác, commander không thấy đơn vị khác.

---

## Kỳ tính toán

### Mở kỳ mới

Điều kiện: không có kỳ nào đang mở (closed = false). System_admin thao tác.

Hệ thống tự tính year/month cho kỳ mới = kỳ trước + 1 tháng. Ví dụ: kỳ trước là tháng 5/2026 → kỳ mới là tháng 6/2026. Tháng 12 → tháng 1 năm sau. System_admin không nhập year/month — chỉ bấm "Mở kỳ mới", hệ thống tự xác định. Kỳ đầu tiên (chưa có kỳ nào): system_admin chọn year/month.

Toàn bộ thao tác mở kỳ mới (tạo period + copy tất cả snapshot) thực hiện trong 1 ActiveRecord transaction. Nếu bất kỳ bước nào lỗi → rollback toàn bộ, không tạo kỳ mới.

Hệ thống tạo period mới (closed = false) và copy snapshot từ kỳ trước:

Snapshot chỉ copy cho thực thể chưa bị xóa (`.kept`). Đầu mối, công tơ, đơn vị, khu vực đã discard không được copy sang kỳ mới.

| Dữ liệu | Nguồn | Đích |
|---|---|---|
| Số đầu kỳ công tơ | meter_readings.reading_end kỳ trước | meter_readings.reading_start kỳ mới |
| no_loss công tơ | meters.no_loss (giá trị hiện tại) | meter_readings.no_loss kỳ mới |
| Quân số theo cấp bậc | personnel_entries kỳ trước | personnel_entries kỳ mới |
| Quân số ngoài biên chế | non_establishment_snapshots kỳ trước | non_establishment_snapshots kỳ mới |
| Cấu hình đơn vị | unit_configs kỳ trước | unit_configs kỳ mới |
| Cột Khác (dạng + giá trị) | other_deductions kỳ trước | other_deductions kỳ mới |
| Phân bổ bơm nước | pump_allocations kỳ trước | pump_allocations kỳ mới |
| Nhóm cấp bậc (tên + quota + position) | ranks kỳ trước | ranks kỳ mới |
| Đơn giá | periods.unit_price kỳ trước | periods.unit_price kỳ mới |
| Tiết kiệm của Bộ | periods.savings_rate kỳ trước | periods.savings_rate kỳ mới |
| Công cộng Sư đoàn | periods.division_public_rate kỳ trước | periods.division_public_rate kỳ mới |
| Tiêu chuẩn bơm nước | periods.water_pump_standard kỳ trước | periods.water_pump_standard kỳ mới |

Dạng hệ số cột Khác: kế thừa hệ số (other_type = coefficient, other_value = hệ số). Hệ thống tự tính lại khoản trừ theo quân số mới khi tính toán.

**Không kế thừa** (nhập mới hoặc tính mới):

- main_meter_readings: nhập mới (chỉ 1 số sử dụng)
- meter_readings.reading_end: nhập mới
- calculations: tính mới bằng engine

**Kỳ đầu tiên** (chưa có kỳ trước):

| Dữ liệu | Giá trị mặc định |
|---|---|
| 7 nhóm cấp bậc | Tên + định mức theo nghị định: 570, 440, 305, 130, 210, 110, 24 kW/người/tháng |
| Tiêu chuẩn bơm nước | 9,45 kW/người/tháng |
| Tiết kiệm của Bộ | 5% |
| Công cộng Sư đoàn | 10% |
| Công cộng đơn vị | 0% |
| Cột Khác | 0 (dạng số cụ thể) |
| Đơn giá | Bắt buộc nhập trước khi mở (không có mặc định) |
| Chỉ số công tơ | Nhập thủ công cả đầu kỳ lẫn cuối kỳ |
| Hệ số bơm nước | 1 (mặc định) |

**Đơn vị mới** (tạo ở kỳ giữa chừng, không có kỳ trước):

| Dữ liệu | Giá trị mặc định |
|---|---|
| Công cộng đơn vị | 0% |
| Cột Khác | 0 (dạng số cụ thể) |

### Đóng kỳ

System_admin đóng kỳ đang mở → closed = true. Kỳ đã đóng: không ai sửa được số liệu.

Cách implement: tạo concern `PeriodGuard` (hoặc tương tự). Áp dụng cho tất cả controller dữ liệu nghiệp vụ: zones, units, contact_points, meters, blocks, groups, meter_entries, pump_entries, electricity_supply, unit_config, ranks, pump_allocations. before_action check: nếu không có kỳ đang mở (Period.where(closed: false).none?) → chặn mọi thao tác tạo/sửa/xóa, hiển thị thông báo "Không có kỳ đang mở. Vui lòng liên hệ quản trị viên hệ thống." Thao tác đọc (xem) vẫn được phép. Nguyên tắc: mọi thay đổi dữ liệu nghiệp vụ đều cần kỳ đang mở. Chỉ quản trị hệ thống (tài khoản, sao lưu, nhật ký) hoạt động độc lập kỳ.

### Mở lại kỳ cũ

System_admin thao tác. Mục đích: sửa sai sót nhập liệu.

- Nếu có kỳ đang mở → hiển thị cảnh báo, phải đóng kỳ đó trước.
- Nếu không có kỳ nào đang mở → mở trực tiếp (closed = false).

Khi đóng kỳ cũ sau khi sửa:

- Hệ thống kiểm tra: số cuối kỳ (meter_readings.reading_end) của kỳ đó có khớp số đầu kỳ (meter_readings.reading_start) của kỳ kế tiếp không.
- Nếu không khớp → hiển thị cảnh báo (chỉ cảnh báo, không tự sửa kỳ kế tiếp — đúng nguyên tắc kỳ này không ảnh hưởng kỳ khác).

### Nguyên tắc cách ly kỳ

- Mọi thao tác trong 1 kỳ tuyệt đối không ảnh hưởng kỳ khác.
- Mỗi kỳ có bản sao cấu hình riêng (đã đảm bảo bằng period_id trên mọi bảng data).
- Chỉ mở được 1 kỳ tại 1 thời điểm.
- Dữ liệu chỉ ảnh hưởng hiển thị (name, block_id, group_id trên contact_points) không có period_id — chấp nhận được vì không ảnh hưởng tính toán và calculations đã cache kết quả.
- Thêm đầu mối mới khi kỳ đóng: đầu mối không có data cho kỳ đóng (không có meter_readings, personnel_entries), không ảnh hưởng calculations kỳ cũ. Đầu mối mới chỉ xuất hiện từ kỳ tiếp theo.
- Thêm đầu mối mới khi kỳ đang mở: hệ thống tự tạo data cho kỳ hiện tại — meter_readings (reading_start = 0, reading_end = null, no_loss từ meters.no_loss), personnel_entries (count = quân số nhập trong form tạo đầu mối, cho mỗi rank trong kỳ hiện tại), other_deductions (mặc định: fixed, 0). Nếu loại ngoài biên chế: tạo non_establishment_snapshots. Nếu loại bơm nước: tạo meter_readings cho công tơ bơm nước. Tương tự khi thêm công tơ mới cho đầu mối đang có.
- Xóa (discard) đầu mối khi kỳ đóng: calculations kỳ cũ vẫn trỏ tới discarded contact_point, hiển thị kỳ cũ vẫn thấy dữ liệu đầu mối đó. Kỳ mới sẽ không copy data cho đầu mối đã xóa.

### Hạn chế thay đổi cấu trúc khi mở kỳ cũ

Khi kỳ đang mở **không phải kỳ mới nhất** (đang mở lại kỳ cũ để sửa sai sót nhập liệu): chặn mọi thay đổi cấu trúc, chỉ cho sửa nhập liệu.

**Cho phép sửa (nhập liệu per kỳ):** meter_readings, main_meter_readings, personnel_entries, non_establishment_snapshots, unit_configs, other_deductions, pump_allocations.

**Chặn (thay đổi cấu trúc):** tạo/xóa/sửa zones, units, contact_points, meters, main_meters, blocks, groups, ranks. Hiển thị thông báo "Đang mở kỳ cũ. Chỉ cho phép sửa số liệu, không cho phép thay đổi cấu trúc (tạo, xóa, sửa khu vực, đơn vị, đầu mối, công tơ, khối, nhóm, nhóm cấp bậc). Đóng kỳ này và mở kỳ mới nhất nếu cần thay đổi cấu trúc."

> **Lý do (v2.3.0):** Thay đổi cấu trúc (tạo/xóa zone, đơn vị, đầu mối...) ảnh hưởng mọi kỳ vì các thực thể cấu trúc không có snapshot per kỳ. Nếu cho phép thay đổi cấu trúc khi mở kỳ cũ → vi phạm nguyên tắc "mọi thao tác ở kỳ đang mở không ảnh hưởng kỳ đã đóng" (kỳ mới hơn đã đóng sẽ bị ảnh hưởng). Nghiệp vụ quy định mở kỳ cũ chỉ để sửa sai sót nhập liệu — không cần thay đổi cấu trúc.

Cách implement: mở rộng PeriodGuard (hoặc tạo concern riêng `StructureChangeGuard`). Kiểm tra: nếu có kỳ đang mở và kỳ đó không phải kỳ mới nhất (`Period.where(closed: false).first != Period.order(year: :desc, month: :desc).first`) → chặn tạo/sửa/xóa trên controller cấu trúc.

---

## Sidebar và routes

### Quy tắc

- Sidebar item = heading trang = breadcrumb = flash message. Không "Quản lý", không "Danh sách".
- Nhóm sắp xếp theo tần suất sử dụng: xem kết quả (hàng ngày) → nhập liệu (hàng tháng) → khai báo (khi cần) → thiết lập (1 lần) → hệ thống (khi cần).
- Trong mỗi nhóm, sắp xếp theo dependency: mục trên cần làm trước mục dưới.
- Mỗi trang CRUD có cùng pattern: danh sách + tạo mới + sửa + xóa.

### 5 nhóm

**XEM KẾT QUẢ:**

| Tên sidebar | Route | Controller | Chức năng |
|---|---|---|---|
| Tổng quan | /dashboard | dashboard#show | Dashboard tổng hợp |
| Bảng tính tiền | /billing | billing#show | Bảng tính tiền per đơn vị/khu vực + xuất Excel |
| Tra cứu lịch sử | /history | history#show | Tra cứu + so sánh 2 kỳ |

**NHẬP LIỆU HÀNG THÁNG:**

Tất cả trang nhập liệu dùng chung UI pattern: form kiểu bảng — tất cả đầu mối trên 1 trang, mỗi hàng = 1 đầu mối, cột = ô nhập. Save toàn bộ trang 1 lần (không save từng hàng). Hiển thị flash thành công/lỗi sau khi save.

| Tên sidebar | Route | Controller | Chức năng |
|---|---|---|---|
| Nhập số điện lực | /electricity_supply | electricity_supply#show | Nhập số sử dụng công tơ tổng (main_meter_readings) |
| Chỉ số đầu mối | /meter_entries | meter_entries#show | Nhập chỉ số công tơ đầu mối sinh hoạt + công cộng. Unit_admin zone-manager thấy thêm đầu mối sinh hoạt + công cộng thuộc khu vực |
| Chỉ số bơm nước | /pump_entries | pump_entries#show | Nhập chỉ số công tơ bơm nước |

Quân số không có trang nhập liệu riêng. Cập nhật quân số theo nhóm cấp bậc thực hiện trực tiếp trên form tạo hoặc chỉnh sửa đầu mối sinh hoạt (trang Đầu mối trong nhóm Khai báo).

**KHAI BÁO:**

| Tên sidebar | Route | Controller | Chức năng |
|---|---|---|---|
| Đầu mối | /contact_points | contact_points | CRUD 4 loại đầu mối + công tơ. Danh sách có filter theo loại (residential/public/water_pump/non_establishment). Mặc định hiển thị tất cả. Form tạo mới chọn loại trước → hiển thị fields phù hợp theo loại. Form tạo/chỉnh sửa đầu mối sinh hoạt bao gồm phần nhập quân số theo 7 nhóm cấp bậc (inline trong form, không phải trang riêng) |
| Khối | /blocks | blocks | CRUD khối |
| Nhóm | /groups | groups | CRUD nhóm |
| Cấu hình đơn vị | /unit_config | unit_config#show | Công cộng đơn vị, cột Khác per đầu mối |

**THIẾT LẬP:**

| Tên sidebar | Route | Controller | Chức năng |
|---|---|---|---|
| Khu vực | /zones | zones | CRUD khu vực + công tơ tổng (nested) |
| Đơn vị | /units | units | CRUD đơn vị |
| Phân bổ bơm nước | /pump_allocations | pump_allocations | Cấu hình phân bổ per khu vực |
| Đơn giá điện | /pricing | pricing#show | Đơn giá per kỳ + mở/đóng kỳ |
| Nhóm cấp bậc | /ranks | ranks | CRUD 7 nhóm + định mức |

**HỆ THỐNG:**

| Tên sidebar | Route | Controller | Chức năng |
|---|---|---|---|
| Tài khoản | /users | users | CRUD tài khoản |
| Nhật ký hoạt động | /audit_logs | audit_logs#index | Xem log (PaperTrail). Lọc theo: loại thao tác (tạo/sửa/xóa), đối tượng (model), người thao tác, khoảng thời gian |
| Sao lưu dữ liệu | /backups | backups | Backup + restore (tối đa 3 bản) |

### Sidebar per role

Sidebar chỉ hiển thị các mục mà vai trò được phép thấy (theo bảng dưới); mục ngoài quyền của vai trò bị ẩn hẳn. Trong các mục đã hiển thị, không ẩn tiếp theo trạng thái kỳ: khi không có kỳ đang mở, các trang nhập liệu vẫn truy cập được nhưng hiển thị thông báo "Không có kỳ đang mở" và disable mọi ô nhập (PeriodGuard). Các trang xem kết quả và khai báo hoạt động bình thường.

| Mục | system_admin | unit_admin | commander | technician |
|---|---|---|---|---|
| **XEM KẾT QUẢ** | | | | |
| Tổng quan | ✓ | ✓ | ✓ | ✗ |
| Bảng tính tiền | ✓ | ✓ | ✓ | ✗ |
| Tra cứu lịch sử | ✓ | ✓ | ✓ | ✗ |
| **NHẬP LIỆU** | | | | |
| Nhập số điện lực | ✓ | ✓ (zone-manager) | ✗ | ✗ |
| Chỉ số đầu mối | ✓ | ✓ | ✗ | ✗ |
| Chỉ số bơm nước | ✓ | ✓ (zone-manager) | ✗ | ✗ |
| **KHAI BÁO** | | | | |
| Đầu mối | ✓ | ✓ | ✓ (xem) | ✗ |
| Khối | ✓ | ✓ | ✓ (xem) | ✗ |
| Nhóm | ✓ | ✓ | ✓ (xem) | ✗ |
| Cấu hình đơn vị | ✓ | ✓ | ✗ | ✗ |
| **THIẾT LẬP** | | | | |
| Khu vực | ✓ | ✓ (zone-manager, xem) | ✓ (zone-manager, xem) | ✗ |
| Đơn vị | ✓ | ✗ | ✗ | ✗ |
| Phân bổ bơm nước | ✓ | ✓ (zone-manager) | ✓ (zone-manager, xem) | ✗ |
| Đơn giá điện | ✓ | ✗ | ✗ | ✗ |
| Nhóm cấp bậc | ✓ | ✗ | ✗ | ✗ |
| **HỆ THỐNG** | | | | |
| Tài khoản | ✓ | ✗ | ✗ | ✓ |
| Nhật ký hoạt động | ✓ | ✗ | ✗ | ✓ |
| Sao lưu dữ liệu | ✗ | ✗ | ✗ | ✓ |

---

## Trang tổng quan

Trang đầu tiên khi đăng nhập. Cùng route /dashboard, nội dung thay đổi theo role.

### Tổng quan hệ thống (system_admin)

- Tổng thâm điện, thành tiền theo từng đơn vị, sắp xếp thâm điện từ nhiều đến ít.
- Tổng sử dụng điện công cộng, điện bơm nước toàn khu vực.
- Trạng thái nhập liệu từng đơn vị: "chưa nhập" hoặc "đã nhập" (dựa vào có dữ liệu công tơ kỳ hiện tại hay chưa).
- Cảnh báo dữ liệu thiếu, cảnh báo tổn hao bất thường.

### Tổng quan đơn vị (unit_admin, commander)

- Tổng thâm điện đơn vị (kW), tổng thành tiền phải thu.
- Số đầu mối thiếu, số đầu mối thừa.
- Trạng thái nhập liệu kỳ hiện tại: đã nhập chỉ số công tơ hay chưa.
- Cảnh báo nếu có.

---

## Tra cứu lịch sử

Route /history. Nội dung theo role: system_admin xem tất cả, unit_admin + commander xem đơn vị mình.

### Xem kỳ cũ

Bảng tính tiền và tổng quan đều có thể xem lại tháng cũ bất kỳ.

### So sánh 2 kỳ

- Chọn kỳ A và kỳ B, hiển thị cạnh nhau cùng đầu mối với 2 cột số liệu và cột chênh lệch.
- Áp dụng cho cả bảng tính tiền và tổng quan.
- Đầu mối chỉ có ở 1 kỳ (đã xóa hoặc mới tạo): vẫn hiển thị dòng, cột kỳ thiếu để trống, cột chênh lệch để trống, kèm ghi chú "chỉ có ở kỳ A" hoặc "mới ở kỳ B".

### Xem theo khoảng thời gian

Mặc định có thể chọn tháng, quý, năm, hoặc tùy chọn ngày bắt đầu đến ngày kết thúc (dữ liệu hiển thị theo các kỳ tương ứng của 2 ngày đó).

---

## Xuất Excel

- Bảng tính tiền có thể xuất ra Excel.
- File Excel và hiển thị trên hệ thống phải giống hệt nhau.
- File Excel phải có đầy đủ công thức tính toán (không chỉ giá trị tĩnh). Ví dụ: ô tổng tiêu chuẩn phải chứa công thức = tiêu chuẩn điện sinh hoạt + tiêu chuẩn điện bơm nước.
- Dùng gem **caxlsx** + **caxlsx_rails** để tạo xlsx.

Lưu ý: bảng tính tiền cần hiển thị 7 cột quân số per nhóm cấp bậc. Dữ liệu này lấy từ bảng `personnel_entries` (có period_id), không phải từ bảng `calculations` (chỉ lưu total_personnel). Khi xem kỳ cũ, personnel_entries kỳ đó vẫn còn nguyên.

---

## Xóa dữ liệu

Quy tắc xóa theo nghiệp vụ mục 23. Soft delete dùng gem discard (đánh dấu discarded_at, không xóa thật).

| Thao tác | Cho phép | Xử lý |
|---|---|---|
| Xóa công tơ cuối cùng của đầu mối (trừ ngoài biên chế) | Không | Validation: đầu mối luôn phải có ít nhất 1 công tơ |
| Xóa đơn vị đang có đầu mối | Không | Validation: phải xóa (discard) hết đầu mối trước |
| Xóa đơn vị đang có tài khoản | Không | Validation: phải xóa hết tài khoản (users) thuộc đơn vị trước. Nếu không, users.unit_id trỏ tới discarded unit → user không thể đăng nhập đúng |
| Xóa khu vực đang có đơn vị | Không | Validation: phải xóa (discard) hết đơn vị trước |
| Xóa khu vực | Có | Soft delete (discard). Discard các main_meters thuộc khu vực (before_discard callback). Cleanup main_meter_readings kỳ đang mở (xem mục Cleanup data khi discard). Dữ liệu kỳ cũ (main_meter_readings) giữ nguyên. Chỉ cho phép khi kỳ đang mở là kỳ mới nhất hoặc không có kỳ nào đang mở (xem mục Hạn chế thay đổi cấu trúc khi mở kỳ cũ) |
| Xóa đơn vị quản lý khu vực | Có (cảnh báo) | Phải qua validation "đơn vị đang có đầu mối" và "đơn vị đang có tài khoản" trước. Sau khi pass validation, hiển thị cảnh báo. Nếu xóa, zones.manager_unit_id → null. System_admin tự quản lý phần khu vực cho đến khi chỉ định đơn vị khác |
| Xóa khối đang có nhóm/đầu mối | Có | Nhóm/đầu mối bên trong: group.block_id → null, contact_point.block_id → null. Chuyển thành trực tiếp thuộc đơn vị |
| Xóa nhóm đang có đầu mối | Có | Đầu mối: contact_point.group_id → null. Nếu nhóm thuộc khối → đầu mối lên khối (contact_point.block_id giữ nguyên). Nếu nhóm thuộc đơn vị trực tiếp → đầu mối lên đơn vị |
| Xóa đầu mối, công tơ có dữ liệu kỳ cũ | Có | Soft delete (discard). Dữ liệu kỳ cũ (meter_readings, personnel_entries, calculations...) giữ nguyên. Cleanup data kỳ đang mở (xem mục Cleanup data khi discard). Nếu đầu mối đang có pump_allocation trong kỳ đang mở → discard pump_allocation đó luôn (xóa thật, không soft delete vì pump_allocations không có discarded_at). Kỳ cũ đã đóng: pump_allocations kỳ cũ giữ nguyên, calculations đã cache |
| Xóa nhóm cấp bậc đang có đầu mối sử dụng | Không | Validation: phải chuyển hết quân số sang nhóm cấp bậc khác trước |
| Xóa tài khoản | Có | Trừ 2 tài khoản mặc định (technician + system_admin ban đầu). Không cho tự xóa chính mình. Tài khoản đang đăng nhập bị xóa → buộc thoát ngay |

### Cleanup data khi discard (v2.4.0)

Khi discard thực thể cấu trúc, nếu có kỳ đang mở → hard delete data per kỳ đang mở của thực thể đó. Kỳ cũ giữ nguyên. Nếu không có kỳ đang mở → không xóa gì.

> **Lý do:** Engine dùng `.with_discarded` để thấy thực thể đã xóa khi tính toán lại kỳ cũ. Nhưng nếu data per kỳ đang mở vẫn còn, engine sẽ cảnh báo/tính toán sai cho thực thể đã xóa. Xóa data per kỳ đang mở → engine kiểm tra có meter_readings kỳ đó không → không có → skip.

> **StructureChangeGuard đảm bảo:** discard thực thể cấu trúc chỉ xảy ra khi kỳ đang mở là kỳ mới nhất hoặc không có kỳ nào mở. Không bao giờ xảy ra khi đang mở kỳ cũ.

| Thực thể | before_discard cleanup (kỳ đang mở) |
|---|---|
| ContactPoint | Hard delete: meter_readings (của tất cả meters thuộc contact_point), personnel_entries, calculations, non_establishment_snapshots, other_deductions — WHERE period_id = kỳ đang mở |
| Meter | Hard delete: meter_readings — WHERE period_id = kỳ đang mở |
| Zone | Hard delete: main_meter_readings (của tất cả main_meters thuộc zone) — WHERE period_id = kỳ đang mở |
| MainMeter | Hard delete: main_meter_readings — WHERE period_id = kỳ đang mở |

### Engine skip thực thể không có data kỳ đang tính (v2.4.0)

Engine (LossCalculator, PumpAllocationCalculator, SummaryCalculator) khi iterate qua đầu mối/công tơ phải kiểm tra: đầu mối có meter_readings cho kỳ đang tính không?

- Có meter_readings → tính (dù đầu mối đã discard — đúng cho kỳ cũ)
- Không có meter_readings → skip hoàn toàn, không cảnh báo

Cách phân biệt "tồn tại trong kỳ nhưng chưa nhập" vs "không tồn tại trong kỳ":
- Có meter_readings bản ghi (reading_end = 0 hoặc chưa nhập) → tồn tại, chưa nhập → cảnh báo "chưa nhập chỉ số"
- Không có meter_readings bản ghi → không tồn tại trong kỳ → skip, không cảnh báo

### Sửa dữ liệu

| Thao tác | Cho phép | Ghi chú |
|---|---|---|
| Sửa tên (khu vực, đơn vị, đầu mối, công tơ, công tơ tổng, khối, nhóm) | Có | Tên chỉ là nhãn hiển thị |
| Sửa loại đầu mối (sinh hoạt → công cộng) | Không | Xóa tạo lại. Mỗi loại có cấu trúc khác nhau |
| Sửa no_loss của công tơ | Có | Thay đổi meters.no_loss (giá trị hiện tại). Kỳ đang mở dùng meter_readings.no_loss (snapshot) — phải cập nhật cả snapshot nếu kỳ đang mở |
| Đổi đơn vị quản lý khu vực | Có | Cập nhật zones.manager_unit_id. Đơn vị mới phải thuộc cùng khu vực |
| Di chuyển đầu mối giữa khối/nhóm | Có | Chỉ thay đổi hiển thị, không ảnh hưởng tính toán |
| Chuyển đơn vị sang khu vực khác | Không | — |

---

## Luồng thiết lập ban đầu

9 bước tuần tự (nghiệp vụ mục 13):

1. **Kỹ thuật viên: Cài đặt hệ thống.** Hệ thống có sẵn 2 tài khoản mặc định (technician, system_admin). Có sẵn 7 nhóm cấp bậc với giá trị mặc định.

2. **Quản trị viên hệ thống: Đăng nhập, thiết lập cơ bản.** Đổi mật khẩu mặc định.

3. **Quản trị viên hệ thống: Mở kỳ đầu tiên.** Nhập đơn giá điện, năm, tháng. Từ bước này trở đi mọi thay đổi dữ liệu nghiệp vụ đều cần kỳ đang mở.

4. **Quản trị viên hệ thống: Tạo khu vực.** Tên khu vực + công tơ tổng (tên).

5. **Quản trị viên hệ thống: Tạo đơn vị.** Gán vào khu vực.

6. **Quản trị viên hệ thống: Chỉ định đơn vị quản lý khu vực.**

7. **Quản trị viên hệ thống: Tạo tài khoản.** Quản trị viên đơn vị, chỉ huy đơn vị. Gán vào đơn vị đã tạo.

8. **Đơn vị quản lý khu vực: Khai báo phần khu vực.** Đầu mối bơm nước + công tơ. Đầu mối sinh hoạt thuộc khu vực. Đầu mối công cộng thuộc khu vực. Đầu mối ngoài biên chế. Phân bổ bơm nước.

9. **Quản trị viên đơn vị: Khai báo đơn vị.** Đầu mối sinh hoạt + công tơ + quân số. Đầu mối công cộng + công tơ. Khối, nhóm (nếu cần). Cấu hình đơn vị (công cộng đơn vị, cột Khác). Nhập thủ công đầu kỳ + cuối kỳ công tơ.

---

## Luồng thao tác hàng tháng

6 bước (nghiệp vụ mục 14). Bước 2 và bước 3 có thể làm song song.

1. **Quản trị viên hệ thống: Mở kỳ mới.** Hệ thống tự kế thừa số đầu kỳ từ cuối kỳ trước. Cập nhật đơn giá điện nếu thay đổi.

2. **Quản trị viên đơn vị: Nhập liệu đơn vị.** Nhập số cuối kỳ từng công tơ sinh hoạt, công cộng. Cập nhật quân số theo nhóm cấp bậc nếu có thay đổi (vào trang chỉnh sửa từng đầu mối sinh hoạt). Cập nhật cấu hình đơn vị nếu cần.

3. **Đơn vị quản lý khu vực: Nhập liệu phần khu vực.** Nhập số sử dụng công tơ tổng. Nhập số cuối kỳ công tơ bơm nước. Nhập số cuối kỳ công tơ đầu mối thuộc khu vực. Cập nhật quân số đầu mối thuộc khu vực nếu có thay đổi. Cập nhật phân bổ bơm nước nếu cần. Khai báo thêm đầu mối thuộc khu vực nếu cần.

4. **Hệ thống: Tính toán.** Tính tổn hao toàn khu vực → phân bổ cho từng công tơ. Tính phân bổ bơm nước → xuống từng đầu mối. Tính tiêu chuẩn, khoản trừ, sử dụng, thâm điện, thành tiền.

5. **Kiểm tra kết quả.** Quản trị viên đơn vị xem bảng tính tiền, đi thu tiền. Chỉ huy đơn vị xem theo dõi. Quản trị viên hệ thống xem bảng gộp, tổng quan, so sánh.

6. **Quản trị viên hệ thống: Đóng kỳ.** Kỳ bị đóng: không ai sửa được số liệu.

---

## Yêu cầu kỹ thuật

### Hoạt động offline

Hệ thống hoạt động trên mạng nội bộ Sư đoàn, không cần internet.

### Xác thực (Devise)

- Đăng nhập bằng username + mật khẩu.
- Mật khẩu tối thiểu 8 ký tự, phải có ít nhất 1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt. Validate ở cảJavaScript (Stimulus) và server (Devise custom validation).
- Quên mật khẩu: technician hoặc system_admin reset. Không có tính năng quên mật khẩu qua email.
- Người dùng tự đổi mật khẩu của mình được.
- Đổi mật khẩu lần đầu đăng nhập (force_password_change).
- Session timeout: tự thoát sau 2 giờ không hoạt động (Devise :timeoutable).
- 1 tài khoản cho phép đăng nhập nhiều thiết bị cùng lúc.
- Xóa tài khoản đang đăng nhập (của người khác): session bị buộc thoát ngay.

### Tài khoản mặc định

Hệ thống khi cài đặt có sẵn 2 tài khoản mặc định: technician và system_admin. Không cho phép xóa 2 tài khoản này.

Seed data tài khoản mặc định:

| Tài khoản | username | password | display_name | role | force_password_change |
|---|---|---|---|---|---|
| Kỹ thuật viên | `kyThuat` | `Abc@1234` | Kỹ thuật viên | technician | true |
| Quản trị viên hệ thống | `quanTri` | `Abc@1234` | Quản trị viên hệ thống | system_admin | true |

Password mặc định bắt buộc đổi lần đầu đăng nhập (force_password_change = true). Cần đánh dấu 2 tài khoản này là undeletable (thêm cột `default_account` boolean, mặc định false, true cho 2 tài khoản này, validation không cho xóa khi default_account = true).

### Thông báo khi đăng nhập

Hiển thị "Kỳ tháng X đã mở, vui lòng nhập liệu" khi có kỳ đang mở.

### Xung đột nhập liệu

Dùng optimistic locking (lock_version trên ActiveRecord). Flow: User A load form → User B load form → User A save (thành công, lock_version tăng) → User B save → ActiveRecord::StaleObjectError → hệ thống catch lỗi, hiển thị cảnh báo "Dữ liệu đã bị thay đổi bởi người khác", reload dữ liệu mới nhất → User B xem lại rồi quyết định lưu lại hay không.

Bảng cần lock_version: meter_readings, main_meter_readings, personnel_entries, non_establishment_snapshots, unit_configs, other_deductions, pump_allocations.

### Nhập thủ công số sử dụng công tơ

Khi cuối kỳ < đầu kỳ (thay công tơ mới): cho phép nhập thủ công số sử dụng (manual_usage) + ghi chú optional (manual_usage_note).

### Phân cách số

Phân cách số tiếng Việt: dấu chấm phân cách hàng nghìn, dấu phẩy phân cách hàng thập phân (ví dụ: 96.578,38).

### Việt hóa

Toàn bộ hệ thống Việt hóa 100%: giao diện, thông báo, cảnh báo, nút bấm, nhãn, xuất file. Code tiếng Anh, i18n tiếng Việt (config/locales/vi.yml).

### Làm tròn số

- Không làm tròn trong quá trình tính toán. Giữ toàn bộ độ chính xác.
- Lưu trữ dạng decimal (PostgreSQL numeric). Không dùng float.
- Chỉ làm tròn khi hiển thị và xuất Excel: 2 chữ số thập phân cho kW, 0 chữ số thập phân cho tiền (đồng).

### Giao diện chung

- Desktop only. Không cần responsive cho mobile/tablet. Hệ thống dùng trên mạng nội bộ quân đội với máy tính bàn.
- Validation: không dùng HTML5 validation (tooltip tiếng Anh của browser, không kiểm soát style). DùngJavaScript validation (Stimulus controller) validate realtime khi blur/submit, hiển thị thông báo lỗi tiếng Việt ngay dưới ô input, style đồng nhất. Server-side validation (model) luôn là lớp cuối cùng — không bao giờ tin JS.
- Tất cả trang danh sách: tìm kiếm, sắp xếp, lọc, phân trang, hiển thị tổng số bản ghi, chọn số dòng mỗi trang.
- Hover highlight dòng.
- Hàng tổng cuối bảng cho các trang có danh sách số liệu.
- Tên cột tuyệt đối không viết tắt, không rút gọn.

### Nhật ký hệ thống

Mọi thao tác trên hệ thống đều được ghi lại (PaperTrail). System_admin và technician có thể xem.

### Sao lưu và phục hồi

- Technician tạo backup toàn bộ data (pg_dump).
- Technician restore hệ thống về 1 bản backup đã tạo (pg_restore).
- Tối đa lưu được 3 bản backup.

### Stack kỹ thuật

- Rails 8, PostgreSQL, Tailwind, Hotwire (Turbo + Stimulus)
- Devise (xác thực), CanCanCan (phân quyền), PaperTrail (nhật ký)
- Discard (soft delete), Pagy (phân trang)
- RSpec + Capybara (test)
- Docker (production deployment)
- Timezone: Asia/Ho_Chi_Minh (UTC+7). Cấu hình trong config/application.rb: `config.time_zone = "Hanoi"`. Database lưu UTC, Rails tự chuyển đổi khi hiển thị.
- Database encoding: UTF-8. PostgreSQL tạo database với `ENCODING = 'UTF8'`. Hỗ trợ đầy đủ tiếng Việt có dấu.

---

## Lịch sử thay đổi

### v2.9.0 (21/05/2026)

- Schema: thêm `lock_version` vào `non_establishment_snapshots` — tất cả bảng nhập liệu per kỳ giờ đều có optimistic locking.
- Cập nhật danh sách bảng cần lock_version (thêm non_establishment_snapshots).
- PeriodGuard: thêm vào ZonesController và UnitsController — mọi thay đổi dữ liệu nghiệp vụ đều cần kỳ đang mở. Loại bỏ trạng thái gap, hệ thống giờ chỉ còn 3 trạng thái: không có kỳ mở (chỉ đọc), kỳ mới nhất đang mở (toàn quyền), kỳ cũ mở lại (chỉ sửa số liệu).
- Luồng thiết lập ban đầu: sắp xếp lại thứ tự — mở kỳ trước, tạo cấu trúc sau, tạo tài khoản sau khi có đơn vị và đơn vị quản lý khu vực (theo nghiệp vụ v2.11.0).
- Cập nhật tham chiếu nguồn nghiệp vụ: từ v2.10.0 sang v2.11.0.

### v2.8.0 (21/05/2026)

- Engine tính toán: sửa quy tắc `.with_discarded` — bỏ "phải" (không tuyệt đối) và bổ sung ngoại lệ kỳ đang mở (PumpAllocationCalculator loại đối tượng đã xóa khi tính kỳ đang mở). Đồng bộ văn bản với hành vi code thực tế.
- Sidebar: viết lại câu mở đầu mục "Sidebar per role" cho khỏi tự mâu thuẫn — tách rõ ẩn theo vai trò (theo bảng) và không ẩn theo trạng thái kỳ.
- Schema meter_readings: sửa kiểu `manual_usage_note` từ `string` thành `text` cho khớp database.

### v2.7.0 (20/05/2026)

- Cập nhật tham chiếu nguồn nghiệp vụ ở đầu tài liệu: từ v2.8.0 sang v2.10.0. Thiết kế đã phản ánh đầy đủ nghiệp vụ v2.9.0 từ bản v2.5.0; nghiệp vụ v2.10.0 gồm các điểm làm rõ vốn đã có sẵn trong thiết kế.
- Engine tính toán: bổ sung trang tổng quan là điểm kích hoạt tính toán lần đầu, bên cạnh bảng tính tiền (theo nghiệp vụ mục 14).
- Schema pump_allocations: bổ sung ràng buộc coefficient ≥ 0 (theo nghiệp vụ mục 24).
- Schema main_meters: ghi rõ cách đảm bảo "mỗi khu vực đúng 1 công tơ tổng" hiện tại — qua luồng tạo/sửa khu vực, chưa đặt unique constraint ở database (theo nghiệp vụ mục 5 và 22).
- Phân quyền: sửa cách diễn đạt số vai trò thành "4 vai trò: 3 nghiệp vụ + 1 kỹ thuật". Cách viết cũ "4 vai trò nghiệp vụ + 1 vai trò kỹ thuật" ngụ ý 5 vai trò, lệch với enum role và nghiệp vụ mục 11.

### v2.6.0 (20/05/2026)

- Phân quyền: hạ quyền các bản ghi snapshot theo kỳ từ CRUD xuống Đọc + Cập nhật cho unit_admin (cả regular và zone-manager). Áp dụng cho: meter_readings, personnel_entries, unit_configs, other_deductions, non_establishment_snapshots. Lý do: các bản ghi này tạo/xóa tự động qua vòng đời thực thể cha (công tơ, đầu mối) và kỳ tính toán — giao diện chỉ cập nhật giá trị, không có trang nào cho phép tạo/xóa độc lập. Giữ quyền tối thiểu (principle of least privilege) để tránh thao tác ngoài ý muốn nếu tương lai có thêm endpoint.
- Phân quyền: ghi nhận kỹ thuật viên có quyền chỉ đọc units — cần cho dropdown đơn vị trên form tạo tài khoản, không có trang riêng hiển thị danh sách đơn vị cho kỹ thuật viên.

### v2.5.0 (20/05/2026)

- Mở rộng quyền đơn vị quản lý khu vực: từ chỉ nhập liệu sang khai báo và nhập liệu phần khu vực (theo nghiệp vụ v2.9.0).
- unit_admin zone-manager: thêm CRUD contact_points, meters thuộc khu vực; thêm CRUD pump_allocations; thêm CRUD main_meter_readings (bao gồm create); thêm CRUD other_deductions đầu mối sinh hoạt thuộc khu vực; thêm đọc + tính toán lại calculations khu vực. main_meters giữ chỉ đọc.
- commander zone-manager: thêm quyền xem đầu mối khu vực, phân bổ bơm nước.
- Sidebar: thêm "Phân bổ bơm nước" cho unit_admin zone-manager và commander zone-manager.
- Luồng thiết lập: bước 8 thêm unit_admin zone-manager làm chủ thể chính, system_admin vẫn toàn quyền.
- Luồng hàng tháng: bước 3 mở rộng bao gồm khai báo thêm đầu mối, cập nhật quân số, phân bổ bơm nước.
- Sửa dữ liệu: cho phép sửa tên công tơ tổng trên màn hình sửa khu vực.

### v2.4.0 (20/05/2026)

- Thêm mục "Cleanup data khi discard": khi discard thực thể cấu trúc, hard delete data per kỳ đang mở (meter_readings, personnel_entries, calculations, non_establishment_snapshots, other_deductions, main_meter_readings). Kỳ cũ giữ nguyên.
- Thêm mục "Engine skip thực thể không có data kỳ đang tính": engine kiểm tra có meter_readings kỳ đó không, không có thì skip hoàn toàn.
- Cập nhật bảng xóa dữ liệu: thêm tham chiếu đến mục Cleanup data cho xóa khu vực và xóa đầu mối/công tơ.

### v2.3.0 (19/05/2026)

- Zone chuyển từ hard delete sang soft delete (discard). Thêm cột discarded_at vào bảng zones, index.
- Thêm quyết định zones soft delete kèm lý do và hệ quả (before_discard discard main_meters).
- Engine tính toán: thêm quy tắc dùng .with_discarded cho zones, units, contact_points, meters, main_meters.
- Thêm mục "Hạn chế thay đổi cấu trúc khi mở kỳ cũ" (StructureChangeGuard).
- Mở kỳ mới: thêm ghi chú snapshot chỉ copy cho thực thể .kept.
- Cập nhật bảng xóa dữ liệu: thêm dòng "Xóa khu vực" với soft delete + điều kiện.

### v2.2.0 (18/05/2026)

- Uniqueness scope contact_points.name: ghi rõ scope = (name, unit_id, zone_id, contact_point_type). Cho phép trùng tên giữa loại khác nhau trong cùng đơn vị/khu vực.
- Xóa đơn vị quản lý khu vực: ghi rõ phải qua validation "đơn vị đang có đầu mối" và "đơn vị đang có tài khoản" trước khi hiển thị cảnh báo.

### v2.1.0 (18/05/2026)

- Phiên bản đầu tiên.