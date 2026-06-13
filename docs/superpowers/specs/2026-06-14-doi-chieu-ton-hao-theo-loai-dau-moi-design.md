---
title: Đối chiếu tổn hao/sử dụng theo loại đầu mối trên bảng tính tiền (mở rộng TN3 / ADR-027)
version: 0.1.0
date: 2026-06-14
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Đối chiếu tổn hao/sử dụng theo loại đầu mối

Follow-up của **TN3 — Hiển thị chi tiết tổn hao** ([`2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md), ADR-027). TN3 đã ship khối tóm tắt A/B/C trên Bảng tính tiền; issue này thêm **bảng đối chiếu theo loại đầu mối** để quản trị viên kiểm tra được **từng phần** số tổn hao/sử dụng khớp với A/B/C và số công tơ tổng.

- **Nguồn nghiệp vụ:** [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) anchor `NV-hien-thi-chi-tiet-ton-hao` (§8.5 — cập nhật mô tả bảng đối chiếu theo loại khi triển khai).
- **Truy vết:** GitHub Issue [`#332`](https://github.com/manhcuongdtbk/electric-water-management/issues/332); umbrella [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319); milestone `1.2.0`.
- **Mở rộng:** ADR-027 trong spec TN3 (quyết định "Điều kiện xem lại" của ADR-027 đã tiên liệu việc derive thêm chiều chi tiết tổn hao).
- **Trạng thái khách:** hướng-khách (`customer-facing`); nghiệm thu khi dùng thử trên Acceptance sau khi triển khai.

## Bối cảnh

Khối A/B/C (ADR-027) tính trên **toàn khu vực**: `A = công tơ tổng − Σ công tơ không tổn hao`, `B = Σ sử dụng công tơ có tổn hao`, `C = A − B`. Bảng tính tiền chỉ có **dòng đầu mối sinh hoạt**, còn công cộng + bơm nước + công tơ không tổn hao không thành dòng — nên B/C/A **khác** tổng các cột trên bảng. PR [`#331`](https://github.com/manhcuongdtbk/electric-water-management/pull/331) đã thêm chú thích giải thích chênh lệch; khách muốn **đối chiếu được từng phần**.

Mã nguồn liên quan (đã có sau TN3):

- `app/models/loss_summary.rb` — A/B/C per `(zone, period)` (snapshot, ghi bởi `LossSnapshotWriter`).
- `app/models/meter_reading.rb` — cột `loss` (tổn hao per công tơ, snapshot) + cờ `no_loss`.
- `app/models/contact_point.rb` — enum `contact_point_type`: `residential` / `public` / `water_pump` / `non_establishment`.
- `app/services/loss_calculator.rb`, `app/services/zone_query.rb` — `meter_usages`, `main_meter_total_usage`.
- `app/controllers/billing_controller.rb` + `app/views/billing/_loss_summary.html.erb` + `app/views/billing/show.xlsx.axlsx` — khối A/B/C (HTML đầu bảng + Excel cuối sheet).
- `app/services/summary_calculator.rb` — `Calculation.residential_usage` (Σ usage mọi công tơ của đầu mối sinh hoạt) + `loss_deduction` (tổn hao per đầu mối) → tổng hợp ở `Billing::Query.summary` thành `@summary[:residential_usage]` / `@summary[:loss_deduction]`.

## ADR-054: Bảng đối chiếu tổn hao/sử dụng theo loại đầu mối (derive read-only từ snapshot)

- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** xem mục Bối cảnh. Mở rộng "Điều kiện xem lại" của ADR-027.
- **Quyết định:** Thêm **bảng nhỏ** dưới khối A/B/C trên Bảng tính tiền, tách theo **loại đầu mối** (Sinh hoạt / Công cộng / Bơm nước), 3 cột **Sử dụng · Tổn hao · Sử dụng thực tế** (= Sử dụng + Tổn hao); một dòng **"Không tổn hao"** riêng + hai dòng tổng:
  - **"Cộng (công tơ có tổn hao)"** = khối A/B/C: Sử dụng = B, Tổn hao = C, Sử dụng thực tế = A.
  - **"Tổng cộng"** = Cộng + Không tổn hao; Sử dụng thực tế của dòng này = **số trên công tơ tổng** (toàn bộ điện cấp = đo được + hao).
  - **Derive read-only** từ snapshot đã có (`meter_readings.loss` + usage thô + `contact_points.contact_point_type` + cờ `no_loss`), gom theo loại cho zone+kỳ đang xem. **KHÔNG đổi schema, KHÔNG snapshot mới.** Chọn hướng **derive** (đã tiên liệu ở "Điều kiện xem lại" của ADR-027) thay vì mở rộng `loss_summaries`, vì breakdown per-loại tính được hoàn toàn từ `meter_readings.loss` + loại + cờ `no_loss`.

  Ví dụ (dữ liệu mẫu "Khu vực 1"):

  | Loại | Sử dụng | Tổn hao | Sử dụng thực tế |
  |---|---|---|---|
  | Sinh hoạt | 1.230,00 | 38,24 | 1.268,24 |
  | Công cộng | 400,00 | 12,44 | 412,44 |
  | Bơm nước | 300,00 | 9,33 | 309,33 |
  | **Cộng (công tơ có tổn hao)** | **1.930,00** | **60,00** | **1.990,00** |
  | Không tổn hao | 110,00 | 0,00 | 110,00 |
  | **Tổng cộng** | **2.040,00** | **60,00** | **2.100,00** |

- **Làm tròn (quyết định hiển thị):** Làm tròn **half-up 2 chữ số TỪNG ô** — mỗi ô = giá trị tròn thật của chính nó (mục 26 nghiệp vụ + quy ước app). Kèm **chú thích**: tổng các dòng (đã làm tròn) có thể lệch **±0,01** so với dòng "Cộng"/"Tổng cộng" do làm tròn; **số neo quyền lực** là A/B/C và số công tơ tổng. **Loại** hai phương án khác:
  - *Ép khớp (largest-remainder):* làm một ô lệch 0,01 khỏi giá trị tròn thật của nó để các dòng cộng khớp tuyệt đối — **bị loại** vì làm sai lệch chính bảng dùng để **kiểm toán/đối chiếu**.
  - *Bỏ làm tròn (số thô đầy đủ):* tổn hao = `usage × C ÷ B` ra số lẻ rất dài, khó đọc cho người dùng cuối và nghịch quy ước làm-tròn-khi-hiển-thị của cả app — **bị loại**.
- **Lý do:** Mục đích tính năng là **đối chiếu/kiểm toán** → trung thực quan trọng hơn "trông khớp". Derive từ snapshot giữ nhất quán ngữ nghĩa "kết quả từ lần tính gần nhất" (ADR-027): breakdown **chỉ hiện khi đã tính** (zone có `LossSummary` cho kỳ đó), trống khi chưa tính. Test đối chiếu so trên **giá trị thô** (cái "khớp thật" nằm ở dữ liệu thô; hiển thị chỉ là hiển thị).
- **Tradeoff:** (+) Không đổi schema, đối chiếu được từng phần, trung thực, đọc nhanh khi render. (−) Tổng hiển thị có thể lệch ±0,01 (đã giải bằng chú thích).
- **Phạm vi đối chiếu:** Bảng này đối chiếu trục **tổn hao / sử dụng thô** (A, B, C, công tơ không tổn hao — nối được tới số điện lực: số điện lực = A + Σ công tơ không tổn hao). **KHÔNG** đối chiếu **điện bơm nước đã phân bổ** (cột "Sử dụng điện bơm nước" trên bảng là điện bơm đã PHÂN BỔ xuống đầu mối sinh hoạt — §9 nghiệp vụ). Breakdown chỉ hiện điện bơm **thô của trạm**. Phần đối chiếu "bơm thô ↔ bơm đã phân bổ" thuộc **TN2 — Phân bổ bơm theo trạm (ADR-026, [`2026-06-11-phan-bo-bom-theo-tram-design.md`](2026-06-11-phan-bo-bom-theo-tram-design.md))**, theo dõi ở umbrella [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319). Cố ý KHÔNG gộp vào #332 để giữ ranh giới tổn hao ↔ phân bổ bơm.

> Lưu ý loại `non_establishment` (Ngoài biên chế): theo **quy ước nghiệp vụ/UI** (§4) không có công tơ → thực tế breakdown chỉ có 3 loại. **Lưu ý kỹ thuật:** đây KHÔNG phải ràng buộc model (`validate_non_establishment_constraints` không cấm meter), nên service phải **gom động theo loại có công tơ có-tổn-hao** (KHÔNG hardcode 3 loại). Như vậy Σ-các-loại = B **luôn đúng** kể cả nếu xuất hiện meter ngoại lệ — khi đó hiện thêm dòng "Ngoài biên chế" (nhãn i18n enum sẵn có), không vỡ đối chiếu.

## Thiết kế triển khai

> Triển khai ở session/PR sau. Phần này mô tả đích.

### Service đọc `LossBreakdown`

PORO read-only, `initialize(zone:, period:)` — trả giá trị **thô** (BigDecimal, chưa làm tròn), tách raw/display để test đối chiếu so trên thô:

- `loss_bearing_rows`: cho mỗi `contact_point_type` có công tơ `no_loss=false` trong zone+kỳ → `{ type:, usage:, loss:, actual: usage + loss }`. `usage` = Σ `meter_usages` của công tơ loại đó (`no_loss=false`); `loss` = Σ `meter_readings.loss` công tơ loại đó.
- `loss_bearing_total`: `{ usage: b, loss: c, actual: a }` — neo từ `LossSummary` của zone+kỳ (nguồn quyền lực cho dòng "Cộng").
- `no_loss_total`: `{ usage: Σ usage công tơ no_loss=true (mọi loại), loss: 0 }` (dòng "Không tổn hao").
- `no_loss_by_type`: usage no_loss tách theo loại — **chỉ phục vụ test đối chiếu chéo sinh hoạt**, không render thành dòng.
- `grand_total`: `{ usage: b + no_loss_total.usage, loss: c, actual: main_meter_total_usage }` (dòng "Tổng cộng").
- Dùng `ZoneQuery` sẵn có (`meters` / `meter_usages` / `meter_readings` / `main_meter_total_usage`). **Chỉ build khi zone có `LossSummary`** cho kỳ (đã tính) — cùng gate với khối A/B/C.

### Controller

`BillingController#show`: thêm `@loss_breakdowns` (map `zone_id => LossBreakdown result`) cho mỗi zone trong `@loss_summaries` — cùng gate, cùng scope per zone (khớp A/B/C đa-zone của SA: mỗi zone một breakdown).

### Hiển thị

Mở rộng `_loss_summary.html.erb`: dưới chip A/B/C **của mỗi zone**, render bảng 4 cột (Loại · Sử dụng · Tổn hao · Sử dụng thực tế). Dòng theo thứ tự: các loại **có công tơ có-tổn-hao** (bỏ loại rỗng để tránh nhiễu) → **"Cộng (công tơ có tổn hao)"** → **"Không tổn hao"** → **"Tổng cộng"**. Làm tròn 2 chữ số **từng ô** + định dạng số tiếng Việt (`number_to_vi`). Thêm **chú thích** (i18n): tổng các dòng có thể lệch ±0,01 do làm tròn; số chuẩn là A/B/C và số công tơ tổng.

### Excel parity

`show.xlsx.axlsx`: trong khối `@loss_summaries` ở **cuối sheet** (chỗ TN3 đã đặt), sau dòng A/B/C của mỗi zone, nối các dòng breakdown (ô text + numeric, **không** formula, **không** merge) — an toàn lưới công thức phía trên.

### i18n (ADR-032)

Mọi nhãn người-dùng MỚI (tiêu đề cột, tên dòng, chú thích) đi qua `t()` + `config/locales/vi.yml`, namespace `billing.loss_breakdown.*`. **KHÔNG hard-code tiếng Việt trong view.** Nhãn loại đầu mối tái dùng i18n enum sẵn có (`activerecord.attributes.contact_point.contact_point_type.*`).

### Kế thừa kỳ

Breakdown là derive từ kết quả tính → không kế thừa; kỳ mới chưa tính → không hiện (giống A/B/C).

### Demo hướng khách (ADR-040 — deliverable bắt buộc, phủ luôn TN3)

#332 là **`customer-facing`** → PR phải gắn nhãn `customer-facing`; guardrail **ADR-040** (`.github/scripts/check-demo-spec.sh`) chặn merge nếu PR không thêm/sửa file `spec/demo/**`. Demo spec là **một phần Definition of Done của #332** (ghi tại spec để không backfill ở PR-time như TN1 #355/#356).

- **File:** `spec/demo/loss_breakdown_demo_spec.rb` (`type: :demo`). Scaffold bằng **`rails g demo:spec loss_breakdown`** (generator ADR-050/051, đã merge qua #353) → skeleton tự có `include_context "demo seeded world"`, boilerplate đăng nhập `demo_admin`, tag `demo_nv: %w[NV-...]`. Điền journey + caption tiếng Việt; gán `demo_nv: %w[NV-hien-thi-chi-tiet-ton-hao]`; kết bằng assertion trên dữ liệu seed thật (green-to-merge). Viết demo **sau khi rebase develop mới nhất** để dùng `DemoRecorder` cập nhật (PR #356 đang tinh chỉnh recorder).
- **Journey (một công đôi việc — phủ cả TN3 lẫn #332):** đăng nhập `demo_admin` → mở **Bảng tính tiền** → bấm **"Tính toán lại"** → caption chỉ ra **cột "Tổn hao"** trên bảng + **khối A/B/C** (TN3) → cuộn tới **bảng đối chiếu theo loại** + dòng "Cộng"/"Không tổn hao"/"Tổng cộng" + chú thích làm tròn (#332). Caption tiếng Việt lấy ý từ `NV-hien-thi-chi-tiet-ton-hao` + UI thật. (TN3 ship 1.2.0 nhưng thiếu demo → demo này phủ luôn; nếu #332 trượt khỏi 1.2.0 thì TN3 cần demo backfill riêng.)
- **Dữ liệu demo:** `db/seeds/demo.rb` đã có 3 loại đầu mối (sinh hoạt/công cộng/bơm) + công tơ tổng nhưng **mọi công tơ `no_loss=false`** → thêm **một công tơ `no_loss=true`** để dòng "Không tổn hao" khác 0 và "Tổng cộng" tách khỏi "Cộng" (kể trọn đối chiếu: số điện lực = A + công tơ không tổn hao). Bổ sung tối thiểu, không phá smoke demo (vẫn còn "Khu vực Trung tâm" + kỳ 6/2026).

## Truy vết chiều test

Mã `CHIEU-<slug>` khai chiều test; test mang mã ở mô tả `it` (CI đối chiếu — ADR-030). Tiền tố `CHIEU-` (KHÔNG `CT-` — đó là tên công tơ trong fixture).

| Mã | Chiều test (mô tả) | Trạng thái |
|---|---|---|
| `CHIEU-breakdown-tong-theo-loai` | Σ các loại (thô): Sử dụng = `loss_summaries.b`; Tổn hao = `loss_summaries.c`; "Cộng"/Sử dụng thực tế = `loss_summaries.a` | có test |
| `CHIEU-breakdown-doi-chieu-sinh-hoat` | Sinh hoạt/Tổn hao = TỔNG cột Tổn hao bảng (`@summary[:loss_deduction]`); (Sinh hoạt có-tổn-hao + Sinh hoạt không-tổn-hao usage) = TỔNG Sử dụng sinh hoạt (`@summary[:residential_usage]`) | có test |
| `CHIEU-breakdown-doi-chieu-cong-to-tong` | "Tổng cộng"/Sử dụng thực tế = `main_meter_total_usage` (số công tơ tổng) | có test |
| `CHIEU-breakdown-khong-ton-hao` | Công tơ `no_loss`: loại khỏi B; Tổn hao = 0; dòng "Không tổn hao" = Σ usage no_loss (mọi loại) | có test |
| `CHIEU-breakdown-lam-tron` | Làm tròn trung thực 2 chữ số TỪNG ô; chú thích lệch ±0,01 do làm tròn hiển thị; test đối chiếu vẫn so trên giá trị thô | có test |
| `CHIEU-breakdown-chua-tinh` | Chưa tính (zone không có `LossSummary` cho kỳ) → không hiện bảng breakdown | có test |
| `CHIEU-breakdown-theo-zone` | SA đa khu vực → mỗi zone một bảng breakdown riêng (khớp A/B/C per zone) | có test |
| `CHIEU-breakdown-vai-tro` | Sáu vai trò: ai thấy bảng tính tiền nào thì thấy breakdown tương ứng (TECH bị chặn) | có test |
| `CHIEU-breakdown-excel` | Excel có các dòng breakdown ở cuối sheet (parity), không phá lưới công thức | có test |
| `CHIEU-breakdown-i18n` | Nhãn breakdown 100% tiếng Việt qua `t()` (ADR-032), không từ tiếng Anh | có test |

## Giới hạn

- Bảng đối chiếu: **chỉ đọc**, derive từ snapshot — không nhập, không đổi schema, không đổi cách tính tiền (tổn hao vẫn trừ phía tiêu chuẩn — §10.1, tránh trừ hai lần).
- Chỉ đối chiếu trục tổn hao/sử dụng thô; **không** bắc cầu điện bơm nước đã phân bổ (TN2/ADR-026, #319). Loại `non_establishment` không có công tơ nên thực tế không xuất hiện.
- **Definition of Done:** ngoài code + 10 chiều test, PR **bắt buộc** kèm demo spec `spec/demo/` + nhãn `customer-facing` (ADR-040) — xem mục "Demo hướng khách".

## Truy vết

- Nghiệp vụ: [`V2_XAC_NHAN_NGHIEP_VU.md`](../../V2_XAC_NHAN_NGHIEP_VU.md) `NV-hien-thi-chi-tiet-ton-hao` (§8.5 — cập nhật mô tả bảng đối chiếu theo loại khi triển khai).
- Spec gốc mở rộng: [`2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md) (ADR-027).
- Issue: [`#332`](https://github.com/manhcuongdtbk/electric-water-management/issues/332); umbrella [`#319`](https://github.com/manhcuongdtbk/electric-water-management/issues/319).

## Lịch sử thay đổi

### 0.1.0 (2026-06-14)

- Bản đầu: **ADR-054** (#332, mở rộng ADR-027) — bảng đối chiếu tổn hao/sử dụng **theo loại đầu mối** (Sinh hoạt / Công cộng / Bơm nước) dưới khối A/B/C trên Bảng tính tiền; 3 cột Sử dụng/Tổn hao/Sử dụng thực tế, dòng "Không tổn hao" riêng + 2 dòng tổng ("Cộng có tổn hao" = A/B/C; "Tổng cộng"/Sử dụng thực tế = công tơ tổng). Derive read-only từ snapshot, không đổi schema.
- Quyết định hiển thị: làm tròn trung thực 2 chữ số từng ô + chú thích lệch ±0,01 (loại largest-remainder và loại bỏ-làm-tròn); test đối chiếu so trên giá trị thô.
- Thiết kế triển khai (service `LossBreakdown` read-only, controller `@loss_breakdowns` per zone, mở rộng `_loss_summary` + Excel parity, i18n `billing.loss_breakdown.*` theo ADR-032) + 10 chiều test `CHIEU-breakdown-*` + demo hướng khách (ADR-040, DoD) phủ luôn TN3.
