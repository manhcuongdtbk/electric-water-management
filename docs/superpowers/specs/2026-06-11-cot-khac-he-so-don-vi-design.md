---
title: Cột "Khác" kiểu hệ số tổng đơn vị (cách nhập thứ ba cho khoản trừ Khác)
version: 0.2.4
date: 2026-06-17
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Cột "Khác" kiểu hệ số tổng đơn vị

Tính năng 1 của milestone **1.2.0**. Thêm **cách nhập thứ ba** cho khoản trừ "Khác" (mục 10.2 nghiệp vụ): khoản trừ = `hệ số × (tổng quân số đơn vị − quân số đầu mối đó)`. Dùng cho bếp ăn chung: mỗi người trong đơn vị góp một phần tiêu chuẩn, bếp nhận lại tổng.

- **Nguồn nghiệp vụ:** [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) anchor `NV-cot-khac-he-so-don-vi` (fold từ `V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` mục 2).
- **Truy vết:** GitHub Issue [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319), milestone `1.2.0`.
- **Trạng thái khách:** đã xác nhận 31/05/2026 (kèm điều chỉnh loại trừ quân số đầu mối đang nhập).

## Bối cảnh

Khoản trừ "Khác" (`OtherDeduction`, một trong 5 khoản trừ ở mục 10.2 nghiệp vụ) hiện có **hai** cách nhập, lưu ở enum `other_type`:

- `fixed` — dùng đúng số cụ thể đã nhập.
- `coefficient` — `other_value × quân số của chính đầu mối đó`.

Bếp ăn chung phục vụ cả đơn vị. Nghiệp vụ muốn: mỗi người trong đơn vị góp một phần (ví dụ 2 kW) vào bếp, và **bếp nhận lại tổng** phần đã góp. Với hai cách hiện có, phần "bếp nhận lại tổng" phải nhập thủ công một số cụ thể âm (ví dụ −132) và **phải tính lại tay mỗi khi quân số đổi**. Cần một cách nhập tự tính lại theo quân số đơn vị của kỳ.

Mã nguồn liên quan hiện tại:

- Model & enum: `app/models/other_deduction.rb` (`enum :other_type, { fixed:, coefficient: }`, prefix `:other`).
- Tính toán: `app/services/summary_calculator.rb` — `compute_other_deduction` (nhánh `other_coefficient?` nhân với `total_personnel` của đầu mối đang xét).
- Kế thừa kỳ: `app/services/period_service.rb` — `snapshot_residential_contact_points` (kế thừa `other_type` + `other_value`).
- UI nhập: `app/views/unit_config/_other_deductions_table.html.erb` (select hai option) + `app/controllers/unit_config_controller.rb`.

## ADR-025: Cách nhập thứ ba `unit_coefficient` cho khoản trừ "Khác"

- **Trạng thái:** Accepted · 2026-06-11
- **Bối cảnh:** Cần một cách nhập khoản trừ "Khác" tự tính theo quân số toàn đơn vị (trừ chính đầu mối), để mô hình hóa "mỗi người góp một phần, bếp nhận lại tổng" mà không phải sửa tay khi quân số đổi. Đã có sẵn enum `other_type` với hai value và đường tính trong `SummaryCalculator`.
- **Quyết định:** Thêm value thứ ba `unit_coefficient` vào enum `OtherDeduction#other_type`. Khoản trừ = `other_value × (Σ quân số residential của đơn vị − quân số đầu mối đang xét)`. Tổng quân số đơn vị tính **live** theo `PersonnelEntry` của kỳ (chỉ đầu mối loại `residential`, **không** gồm ngoài biên chế / công cộng), trừ đi quân số của chính đầu mối đang xét. Cho phép `other_value` âm hoặc dương. Chỉ hợp lệ cho đầu mối **thuộc đơn vị**; đầu mối thuộc khu vực trực tiếp không dùng (validate chặn ở model, ẩn option ở UI). Không thêm bảng/cột; vì `other_type` là **PostgreSQL native enum** (`other_deduction_type`) nên cần một migration `ALTER TYPE ... ADD VALUE` để bổ sung giá trị.
- **Lý do:** Tái dùng đúng cấu trúc sẵn có (enum + một nhánh tính), thay đổi nhỏ nhất, kế thừa kỳ tự hoạt động (đã kế thừa `other_type` + `other_value`). Tính live khớp yêu cầu "quân số đổi thì tự tính lại".
- **Tradeoff:** (+) Chỉ một migration `ALTER TYPE ADD VALUE` (không thêm bảng/cột), ít bề mặt lỗi, nhất quán với hai cách cũ. (−) `SummaryCalculator` cần biết tổng quân số đơn vị (đang xử lý theo từng đầu mối) → thêm một bước gom quân số theo đơn vị cho kỳ.
- **Phương án đã loại:**
  - *Một bảng cấu hình bếp riêng:* phức tạp, thêm khái niệm mới ngoài thiết kế, không cần thiết khi enum đã mô hình hóa đủ.
  - *Tính số cụ thể tự động rồi lưu vào `fixed`:* phải tái tính và ghi đè mỗi lần quân số đổi → đúng cái đang muốn tránh.
