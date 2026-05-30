# Thiết kế bản viết lại V2_KICH_BAN_TEST.md

> **Ngày:** 31/05/2026
> **Tính chất:** Spec thiết kế (planning artifact) cho việc viết lại toàn bộ `docs/V2_KICH_BAN_TEST.md`. Không phải tài liệu nghiệp vụ — là kế hoạch cấu trúc + quy ước trước khi viết nội dung.
> **Nguồn quyết định:** Phiên brainstorming 31/05/2026 (5 quyết định đã chốt, ghi ở mục 2).

---

## 1. Bối cảnh và vấn đề

`docs/V2_KICH_BAN_TEST.md` hiện tại (v1.2.0, 18/05/2026, 113 test case T01–T113) đã lỗi thời so với 3 tài liệu mới hơn:

- Dựa trên NGHIEP_VU v2.8.0 / THIET_KE v2.1.0 (nay là **v2.13.0**).
- Mô tả hệ thống như **4 vai trò**, không phải **6 vai trò thực tế** (thiếu phân biệt UA-ZM/CMD-ZM; Commander nay thấy trang read-only/disabled thay vì bị chặn).
- Không cover hệ thống **6 nhóm giao điểm nguy hiểm** và **ma trận 18 trang × 6 vai trò** của CHIEU_TEST v1.2.0.

Phần golden numbers engine (T01–T04) vẫn đúng và khớp `spec/support/sample_data.rb`, nhưng phần còn lại cần viết mới.

**Quan hệ trong bộ 4 tài liệu:**

| Tài liệu | Sở hữu |
|---|---|
| V2_XAC_NHAN_NGHIEP_VU | Nghiệp vụ (cái gì) — nguồn sự thật |
| V2_THIET_KE_HE_THONG | Thiết kế (làm thế nào) |
| V2_HANH_VI_HE_THONG | Hành vi runtime (hành xử ra sao) |
| V2_CHIEU_TEST | **Không gian** test — 12 chiều, input/output specs trừu tượng, 6 nhóm giao điểm nguy hiểm |
| **V2_KICH_BAN_TEST (file này)** | **Kịch bản số liệu cụ thể** — instance hóa không gian của CHIEU_TEST bằng dữ liệu thật + golden numbers. Không lặp lại 12 chiều/ma trận. |

---

## 2. Các quyết định đã chốt (brainstorming 31/05/2026)

1. **Mục đích = Hybrid.** Vừa là kịch bản giao điểm nguy hiểm có số liệu, vừa giữ phần test thủ công theo trang cho QA.
2. **Dữ liệu mẫu = mở rộng thêm Khu vực 2.** Giữ Khu vực 1 (khớp `setup_zone_one_full_sample`) làm nền, thêm Khu vực 2 để cover SA filter, cách ly cross-zone, phân biệt UA-ZM/CMD-ZM giữa 2 khu vực, CP thuộc khu vực trực tiếp.
3. **Golden numbers = verify bằng engine thật.** Setup dữ liệu KV1 + KV2 trong Docker (rails console / spec tạm), chạy `CalculationOrchestrator` lấy số chính xác đến decimal, ghi vào doc. Không tính tay cho số mới.
4. **Cấu trúc = Lựa chọn 1** (6 phần theo tầng dữ liệu — xem mục 4).
5. **ID = theo nhóm + truy vết RSpec.** ID có tiền tố nhóm; Phần 6 quét `spec/` map mỗi kịch bản → file RSpec.

---

## 3. Quy ước

### 3.1. Mã test case (ID theo nhóm)

| Tiền tố | Nhóm | Ví dụ |
|---|---|---|
| `DATA` | Dữ liệu mẫu (Phần 1) | DATA-KV1, DATA-KV2 |
| `EN` | Engine golden numbers (Phần 2) | EN-KV1-LOSS, EN-KV2-SUMMARY |
| `GD1`–`GD6` | 6 nhóm giao điểm nguy hiểm (Phần 3) | GD1-01, GD4-03 |
| `TR` | Walkthrough theo trang × vai trò (Phần 4) | TR-billing-SA, TR-meter_entries-UAZM |
| `VH` | Vận hành: kỳ, CRUD, auth, backup (Phần 5) | VH-period-01, VH-validation-05 |

