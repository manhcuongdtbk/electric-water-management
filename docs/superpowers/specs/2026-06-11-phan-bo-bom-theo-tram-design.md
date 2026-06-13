---
title: Phân bổ điện bơm nước theo từng trạm bơm (mở rộng đối tượng nhận)
version: 0.2.1
date: 2026-06-11
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Phân bổ điện bơm nước theo từng trạm bơm

Tính năng 2 của milestone **1.2.0**. Thay cơ chế gộp toàn khu vực bằng **phân bổ riêng cho từng trạm bơm**: mỗi trạm có danh sách đối tượng nhận riêng. Mở rộng loại đối tượng nhận: thêm khối, nhóm, và đầu mối sinh hoạt thuộc đơn vị.

- **Nguồn nghiệp vụ:** [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) anchor `NV-phan-bo-bom-theo-tram` (fold từ `V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` mục 3).
- **Truy vết:** GitHub Issue [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319), milestone `1.2.0`.
- **Trạng thái khách:** đã xác nhận 31/05/2026 (cả ba loại đối tượng nhận mới).

## Bối cảnh

Một khu vực có nhiều trạm bơm, mỗi trạm phục vụ một vùng. Hiện tại hệ thống **gộp điện tất cả trạm bơm thành một tổng** rồi chia cho các đối tượng nhận toàn khu vực. Nghiệp vụ muốn tách riêng: trạm nào phục vụ vùng nào thì chỉ phân bổ cho đối tượng của vùng đó.

Mã nguồn liên quan hiện tại:

- Cấu hình: `app/models/pump_allocation.rb` — gắn `zone_id` + `period_id`, đối tượng nhận là `unit_id` **XOR** `contact_point_id`, cách phân bổ là `fixed_percentage` **XOR** `coefficient`. Ràng buộc: tổng `fixed_percentage` ≤ 100, `contact_point` phải zone-level.
- Tính toán: `app/services/pump_allocation_calculator.rb` — gom **toàn bộ** công tơ bơm nước khu vực (`ZoneQuery#pump_meters`) → `D = raw_pump_usage + pump_loss`, phân bổ một lần cho cả khu vực, đơn vị chia xuống đầu mối theo quân số.
- Trang: `app/controllers/pump_allocations_controller.rb` + `app/views/pump_allocations/` (một bảng chung).
- Kế thừa kỳ: `app/services/period_service.rb` — `copy_pump_allocations`.

**Không có model "trạm bơm" riêng.** Công tơ bơm nước thuộc các đầu mối loại `water_pump` (zone-level, mỗi đầu mối có nhiều công tơ). Tổn hao per-công-tơ đã có sẵn (`LossCalculator#meter_losses`).

## ADR-026: Trạm bơm = đầu mối `water_pump`; recipient khóa ngoại rời; cờ kỳ phân biệt cơ chế

- **Trạng thái:** Accepted · 2026-06-11
- **Bối cảnh:** Cần phân bổ điện bơm nước theo từng trạm bơm thay vì gộp khu vực, thêm ba loại đối tượng nhận (khối, nhóm, đầu mối sinh hoạt thuộc đơn vị), đồng thời **giữ nguyên hành vi kỳ cũ** (đã đóng) là gộp toàn khu vực. Hệ thống chưa có model trạm bơm; công tơ bơm nước nằm dưới đầu mối `water_pump`.
- **Quyết định:**
  1. **Trạm bơm = đầu mối `water_pump`.** Mỗi đầu mối `water_pump` là một trạm; `D` của trạm = Σ (sử dụng thô + tổn hao) các công tơ của đầu mối đó. Σ `D` các trạm = `D` toàn khu vực (bất biến cũ giữ nguyên).
  2. **`PumpAllocation` gắn thêm `pump_contact_point_id`** (khóa ngoại tới đầu mối `water_pump` nguồn, nullable). Mở rộng đối tượng nhận bằng **khóa ngoại rời + ràng buộc đúng một trong bốn**: `unit_id`, `block_id`, `group_id`, `contact_point_id`. Nới ràng buộc cho phép `contact_point` cấp đơn vị (residential thuộc đơn vị), không chỉ zone-level.
  3. **Thêm cờ `Period#pump_allocation_per_station`** (boolean). Kỳ mở sau khi tính năng lên = `true`; kỳ cũ (đã đóng) = `false`. `PumpAllocationCalculator` rẽ nhánh theo cờ.
