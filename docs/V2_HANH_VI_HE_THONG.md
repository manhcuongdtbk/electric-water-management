# Hành vi hệ thống — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Phiên bản:** 1.0.0
> **Ngày:** 21/05/2026
> **Tính chất:** Tài liệu mô tả hành vi thực tế của hệ thống đã được verify qua code và test. Bổ sung cho V2_XAC_NHAN_NGHIEP_VU (cái gì) và V2_THIET_KE_HE_THONG (làm thế nào) bằng cách trả lời "hệ thống hành xử ra sao" trong các kịch bản thực tế.
> **Nguồn:** Kết quả audit toàn diện codebase, 14 đợt page-by-page, 781+ test cases.

---

## Mục lục

1. [5 vai trò thực tế](#1-5-vai-trò-thực-tế)
2. [3 trạng thái kỳ](#2-3-trạng-thái-kỳ)
3. [Hành vi từng trang theo vai trò và trạng thái kỳ](#3-hành-vi-từng-trang-theo-vai-trò-và-trạng-thái-kỳ)
4. [Dữ liệu xuyên kỳ — entity bị xóa](#4-dữ-liệu-xuyên-kỳ--entity-bị-xóa)
5. [Kế thừa và cleanup khi đóng/mở kỳ](#5-kế-thừa-và-cleanup-khi-đóngmở-kỳ)
6. [Nguyên tắc .kept vs .with_discarded](#6-nguyên-tắc-kept-vs-with_discarded)
7. [Bài học từ audit](#7-bài-học-từ-audit)

---

## 1. 5 vai trò thực tế

User model có 4 enum values, nhưng hệ thống có **5 vai trò** với scope khác nhau:

| Ký hiệu | Vai trò | Cách xác định | Phạm vi |
|---|---|---|---|
| SA | Quản trị viên hệ thống | `role == "system_admin"` | Toàn hệ thống |
| UA-ZM | Quản trị viên đơn vị quản lý khu vực | `role == "unit_admin"` + `Zone.exists?(manager_unit_id: unit_id)` | Đơn vị mình + đầu mối/công tơ khu vực mình quản lý |
| UA | Quản trị viên đơn vị | `role == "unit_admin"` + không quản lý khu vực | Chỉ đơn vị mình |
| CMD | Chỉ huy đơn vị | `role == "commander"` (+ ZM variant tương tự UA-ZM) | Chỉ xem, phạm vi như UA hoặc UA-ZM |
| TECH | Kỹ thuật viên | `role == "technician"` | Tài khoản, sao lưu, nhật ký. Không thấy dữ liệu nghiệp vụ |

UA-ZM không phải role riêng trong database — là unit_admin có đơn vị được chỉ định quản lý khu vực. Tương tự CMD-ZM. Code xác định qua `current_zone_manager?` (kiểm tra `Zone.kept.exists?(manager_unit_id: current_user.unit_id)`).

**Khác biệt UA vs UA-ZM:**

| Trang | UA | UA-ZM |
|---|---|---|
| Sidebar | 8 mục | 12 mục (+điện lực, bơm nước, khu vực, phân bổ) |
| Billing | Đầu mối đơn vị mình (28 cột) | Đơn vị mình + đầu mối sinh hoạt khu vực (29 cột, cột Đơn vị hiện) |
| Đầu mối | CRUD residential+public đơn vị mình | + CRUD 4 loại khu vực mình |
| Nhập liệu | Công tơ đơn vị mình | + công tơ khu vực + bơm nước + điện lực |

---

## 2. 3 trạng thái kỳ

Hệ thống chỉ có 3 trạng thái (không có gap — PeriodGuard chặn mọi thay đổi nghiệp vụ khi không có kỳ mở):

### Trạng thái A: Không có kỳ mở

```
Tất cả kỳ đã đóng, hoặc chưa có kỳ nào.
```

- **Dữ liệu nghiệp vụ:** Chỉ đọc. Mọi thao tác tạo/sửa/xóa bị PeriodGuard chặn (redirect + thông báo).
- **Quản trị hệ thống:** Tài khoản, sao lưu, nhật ký vẫn hoạt động.
- **Thoát:** Mở kỳ mới hoặc mở lại kỳ cũ.

### Trạng thái B: Kỳ mới nhất đang mở

```
Kỳ mở là kỳ có year/month lớn nhất.
```

- **Cấu trúc:** Tạo/sửa/xóa zones, units, contact_points, meters, blocks, groups, ranks.
- **Nhập liệu:** Tạo/sửa meter_readings, main_meter_readings, personnel_entries, unit_configs, other_deductions, pump_allocations.
- **Tính toán:** Recalculate hoạt động.
- **Thoát:** Đóng kỳ.

### Trạng thái C: Kỳ cũ mở lại

```
Kỳ mở KHÔNG phải kỳ mới nhất (có kỳ đóng với year/month lớn hơn).
```

- **Cấu trúc:** StructureChangeGuard chặn mọi thay đổi cấu trúc.
- **Nhập liệu:** Chỉ sửa số liệu per kỳ (meter_readings, personnel_entries, unit_configs, other_deductions, pump_allocations, main_meter_readings).
- **Tính toán:** Recalculate hoạt động (engine dùng `.with_discarded`).
- **Thoát:** Đóng kỳ (cảnh báo nếu reading_end lệch kỳ kế tiếp, không tự sửa kỳ kế tiếp).

### Quy tắc xuyên suốt

- Chỉ có **đúng 1 kỳ mở** tại 1 thời điểm (database partial unique index).
- Mọi thay đổi dữ liệu nghiệp vụ cần kỳ mở (PeriodGuard).
- Thay đổi cấu trúc chỉ khi kỳ mở là kỳ mới nhất (StructureChangeGuard).

---

## 3. Hành vi từng trang theo vai trò và trạng thái kỳ

### Bảng tính tiền (/billing)

| Vai trò | Filter | Dữ liệu | Cột | Recalculate |
|---|---|---|---|---|
| SA | Dropdown zone + unit | Tất cả đầu mối sinh hoạt | 30 (có Khu vực + Đơn vị) | Có |
| UA-ZM | Cố định zone + unit (hiển thị từ current_user) | Đơn vị mình + đầu mối sinh hoạt khu vực | 29 (có Đơn vị, ẩn Khu vực) | Có |
| UA | Cố định zone + unit | Chỉ đơn vị mình | 28 (ẩn cả 2) | Có |
| CMD/CMD-ZM | Như UA/UA-ZM | Như UA/UA-ZM | Như UA/UA-ZM | Không |
| TECH | Redirect /users | — | — | — |

Filter display: SA dùng dropdown `@available_zones`/`@available_units`. Non-SA dùng `current_user.unit.zone.name` + `current_user.unit.name` (hiển thị cố định, không dùng `@zone`/`@unit`).

### Nhập chỉ số công tơ (/meter_entries, /pump_entries)

| Vai trò | meter_entries thấy | pump_entries thấy | Sửa được |
|---|---|---|---|
| SA | Tất cả residential+public | Tất cả water_pump | Có |
| UA-ZM | Đơn vị mình + khu vực | Khu vực mình | Có |
| UA | Đơn vị mình | Trống | Có |
| CMD | Đơn vị mình (+khu vực nếu ZM) | Khu vực nếu ZM | Không (disabled) |
| TECH | Redirect | Redirect | — |

### Cấu hình đơn vị (/unit_config)

| Vai trò | unit_public_rate | OD đơn vị | OD khu vực | Sửa |
|---|---|---|---|---|
| SA | Chọn unit bất kỳ | Unit đó | Nếu unit là ZM | Có |
| UA-ZM | Đơn vị mình | Đơn vị mình | Khu vực mình | Có |
| UA | Đơn vị mình | Đơn vị mình | Trống | Có |
| CMD | Không thấy trang (sidebar ẩn) | — | — | — |

### Phân bổ bơm nước (/pump_allocations)

| Vai trò | Thấy | CUD | Đặc biệt |
|---|---|---|---|
| SA | Tất cả | Có | — |
| UA-ZM | Khu vực mình | Có | Cho sửa khi kỳ cũ mở lại (không có StructureChangeGuard) |
| CMD-ZM | Khu vực mình | Không | — |
| UA/CMD/TECH | Không thấy | — | — |

### Tổng quan (/dashboard)

| Vai trò | Nội dung |
|---|---|
| SA | Bảng đơn vị (thâm điện, thành tiền, trạng thái nhập liệu) + bảng khu vực (công cộng, bơm nước per zone) + cảnh báo |
| UA-ZM | Tổng quan đơn vị mình + khu vực |
| UA | Tổng quan đơn vị mình |
| CMD | Như UA/UA-ZM chỉ xem |

---

## 4. Dữ liệu xuyên kỳ — entity bị xóa

**Đây là phần quan trọng nhất, không có trong 2 tài liệu kia.**

### Nguyên tắc

Nghiệp vụ 23.1: "Dữ liệu kỳ cũ giữ nguyên" khi xóa entity. Cụ thể:

- **Kỳ đã đóng:** Data không bị ảnh hưởng khi entity bị xóa ở kỳ khác.
- **Kỳ đang mở (khi xóa):** Data bị hard delete (cleanup callbacks).
- **Kỳ tương lai:** Entity không được copy (snapshot dùng `.kept`).

### Kịch bản minh họa

```
Kỳ N-1: tạo Zone A, B, C → nhập liệu → tính toán → đóng
Kỳ N:   xóa Zone A → nhập liệu B, C → tính toán → đóng
Kỳ N+1: mở
```

| Hành động | Kỳ N-1 | Kỳ N | Kỳ N+1 |
|---|---|---|---|
| Xem bảng tính tiền | Thấy A, B, C | Thấy B, C | Thấy B, C |
| Xem chỉ số công tơ | Thấy A, B, C | Thấy B, C | Thấy B, C |
| Xem nhập số điện lực | Thấy main_meter A, B, C | Thấy B, C | Thấy B, C |
| SA filter dropdown zone | Chọn được A, B, C | Chọn được B, C | Chọn được B, C |
| Recalculate | Tính A, B, C | Tính B, C | Tính B, C |

### Vì sao hoạt động đúng mà không cần biết "xóa ở kỳ nào"

Hệ thống **không lưu** entity bị xóa ở kỳ nào (`discarded_at` là timestamp, không phải period reference). Thay vào đó, **data per kỳ tự lọc:**

1. **Xóa Zone A ở kỳ N:** `before_discard` callbacks hard delete data kỳ N (meter_readings, calculations, personnel_entries, other_deductions, main_meter_readings, pump_allocations).
2. **Kỳ N-1 đã đóng:** Data không bị ảnh hưởng — calculations, meter_readings vẫn còn.
3. **Kỳ N+1 mở mới:** `snapshot_existing_entities` dùng `.kept` → Zone A discarded → không copy.

Kết quả: `Calculation.where(period: kỳ_N_1)` có record Zone A → hiện. `where(period: kỳ_N)` không có → không hiện. Không cần kiểm tra `discarded_at`.

### Cleanup callbacks khi xóa entity

| Entity bị xóa | Cleanup kỳ đang mở | Data kỳ cũ |
|---|---|---|
| Zone | Hard delete main_meter_readings + discard main_meters | Giữ nguyên |
| Unit | Hard delete pump_allocations + clear zone manager | Giữ nguyên (phải xóa hết CPs/users trước) |
| ContactPoint | Hard delete meter_readings, calculations, personnel_entries, other_deductions, non_establishment_snapshots, pump_allocations + discard meters | Giữ nguyên |
| Meter | Hard delete meter_readings | Giữ nguyên (phải không phải meter cuối) |
| Block/Group | Nullify block_id/group_id trên children | — (không có data per kỳ) |

---

## 5. Kế thừa và cleanup khi đóng/mở kỳ

### Mở kỳ mới (copy từ kỳ trước)

| Data | Copy từ kỳ trước | Mặc định nếu không có kỳ trước |
|---|---|---|
| ranks | Tên + quota + position | 7 ranks mặc định |
| meter_readings | reading_start = reading_end cũ, no_loss từ meters.no_loss | reading_start = 0 |
| personnel_entries | count từ kỳ trước | 0 |
| non_establishment_snapshots | personnel_count từ kỳ trước hoặc contact_point | contact_point.personnel_count |
| unit_configs | unit_public_rate từ kỳ trước | 0% |
| other_deductions | other_type + other_value từ kỳ trước | fixed, 0 |
| pump_allocations | coefficient + fixed_percentage từ kỳ trước | coefficient = 1 |
| period config | unit_price, savings_rate, division_public_rate, water_pump_standard | Bắt buộc nhập (kỳ đầu) |
| **main_meter_readings** | **KHÔNG copy** — nhập mới mỗi kỳ | — |

Chỉ copy entity `.kept` (không copy entity đã xóa).

### Entity tạo giữa kỳ đang mở

| Entity | after_create callback |
|---|---|
| ContactPoint residential | meter_readings (start=0) + personnel_entries (count từ form) + other_deductions (fixed, 0) |
| ContactPoint non_establishment | non_establishment_snapshots (personnel_count từ form) |
| Meter | meter_reading (start=0, no_loss từ meter) |
| Unit | unit_config (unit_public_rate = 0%) |
| Rank | personnel_entries (count=0) cho mọi đầu mối sinh hoạt hiện có |

### Đóng kỳ cũ sau khi sửa

Khi đóng kỳ đã mở lại, hệ thống kiểm tra: `reading_end` kỳ này có khớp `reading_start` kỳ kế tiếp không. Nếu lệch → **cảnh báo** (không tự sửa kỳ kế tiếp). User phải mở từng kỳ kế tiếp sửa thủ công.

---

## 6. Nguyên tắc .kept vs .with_discarded

| Ngữ cảnh | Dùng | Lý do |
|---|---|---|
| **Query hiển thị data per kỳ** (billing, meter_entries, dashboard, ...) | Không dùng `.kept` — data per kỳ tự lọc | Kỳ cũ cần hiện entity đã xóa |
| **SA dropdown filter** (zone, unit khi xem billing/history) | `.with_discarded` | SA cần chọn zone/unit đã xóa để xem kỳ cũ |
| **zones_in_scope** (recalculate, warnings) | `.with_discarded` | Tính toán + cảnh báo phải bao gồm zone đã xóa |
| **Engine** (ZoneQuery, calculators) | `.with_discarded` | Tính toán kỳ cũ phải bao gồm entity đã xóa |
| **Model callbacks** (discard, create, validate) | `.kept` | Thao tác trên trạng thái hiện tại |
| **PeriodService snapshot** | `.kept` | Chỉ copy entity còn tồn tại cho kỳ mới |
| **Form dropdown** (tạo/sửa entity) | `.kept` | Chỉ chọn entity còn tồn tại |
| **CRUD index/show** | `.kept` | Quản lý entity hiện tại |
| **Ability** (phân quyền) | `.kept` | Quyền dựa trên trạng thái hiện tại |

---

## 7. Bài học từ audit

### Audit phải theo luồng nghiệp vụ, không theo file

Audit file-by-file (schema → model → controller) bỏ sót vấn đề cross-cutting. Phải audit theo **kịch bản runtime**: tạo entity ở kỳ N-1, xóa ở kỳ N, xem kỳ N-1 — traverse nhiều file, nhiều layer.

### Đánh giá thiết kế, không chỉ mô tả hiện trạng

"Gap cho phép tạo zone/unit" → phải hỏi "nên cho phép không?" thay vì chỉ ghi nhận. Kết quả: loại bỏ gap, đơn giản hóa từ 5 trạng thái xuống 3.

### Test phải cover xuyên kỳ

Test tại 1 thời điểm (kỳ đang mở) không đủ. Phải test: tạo → đóng → mở kỳ mới → xóa → mở lại kỳ cũ → verify visibility. 24 test cases cover kịch bản này.

### 5 vai trò, không phải 4

UA-ZM là vai trò thực tế với scope khác UA. Mọi audit phải test cả 5 vai trò, đặc biệt UA-ZM xem data khu vực + zone-level CPs đã xóa.

### Code AI viết cần review kỹ hơn

Code từ session AI trước có thể thiếu suy nghĩ sâu về edge cases. Pattern: giải quyết vấn đề trước mắt (over-engineer dropdown) mà không đánh giá impact (empty dropdown, fragile SQL, performance). Cần trace qua mọi kịch bản thực tế.

---

## Lịch sử thay đổi

### v1.0.0 (21/05/2026)

- Tài liệu ban đầu, tổng hợp từ audit session toàn diện.
- Cover: 5 vai trò, 3 trạng thái kỳ, hành vi 14 trang, dữ liệu xuyên kỳ, nguyên tắc .kept/.with_discarded.