### 3.2. Tag loại test (giữ từ file cũ)

- `[THỦ CÔNG]` — chỉ kiểm tra bằng mắt (giao diện, merge dọc, hover, mở file Excel).
- `[TỰ ĐỘNG]` — phù hợp RSpec (model/service/request/system spec).
- `[CẢ HAI]` — thủ công verify giao diện + automation verify logic.

### 3.3. Số liệu

- kW: 2 chữ số thập phân; tiền: 0 chữ số thập phân; phân cách tiếng Việt (dấu chấm hàng nghìn, dấu phẩy thập phân).
- Làm tròn ROUND_HALF_UP, chỉ khi hiển thị/xuất Excel. Số chính xác (chưa làm tròn) ghi kèm khi cần.
- Hàng tổng/tổng trừ tính từ giá trị chính xác rồi làm tròn — có thể chênh ±0,01 so với cộng tay số đã làm tròn (hành vi đúng).

### 3.4. Cross-reference

Mỗi kịch bản (đặc biệt Phần 3, 4) ghi: chiều CHIEU_TEST liên quan + (nếu có) file RSpec automation. Không chép lại nội dung CHIEU_TEST — chỉ trỏ tới.

---

## 4. Cấu trúc 6 phần (Lựa chọn 1)

### Phần 0 — Mở đầu

Mục đích; quan hệ với 3 doc kia (bảng ở mục 1); quy ước (mục 3); cập nhật version nguồn (NGHIEP_VU v2.13.0, THIET_KE v2.13.0, HANH_VI v1.2.0, CHIEU_TEST v1.2.0). Mục lục.

### Phần 1 — Dữ liệu mẫu (2 khu vực)

- **1A. Khu vực 1** — khớp 100% `setup_zone_one_full_sample`:
  - Cấu hình chung (đơn giá 2.336,4; tiết kiệm Bộ 5%; công cộng Sư đoàn 10%; bơm nước 9,45).
  - 7 nhóm cấp bậc mặc định (570, 440, 305, 130, 210, 110, 24).
  - Cấu trúc: Đơn vị A (manager, công cộng 3%), Đơn vị B (0%); khối "Phòng Tham mưu", nhóm "Ban Tác huấn"; 5 CP sinh hoạt (Ban Tác huấn, Văn thư, Kho vật tư, Đại đội 1, Chỉ huy khu vực), 3 công cộng (Nhà ăn, Trạm gác, Đèn đường), bơm nước (Trạm bơm 1), ngoài biên chế (Thợ xây, 5 người).
  - Quân số, chỉ số công tơ (9 công tơ + CT-Tổng 2.100), cột Khác, phân bổ bơm nước — đúng `sample_data.rb`.
- **1B. Khu vực 2 (mới)** — thiết kế tối thiểu nhưng đủ cover các giao điểm cần multi-zone. Shape đề xuất (số cụ thể chốt sau khi chạy engine):
  - Main meter CT-Tổng-KV2.
  - **Đơn vị C** (manager KV2), **Đơn vị D** (non-manager).
  - CP sinh hoạt Đơn vị C có khối "Phòng Chính trị" + nhóm (cho merge); CP sinh hoạt Đơn vị D trực tiếp (không khối/nhóm); CP sinh hoạt thuộc khu vực trực tiếp; 1 công cộng; 1 bơm nước. (Cân nhắc 1 ngoài biên chế nếu cần cho GD2.)
  - Mục tiêu cover: SA zone/unit filter (2 khu vực, nhiều đơn vị); cách ly cross-zone; UA-ZM (adminC) vs UA (adminD); CMD-ZM (chiHuyC) vs CMD (chiHuyD); CP thuộc khu vực trực tiếp; vị trí phân cấp khác KV1.