- **Lý do:** Đầu mối `water_pump` đã mang đúng ngữ nghĩa "trạm bơm" và đã có công tơ — không cần migrate hay thêm tầng quan hệ. khóa ngoại rời + exactly-one ăn khớp `accessible_by`/Discard mà dự án dùng nặng, tránh bẫy polymorphic, nhất quán style XOR hiện có. Cờ kỳ là cách tường minh, không suy đoán, để phân biệt cơ chế cũ/mới và xử lý kỳ đã đóng.
- **Tradeoff:** (+) Không migrate dữ liệu trạm, không phá kỳ cũ, mở rộng theo pattern sẵn có. (−) Bốn khóa ngoại nullable + validate exactly-one rườm hơn hai; calculator có hai nhánh (cũ/mới) cùng tồn tại cho tới khi không còn kỳ cũ cần xem.
- **Phương án đã loại:**
  - *Model `PumpStation` riêng:* phải migrate toàn bộ đầu mối `water_pump`, thêm quan hệ meter→station, nặng và rủi ro cho dữ liệu kỳ cũ.
  - *Recipient polymorphic (`recipient_type`/`recipient_id`):* gọn trên giấy nhưng phức tạp hóa `accessible_by`/Discard scoping và lệch style XOR hiện có.
  - *Suy ra cơ chế từ dữ liệu (có `pump_contact_point_id` ⟺ per-trạm):* nhập nhằng khi kỳ mới chưa cấu hình trạm nào (rỗng) so với kỳ cũ.
- **Điều kiện xem lại:** Nếu một trạm bơm cần gắn nhiều đầu mối `water_pump`, hoặc số loại đối tượng nhận vượt bốn (lúc đó cân nhắc lại polymorphic).

## Thiết kế triển khai

> Triển khai ở session/PR sau. Phần này mô tả đích.

### Data model

- `pump_allocations`: thêm `pump_contact_point_id` (khóa ngoại → `contact_points`, nullable, index theo `(zone_id, period_id, pump_contact_point_id)`); thêm `block_id`, `group_id` (khóa ngoại nullable).
- `periods`: thêm `pump_allocation_per_station` (boolean, default theo ngày triển khai — xem "Chuyển tiếp").
- Ràng buộc `PumpAllocation`:
  - **Đối tượng nhận:** đúng một trong `{unit_id, block_id, group_id, contact_point_id}`.
  - `block`/`group` phải thuộc `zone` (qua đơn vị quản lý / cấu trúc đơn vị); `contact_point` recipient cho phép residential thuộc đơn vị **hoặc** zone-level **hoặc** ngoài biên chế.
  - **Per-trạm (kỳ `per_station = true`):** `pump_contact_point_id` bắt buộc và trỏ tới đầu mối `water_pump` cùng zone; ràng buộc tổng `fixed_percentage` ≤ 100 và "phải có recipient hệ số nếu chưa đạt 100%" tính **theo từng trạm**.
  - **Kỳ cũ (`per_station = false`):** `pump_contact_point_id` để trống; ràng buộc như hiện tại (theo zone).

### Tính toán (`PumpAllocationCalculator`)

- Rẽ nhánh theo `period.pump_allocation_per_station`:
  - **false:** giữ nguyên logic hiện tại (một `D` toàn khu vực, một danh sách allocation theo zone).
  - **true:** lặp **theo từng trạm** (mỗi đầu mối `water_pump` của zone):
    - `D_trạm` = Σ (sử dụng thô + `meter_losses`) các công tơ của đầu mối đó.
    - Lấy allocation có `pump_contact_point_id` = trạm đó; áp đúng thuật toán cũ (fixed% trước, phần còn lại theo hệ số × quân số) **trong phạm vi trạm**.
    - Đối tượng nhận khối/nhóm: chia đều xuống đầu mối residential bên trong theo quân số (tái dùng `distribute_to_residential_contact_points`, mở rộng nguồn quân số từ `unit` sang `block`/`group`).
    - Đầu mối sinh hoạt thuộc đơn vị nhận trực tiếp.
  - Gộp `contact_point_allocations` của tất cả trạm; tổng = `D` toàn khu vực.
- Cảnh báo: trạm chưa có đối tượng nhận → cảnh báo (tái dùng cơ chế warnings hiện có). Tổn hao vẫn tính zone-wide ở `LossCalculator` (mục 8 không đổi), chỉ gán `meter_losses` về trạm tương ứng.

### Trang Phân bổ bơm nước

