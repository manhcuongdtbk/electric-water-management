---
title: Phân bổ điện bơm nước theo từng trạm bơm (mở rộng đối tượng nhận)
version: 0.6.0
date: 2026-06-11
governed_by: 2026-06-07-sdlc-overview-design.md
customer_facing: true
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
    - 6 loại đối tượng nhận của nghiệp vụ (§9.2) ánh xạ vào 4 khóa ngoại: `unit_id` (đơn vị), `block_id` (khối), `group_id` (nhóm), và `contact_point_id` gom **ba biến thể đầu mối** — đầu mối sinh hoạt thuộc khu vực, đầu mối ngoài biên chế thuộc khu vực, và đầu mối sinh hoạt thuộc đơn vị (phân biệt bằng `zone_id`/`unit_id` của đầu mối, không cần khóa riêng).
  - `block`/`group` phải thuộc `zone` (qua đơn vị quản lý / cấu trúc đơn vị); `contact_point` recipient cho phép residential thuộc đơn vị **hoặc** zone-level **hoặc** ngoài biên chế.
  - **Per-trạm (kỳ `per_station = true`):** `pump_contact_point_id` bắt buộc và trỏ tới đầu mối `water_pump` cùng zone; ràng buộc tổng `fixed_percentage` ≤ 100 và "phải có recipient hệ số nếu chưa đạt 100%" tính **theo từng trạm**. Recipient kiểu `unit`/`block`/`group` phải có ít nhất 1 đầu mối sinh hoạt bên trong.
  - **Kỳ cũ (`per_station = false`):** `pump_contact_point_id` để trống; ràng buộc như hiện tại (theo zone).
  - **Không chồng chéo (toàn zone, xuyên trạm):** tập đầu mối sinh hoạt mà mỗi recipient "phân giải" tới phải không giao nhau — cả trong cùng trạm lẫn giữa các trạm. Ví dụ: `unit` + `block` bên trong = cấm.
  - **Không chia cấp (toàn zone, xuyên trạm):** toàn bộ đơn vị thuộc một trạm duy nhất. Nếu bất kỳ recipient nào (khối, nhóm, đầu mối) thuộc đơn vị X đã gắn trạm A, thì mọi recipient khác thuộc đơn vị X chỉ được gắn trạm A.

### Tính toán (`PumpAllocationCalculator`)

- Rẽ nhánh theo `period.pump_allocation_per_station`:
  - **false:** giữ nguyên logic hiện tại (một `D` toàn khu vực, một danh sách allocation theo zone).
  - **true:** lặp **theo từng trạm** (mỗi đầu mối `water_pump` của zone):
    - `D_trạm` = Σ (sử dụng thô + `meter_losses`) các công tơ của đầu mối đó.
    - Lấy allocation có `pump_contact_point_id` = trạm đó; áp đúng thuật toán cũ (fixed% trước, phần còn lại theo hệ số × quân số) **trong phạm vi trạm**.
    - Đối tượng nhận khối/nhóm: chia đều xuống đầu mối residential bên trong theo quân số (tái dùng `distribute_to_residential_contact_points`, mở rộng nguồn quân số từ `unit` sang `block`/`group`).
    - Đầu mối sinh hoạt thuộc đơn vị nhận trực tiếp.
  - Gộp `contact_point_allocations` của tất cả trạm; tổng = `D` toàn khu vực.
- Cảnh báo: trạm chưa có đối tượng nhận → cảnh báo; recipient kiểu `unit`/`block`/`group` có 0 đầu mối sinh hoạt bên trong → bỏ qua phân phối + cảnh báo (tái dùng cơ chế warnings hiện có). Tổn hao vẫn tính zone-wide ở `LossCalculator` (mục 8 không đổi), chỉ gán `meter_losses` về trạm tương ứng.

### Trang Phân bổ bơm nước

- Kỳ `per_station = true`: hiển thị **một bảng cho mỗi trạm bơm** (nhóm theo đầu mối `water_pump`). Form thêm chọn trạm + bốn loại đối tượng nhận (đơn vị/khối/nhóm/đầu mối). Stimulus `pump_allocation_form` mở rộng để bật/tắt theo loại recipient và lọc theo trạm/zone.
- Kỳ cũ (`per_station = false`): giữ một bảng gộp như hiện tại (read-only khi kỳ đã đóng).
- Quyền: quản trị viên hệ thống và đơn vị quản lý khu vực cấu hình; chỉ huy chỉ xem (`can?(:update, ...)`).

### Kế thừa kỳ & chuyển tiếp