- **1C. Tài khoản (6 vai trò × 2 khu vực).** Bổ sung CMD/CMD-ZM (file cũ thiếu):

  | Tài khoản | role | Đơn vị | Vai trò thực tế |
  |---|---|---|---|
  | kyThuat | technician | — | TECH |
  | quanTri | system_admin | — | SA |
  | adminA | unit_admin | Đơn vị A (manager KV1) | UA-ZM |
  | adminB | unit_admin | Đơn vị B | UA |
  | chiHuyA | commander | Đơn vị A | CMD-ZM |
  | chiHuyB | commander | Đơn vị B | CMD |
  | adminC | unit_admin | Đơn vị C (manager KV2) | UA-ZM |
  | adminD | unit_admin | Đơn vị D | UA |
  | chiHuyC | commander | Đơn vị C | CMD-ZM |
  | chiHuyD | commander | Đơn vị D | CMD |

  (KV1 cung cấp đủ 6 vai trò; KV2 lặp lại UA-ZM/UA/CMD-ZM/CMD để test cách ly và filter cross-zone.)

### Phần 2 — Golden numbers từ engine (verify bằng engine thật)

Cho **cả KV1 và KV2**, lấy trực tiếp từ `CalculationOrchestrator`:

- Tổn hao (LossCalculator): A, B, C; tổn hao per công tơ; tổn hao per đầu mối.
- Bơm nước (PumpAllocationCalculator): D; phân bổ per đối tượng (% cố định + hệ số); từ đơn vị xuống đầu mối.
- Tổng hợp (SummaryCalculator): per đầu mối sinh hoạt (đầy đủ 20+ cột calculations); thừa/thiếu + thành tiền.
- Hàng tổng.

Mỗi giá trị ghi **số chính xác (công thức)** + **số hiển thị (đã làm tròn)**. Đây là nguồn số duy nhất; Phần 3–5 trỏ về, không tính lại.

### Phần 3 — Kịch bản giao điểm nguy hiểm (6 nhóm CHIEU_TEST)

Mỗi nhóm 1 suite; mỗi kịch bản: **điều kiện tiên quyết → các bước → kết quả mong đợi (số cụ thể)** + verify cả backend lẫn hiển thị.

- **GD1 — Kỳ × Vai trò × Entity state:** tạo CP kỳ N-1 → đóng → mở N → xóa CP → mở lại N-1 → 6 vai trò thấy gì (billing data, dropdown, recalculate); SA dropdown `with_discarded`.
- **GD2 — Kỳ × Loại đầu mối × Cleanup:** xóa từng loại (residential/public/water_pump/non_establishment) → verify data kỳ mở bị hard delete, kỳ cũ giữ nguyên; ảnh hưởng engine khi tính lại kỳ mở.
- **GD3 — Vai trò × Thuộc về × Trang:** CP thuộc đơn vị vs khu vực trực tiếp; ai thấy CP nào trên billing/meter_entries/unit_config; cột Đơn vị trống cho CP khu vực trực tiếp.
- **GD4 — Kỳ đang xem × Trạng thái tính toán × Vai trò:** chưa tính (bảng trống), stale (số cũ sau khi sửa), xuất Excel khi stale; SA mở kỳ cũ nhưng xem kỳ khác → recalculate disabled.
- **GD5 — Vị trí phân cấp × Định dạng output:** 5 vị trí CP (trực tiếp/khối/nhóm/nhóm-trong-khối/khu vực) → merge HTML rowspan + Excel merge; số cột theo role (SA 30, UA-ZM 29, UA 28) + Excel formula column index.
- **GD6 — Cách nhận data × Kỳ × Loại đầu mối:** tạo giữa kỳ (reading_start=0, personnel từ form, OD=0); thêm rank giữa kỳ; mở kỳ mới → kế thừa; main_meter_readings không kế thừa.

### Phần 4 — Walkthrough theo trang × 6 vai trò (test thủ công QA)