- **Điều kiện xem lại:** Nếu sau này cần loại trừ theo tập con khác (không phải "toàn đơn vị trừ chính nó"), hoặc cần nhiều "quỹ dùng chung" song song trong một đơn vị.

## Thiết kế triển khai

> Triển khai ở session/PR sau (theo phạm vi groundwork). Phần này mô tả đích để plan thực thi bám theo.

### Data model

- `OtherDeduction#other_type`: thêm value `unit_coefficient: "unit_coefficient"` vào enum (cùng prefix `:other` → `other_unit_coefficient?`). Không đổi cột `other_value`.
- `other_type` là **PostgreSQL native enum** (`other_deduction_type`, không phải cột chuỗi) → cần migration `ALTER TYPE other_deduction_type ADD VALUE 'unit_coefficient'` (dùng `disable_ddl_transaction!` vì `ADD VALUE` không chạy trong transaction). Không thêm bảng/cột. Bản ghi cũ giữ nguyên `fixed`/`coefficient`.

### Tính toán (`SummaryCalculator`)

- Trước vòng tính theo đầu mối: gom **tổng quân số residential theo đơn vị** cho kỳ (một truy vấn `PersonnelEntry.group` theo `unit_id`, lọc đầu mối `residential`). Tái dùng được pattern cache quân số ở `PumpAllocationCalculator#build_personnel_cache`.
- `compute_other_deduction` thêm nhánh `other_unit_coefficient?`:
  `other_value × (unit_total_residential − cp_personnel)`, với `unit_total_residential` = tổng quân số residential của đơn vị chứa đầu mối, `cp_personnel` = quân số đầu mối đang xét.
- Đầu mối không thuộc đơn vị (zone-direct): nhánh này không bao giờ chạy (đã bị validate/UI chặn từ trước); nếu gặp dữ liệu bất thường → khoản trừ = 0 (an toàn).
- Không làm tròn giữa chừng (BigDecimal, theo mục 26 nghiệp vụ).

### Validation (`OtherDeduction` model)

- `other_type == "unit_coefficient"` chỉ hợp lệ khi `contact_point.unit_id` có giá trị (đầu mối thuộc đơn vị). Ngược lại thêm lỗi tiếng Việt.
- Cho phép `other_value` âm và dương (đã không giới hạn dấu).

### UI (`unit_config`)

- `_other_deductions_table.html.erb`: thêm option "Theo hệ số (đơn vị)" vào select `other_type`.
- Phần đầu mối **thuộc đơn vị**: hiện đủ ba option. Phần đầu mối **thuộc khu vực** (`@zone_other_deductions`): chỉ hiện hai option cũ (ẩn `unit_coefficient`).
- Stimulus (nếu thêm): có thể hiển thị xem trước giá trị tính được; không bắt buộc cho groundwork.

### Kế thừa kỳ

- Không đổi: `snapshot_residential_contact_points` đã kế thừa `other_type` + `other_value`. Value mới kế thừa tự nhiên; tổng quân số kỳ mới tự tính lại.

## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-khac-don-vi-dau` | `unit_coefficient` với `other_value` dương (đầu mối bị trừ) và âm (đầu mối được cộng ngược, ví dụ bếp) | có test |
| `CHIEU-khac-don-vi-vi-du` | Khớp ví dụ số liệu nghiệp vụ (đơn vị, bếp, `other_value` âm → giá trị đúng) | có test |
| `CHIEU-khac-don-vi-tu-tinh-lai` | Quân số đổi giữa kỳ → khoản trừ tự tính lại (không sửa tay) | có test |
| `CHIEU-khac-don-vi-mot-dau-moi` | Đơn vị chỉ có một đầu mối (tổng − chính nó = 0) → khoản trừ = 0 | có test |
| `CHIEU-khac-don-vi-zone-direct` | Đầu mối zone-direct chọn `unit_coefficient` → validate chặn (request) + option bị ẩn (UI) | có test |
| `CHIEU-khac-don-vi-ke-thua` | Kế thừa sang kỳ mới giữ `unit_coefficient` + hệ số, tính lại theo quân số kỳ mới | có test |
| `CHIEU-khac-don-vi-vai-tro` | Sáu vai trò: ai sửa được cột Khác giữ nguyên (quản trị viên đơn vị; chỉ huy chỉ xem) | có test |
| `CHIEU-khac-don-vi-loai-tru-cc-nb` | Defensive: residential-only filter loại public CP khỏi tổng quân số đơn vị ngay cả khi có personnel bất thường (CC không có quân số theo nghiệp vụ; NE không thuộc đơn vị — model chặn) | có test |

## Giới hạn

- Không đụng cơ chế bốn khoản trừ còn lại.
- "Tổng quân số đơn vị" cố ý **chỉ** gồm đầu mối residential — khớp đúng chữ "đầu mối sinh hoạt" trong nghiệp vụ và ví dụ số liệu khách đã duyệt.

## Truy vết

- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) `NV-cot-khac-he-so-don-vi`.
- Issue: [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319).
- Spec anh em milestone 1.2.0: [phân bổ bơm theo trạm](2026-06-11-phan-bo-bom-theo-tram-design.md), [hiển thị chi tiết tổn hao](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md).

## Lịch sử thay đổi

### 0.2.4 (2026-06-17)

- Sửa lại mô tả chiều test `CHIEU-khac-don-vi-loai-tru-cc-nb`: đánh dấu là **defensive** test — đầu mối công cộng "không có người" theo nghiệp vụ (spec mục 4), nên scenario personnel bất thường trên public CP không xảy ra trong thực tế. Test kiểm chứng query filter `residential_contact_points`, không phải kiểm chứng quy tắc nghiệp vụ.

### 0.2.3 (2026-06-17)

- Sửa mô tả chiều test `CHIEU-khac-don-vi-loai-tru-cc-nb`: làm rõ chỉ public CP thuộc đơn vị mới cần test loại trừ; NE không thể thuộc đơn vị (model validates `unit_id must_be_blank`) nên tự động bị loại — không phải "cùng đơn vị".

### 0.2.2 (2026-06-17)

- Thêm chiều test `CHIEU-khac-don-vi-loai-tru-cc-nb`: quân số đầu mối công cộng thuộc đơn vị không tính vào tổng quân số đơn vị. Phát hiện qua audit spec-to-test tracing (PR #404).

### 0.2.1 (2026-06-13)

- Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.

### 0.2.0 (2026-06-13)

- Chuyển danh sách chiều test → bảng `## Truy vết chiều test` với anchor `CHIEU-<slug>` (ADR-030, Issue #329); gắn anchor vào mô tả các test sẵn có. CI đối chiếu bảng ↔ test.

### 0.1.1 (2026-06-11)

- Sửa lỗi-fact phát hiện khi triển khai: `other_type` là **PostgreSQL native enum** (`other_deduction_type`), không phải cột chuỗi — nên cần migration `ALTER TYPE ... ADD VALUE` (dùng `disable_ddl_transaction!`), không phải "không migration". Cập nhật mục Quyết định, Tradeoff, Data model.

### 0.1.0 (2026-06-11)

- Bản đầu: ADR-025 + thiết kế triển khai + chiều test cho cách nhập `unit_coefficient` của khoản trừ "Khác".
