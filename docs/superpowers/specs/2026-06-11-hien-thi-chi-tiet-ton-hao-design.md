---
title: Hiển thị chi tiết tổn hao (cột Tổn hao / Sử dụng thực tế + tóm tắt A/B/C)
version: 0.2.1
status: approved (triển khai 1.2.0)
date: 2026-06-11
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Hiển thị chi tiết tổn hao

Tính năng 3 của milestone **1.2.0**. Hệ thống đã tính tổn hao đúng (đã kiểm chứng kỳ 4/2026), nhưng chỉ hiển thị một con số tổng. Thêm hiển thị chi tiết để quản trị viên đối chiếu cách tính: hai cột "Tổn hao" + "Sử dụng thực tế" trên trang Chỉ số đầu mối và Chỉ số bơm nước; tóm tắt A/B/C trên trang Bảng tính tiền.

- **Nguồn nghiệp vụ:** [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) anchor `NV-hien-thi-chi-tiet-ton-hao` (fold từ `V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` mục 4).
- **Truy vết:** GitHub Issue [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319), milestone `1.2.0`.
- **Trạng thái khách:** đã duyệt phương án; **nghiệm thu khi dùng thử** trên Acceptance sau khi triển khai (không chặn fold/design).

## Bối cảnh

Tổn hao tính theo công thức A/B/C (mục 8 nghiệp vụ): `A = công tơ tổng − Σ công tơ không tổn hao`, `B = Σ sử dụng công tơ có tổn hao`, `C = A − B`; tổn hao công tơ = `sử dụng × C ÷ B`. Hiện chỉ hiển thị tổng tổn hao mỗi đầu mối ở khoản trừ trên bảng tính tiền.

Mã nguồn liên quan hiện tại:

- Tính: `app/services/loss_calculator.rb` — trả `meter_losses` (per công tơ), `contact_point_losses`, `total_loss` (C), `total_b` (B). **Tính on-the-fly, không lưu per-công-tơ.**
- Orchestrate: `app/services/calculation_orchestrator.rb` (Loss → PumpAllocation → Summary, trong transaction).
- Lưu kết quả: `app/models/calculation.rb` (per đầu mối per kỳ) — có `loss_deduction` (tổng per đầu mối) nhưng **không** lưu loss per công tơ, không lưu A/B/C.
- Trang nhập chỉ số: `app/controllers/concerns/meter_reading_entry.rb` + `app/views/meter_entries/show.html.erb` + `app/views/pump_entries/show.html.erb` (cột Đầu kỳ / Cuối kỳ / Sử dụng).
- Bảng tính tiền: `app/controllers/billing_controller.rb` + `app/views/billing/` (header có đơn giá + cảnh báo).

## ADR-027: Lưu snapshot tổn hao per-công-tơ + A/B/C per zone-kỳ

- **Trạng thái:** Proposed · 2026-06-11
- **Bối cảnh:** Cần hiển thị tổn hao per công tơ và "sử dụng thực tế" (sử dụng + tổn hao) trên hai trang nhập chỉ số, và tóm tắt A/B/C trên bảng tính tiền. Yêu cầu nghiệp vụ: hai cột "hiển thị kết quả từ lần tính toán gần nhất" và **để trống nếu chưa tính**. Hiện loss per-công-tơ chỉ tồn tại trong bộ nhớ khi chạy `LossCalculator`.
- **Quyết định:** **Lưu snapshot** kết quả tổn hao tại thời điểm tính:
  - Thêm cột `meter_readings.loss` (decimal, nullable) — tổn hao của công tơ đó ở kỳ đó, ghi bởi `CalculationOrchestrator` trong transaction tính toán. "Sử dụng thực tế" = `sử dụng + loss`, tính khi hiển thị (không lưu thêm cột).
  - Thêm bảng `loss_summaries` (`zone_id`, `period_id`, `a`, `b`, `c`, unique theo `(zone_id, period_id)`) — tóm tắt A/B/C per khu vực per kỳ, ghi cùng transaction.
  - `loss` null ⟹ chưa tính ⟹ hai cột để trống. Sửa chỉ số **sau** khi tính (chưa tính lại): **giữ** giá trị lần tính gần nhất (không xóa, không tính lại live).
