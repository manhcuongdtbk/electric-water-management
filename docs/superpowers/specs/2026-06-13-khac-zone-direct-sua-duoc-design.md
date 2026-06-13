---
title: Sửa khoản trừ "Khác" của đầu mối zone-direct theo ngữ cảnh khu vực (bug #328)
version: 0.1.0
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Sửa khoản trừ "Khác" của đầu mối zone-direct theo ngữ cảnh khu vực

Bản vá bug [`#328`](https://github.com/manhcuongdtbk/electric-water-management/issues/328) (mức **Thường**, không hotfix). Khoản trừ "Khác" của đầu mối sinh hoạt **thuộc khu vực trực tiếp** (zone-direct) không sửa được qua giao diện khi khu vực **không có đơn vị quản lý** (`manager_unit_id` null) — nhưng giá trị đó vẫn đi vào billing. Bản vá tách editability khỏi `manager_unit_id`, cho quản trị viên hệ thống sửa "Khác" theo **ngữ cảnh khu vực**.

- **Nguồn nghiệp vụ:** khoản trừ "Khác" — [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) mục 10.2; đầu mối thuộc khu vực trực tiếp — [`V2_HANH_VI_HE_THONG.md`](../../V2_HANH_VI_HE_THONG.md) (Chiều "Thuộc về": đơn vị / khu vực trực tiếp).
- **Truy vết:** GitHub Issue [`#328`](https://github.com/manhcuongdtbk/electric-water-management/issues/328). Lỗi **pre-existing**, phát hiện khi review TN1 (PR [`#327`](https://github.com/manhcuongdtbk/electric-water-management/pull/327), milestone 1.2.0); không do TN1.
- **Liên quan:** PR [`#330`](https://github.com/manhcuongdtbk/electric-water-management/pull/330) đã vá *triệu chứng crash* (nhánh re-render của quản trị viên hệ thống thiếu `@available_zones`). Issue này là gap **editability** còn lại, chưa làm trong #330.

## Bối cảnh

### Triệu chứng và cách tái hiện

Đạt tới trạng thái "khu vực có đầu mối sinh hoạt zone-direct nhưng `manager_unit_id` = null" theo một trong hai cách:

1. Tạo khu vực → tạo đầu mối sinh hoạt zone-direct **trước khi** khu vực có đơn vị nào (model không chặn — chỉ cần khu vực + kỳ mở); **hoặc**
2. **Gỡ/đổi đơn vị quản lý** (luồng `reassign_manager`) khi khu vực đang có đầu mối zone-direct; hoặc xóa đơn vị đang là manager (`Unit#clear_zone_manager_if_self` set `manager_unit_id` null).

Sau đó: đăng nhập quản trị viên hệ thống → **Cấu hình đơn vị** → không trang đơn vị nào surface được "Khác" của các đầu mối zone-direct đó → khoản trừ **kẹt** ở giá trị hiện tại.

### Nguyên nhân gốc (trục editability ≠ trục billing)

- **Editability** khóa theo `manager_unit_id`: `UnitConfigController#scope_zone_other_deductions` dùng `Zone.kept.where(manager_unit_id: @unit.id)` → chỉ trang Cấu hình của **đơn vị quản lý** mới liệt kê đầu mối zone-direct (Phần 3 của `show.html.erb`). Khi khu vực không có manager, không `@unit` nào match → scope rỗng cho **mọi** đơn vị.
- **Billing** lại quy theo **khu vực**, không theo manager: `ContactPoint.in_zone` (`where(zone_id: zone.id).or(...)`) và `SummaryCalculator#preload_other_deductions` dùng `OtherDeduction` của đầu mối **bất kể** UI có sửa được hay không.
- Hai trục lệch nhau ⇒ "Khác" ≠ 0 bị kẹt vẫn ảnh hưởng bảng tính tiền của đầu mối đó (mục "Có đụng tiền" của issue). Mặc định "Khác" = 0 nên trường hợp phổ biến vô hại, nhưng sai lệch tiền là có thật khi đã set rồi gỡ manager.
- **Ai sửa được trong trạng thái orphan:** chỉ quản trị viên hệ thống. `Ability#unit_admin_abilities` cấp quyền `OtherDeduction` mức khu vực **chỉ qua** `managed_zone_ids` (rỗng khi không có manager), nên không quản trị viên đơn vị nào với tới.

### Mã nguồn liên quan hiện tại

- Controller: [`app/controllers/unit_config_controller.rb`](../../../app/controllers/unit_config_controller.rb) — `#show`, `#update`, `scope_other_deductions`, `scope_zone_other_deductions`, `resolve_unit_for_update`, `set_sa_filter_dropdowns`.
- View: [`app/views/unit_config/show.html.erb`](../../../app/views/unit_config/show.html.erb) — Phần 1 (`unit_public_rate`), Phần 2 (CP đơn vị), Phần 3 (CP khu vực); partial `_other_deductions_table.html.erb`.
- Quyền: [`app/models/ability.rb`](../../../app/models/ability.rb) — quản trị viên hệ thống `can :manage, OtherDeduction`; quản trị viên đơn vị/chỉ huy chỉ qua `managed_zone_ids`.
- Luồng manager: [`app/controllers/zones_controller.rb`](../../../app/controllers/zones_controller.rb) `#reassign_manager`; [`app/models/unit.rb`](../../../app/models/unit.rb) `assign_as_zone_manager` (chỉ đơn vị đầu tiên), `clear_zone_manager_if_self`.

## ADR-034: Tách editability "Khác" của đầu mối zone-direct khỏi `manager_unit_id`

- **Trạng thái:** Accepted · 2026-06-13
- **Bối cảnh:** Editability của khoản trừ "Khác" cho đầu mối sinh hoạt zone-direct khóa theo `manager_unit_id`, trong khi billing quy theo khu vực. Tồn tại trạng thái hợp lệ khu vực không có manager (gỡ/đổi manager là tính năng thật; xóa đơn vị quản lý nulls manager; tạo CP zone-direct trước khi có đơn vị). Trong trạng thái đó "Khác" kẹt nhưng vẫn vào billing, và chỉ quản trị viên hệ thống mới có quyền sửa.
- **Quyết định:** Sửa "Khác" của đầu mối zone-direct theo **ngữ cảnh khu vực**, độc lập `manager_unit_id`. Trên trang Cấu hình đơn vị, khi quản trị viên hệ thống chọn một **khu vực** mà **không** chọn đơn vị (`@zone` có, `@unit` nil), liệt kê các đầu mối zone-direct sinh hoạt của khu vực đó để sửa "Khác" — **luôn** hiện khi chọn khu vực, bất kể khu vực có manager hay không. Đường manager-unit hiện có (Phần 3 trên trang đơn vị quản lý) **giữ nguyên** để quản trị viên đơn vị non-SA tiếp tục sửa. Không thêm hard-block khi gỡ/đổi manager.
- **Lý do:** Khớp đúng trục billing (đã quy theo khu vực) → một mô hình quyền sở hữu nhất quán "đầu mối zone-direct sửa ở ngữ cảnh khu vực". Đảm bảo bất biến mạnh hơn cảnh báo: "Khác" **không bao giờ** kẹt ở mọi trạng thái manager. Tái dùng dropdown khu vực/đơn vị sẵn có của trang; đồng thời làm trang "chọn-khu-vực" không còn trống (xử lý luôn UX note optional của issue). Vì (ii) đã đảm bảo sửa-được nên cảnh báo mềm khi gỡ manager là thừa.
- **Tradeoff:** (+) Sửa tận gốc (data-integrity guarantee), không cần ràng buộc mới trên luồng manager, không thêm bảng/cột, tái dùng UI sẵn có. (−) Khi khu vực có manager, quản trị viên hệ thống có hai đường sửa cùng dữ liệu (trang đơn vị quản lý + trang khu vực) — chấp nhận được, cùng `OtherDeduction`, optimistic lock (`lock_version`) bảo vệ; `#update` cần một nhánh zone-context riêng (không `@unit`).
- **Phương án đã loại:**
  - *(i) Giữ bất biến có-manager (chặn/cảnh báo gỡ-đổi manager + chặn tạo CP zone-direct khi chưa có đơn vị):* vá bằng ràng buộc thay vì sửa gốc; thêm friction cho thao tác hợp lệ; vẫn phải xử lý data orphan đã tồn tại.
  - *Đổi billing sang quy theo manager:* đảo ngược mô hình đang chạy, phạm vi rộng, rủi ro sai tiền — ngược hướng.
- **Điều kiện xem lại:** nếu sau này quản trị viên đơn vị non-SA cần sửa "Khác" zone-direct khi khu vực không có manager (hiện không vai trò nào với tới) → cân nhắc mở quyền theo khu vực ở `Ability`.

## Thiết kế triển khai

### Controller — `unit_config_controller.rb`

- **Tổng quát hóa nguồn `zone_ids`** cho scope zone-direct (tách helper `zone_other_deduction_zone_ids`):
  - `@unit` present → `Zone.kept.where(manager_unit_id: @unit.id).pluck(:id)` (hành vi cũ — phục vụ non-SA manager + quản trị viên hệ thống đang xem một đơn vị).
  - `@unit` nil & `@zone` present & `current_user.system_admin?` → `[@zone.id]`.
  - còn lại → rỗng.
- `scope_zone_other_deductions` đổi guard từ `unless @period && @unit` thành `unless @period`, lấy `zone_ids` từ helper, giữ nguyên filter `unit_id: nil, contact_point_type: "residential"` + `accessible_by(current_ability)` + `order("contact_points.name")`.
- **`#show`:** đã `resolve_zone_unit_filter` cho quản trị viên hệ thống; khi chọn khu-vực-không-đơn-vị thì `@unit` nil, `@unit_config` nil (find_or_create trả nil), `scope_zone_other_deductions` trả ODs zone-direct của `@zone`. Không đổi luồng non-SA.
- **`#update`:** thêm nhánh zone-context — khi quản trị viên hệ thống gửi `zone_id` mà không có `unit_id` (đầu vào hợp lệ duy nhất cho zone-context), resolve `@zone`, để `@unit` nil, **bỏ qua** cập nhật `unit_config`, scope ODs sửa được = `scope_zone_other_deductions`. Vẫn `authorize!(:update, od)` từng OD, giữ `ActiveRecord::Base.transaction`, optimistic lock và nhánh re-render lỗi (set lại `@zone` + `set_sa_filter_dropdowns`). `require_open_period` (before_action) đã guard.
- `resolve_unit_for_update`/`resolve_zone_for_update`: tách logic resolve `@zone` cho quản trị viên hệ thống ở zone-context (tôn trọng `reopened_old_period?` như đường unit nếu cần — xem Giới hạn).

### View — `show.html.erb`

- Điều kiện render form: `(@unit || @zone) && current_period` (hiện chỉ `@unit`).
- Hidden field: `unit_id` khi có `@unit`; ngược lại `zone_id` (cho nhánh zone-context của `#update`).
- Phần 1 (`unit_public_rate`) và Phần 2 (CP đơn vị) chỉ render khi có `@unit_config`/`@unit` (đã vậy). Phần 3 (CP khu vực) render khi `@zone_other_deductions.any?` (đã vậy) — nay phủ luôn case zone-context.
- `can_edit` cho zone-context: `!no_open_period? && can?(:update, OtherDeduction)` (chỉ quản trị viên hệ thống với tới). Reuse trong `_other_deductions_table` (disable input + ẩn nút Lưu khi không sửa được — guard chỉ huy/kỳ đóng).
- **Empty-state hint:** khi quản trị viên hệ thống đã chọn khu vực mà không có gì hiện (không `@unit`, `@zone_other_deductions` rỗng) → hiện gợi ý "Chọn đơn vị để xem cấu hình đơn vị, hoặc khu vực này chưa có đầu mối thuộc khu vực." (xử lý UX note optional của issue).

### i18n (ADR-032 — guardrail i18n view)

- Chuỗi người-dùng mới (empty-state hint, heading nếu thêm) đi qua `config/locales/vi.yml` (tiếng Việt 100%), **không** hard-code trong view. View hiện có chuỗi cứng theo diện grandfather; chuỗi **mới** tuân guardrail. Verify bằng script i18n-view trước khi mở PR.

### Glossary — `docs/THUAT_NGU.md`

- Bổ sung định nghĩa **"probe"** (thăm dò) vào §3 (Gloss khái niệm): đoạn mã/kiểm thử chạy thử để xác minh hành vi rồi rollback (không để lại dữ liệu) — theo yêu cầu ghi chú thuật ngữ trong comment issue #328 và nguyên tắc glossary ADR-023/024 (định nghĩa cả khi từ chỉ xuất hiện trong bản ghi). Gộp vào PR này, không tách rời. Bump version + `## Lịch sử thay đổi` của THUAT_NGU (ADR-002).

## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030). Liên quan Chiều 6 (Thuộc về: đơn vị / khu vực trực tiếp), Chiều 2 (Vai trò), Chiều 3 (Trang và thao tác).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-khac-zone-direct-sua-duoc` | Quản trị viên hệ thống chọn khu vực (không chọn đơn vị) → sửa "Khác" của đầu mối zone-direct được và lưu đúng (BigDecimal, không float); drive thẳng action `#update` với `zone_id` không `unit_id` | có test |
| `CHIEU-khac-zone-direct-orphan` | Khu vực `manager_unit_id` null vẫn surface và sửa được "Khác" zone-direct (regression trực tiếp #328) | có test |
| `CHIEU-khac-zone-direct-vai-tro` | Sáu vai trò: chỉ quản trị viên hệ thống vào được ngữ cảnh khu vực; quản trị viên đơn vị (manager) vẫn sửa qua trang đơn vị; chỉ huy chỉ xem (input disabled, không nút Lưu) | có test |
| `CHIEU-khac-zone-direct-trang-trong` | Chọn khu vực không có đầu mối zone-direct (và không chọn đơn vị) → hiện gợi ý empty-state, không lỗi | có test |

## Giới hạn / ngoài scope (cố ý)

- **Không** thêm hard-block hay cảnh báo mềm khi gỡ/đổi/xóa manager (hướng (i)) — (ii) đã đảm bảo sửa-được.
- **Không** đụng billing/`SummaryCalculator`, `ContactPoint.in_zone`, hay cách quy đầu mối zone-direct về khu vực.
- **Không** mở quyền cho non-SA sửa "Khác" zone-direct khi khu vực không có manager (giữ nguyên `Ability`; chỉ quản trị viên hệ thống với tới ở orphan — đúng vai trò admin dự phòng).
- **Không** thêm khả năng sửa cho kỳ đã đóng: zone-context tôn trọng `require_open_period` y như đường unit; xem kỳ cũ chỉ hiển thị (không trong scope sửa).
- **Không** làm TN2 (phân bổ bơm theo trạm, ADR-026); **không** đụng PR #330 (đã merge).

## Truy vết

- Issue: [`#328`](https://github.com/manhcuongdtbk/electric-water-management/issues/328).
- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) mục 10.2 (khoản trừ "Khác"); [`V2_HANH_VI_HE_THONG.md`](../../V2_HANH_VI_HE_THONG.md) (Thuộc về: đơn vị / khu vực trực tiếp).
- Spec anh em (cùng vùng "Khác"/Cấu hình đơn vị): [Cột "Khác" hệ số đơn vị](2026-06-11-cot-khac-he-so-don-vi-design.md).

## Lịch sử thay đổi

### 0.1.0 (2026-06-13)

- Bản đầu: ADR-034 + thiết kế triển khai (controller/view/i18n/glossary) + bảng Truy vết chiều test cho bản vá editability "Khác" của đầu mối zone-direct (#328).