18 trang (theo ma trận CHIEU_TEST chiều 3). Mỗi trang × mỗi vai trò: expected output **cụ thể** — số cột, data rows (lấy số từ Phần 2), input state (disabled cho CMD/kỳ cũ), nút (can?()), cảnh báo, sidebar, trạng thái rỗng. Là instance hóa cụ thể, **không** chép ma trận CHIEU_TEST.

18 trang: dashboard, billing, history, electricity_supply, meter_entries, pump_entries, contact_points, blocks, groups, unit_config, zones, units, pump_allocations, pricing, ranks, users, audit_logs, backups.

### Phần 5 — Vận hành

- **Vòng đời kỳ:** mở kỳ đầu, mở kỳ mới (kế thừa, với số KV1 → kỳ kế tiếp), đóng kỳ (chặn nhập liệu), mở lại kỳ cũ (StructureChangeGuard, cảnh báo mismatch reading_end), tháng 12 → tháng 1.
- **CRUD/validation:** số liệu cụ thể cho các ràng buộc mục 24 nghiệp vụ (chỉ số ≥0, đơn giá >0, %≤100, phân bổ bơm nước, trùng tên, xóa công tơ cuối, xóa đơn vị có CP/tài khoản, xóa rank có quân số...).
- **Auth/hệ thống:** session 2h, đa thiết bị, đổi/reset mật khẩu (độ phức tạp), nhật ký, backup (tối đa 3), restore qua dòng lệnh.

### Phần 6 — Bản đồ truy vết

Bảng: mỗi kịch bản → chiều CHIEU_TEST + nhóm giao điểm + file RSpec automation (nếu lập được, qua quét `spec/`). Mục ghi chú automation (ưu tiên viết RSpec, test chỉ thủ công).

---

## 5. Workflow thực hiện (golden numbers verify bằng engine)

1. **Đọc engine code** (`app/services/` — LossCalculator, PumpAllocationCalculator, SummaryCalculator, CalculationOrchestrator) + factories (`spec/factories/`) để hiểu cách drive engine.
2. **Thiết kế KV2 cụ thể** (entities + số liệu input) — bổ sung helper vào `sample_data.rb` hoặc script tạm.
3. **Chạy engine trong Docker** (`bin/docker console` hoặc spec tạm) cho KV1 + KV2 → lấy calculations chính xác đến decimal.
4. **Ghi golden numbers** vào Phần 2.
5. **Viết Phần 0, 1, 3, 4, 5, 6** trỏ về golden numbers Phần 2.
6. **Quét `spec/`** lập bản đồ truy vết Phần 6.

Lưu ý: lệnh chạy lâu (>2 phút) phải hỏi trước hoặc chia nhỏ (theo feedback đã lưu).

---

## 6. Phạm vi và ranh giới

- **Trong phạm vi:** viết lại toàn bộ nội dung `docs/V2_KICH_BAN_TEST.md`. Có thể bổ sung helper `setup_zone_two_*` vào `spec/support/sample_data.rb` nếu cần để verify KV2 (chỉ thêm, không sửa `setup_zone_one_full_sample`).
- **Ngoài phạm vi:** không sửa code nghiệp vụ, không sửa 3 doc nguồn kia, không viết test RSpec mới (chỉ tham chiếu test đã có). Nếu phát hiện code/thiết kế mâu thuẫn nghiệp vụ → báo, không tự sửa.
- **Không tự mở rộng scope** ngoài việc viết lại doc + helper verify.

---

## 7. Tự kiểm (spec self-review)

- [ ] Không còn placeholder/TBD trong cấu trúc.
- [ ] Các phần không mâu thuẫn nhau; ID scheme nhất quán.
- [ ] Đủ tập trung cho 1 kế hoạch triển khai (1 file doc + helper verify).
- [ ] Không mơ hồ: golden numbers verify bằng engine (không tính tay cho số mới); KV1 khớp `sample_data.rb`; KV2 shape rõ, số chốt sau khi chạy engine.
- [ ] Cập nhật version nguồn lên v2.13.0 / v1.2.0.