- Kỳ `per_station = true` kế thừa cấu hình **từng trạm** (đối tượng nhận, %, hệ số, `pump_contact_point_id`) từ kỳ `per_station = true` trước đó.
- **Chuyển tiếp cũ → per-trạm đầu tiên:** **không** kế thừa allocation qua ranh giới này. Kỳ per-trạm đầu tiên bắt đầu **trống**; admin cấu hình lại từng trạm; trạm chưa cấu hình → cảnh báo. Lý do không kế thừa: (1) cấu hình cũ kỳ-gộp không gắn được vào trạm cụ thể; (2) phần trăm cố định đổi ngữ nghĩa — kỳ gộp là phần trăm của toàn khu vực, kỳ per-trạm là phần trăm của trạm đó — kế thừa con số cũ sẽ sai ý nghĩa.
- `period_service.copy_pump_allocations` cập nhật: chỉ copy khi cả kỳ nguồn lẫn kỳ đích đều `per_station = true`.

## Truy vết chiều test

Tính năng **đã triển khai** (TN2, milestone 1.2.0). Mỗi chiều đã có test thật; cột Trạng thái trỏ tới spec/example chứng minh. Liên quan [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) (chiều "phân bổ bơm nước") và [`V2_HANH_VI_HE_THONG.md`](../../V2_HANH_VI_HE_THONG.md).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-phan-bo-tram-ky-cu` | Kỳ cũ (`per_station = false`): gộp toàn khu vực **không đổi** (regression) | có test — `spec/services/pump_allocation_calculator_spec.rb` (T02 dữ liệu mẫu + nhánh legacy pin `per_station = false` của mutation #376) |
| `CHIEU-phan-bo-tram-tong` | Kỳ mới: hai trạm, recipient riêng; Σ per-trạm = `D` toàn khu vực | có test — `spec/services/pump_allocation_calculator_spec.rb` ("hai trạm có recipient riêng; … tổng = D toàn khu vực") |
| `CHIEU-phan-bo-tram-bon-recipient` | Bốn loại recipient (đơn vị / khối / nhóm / đầu mối sinh hoạt thuộc đơn vị) chia xuống đúng | có test — `spec/services/pump_allocation_calculator_spec.rb` ("recipient khối: chia xuống đầu mối residential … theo quân số") + `spec/models/pump_allocation_spec.rb` (bốn loại recipient hợp lệ, associations đủ bốn khóa ngoại) |
| `CHIEU-phan-bo-tram-rang-buoc` | Ràng buộc per-trạm **đã enforce**: đúng một recipient; Σ fixed% ≤ 100 theo từng trạm; `pump_contact_point` bắt buộc + phải là `water_pump` cùng zone | có test — `spec/models/pump_allocation_spec.rb` (đúng một recipient; Σ fixed% ≤ 100 **theo từng trạm**; `pump_contact_point` bắt buộc + phải là `water_pump` cùng zone) |
| `CHIEU-phan-bo-tram-config-completeness` | Ràng buộc **config-completeness** per-trạm (mục 9.6): còn điện thừa (`remaining > 0`) nhưng không có recipient hệ số trọng số dương (`total_weighted == 0`) → **chặn tính toán** lúc tính (raise `PumpAllocationCalculator::IncompleteStationConfig`, transaction rollback, không persist); cấu hình đầy đủ (Σ% cố định đủ 100% hoặc có recipient hệ số hợp lệ) → tính bình thường | có test — `spec/services/pump_allocation_calculator_spec.rb` (context "config-completeness per-trạm (#401)": thiếu hệ số → chặn; đủ 100% cố định → không chặn; có hệ số hợp lệ → không chặn) + `spec/services/calculation_orchestrator_spec.rb` ("cấu hình trạm chưa đủ → chặn, không persist") + `spec/requests/billing_spec.rb` ("trạm chưa phân bổ hết điện → recalc bị chặn với lỗi, không ghi Calculation") |
| `CHIEU-phan-bo-tram-chua-cau-hinh` | Trạm chưa cấu hình recipient → cảnh báo trên bảng tính tiền | có test — `spec/services/pump_allocation_calculator_spec.rb` ("trạm chưa có recipient → cảnh báo, không chặn", warning `station_without_recipient`) |
| `CHIEU-phan-bo-tram-chuyen-tiep` | Chuyển tiếp: kỳ per-trạm đầu tiên bắt đầu trống; kỳ per-trạm sau kế thừa đúng | có test — `spec/services/period_service_spec.rb` ("KHÔNG kế thừa qua ranh giới cũ→per-trạm: kỳ per-trạm đầu tiên bắt đầu trống" + "kế thừa khi cả nguồn lẫn đích đều per-trạm") |
| `CHIEU-phan-bo-tram-da-xoa` | Recipient đã xóa (Discard) khi xem kỳ cũ → dùng `.with_discarded` đúng chỗ (mục 7 hành vi hệ thống) | có test — `spec/services/pump_allocation_calculator_spec.rb` ("kỳ đã đóng (per-trạm): vẫn tính cho đầu mối residential đã discard"; recipient của trạm bị Discard trên kỳ per-trạm đã đóng vẫn được tính); nhánh legacy giữ example "kỳ đã đóng: vẫn tính phân bổ của đầu mối đã discard" |
| `CHIEU-phan-bo-tram-vai-tro` | Sáu vai trò + đơn vị quản lý khu vực cấu hình được, chỉ huy chỉ xem | có test — `spec/requests/pump_allocations_spec.rb` + `spec/system/pump_allocations_spec.rb` + `spec/abilities/ability_spec.rb` (UA-ZM/CMD-ZM CRUD/đọc khu vực, CMD chỉ xem, zone-manager đọc Block/Group); độ phủ truy cập sáu vai trò ép qua guardrail `role_access_matrix` (ADR-056) |
| `CHIEU-phan-bo-tram-nhom` | Index nhóm theo trạm: một thẻ/trạm bơm (kể cả trạm rỗng kèm cảnh báo); kỳ cũ gộp một thẻ "Gộp toàn khu vực (kỳ cũ)"; link "Thêm đối tượng vào trạm này" mang theo id trạm; mỗi đối tượng nhận đặt ở **cột cấp riêng** (Đơn vị / Khối / Nhóm / Đầu mối, "—" nếu trống) như trang Đầu mối; hàng "Tổng" chỉ gồm nhãn + Σ% cố định (không "= 100%", không số đối tượng hệ số); ghi chú cách chia điện một lần ở đầu trang | có test — `spec/system/pump_allocations_spec.rb` ("Pump allocations grouped by station": thẻ/trạm, trạm rỗng cảnh báo, link mang id) + `spec/requests/pump_allocations_spec.rb` (E4 A/B/B2/B3 đặt đúng cột cấp; F hàng Tổng chỉ nhãn + Σ% cố định) |
| `CHIEU-tram-phan-tram-khu-vuc` | % của khu vực mỗi trạm = `D_trạm / D_khu_vực` (D = Σ sử dụng + tổn hao công tơ bơm), suy từ **chỉ số hiện tại** (không cần đã tính toán); hiện cạnh tên trạm trên trang Phân bổ bơm nước và dưới đầu cột trạm trên bảng tính tiền; `D_khu_vực = 0` → "—" không chia cho 0; Σ phần trăm = 100% | có test — `spec/requests/pump_allocations_spec.rb` ("% của khu vực mỗi trạm": tiêu đề thẻ "chiếm 65%…", D_khu_vực=0 → "—") + `spec/requests/billing_spec.rb` ("đầu mỗi cột trạm hiện % của khu vực") |
| `CHIEU-phan-bo-tram-khong-chong-cheo` | Ràng buộc không chồng chéo + không chia cấp: recipient chồng phân cấp (đơn vị + khối bên trong) → chặn; recipient cùng đơn vị ở 2 trạm khác nhau → chặn | có test — `spec/models/pump_allocation_spec.rb` ("ràng buộc không chồng chéo": đơn vị+khối chặn, đầu mối+khối chặn, xuyên trạm chặn, không chồng cho phép; "ràng buộc không chia cấp": cùng đơn vị khác trạm chặn, khác đơn vị cùng trạm cho phép, đầu mối khu vực exempt) |
| `CHIEU-phan-bo-tram-recipient-rong` | Recipient kiểu đơn vị/khối/nhóm có 0 đầu mối sinh hoạt → chặn khi cấu hình; graceful khi tính toán (bỏ qua + cảnh báo) | có test — `spec/models/pump_allocation_spec.rb` ("ràng buộc đối tượng nhận rỗng": đơn vị/khối/nhóm rỗng chặn, đầu mối trực tiếp exempt, có đầu mối cho phép) + `spec/services/pump_allocation_calculator_spec.rb` ("đối tượng nhận rỗng: bỏ qua phân phối + cảnh báo") |

## Giới hạn

- Cách phân bổ (fixed% hoặc hệ số × quân số) **không đổi** — chỉ đổi phạm vi (toàn khu vực → từng trạm) và thêm loại recipient.
- Tổn hao vẫn tính chung toàn khu vực; chỉ gán tổn hao công tơ về trạm tương ứng.
- Một đầu mối `water_pump` = một trạm (không gộp nhiều đầu mối thành một trạm trong phạm vi này).

## Truy vết

- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) `NV-phan-bo-bom-theo-tram`.
- Issue: [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319).
- Spec anh em milestone 1.2.0: [cột Khác hệ số đơn vị](2026-06-11-cot-khac-he-so-don-vi-design.md), [hiển thị chi tiết tổn hao](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md).

## Truy vết demo

Tính năng `customer_facing: true` → khai demo theo ADR-052 (guardrail `check-demo-deliverable.sh`):

- `spec/demo/pump_allocation_per_station_demo_spec.rb`

## Lịch sử thay đổi

### 0.6.0 (2026-06-20)

- Implement ràng buộc **đối tượng nhận rỗng** (recipient-rỗng) — model validation `validate_recipient_has_residential_contact_points` chặn đơn vị/khối/nhóm không có đầu mối sinh hoạt nào bên trong khi cấu hình (§27.5). Calculator cảnh báo `empty_recipient` khi tính toán gặp đối tượng nhận mất đầu mối (đầu mối bị xóa sau cấu hình) — bỏ qua phân phối + cảnh báo. Lật `CHIEU-phan-bo-tram-recipient-rong` từ DEFERRED sang có test.

### 0.5.0 (2026-06-20)

- Implement ràng buộc **không chồng chéo** (non-overlap) và **không chia cấp** (no-split) trong model `PumpAllocation` — validate khi cấu hình kỳ per-trạm. Hai validation mới: `validate_no_overlap` (tập đầu mối sinh hoạt phân giải từ mỗi đối tượng nhận phải không giao nhau, xuyên trạm) và `validate_no_split` (đối tượng thuộc cùng đơn vị phải nằm cùng trạm). Lật `CHIEU-phan-bo-tram-khong-chong-cheo` từ DEFERRED sang có test.

### 0.4.0 (2026-06-20)

- Merge nhánh triển khai TN2 (PR #396, v0.3.6) với nhánh ràng buộc phân cấp (develop v0.3.1, PR #407). Tích hợp bảng chiều test: giữ trạng thái "có test" của 12 hàng triển khai + thêm 2 hàng DEFERRED từ develop (`CHIEU-phan-bo-tram-khong-chong-cheo`, `CHIEU-phan-bo-tram-recipient-rong`). Không thay đổi code hay nội dung thiết kế — chỉ hợp nhất hai nhánh song song.

### 0.3.6 (2026-06-17)

- Dễ đọc cho người dùng quân sự ít quen máy tính: dựng lại bảng nhóm-theo-trạm (trang Phân bổ bơm nước) và bảng chi tiết theo trạm (trang Bảng tính tiền). Đối tượng nhận giờ đặt ở **cột cấp riêng** (Đơn vị / Khối / Nhóm / Đầu mối, "—" nếu trống) như trang Đầu mối; cột "Hệ số" giữ nguyên giá trị (không thay bằng chữ); hàng "Tổng" chỉ còn nhãn + Σ% cố định (bỏ "= 100%" và số đối tượng hệ số); thêm ghi chú một lần ở đầu trang giải thích cách chia điện. Cập nhật hàng `CHIEU-phan-bo-tram-nhom`.
- Thêm chỉ báo **"% của khu vực" mỗi trạm** = `D_trạm / D_khu_vực` (D = Σ sử dụng + tổn hao công tơ bơm), suy từ chỉ số hiện tại (không cần đã tính toán). Trang Phân bổ bơm nước: cạnh tên trạm ("Trạm bơm Tây — chiếm 65% điện bơm của khu vực"). Bảng tính tiền: dưới đầu cột mỗi trạm ("65% khu vực"). `D_khu_vực = 0` → "—" (không chia cho 0); Σ phần trăm = 100%. Thêm hàng `CHIEU-tram-phan-tram-khu-vuc`. Chỉ thêm view + controller + i18n + test (calculator/model/migration/seed không đổi).

### 0.3.5 (2026-06-16)

- #401: enforce ràng buộc config-completeness per-trạm trong code. `PumpAllocationCalculator` raise `IncompleteStationConfig` khi một trạm (hoặc nhánh gộp toàn khu vực) còn điện thừa nhưng không có recipient hệ số trọng số dương (`remaining > 0 && total_weighted == 0`) — trước đây điện bị bỏ rơi âm thầm khiến bảng tính tiền nói dối (tổng trạm < điện thật của trạm). `CalculationOrchestrator` để lỗi nổi lên → transaction rollback (không persist); `BillingController#recalculate` rescue và hiển thị lỗi tiếng Việt. Lật hàng `CHIEU-phan-bo-tram-config-completeness` từ `DEFERRED #401` sang **có test** (calculator + orchestrator + request). i18n key mới `services.pump_allocation_calculator.errors.incomplete_station_config`. Đính chính câu trợ giúp % cố định trong form (zone-wide cũ → per-trạm).