- **Lý do:** Ngữ nghĩa "kết quả từ lần tính gần nhất" và "để trống nếu chưa tính" chỉ đúng nếu **persist** — tính live sẽ luôn ra số (whenever có chỉ số) và không phân biệt được "chưa tính". Persist cũng nhất quán với `Calculation` (vốn là snapshot per đầu mối): toàn bộ bảng tính tiền đã "cũ cho tới khi bấm tính lại". `meter_readings` là nơi tự nhiên cho loss per-công-tơ (đã per công tơ per kỳ, snapshot-style); A/B/C là per zone-kỳ nên cần bảng nhỏ riêng.
- **Tradeoff:** (+) Đúng ngữ nghĩa nghiệp vụ, nhất quán snapshot, đọc nhanh khi render. (−) Thêm một cột + một bảng; loss snapshot có thể "cũ" so với chỉ số vừa sửa (đúng yêu cầu, nhưng phải nêu rõ ở UI/spec để không nhầm là sai).
- **Phương án đã loại:**
  - *Tính lại on-the-fly mỗi lần render:* không phân biệt được "chưa tính", có thể lệch với `Calculation` đã lưu khi chỉ số đổi.
  - *Xóa loss về trống khi chỉ số đổi:* phức tạp (theo dõi thay đổi), mất thông tin tham khảo, lệch với hành vi snapshot chung của bảng tính tiền.
- **Điều kiện xem lại:** Nếu cần lưu thêm chiều chi tiết tổn hao (ví dụ theo trạm bơm cho tính năng 2) thì cân nhắc mở rộng `loss_summaries` thay vì thêm bảng mới.

## Thiết kế triển khai

> Triển khai ở session/PR sau. Phần này mô tả đích.

### Data model

- `meter_readings`: thêm `loss` (decimal, nullable). Null = chưa tính ở kỳ đó.
- Bảng mới `loss_summaries`: `zone_id`, `period_id`, `a`, `b`, `c` (decimal), `lock_version` không cần (chỉ engine ghi). Unique `(zone_id, period_id)`.

### Ghi snapshot (`CalculationOrchestrator` / `LossCalculator`)

- Trong transaction tính toán hiện có: sau khi `LossCalculator` chạy, ghi `meter_readings.loss` cho từng công tơ (`meter_losses[meter_id]`) và `find_or_create_by` một `loss_summaries` per `(zone, period)` với `a`, `b`, `c`.
- Trường hợp đặc biệt (mục 8.2): C < 0 → C = 0; B = 0 → tổn hao = 0. A/B/C lưu đúng giá trị engine dùng (kèm cảnh báo sẵn có).
- LossCalculator bổ sung trường `total_a` (A) để writer ghi đủ A/B/C; phần persistence tách thành service `LossSnapshotWriter` gọi trong transaction của `CalculationOrchestrator`.

### Hiển thị

- Trang **Chỉ số đầu mối** (`meter_entries`) và **Chỉ số bơm nước** (`pump_entries`): thêm hai cột **chỉ đọc** sau cột "Sử dụng":
  - "Tổn hao" = `meter_readings.loss` (trống nếu null).
  - "Sử dụng thực tế" = `sử dụng + loss` (trống nếu loss null). Tính khi render, không lưu.
  - Áp dụng cho tất cả công tơ trên trang (sinh hoạt, công cộng, bơm nước).