- Kỳ `per_station = true`: hiển thị **một bảng cho mỗi trạm bơm** (nhóm theo đầu mối `water_pump`). Form thêm chọn trạm + bốn loại đối tượng nhận (đơn vị/khối/nhóm/đầu mối). Stimulus `pump_allocation_form` mở rộng để bật/tắt theo loại recipient và lọc theo trạm/zone.
- Kỳ cũ (`per_station = false`): giữ một bảng gộp như hiện tại (read-only khi kỳ đã đóng).
- Quyền: quản trị viên hệ thống và đơn vị quản lý khu vực cấu hình; chỉ huy chỉ xem (`can?(:update, ...)`).

### Kế thừa kỳ & chuyển tiếp

- Kỳ `per_station = true` kế thừa cấu hình **từng trạm** (đối tượng nhận, %, hệ số, `pump_contact_point_id`) từ kỳ `per_station = true` trước đó.
- **Chuyển tiếp cũ → per-trạm đầu tiên:** **không** kế thừa allocation qua ranh giới này. Kỳ per-trạm đầu tiên bắt đầu **trống**; admin cấu hình lại từng trạm; trạm chưa cấu hình → cảnh báo. (Cấu hình cũ kỳ-gộp không gắn được vào trạm cụ thể, kế thừa sẽ tạo trạng thái lỗi.)
- `period_service.copy_pump_allocations` cập nhật: chỉ copy khi cả kỳ nguồn lẫn kỳ đích đều `per_station = true`.

## Truy vết chiều test

Tính năng **chưa triển khai** — mọi chiều `DEFERRED #319` cho tới khi build (ADR-030). Khi build: đổi trạng thái từng hàng sang "có test" + gắn anchor vào mô tả test. Liên quan [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) (chiều "phân bổ bơm nước") và [`V2_HANH_VI_HE_THONG.md`](../../V2_HANH_VI_HE_THONG.md).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-phan-bo-tram-ky-cu` | Kỳ cũ (`per_station = false`): gộp toàn khu vực **không đổi** (regression) | DEFERRED #319 |
| `CHIEU-phan-bo-tram-tong` | Kỳ mới: hai trạm, recipient riêng; Σ per-trạm = `D` toàn khu vực | DEFERRED #319 |
| `CHIEU-phan-bo-tram-bon-recipient` | Bốn loại recipient (đơn vị / khối / nhóm / đầu mối sinh hoạt thuộc đơn vị) chia xuống đúng | DEFERRED #319 |
| `CHIEU-phan-bo-tram-rang-buoc` | Ràng buộc per-trạm: Σ fixed% ≤ 100; thiếu recipient hệ số khi < 100% → chặn; Σ(quân số×hệ số) = 0 → chặn | DEFERRED #319 |
| `CHIEU-phan-bo-tram-chua-cau-hinh` | Trạm chưa cấu hình recipient → cảnh báo trên bảng tính tiền | DEFERRED #319 |
| `CHIEU-phan-bo-tram-chuyen-tiep` | Chuyển tiếp: kỳ per-trạm đầu tiên bắt đầu trống; kỳ per-trạm sau kế thừa đúng | DEFERRED #319 |
| `CHIEU-phan-bo-tram-da-xoa` | Recipient đã xóa (Discard) khi xem kỳ cũ → dùng `.with_discarded` đúng chỗ (mục 7 hành vi hệ thống) | DEFERRED #319 |
| `CHIEU-phan-bo-tram-vai-tro` | Sáu vai trò + đơn vị quản lý khu vực cấu hình được, chỉ huy chỉ xem | DEFERRED #319 |

## Giới hạn

- Cách phân bổ (fixed% hoặc hệ số × quân số) **không đổi** — chỉ đổi phạm vi (toàn khu vực → từng trạm) và thêm loại recipient.
- Tổn hao vẫn tính chung toàn khu vực; chỉ gán tổn hao công tơ về trạm tương ứng.
- Một đầu mối `water_pump` = một trạm (không gộp nhiều đầu mối thành một trạm trong phạm vi này).

## Truy vết

- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) `NV-phan-bo-bom-theo-tram`.
- Issue: [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319).
- Spec anh em milestone 1.2.0: [cột Khác hệ số đơn vị](2026-06-11-cot-khac-he-so-don-vi-design.md), [hiển thị chi tiết tổn hao](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md).

## Lịch sử thay đổi

### 0.2.1 (2026-06-13)

- Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.

### 0.2.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>`, mọi hàng `DEFERRED #319` (chưa triển khai) — ADR-030, Issue #329. Khi build TN2: đổi trạng thái từng hàng sang "có test" + gắn anchor vào test.

### 0.1.0 (2026-06-11)

- Bản đầu: ADR-026 + thiết kế triển khai + chiều test cho phân bổ bơm nước theo từng trạm bơm và bốn loại đối tượng nhận.