### 0.3.4 (2026-06-16)

- ADR-026: ghi rõ ánh xạ 6 loại đối tượng nhận → 4 khóa ngoại (audit phát hiện thiếu giải thích).

### 0.3.3 (2026-06-16)

- UI: index Phân bổ bơm nước **nhóm theo trạm bơm** (một thẻ/trạm thay vì bảng phẳng) theo thiết kế "một bảng cho mỗi trạm bơm". Mỗi thẻ có header (tên trạm + số đối tượng + Σ% cố định + số đối tượng hệ số) và nút "Thêm đối tượng vào trạm này" (prefill trạm qua `new?pump_contact_point_id=`); trạm chưa có đối tượng hiện thẻ rỗng kèm cảnh báo; kỳ cũ gộp một thẻ "Gộp toàn khu vực (kỳ cũ)". Bỏ pagy/per_page + sortable header (divergence có chủ đích so với `_list_toolbar`), giữ tìm kiếm (thêm tên trạm) + bộ lọc khu vực (SA). Thêm hàng `CHIEU-phan-bo-tram-nhom`.

### 0.3.2 (2026-06-16)

- Đính chính truy vết chiều test — 2 ràng buộc config-completeness ("phải có recipient hệ số nếu Σ% cố định < 100%" và "Σ(quân số × hệ số) > 0") **chưa enforce** trong code, chuyển sang hàng `CHIEU-phan-bo-tram-config-completeness` `DEFERRED #401` (audit phát hiện hàng `CHIEU-phan-bo-tram-rang-buoc` trước đó khai man là đã test). Thu hẹp `CHIEU-phan-bo-tram-rang-buoc` chỉ còn ba ràng buộc thực sự được test (đúng một recipient; Σ fixed% ≤ 100 theo từng trạm; `pump_contact_point` bắt buộc + phải là `water_pump` cùng zone).

