---
title: Chỉ báo độ tươi dữ liệu dẫn xuất (Chiều 8 quy mô hệ thống) + guard xuất Excel
version: 1.0.0
date: 2026-06-14
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Chỉ báo độ tươi dữ liệu dẫn xuất

Vấn đề **mức hệ thống** (không phải một trang): mọi **dữ liệu dẫn xuất** — `calculations`, `meter_readings.loss`, `loss_summaries` (A/B/C), thừa/thiếu ở Tổng quan — là **snapshot**, chỉ làm mới khi bấm "Tính toán lại". Input lại sửa được ở **nhiều trang**. Sửa input một trang làm dữ liệu dẫn xuất trên mọi trang khác **âm thầm trở nên cũ**, nhìn bằng mắt không phân biệt được "đã tính & còn đúng" với "đã tính & đã cũ". Đây là **Chiều 8 (trạng thái tính toán)** ở quy mô toàn hệ thống, với **kịch bản nguy hiểm** đã ghi nhận: xuất Excel khi stale → file số liệu sai; xem billing cũ → tưởng đơn vị chưa nhập.

- **Nguồn nghiệp vụ/hành vi:** [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) "Chiều 8 — Trạng thái tính toán" (bảng 3 trạng thái + kịch bản nguy hiểm).
- **Tradeoff snapshot cố ý:** [`2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md) ADR-027 (persist "kết quả lần tính gần nhất"; không tính live). Thiết kế này **không phá** ngữ nghĩa đó — chỉ **làm lộ** trạng thái cũ và chặn rò rỉ ra Excel.
- **Truy vết:** GitHub Issue [`#334`](https://github.com/manhcuongdtbk/electric-water-management/issues/334), milestone `1.3.0`, nhãn `priority-high`. Phát sinh từ review TN3 ([`#331`](https://github.com/manhcuongdtbk/electric-water-management/issues/331)).
- **Trạng thái khách:** vấn đề nền tảng/an toàn dữ liệu; nghiệm thu khi dùng thử trên Acceptance sau triển khai.

## Bối cảnh (mã nguồn hiện tại)

- Tính: `app/services/calculation_orchestrator.rb` chạy **per khu vực** trong transaction (`LossCalculator` → `LossSnapshotWriter` → `PumpAllocationCalculator` → `SummaryCalculator`). Trigger: `billing_controller#recalculate` (POST, chỉ kỳ mở; lặp các zone trong scope).
- Mốc thời gian tính: `calculations.calculated_at` (NOT NULL) set per đầu mối trong `summary_calculator.rb` (`Time.current`). `loss_summaries` và `meter_readings.loss` **không** có `calculated_at` riêng (chỉ `updated_at`; `loss` ghi qua `update_all`, không bump `updated_at`). Vì vậy mốc "đã tính" tin cậy ở mức zone phải lấy từ phía tính, không suy từ bảng dẫn xuất.
- Nguồn input (đều có `updated_at` qua concern `Auditable`, đều có `period_id`): `meter_readings` (qua `meter`→`contact_point`→zone), `main_meter_readings` (qua `main_meter`→zone), `personnel_entries`/`other_deductions`/`non_establishment_snapshots` (qua `contact_point`→zone), `pump_allocations` (`zone_id` trực tiếp), `unit_configs` (qua `unit.zone_id`).
- Cảnh báo hiện có (#331): **chú thích tĩnh** ở `meter_entries`/`pump_entries` ("có thể chưa cập nhật nếu vừa sửa") — không so timestamp, không chỉ ra zone nào cũ.
- Trang hiển thị/ảnh hưởng: `billing_controller` (+ `format.xlsx` qua `app/views/billing/show.xlsx.axlsx`), `dashboard_controller`, `meter_entries`/`pump_entries` (concern `meter_reading_entry`), trang nhập số điện lực (`main_meter_readings`).

## ADR-048: Chỉ báo độ tươi per-khu-vực qua bảng trạng thái `calculation_states` + guard xuất Excel ba lớp

- **Trạng thái:** Proposed (chờ quyết #334) · 2026-06-14
- **Bối cảnh:** Dữ liệu dẫn xuất cố ý là snapshot (ADR-027), không auto-recalc (tính trên toàn khu vực, cần đợi mọi đơn vị nhập xong + cảnh báo thiếu-dữ-liệu). Cần làm cho trạng thái cũ **nhìn thấy được** và chặn kịch bản nguy hiểm (Excel sai), **không** đổi mô hình snapshot, **không** auto-recalc.
- **Quyết định:**
  1. **Độ mịn per khu vực-kỳ** — đúng đơn vị recalc (`CalculationOrchestrator` chạy per zone). Không per-dòng (nhiều input dùng chung zone, `meter_readings.loss` không có mốc riêng → dễ báo sai), không global (SA nhiều zone không biết zone nào cũ).
  2. **Bảng mới `calculation_states(zone_id, period_id)` unique**, hai cột mốc:
     - `inputs_changed_at: datetime` (nullable) — bump khi input liên quan zone-kỳ đó thay đổi.
     - `last_calculated_at: datetime` (nullable) — set khi orchestrator tính xong zone-kỳ.
     - Suy ra 3 trạng thái khớp bảng Chiều 8: `last_calculated_at` nil ⟹ **chưa tính**; `inputs_changed_at` có và (`last_calculated_at` nil hoặc `inputs_changed_at > last_calculated_at`) ⟹ **cần tính lại (stale)**; còn lại ⟹ **đã tính & còn đúng**.
  3. **Phát hiện qua marker bump (không quét max(updated_at) khi render)** — concern dùng chung `TouchesCalculationState` include vào 7 input model, `after_commit` trên `create`/`update`/**`destroy`** → resolve `(zone_id, period_id)` (dùng chung resolver với engine, xử lý đúng đầu mối zone-direct vs qua-unit) → set `inputs_changed_at = Time.current`. **Bắt cả hard-delete** ⟹ đóng false-negative nguy hiểm (xóa input sau tính mà render vẫn báo "còn mới"). So sánh khi render là O(1) một dòng.
  4. **Chỉ báo per-zone trên 5 trang**: Bảng tính tiền, Tổng quan, Nhập chỉ số đầu mối, Nhập chỉ số bơm, Nhập số điện lực. Chỉ thể hiện "cần tính lại" có-thể-hành-động khi **kỳ đang mở** (kỳ đóng = đông cứng, không thể sửa input theo `PeriodGuard` ⟹ không stale). Nâng cấp chú thích tĩnh #331 thành chỉ báo động.
  5. **Guard xuất Excel ba lớp** (đóng kịch bản nguy hiểm, tôn trọng snapshot — cảnh báo/xác nhận, không chặn cứng vận hành):
     - **Lớp 1 (UX):** nút Xuất Excel dùng Stimulus; có zone stale trong scope → xác nhận tiếng Việt "… Vẫn xuất?" → tiếp tục với tham số `acknowledged_stale=1`.
     - **Lớp 2 (server):** `billing#show.xlsx` stale mà thiếu `acknowledged_stale` → redirect kèm flash cảnh báo + lối Tính lại (phòng truy cập URL trực tiếp, bypass JS).
     - **Lớp 3 (an toàn cuối):** khi vẫn xuất lúc stale → **đóng dấu cảnh báo trong file Excel** ("CẢNH BÁO: dữ liệu có thể đã cũ…"). Lớp thực sự đóng "file Excel sai" kể cả khi bỏ qua JS.
- **Lý do:** Marker + cột mốc cho phép phân biệt rạch ròi 3 trạng thái Chiều 8, bắt được xóa, đọc nhanh khi render. Tên `calculation_states` ánh xạ đúng nghiệp vụ "Chiều 8 — Trạng thái tính toán". Guard nhiều lớp đóng kịch bản nguy hiểm mà không phá snapshot cố ý cũng không auto-recalc.
- **Tradeoff:** (+) Đúng ngữ nghĩa, đóng false-negative + kịch bản Excel, render rẻ. (−) Thêm 1 bảng + concern trên 7 model (gồm đường destroy); cần resolver zone-kỳ dùng chung với engine (rủi ro diverge — giảm bằng cách tái dùng logic ánh xạ sẵn có và test mọi nguồn input).
- **Phương án đã loại:** *Quét max(updated_at) khi render* — không bắt hard-delete (false-negative nguy hiểm). *Per-dòng* — phức tạp, `meter_readings.loss` không mốc riêng, dễ sai. *Global* — không chỉ ra zone cũ. *Auto-recalculate* — ngược thiết kế cố ý (#334 nêu rõ). *Chặn cứng xuất Excel* — cản trở vận hành (cần xem nháp).

## Thành phần & ranh giới

- **Migration** `calculation_states` (`zone_id`, `period_id`, `inputs_changed_at`, `last_calculated_at`; unique `(zone_id, period_id)`; index phục vụ tra theo period).
- **Model** `CalculationState` — chỉ chứa logic suy trạng thái (`never_calculated?`, `stale?`, `fresh?`) thuần từ hai mốc; không phụ thuộc request.
- **Concern** `TouchesCalculationState` — include vào 7 input model; khai báo cách resolve `(zone_id, period_id)` cho model đó; `after_commit` (create/update/destroy) → `CalculationState` upsert `inputs_changed_at`. Resolver zone dùng chung với engine (đầu mối zone-direct vs qua-unit).
- **Hook** trong `CalculationOrchestrator` — sau khi tính xong zone-kỳ, upsert `last_calculated_at`. Trong transaction sẵn có.
- **Query object/helper** `CalculationFreshness` — nhận scope zone + period, trả map zone→trạng thái cho view (O(1) đọc bảng); một nguồn sự thật cho cả 5 trang và guard Excel.
- **View**: partial chỉ báo per-zone dùng chung; text qua i18n. Guard Excel: Stimulus controller cho nút xuất + nhánh server trong `billing_controller` + dòng đóng dấu trong `show.xlsx.axlsx`.

## i18n (ADR-032)

Mọi text người-dùng MỚI qua `t(...)` + `config/locales/vi.yml` (không hard-code tiếng Việt trong view). Nhóm khóa dự kiến dưới `calculation_states.*` (nhãn trạng thái: cần tính lại / chưa tính / đã tính) và `billing.export.*` (xác nhận stale, flash redirect, dòng cảnh báo trong Excel). Chú thích tĩnh #331 chuyển sang chỉ báo động (giữ/đổi khóa phù hợp).

## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030). Request spec drive qua **action thật** (sửa input → GET trang → thấy chỉ báo; POST `recalculate` → hết stale; xuất Excel stale → flash/đóng dấu), không gọi service trực tiếp.

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-do-tuoi-chua-tinh` | Kỳ mở chưa từng tính → trạng thái "chưa tính" (phân biệt với stale), không hiện hành-động "cần tính lại" như đã-tính-cũ | có test |
| `CHIEU-do-tuoi-sau-tinh-con-dung` | Tính xong, không sửa input → "đã tính & còn đúng", không banner cần-tính-lại | có test |
| `CHIEU-do-tuoi-stale-sau-sua` | Sửa input (vd `meter_readings`) sau khi tính → đúng zone đó "cần tính lại"; `inputs_changed_at > last_calculated_at` | có test |
| `CHIEU-do-tuoi-bump-khi-xoa` | Hard-delete input sau khi tính → vẫn "cần tính lại" (đóng false-negative; phân biệt với quét max(updated_at)) | có test |
| `CHIEU-do-tuoi-nguon-input` | Mỗi nguồn (meter_readings, main_meter_readings, personnel_entries, other_deductions, non_establishment_snapshots, pump_allocations, unit_configs) sửa → bump đúng zone-kỳ (gồm đầu mối zone-direct vs qua-unit) | có test |
| `CHIEU-do-tuoi-recalc-het-stale` | POST `recalculate` → `last_calculated_at` cập nhật → hết stale cho các zone đã tính | có test |
| `CHIEU-do-tuoi-per-zone` | Nhiều zone: chỉ zone có input đổi mới stale; SA xem nhiều zone → mỗi zone trạng thái riêng | có test |
| `CHIEU-do-tuoi-excel-block` | Xuất Excel khi stale chưa `acknowledged_stale` → redirect + flash cảnh báo, không sinh file | có test |
| `CHIEU-do-tuoi-excel-stamp` | Xuất Excel stale có `acknowledged_stale` → file có dòng cảnh báo đóng dấu | có test |
| `CHIEU-do-tuoi-ky-dong` | Kỳ đóng → không stale/không banner (đông cứng); kỳ cũ mở lại (open) → áp dụng bình thường | có test |
| `CHIEU-do-tuoi-5-trang` | Chỉ báo hiện trên cả 5 trang (billing, dashboard, meter_entries, pump_entries, nhập số điện lực) | có test |
| `CHIEU-do-tuoi-vai-tro` | Sáu vai trò: ai thấy trang nào thấy chỉ báo tương ứng; chỉ vai trò có quyền `recalculate` thấy nút hành động; chỉ huy (commander) read-only | có test |

## Giới hạn

- Không auto-recalculate; không tính live. Giữ nguyên ngữ nghĩa snapshot (ADR-027) và cảnh báo thiếu-dữ-liệu (`ZoneWarningCollector`).
- Chỉ báo ở mức **per khu vực-kỳ**, không per-dòng.
- Không tạo trang mới; chỉ thêm chỉ báo + guard vào trang/luồng sẵn có.
- Tương tác với tính năng đang chờ "bỏ mở kỳ/đóng kỳ": không phụ thuộc; nếu tính năng đó triển khai sau, trạng thái per zone-kỳ vẫn đúng.

## Lịch sử thay đổi

### 1.0.0 (2026-06-14)

- Bản thiết kế đầu tiên (ADR-048): chỉ báo độ tươi dữ liệu dẫn xuất per khu vực-kỳ qua bảng `calculation_states` (marker bump bắt cả hard-delete) + guard xuất Excel ba lớp. Brainstorm chốt hướng từ đề xuất mở của Issue #334 (milestone 1.3.0, priority-high).