- Trang **Bảng tính tiền** (`billing`): thêm tóm tắt A/B/C ở header (cạnh đơn giá + cảnh báo), đọc từ `loss_summaries` theo zone đang chọn. Nhãn: Công tơ tổng (A), Tổng sử dụng (B), Tổng tổn hao (C = A − B).
- Làm tròn chỉ khi hiển thị (2 chữ số thập phân kW), phân cách số tiếng Việt (mục 26 nghiệp vụ).
- SA xem nhiều khu vực (chưa lọc zone): tóm tắt hiển thị một dòng A/B/C cho mỗi khu vực trong phạm vi (mỗi dòng đọc từ `loss_summaries` của zone đó). Non-SA / SA đã chọn zone = một zone = một dòng.
- Excel: A/B/C có trong file xuất, đặt ở cuối sheet (dưới hàng TỔNG) để không dịch lưới công thức (`$B$1` đơn giá, dòng dữ liệu bắt đầu ở 6). HTML đặt ở đầu bảng; Excel ở cuối là khác biệt cố ý, an toàn công thức.
- Chú thích kèm khối A/B/C (HTML): A/B/C tính trên toàn khu vực theo sử dụng thô của mọi công tơ có tổn hao (gồm cả công cộng và bơm nước), nên có thể khác tổng các cột trên bảng — vốn chỉ tính đầu mối sinh hoạt. Tránh hiểu nhầm C/B "lệch" với hàng TỔNG (bảng chỉ có dòng đầu mối sinh hoạt; tổn hao/sử dụng của công cộng + bơm nước nằm trong A/B/C nhưng không thành dòng bảng).

### Kế thừa kỳ

- `loss` và `loss_summaries` là **kết quả tính**, không kế thừa. Kỳ mới: `loss` null cho tới khi tính; không có `loss_summaries` cho tới khi tính.

## Chiều test cần bổ sung

Đưa vào [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) (chiều "trạng thái tính toán / hiển thị tổn hao"):

- Chưa bấm tính toán → hai cột Tổn hao / Sử dụng thực tế **trống**; chưa có tóm tắt A/B/C.
- Sau khi tính → hai cột hiển thị đúng `meter_losses`; "Sử dụng thực tế" = sử dụng + loss; A/B/C khớp `LossCalculator`.
- Sửa chỉ số sau khi tính (chưa tính lại) → hai cột **giữ** giá trị lần tính gần nhất.
- Trường hợp đặc biệt: C < 0, B = 0, khu vực trống → giá trị + cảnh báo đúng.
- A/B/C hiển thị theo zone đang chọn (quản trị viên hệ thống đổi zone → đổi A/B/C).
- Công tơ không tổn hao (`no_loss`) → loss = 0.
- Sáu vai trò: hai cột read-only cho mọi vai trò; ai thấy bảng tính tiền nào thì thấy A/B/C tương ứng.

## Giới hạn

- Hai cột mới **chỉ đọc** — không nhập.
- Không tạo trang mới; chỉ thêm vào ba trang sẵn có.
- "Sử dụng thực tế" chỉ để đối chiếu hiển thị; **không** đổi cách tính tiền (tổn hao vẫn trừ ở phía tiêu chuẩn, không cộng vào sử dụng — mục 10.1 nghiệp vụ, tránh trừ hai lần).

## Truy vết

- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) `NV-hien-thi-chi-tiet-ton-hao`.
- Issue: [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319).
- Spec anh em milestone 1.2.0: [cột Khác hệ số đơn vị](2026-06-11-cot-khac-he-so-don-vi-design.md), [phân bổ bơm theo trạm](2026-06-11-phan-bo-bom-theo-tram-design.md).

## Changelog

### 0.2.1 (2026-06-12)

- Thêm chú thích kèm khối A/B/C (HTML): A/B/C tính trên toàn khu vực (gồm công cộng + bơm nước), nên có thể khác tổng các cột trên bảng — tránh hiểu nhầm C/B "lệch" với hàng TỔNG. Refinement từ review.

### 0.2.0 (2026-06-12)

- Triển khai TN3: thêm cột `meter_readings.loss` + bảng `loss_summaries`, service `LossSnapshotWriter`, trường `LossCalculator#total_a`. Hai cột read-only trên trang nhập chỉ số; tóm tắt A/B/C trên bảng tính tiền (HTML + Excel).
- Chốt 2 quyết định mở: SA đa khu vực → A/B/C một dòng mỗi khu vực; Excel có A/B/C đặt cuối sheet (an toàn công thức).

### 0.1.0 (2026-06-11)

- Bản đầu: ADR-027 + thiết kế triển khai + chiều test cho hiển thị chi tiết tổn hao (cột Tổn hao / Sử dụng thực tế + tóm tắt A/B/C).