### 0.3.1 (2026-06-18)

- Kế thừa kỳ & chuyển tiếp: thêm lý do (2) phần trăm cố định đổi ngữ nghĩa (kỳ gộp = % khu vực, kỳ per-trạm = % trạm). Khớp nghiệp vụ v2.17.1.

### 0.3.1 (2026-06-14)

- Bổ sung test per-trạm cho recipient đã discard trên kỳ đã đóng → lật `CHIEU-phan-bo-tram-da-xoa` sang có-test (đóng nốt khoảng trống của 0.3.0).

### 0.3.0 (2026-06-18)

- Ràng buộc data model: thêm "không chồng chéo" (tập đầu mối sinh hoạt phân giải từ mỗi recipient phải không giao nhau, xuyên trạm) và "không chia cấp" (toàn bộ đơn vị thuộc một trạm duy nhất). Thêm recipient kiểu đơn vị/khối/nhóm phải có ít nhất 1 đầu mối sinh hoạt.
- Tính toán: thêm cảnh báo khi recipient có 0 đầu mối sinh hoạt (bỏ qua phân phối).
- Chiều test: thêm `CHIEU-phan-bo-tram-khong-chong-cheo` và `CHIEU-phan-bo-tram-recipient-rong`.
- Khớp nghiệp vụ v2.17.0.

### 0.3.0 (2026-06-14)

- Triển khai TN2: calculator per-trạm, recipient bốn loại (đơn vị/khối/nhóm/đầu mối), cờ `Period#pump_allocation_per_station`, kế thừa kỳ chỉ per-trạm→per-trạm, UI chọn trạm + bốn loại recipient, demo ADR-059. Khai `customer_facing: true` + `## Truy vết demo` (ADR-052); lật 8 `CHIEU-phan-bo-tram-*` từ DEFERRED sang có-test (riêng `CHIEU-phan-bo-tram-da-xoa` còn DEFERRED #319 — chưa có example per-trạm cho recipient discard trên kỳ per-trạm đã đóng).

### 0.2.1 (2026-06-13)

- Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.

### 0.2.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>`, mọi hàng `DEFERRED #319` (chưa triển khai) — ADR-030, Issue #329. Khi build TN2: đổi trạng thái từng hàng sang "có test" + gắn anchor vào test.

### 0.1.0 (2026-06-11)

- Bản đầu: ADR-026 + thiết kế triển khai + chiều test cho phân bổ bơm nước theo từng trạm bơm và bốn loại đối tượng nhận.
