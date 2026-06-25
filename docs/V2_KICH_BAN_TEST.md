# V2 — Kịch bản kiểm thử (số liệu cụ thể)

> **Phiên bản:** 2.2.2
> **Ngày:** 25/06/2026
> **Nguồn nghiệp vụ:** `docs/V2_XAC_NHAN_NGHIEP_VU.md` v2.13.0
> **Nguồn thiết kế:** `docs/V2_THIET_KE_HE_THONG.md` v2.13.0
> **Nguồn hành vi runtime:** `docs/V2_HANH_VI_HE_THONG.md` v1.2.1
> **Nguồn không gian kiểm thử:** `docs/V2_CHIEU_TEST.md` v1.2.2
> **Tính chất:** Kịch bản số liệu cụ thể — instance hóa không gian kiểm thử của `V2_CHIEU_TEST.md` bằng dữ liệu thật cộng với golden numbers được kiểm chứng bằng engine. Tài liệu này KHÔNG lặp lại 12 chiều kiểm thử hay ma trận trang × vai trò của `V2_CHIEU_TEST.md`; nó chỉ trỏ tới các chiều đó và cung cấp số liệu cụ thể để kiểm chứng.

---

## Phần 0 — Mở đầu

### 0.1. Quan hệ trong bộ bốn tài liệu

| Tài liệu | Sở hữu |
|---|---|
| `V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ (cái gì) — nguồn sự thật |
| `V2_THIET_KE_HE_THONG.md` | Thiết kế (làm thế nào) |
| `V2_HANH_VI_HE_THONG.md` | Hành vi runtime (hành xử ra sao) |
| `V2_CHIEU_TEST.md` | **Không gian** kiểm thử — 12 chiều, đặc tả đầu vào và đầu ra trừu tượng, 6 nhóm giao điểm nguy hiểm |
| **`V2_KICH_BAN_TEST.md` (tài liệu này)** | **Kịch bản số liệu cụ thể** — instance hóa không gian của `V2_CHIEU_TEST.md` bằng dữ liệu thật cộng với golden numbers. Không lặp lại 12 chiều hay ma trận. |

### 0.2. Quy ước

#### 0.2.1. Mã kịch bản (theo nhóm)

| Tiền tố | Nhóm | Ví dụ |
|---|---|---|
| `DATA` | Dữ liệu mẫu (Phần 1) | DATA-KV1, DATA-KV2 |
| `EN` | Engine golden numbers (Phần 2) | EN-KV1-LOSS, EN-KV2-SUMMARY |
| `GD1`–`GD6` | 6 nhóm giao điểm nguy hiểm (Phần 3) | GD1-01, GD4-03 |
| `TR` | Walkthrough theo trang × vai trò (Phần 4) | TR-billing-SA, TR-meter_entries-UAZM |
| `VH` | Vận hành: vòng đời kỳ, CRUD, xác thực, sao lưu (Phần 5) | VH-period-01, VH-validation-05 |

#### 0.2.2. Thẻ loại kiểm thử

- `[THỦ CÔNG]` — chỉ kiểm tra bằng mắt (giao diện, gộp ô theo chiều dọc, di chuột, mở tập tin Excel).
- `[TỰ ĐỘNG]` — phù hợp với RSpec (model, service, request, hoặc system spec).
- `[CẢ HAI]` — vừa kiểm tra giao diện bằng tay vừa kiểm chứng logic bằng automation.

#### 0.2.3. Số liệu

- Số điện (đơn vị kW): 2 chữ số thập phân. Tiền (đơn vị đồng): 0 chữ số thập phân.
- Phân cách kiểu Việt Nam: dấu chấm phân tách hàng nghìn, dấu phẩy phân tách phần thập phân. Ví dụ: 2.336,4 và 9,45.
- Làm tròn ROUND_HALF_UP (số 5 làm tròn lên), chỉ áp dụng khi hiển thị hoặc xuất Excel. Không làm tròn giữa quá trình tính toán. Số chính xác (chưa làm tròn) ghi kèm khi cần.
- Hàng tổng và hàng tổng trừ được tính từ giá trị chính xác rồi mới làm tròn, nên có thể chênh tối đa 0,01 so với việc cộng tay các số đã làm tròn. Đây là hành vi đúng.

#### 0.2.4. Tham chiếu chéo

Mỗi kịch bản (đặc biệt ở Phần 3 và Phần 4) ghi: chiều kiểm thử liên quan trong `V2_CHIEU_TEST.md` cộng với (nếu có) tập tin RSpec tương ứng. Tài liệu này không chép lại nội dung của `V2_CHIEU_TEST.md`, chỉ trỏ tới.

### 0.3. Mục lục

- **Phần 0 — Mở đầu**
- **Phần 1 — Dữ liệu mẫu (2 khu vực)**
- **Phần 2 — Golden numbers từ engine**
- **Phần 3 — Kịch bản giao điểm nguy hiểm (6 nhóm)**
- **Phần 4 — Walkthrough theo trang × vai trò**
- **Phần 5 — Vận hành**
- **Phần 6 — Bản đồ truy vết**
- **Lịch sử thay đổi**

---

## Phần 1 — Dữ liệu mẫu (2 khu vực)

Toàn bộ số liệu đầu vào trong phần này khớp 100% với `spec/support/sample_data.rb`: Khu vực 1 từ `setup_zone_one_full_sample`, Khu vực 2 từ `setup_zone_two_full_sample`. Phần này chỉ ghi **dữ liệu đầu vào**; các con số tính toán (tổn hao, thành tiền, thừa hoặc thiếu) nằm ở Phần 2.

Cả hai khu vực dùng chung một kỳ tính toán đang mở: kỳ tháng 5 năm 2026.

### 1A. Khu vực 1 (DATA-KV1)

#### 1A.1. Cấu hình chung

| Tham số | Giá trị |
|---|---|
| Kỳ tính toán | Tháng 5 năm 2026 (đang mở) |
| Đơn giá điện | 2.336,4 đồng/kW |
| Tỷ lệ tiết kiệm của Bộ | 5% |
| Tỷ lệ công cộng dùng chung Sư đoàn | 10% |
| Tiêu chuẩn điện bơm nước | 9,45 kW/người/tháng |

#### 1A.2. Bảy nhóm cấp bậc và định mức

| Nhóm cấp bậc | Định mức (kW/người/tháng) |
|---|---|
| Chỉ huy Sư đoàn; sĩ quan có trần quân hàm là Đại tá | 570 |
| Chỉ huy Trung đoàn; sĩ quan có trần quân hàm là Thượng tá | 440 |
| Chỉ huy Tiểu đoàn; sĩ quan có trần quân hàm là Trung tá, Thiếu tá | 305 |
| Chỉ huy Đại đội, Trung đội; sĩ quan có trần quân hàm là cấp Úy | 130 |
| Cơ quan Sư đoàn, Trung đoàn | 210 |
| Tiểu đoàn, Đại đội | 110 |
| Hạ sĩ quan, binh sĩ | 24 |

Bảy nhóm cấp bậc và định mức là dữ liệu mặc định toàn hệ thống, dùng chung cho cả Khu vực 1 và Khu vực 2.

#### 1A.3. Cấu trúc tổ chức

```
Khu vực 1  (công tơ tổng: CT-Tổng-KV1)
│
├── Đơn vị A  (quản lý Khu vực 1; tỷ lệ công cộng đơn vị 3%)
│   │
│   ├── Khối "Phòng Tham mưu"
│   │   ├── Nhóm "Ban Tác huấn"
│   │   │   └── Đầu mối sinh hoạt "Ban Tác huấn"  (trong nhóm)
│   │   └── Đầu mối sinh hoạt "Văn thư"  (trong khối, không thuộc nhóm)
│   │
│   ├── Đầu mối sinh hoạt "Kho vật tư"  (trực tiếp đơn vị, không khối không nhóm)
│   └── Đầu mối công cộng "Nhà ăn"
│
├── Đơn vị B  (tỷ lệ công cộng đơn vị 0%)
│   ├── Đầu mối sinh hoạt "Đại đội 1"  (trực tiếp đơn vị)
│   └── Đầu mối công cộng "Trạm gác"
│
├── Đầu mối sinh hoạt "Chỉ huy khu vực"  (thuộc khu vực trực tiếp)
├── Đầu mối công cộng "Đèn đường"  (thuộc khu vực)
├── Đầu mối bơm nước "Trạm bơm 1"  (thuộc khu vực)
└── Đầu mối ngoài biên chế "Thợ xây"  (thuộc khu vực, 5 người)
```

Bốn vị trí phân cấp của đầu mối sinh hoạt xuất hiện ở Khu vực 1: trong nhóm thuộc khối (Ban Tác huấn), trong khối không thuộc nhóm (Văn thư), trực tiếp dưới đơn vị không khối không nhóm (Kho vật tư và Đại đội 1), và thuộc khu vực trực tiếp (Chỉ huy khu vực).

#### 1A.4. Quân số đầu mối sinh hoạt theo nhóm cấp bậc

| Đầu mối | Nhóm cấp bậc | Quân số | Tổng |
|---|---|---|---|
| Ban Tác huấn | Tiểu đoàn, Đại đội (110) | 2 | 5 |
| | Hạ sĩ quan, binh sĩ (24) | 3 | |
| Văn thư | Cơ quan Sư đoàn, Trung đoàn (210) | 1 | 2 |
| | Hạ sĩ quan, binh sĩ (24) | 1 | |
| Kho vật tư | Chỉ huy Đại đội, Trung đội; cấp Úy (130) | 1 | 3 |
| | Hạ sĩ quan, binh sĩ (24) | 2 | |
| Đại đội 1 | Chỉ huy Đại đội, Trung đội; cấp Úy (130) | 1 | 11 |
| | Hạ sĩ quan, binh sĩ (24) | 10 | |
| Chỉ huy khu vực | Chỉ huy Sư đoàn; Đại tá (570) | 1 | 1 |

Đầu mối ngoài biên chế "Thợ xây" có quân số là một con số tổng (5 người), không phân theo nhóm cấp bậc.

#### 1A.5. Chỉ số công tơ

| Công tơ | Đầu mối | Chỉ số đầu kỳ | Chỉ số cuối kỳ | Số điện sử dụng | Không tổn hao |
|---|---|---|---|---|---|
| CT-A1 | Ban Tác huấn | 1.000 | 1.250 | 250 | Không |
| CT-A2 | Văn thư | 500 | 680 | 180 | Không |
| CT-A3 | Kho vật tư | 200 | 310 | 110 | **Có** |
| CT-CC-A | Nhà ăn | 300 | 520 | 220 | Không |
| CT-B1 | Đại đội 1 | 2.000 | 2.350 | 350 | Không |
| CT-CC-B | Trạm gác | 100 | 150 | 50 | Không |
| CT-KV1 | Chỉ huy khu vực | 800 | 1.250 | 450 | Không |
| CT-CC-KV | Đèn đường | 400 | 530 | 130 | Không |
| CT-BN1 | Trạm bơm 1 | 600 | 900 | 300 | Không |

Công tơ tổng **CT-Tổng-KV1**: số điện sử dụng 2.100 kW (nhập trực tiếp số sử dụng, không qua chỉ số đầu kỳ và cuối kỳ).

Công tơ CT-A3 của đầu mối "Kho vật tư" được đánh dấu không tổn hao: số điện của công tơ này không tham gia vào mẫu số tính tỷ lệ tổn hao.

#### 1A.6. Cột "Khác"

| Đầu mối | Loại | Giá trị |
|---|---|---|
| Ban Tác huấn | Cố định | 5 |
| Văn thư | Hệ số | −2,5 |
| Kho vật tư | Cố định | 0 |
| Đại đội 1 | Hệ số | 3 |
| Chỉ huy khu vực | Cố định | 0 |

#### 1A.7. Phân bổ bơm nước (Trạm bơm 1)

| Đối tượng phân bổ | Phần trăm cố định | Hệ số |
|---|---|---|
| Chỉ huy khu vực (đầu mối) | 20% | 1 |
| Đơn vị A | — | 1 |
| Đơn vị B | — | 1 |
| Thợ xây (đầu mối ngoài biên chế) | — | 0,5 |

> **Ghi chú DATA-KV1:** Khu vực 1 đã bao phủ bốn loại đầu mối (sinh hoạt, công cộng, bơm nước, ngoài biên chế), công tơ không tổn hao (CT-A3), bốn trên năm vị trí phân cấp của đầu mối sinh hoạt, và phân bổ bơm nước có kết hợp phần trăm cố định với hệ số.

### 1B. Khu vực 2 (DATA-KV2)

Khu vực 2 là dữ liệu mới, gọn nhất có thể, chỉ lấp những lỗ hổng mà Khu vực 1 chưa bao phủ. Khu vực 2 dùng cùng kỳ tháng 5 năm 2026, cùng đơn giá 2.336,4 đồng/kW, cùng tỷ lệ tiết kiệm của Bộ 5% và tỷ lệ công cộng dùng chung Sư đoàn 10%, cùng bảy nhóm cấp bậc.

#### 1B.1. Cấu trúc tổ chức

```
Khu vực 2  (công tơ tổng: CT-Tổng-KV2)
│
├── Đơn vị C  (quản lý Khu vực 2; tỷ lệ công cộng đơn vị 5%)
│   │
│   ├── Nhóm "Tổ Quân y"  (trực tiếp dưới đơn vị, KHÔNG thuộc khối)
│   │   └── Đầu mối sinh hoạt "Quân y"  (trong nhóm, không khối)
│   └── Đầu mối công cộng "Nhà ăn 2"
│
├── Đơn vị D  (tỷ lệ công cộng đơn vị 0%)
│   └── Đầu mối sinh hoạt "Trinh sát"  (trực tiếp đơn vị)
│
├── Đầu mối sinh hoạt "Chỉ huy khu vực 2"  (thuộc khu vực trực tiếp)
└── Đầu mối bơm nước "Trạm bơm 2"  (thuộc khu vực)
```

Đầu mối "Quân y" nằm trong nhóm "Tổ Quân y" mà nhóm này trực tiếp dưới đơn vị, không thuộc khối nào. Đây là **vị trí phân cấp thứ ba** theo V2_CHIEU_TEST chiều 10 (nhóm trực tiếp dưới đơn vị, không khối) — vị trí duy nhất mà Khu vực 1 không có.

#### 1B.2. Quân số đầu mối sinh hoạt theo nhóm cấp bậc

| Đầu mối | Nhóm cấp bậc | Quân số | Tổng |
|---|---|---|---|
| Quân y | Chỉ huy Đại đội, Trung đội; cấp Úy (130) | 1 | 5 |
| | Hạ sĩ quan, binh sĩ (24) | 4 | |
| Trinh sát | Tiểu đoàn, Đại đội (110) | 2 | 8 |
| | Hạ sĩ quan, binh sĩ (24) | 6 | |
| Chỉ huy khu vực 2 | Chỉ huy Trung đoàn; Thượng tá (440) | 1 | 1 |

#### 1B.3. Chỉ số công tơ

| Công tơ | Đầu mối | Chỉ số đầu kỳ | Chỉ số cuối kỳ | Số điện sử dụng | Không tổn hao |
|---|---|---|---|---|---|
| CT-QY | Quân y | 0 | 150 | 150 | Không |
| CT-TS | Trinh sát | 1.000 | 1.300 | 300 | Không |
| CT-CHKV2 | Chỉ huy khu vực 2 | 200 | 550 | 350 | Không |
| CT-CC-C | Nhà ăn 2 | 0 | 120 | 120 | Không |
| CT-BN2 | Trạm bơm 2 | 0 | 150 | 150 | Không |

Công tơ tổng **CT-Tổng-KV2**: số điện sử dụng 1.100 kW.

#### 1B.4. Cột "Khác"

| Đầu mối | Loại | Giá trị |
|---|---|---|
| Quân y | Cố định | 0 |
| Trinh sát | Cố định | 0 |
| Chỉ huy khu vực 2 | Cố định | 0 |

Tất cả cột "Khác" của Khu vực 2 đều cố định bằng 0.

#### 1B.5. Phân bổ bơm nước (Trạm bơm 2)

| Đối tượng phân bổ | Phần trăm cố định | Hệ số |
|---|---|---|
| Đơn vị C | — | 1 |
| Đơn vị D | — | 1 |
| Chỉ huy khu vực 2 (đầu mối) | — | 1 |

Phân bổ bơm nước Khu vực 2 là **thuần hệ số**: không có đối tượng nào có phần trăm cố định, tổng phần trăm cố định bằng 0.

> **Ghi chú DATA-KV2:** Khu vực 2 bổ sung những lỗ hổng mà Khu vực 1 không có: vị trí phân cấp thứ ba theo V2_CHIEU_TEST chiều 10 (nhóm trực tiếp dưới đơn vị, không khối), bối cảnh đa khu vực (quản trị viên hệ thống lọc theo khu vực, cách ly dữ liệu giữa hai khu vực, phân biệt UA-ZM/CMD-ZM và UA/CMD giữa các khu vực), và phân bổ bơm nước thuần hệ số (tổng phần trăm cố định bằng 0 — nhánh code khác với Khu vực 1). Khu vực 2 KHÔNG có đầu mối ngoài biên chế và KHÔNG có công tơ không tổn hao, vì Khu vực 1 đã bao phủ hai trường hợp này.

### 1C. Tài khoản (7 vai trò × 2 khu vực)

| Tên đăng nhập | role | Đơn vị | Vai trò thực tế |
|---|---|---|---|
| kyThuat | technician | — | TECH |
| quanTri | system_admin | — | SA |
| chiHuySuDoan | division_commander | — | DC |
| adminA | unit_admin | Đơn vị A (quản lý Khu vực 1) | UA-ZM |
| adminB | unit_admin | Đơn vị B | UA |
| chiHuyA | commander | Đơn vị A | CMD-ZM |
| chiHuyB | commander | Đơn vị B | CMD |
| adminC | unit_admin | Đơn vị C (quản lý Khu vực 2) | UA-ZM |
| adminD | unit_admin | Đơn vị D | UA |
| chiHuyC | commander | Đơn vị C | CMD-ZM |
| chiHuyD | commander | Đơn vị D | CMD |

Hệ thống có nhiều vai trò thực tế hơn số enum trong database — định nghĩa đầy đủ và phạm vi từng vai trò: xem `V2_HANH_VI_HE_THONG.md` mục 1. Bảng dưới ánh xạ tài khoản test → vai trò thực tế; ký hiệu viết tắt (SA, DC, UA-ZM...) tra tại `docs/THUAT_NGU.md` mục 1.

Khu vực 1 cung cấp đủ mọi vai trò (DC chỉ cần 1 tài khoản — scope toàn hệ thống, không phân biệt khu vực); Khu vực 2 lặp lại bốn vai trò UA-ZM, UA, CMD-ZM, CMD để kiểm thử cách ly dữ liệu và lọc theo khu vực giữa hai khu vực.

---

## Phần 2 — Golden numbers từ engine

Phần này là **nguồn số duy nhất** của toàn tài liệu: mọi con số tính toán (tổn hao, phân bổ bơm nước, tiêu chuẩn, khoản trừ, thừa hoặc thiếu, thành tiền) đều xuất ra từ engine và được ghi ở đây. Các phần sau (Phần 3, Phần 4, Phần 5) trỏ về Phần 2 chứ không tính lại.

### 2.0. Nguồn gốc số liệu (provenance)

- Tất cả số liệu sinh ra bằng `CalculationOrchestrator.new(zone:, period:).call` chạy trên dữ liệu mẫu của Phần 1: Khu vực 1 từ `setup_zone_one_full_sample`, Khu vực 2 từ `setup_zone_two_full_sample(period:)`. Cả hai khu vực dựng trong **cùng một kỳ tính toán đang mở** (tháng 5 năm 2026, đơn giá 2.336,4 đồng/kW, công tơ tổng Khu vực 1 = 2.100 kW, công tơ tổng Khu vực 2 = 1.100 kW). Engine không trả cảnh báo cho cả hai khu vực.
- **Khu vực 1** đã được kiểm chứng bằng các bộ RSpec hiện có: `spec/services/loss_calculator_spec.rb`, `spec/services/pump_allocation_calculator_spec.rb`, `spec/services/summary_calculator_spec.rb`, `spec/services/calculation_orchestrator_spec.rb`.
- **Khu vực 2** được sinh ra bằng cách chạy `CalculationOrchestrator` trên `setup_zone_two_full_sample` — cùng engine, cùng kỳ. Các con số Khu vực 2 do đó cũng là golden numbers engine-verified.

### 2.1. Quy tắc làm tròn áp dụng trong Phần 2

- Mọi giá trị tính toán được in ra ở dạng **chính xác (chưa làm tròn)** từ `BigDecimal`. Tài liệu ghi kèm **giá trị hiển thị** đã làm tròn theo quy tắc ROUND_HALF_UP.
- Số điện (đơn vị kW): 2 chữ số thập phân.
- Tiền (đơn vị đồng): 0 chữ số thập phân.
- Quân số (`total_personnel`) là cột số nguyên, không làm tròn.
- Phân cách kiểu Việt Nam: dấu chấm phân tách hàng nghìn, dấu phẩy phân tách phần thập phân.
- Số chính xác chỉ ghi kèm khi cần truy vết (tổn hao, phân bổ bơm nước). Các bảng tổng hợp dùng giá trị hiển thị; số chính xác đầy đủ nằm trong tập tin golden numbers nội bộ và trong các bộ RSpec.

---

## 2A. Khu vực 1 (EN-KV1)

### EN-KV1-LOSS — Tổn hao `[TỰ ĐỘNG]`

**Công thức (tóm tắt, xem `V2_THIET_KE_HE_THONG.md` mục Engine tính toán):**

- A = tổng sử dụng công tơ tổng − tổng sử dụng các công tơ **không tổn hao**.
- B = tổng sử dụng các công tơ **có tổn hao** (sinh hoạt + công cộng + bơm nước).
- C = A − B (tổng tổn hao toàn khu vực).
- Tổn hao công tơ = sử dụng công tơ × C ÷ B.
- Tổn hao đầu mối = tổng tổn hao các công tơ trong đầu mối.

**Giá trị A, B, C của Khu vực 1:**

| Đại lượng | Giá trị |
|---|---|
| A (công tơ tổng − không tổn hao) | 1.990,00 |
| B (tổng sử dụng có tổn hao) | 1.930,00 |
| C (tổng tổn hao = A − B) | 60,00 |

Công tơ CT-A3 (đầu mối Kho vật tư) là công tơ không tổn hao: sử dụng 110 kW của nó bị trừ khỏi A và không tính vào B. Do đó A = 2.100 − 110 = 1.990; B = tổng sử dụng 8 công tơ có tổn hao = 1.930.

**Tổn hao per công tơ:**

| Công tơ | Đầu mối | Sử dụng (kW) | Số chính xác | Tổn hao hiển thị (kW) |
|---|---|---|---|---|
| CT-A1 | Ban Tác huấn | 250 | 7,7720207253886010362694300518135 | 7,77 |
| CT-A2 | Văn thư | 180 | 5,5958549222797927461139896373057 | 5,60 |
| CT-A3 | Kho vật tư | 110 | 0,0 | 0,00 |
| CT-B1 | Đại đội 1 | 350 | 10,880829015544041450777202072539 | 10,88 |
| CT-BN1 | Trạm bơm 1 | 300 | 9,3264248704663212435233160621762 | 9,33 |
| CT-CC-A | Nhà ăn | 220 | 6,8393782383419689119170984455959 | 6,84 |
| CT-CC-B | Trạm gác | 50 | 1,5544041450777202072538860103627 | 1,55 |
| CT-CC-KV | Đèn đường | 130 | 4,041450777202072538860103626943 | 4,04 |
| CT-KV1 | Chỉ huy khu vực | 450 | 13,989637305699481865284974093264 | 13,99 |

Công tơ CT-A3 có tổn hao bằng 0,00 vì là công tơ không tổn hao.

**Tổn hao per đầu mối sinh hoạt** (tổng tổn hao các công tơ trong đầu mối):

| Đầu mối | Tổn hao hiển thị (kW) |
|---|---|
| Ban Tác huấn | 7,77 |
| Văn thư | 5,60 |
| Kho vật tư | 0,00 |
| Đại đội 1 | 10,88 |
| Chỉ huy khu vực | 13,99 |

(Tổn hao các đầu mối không sinh hoạt — Nhà ăn 6,84; Trạm gác 1,55; Đèn đường 4,04; Trạm bơm 1 9,33 — không lên bảng tính tiền nhưng tham gia engine: tổn hao công tơ bơm nước cộng vào D ở bước sau.)

### EN-KV1-PUMP — Phân bổ bơm nước `[TỰ ĐỘNG]`

**Công thức (tóm tắt):**

- D = sử dụng thô công tơ bơm nước + tổn hao công tơ bơm nước.
- Bước 1: đối tượng có phần trăm cố định nhận D × phần trăm ÷ 100.
- Bước 2: phần còn lại (D − tổng phần cố định) chia theo trọng số = quân số × hệ số.
- Đơn vị nhận xong chia tiếp xuống từng đầu mối sinh hoạt trong đơn vị theo quân số.

**Giá trị D của Khu vực 1:**

| Đại lượng | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| D (tổng điện bơm nước) | 309,3264248704663212435233160621762 | 309,33 |

D = 300 (sử dụng thô CT-BN1) + 9,3264248704663212435233160621762 (tổn hao CT-BN1) = 309,33 (hiển thị).

**Phân bổ per đối tượng:**

Chỉ huy khu vực (đầu mối thuộc khu vực) nhận 20% cố định trước; phần còn lại chia theo hệ số × quân số cho Đơn vị A, Đơn vị B, và đầu mối ngoài biên chế Thợ xây.

| Đối tượng phân bổ | Quy tắc | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|---|
| Chỉ huy khu vực (đầu mối) | 20% cố định | 61,86528497409326424870466321243524 | 61,87 |
| Đơn vị A | hệ số | (tổng đầu mối, xem dưới) | 105,30 |
| Đơn vị B | hệ số | (tổng đầu mối, xem dưới) | 115,83 |
| Thợ xây (ngoài biên chế) | hệ số | 26,325653180465218829236026898908612765957446808511 | 26,33 |

Tổng phân bổ của một đơn vị bằng tổng phần phân bổ xuống các đầu mối sinh hoạt của đơn vị đó (engine ghi phân bổ ở mức đầu mối; mức đơn vị suy ra bằng cách cộng các đầu mối).

**Đơn vị A** (tổng 105,30 kW = tổng ba đầu mối sinh hoạt):

| Đầu mối | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| Ban Tác huấn | 52,6513063609304376584720537978172255319148936170215 | 52,65 |
| Văn thư | 21,0605225443721750633888215191268902127659574468086 | 21,06 |
| Kho vật tư | 31,5907838165582625950832322786903353191489361702129 | 31,59 |
| **Tổng Đơn vị A** | — | **105,30** |

**Đơn vị B** (tổng 115,83 kW, chỉ có một đầu mối sinh hoạt):

| Đầu mối | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| Đại đội 1 | 115,8328739940469628486385183551978961702127659574468 | 115,83 |
| **Tổng Đơn vị B** | — | **115,83** |

### EN-KV1-SUMMARY — Tổng hợp per đầu mối sinh hoạt `[TỰ ĐỘNG]`

Mỗi bảng dưới đây là một dòng đầy đủ trên bảng tính tiền của một đầu mối sinh hoạt. Giá trị đã làm tròn hiển thị (kW: 2 chữ số thập phân; tiền: 0 chữ số thập phân). Quy ước cột "Thừa/Thiếu": dương = thiếu (thâm điện, phải thu); âm hoặc bằng 0 thể hiện ở cột thừa (số dương).

#### EN-KV1-SUMMARY-01 — Ban Tác huấn

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 292,00 |
| Tiêu chuẩn bơm nước (kW) | 47,25 |
| Tổng tiêu chuẩn (kW) | 339,25 |
| Tiết kiệm của Bộ (kW) | 16,96 |
| Tổn hao (kW) | 7,77 |
| Công cộng Sư đoàn (kW) | 33,93 |
| Công cộng đơn vị (kW) | 10,18 |
| Khác (kW) | 5,00 |
| Tổng trừ (kW) | 73,84 |
| Tiêu chuẩn còn lại (kW) | 265,41 |
| Sử dụng sinh hoạt (kW) | 250,00 |
| Sử dụng bơm nước (kW) | 52,65 |
| Tổng sử dụng (kW) | 302,65 |
| Thừa/Thiếu (kW) | thiếu 37,24 |
| Thành tiền (đồng) | 87.004 |

> **Điểm kiểm tra:** đầu mối thuộc nhóm trong khối (vị trí phân cấp đầy đủ nhất), cột Khác cố định dương (+5), công cộng đơn vị 3% > 0 → tổng trừ tăng, kết quả thiếu.

#### EN-KV1-SUMMARY-02 — Văn thư

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 234,00 |
| Tiêu chuẩn bơm nước (kW) | 18,90 |
| Tổng tiêu chuẩn (kW) | 252,90 |
| Tiết kiệm của Bộ (kW) | 12,65 |
| Tổn hao (kW) | 5,60 |
| Công cộng Sư đoàn (kW) | 25,29 |
| Công cộng đơn vị (kW) | 7,59 |
| Khác (kW) | −5,00 |
| Tổng trừ (kW) | 46,12 |
| Tiêu chuẩn còn lại (kW) | 206,78 |
| Sử dụng sinh hoạt (kW) | 180,00 |
| Sử dụng bơm nước (kW) | 21,06 |
| Tổng sử dụng (kW) | 201,06 |
| Thừa/Thiếu (kW) | thừa 5,72 |
| Thành tiền (đồng) | 13.368 |

> **Điểm kiểm tra:** cột Khác là hệ số âm (−2,5 × quân số 2 = −5,00) → tổng trừ giảm → tiêu chuẩn còn lại tăng → kết quả thừa. Đây là đầu mối nằm trong khối nhưng không thuộc nhóm.

#### EN-KV1-SUMMARY-03 — Kho vật tư

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 178,00 |
| Tiêu chuẩn bơm nước (kW) | 28,35 |
| Tổng tiêu chuẩn (kW) | 206,35 |
| Tiết kiệm của Bộ (kW) | 10,32 |
| Tổn hao (kW) | 0,00 |
| Công cộng Sư đoàn (kW) | 20,64 |
| Công cộng đơn vị (kW) | 6,19 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 37,14 |
| Tiêu chuẩn còn lại (kW) | 169,21 |
| Sử dụng sinh hoạt (kW) | 110,00 |
| Sử dụng bơm nước (kW) | 31,59 |
| Tổng sử dụng (kW) | 141,59 |
| Thừa/Thiếu (kW) | thừa 27,62 |
| Thành tiền (đồng) | 64.523 |

> **Điểm kiểm tra:** công tơ CT-A3 không tổn hao → cột Tổn hao = 0,00. Đầu mối trực tiếp dưới đơn vị (không khối, không nhóm). Sử dụng thấp hơn tiêu chuẩn còn lại → kết quả thừa.

#### EN-KV1-SUMMARY-04 — Đại đội 1

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 370,00 |
| Tiêu chuẩn bơm nước (kW) | 103,95 |
| Tổng tiêu chuẩn (kW) | 473,95 |
| Tiết kiệm của Bộ (kW) | 23,70 |
| Tổn hao (kW) | 10,88 |
| Công cộng Sư đoàn (kW) | 47,40 |
| Công cộng đơn vị (kW) | 0,00 |
| Khác (kW) | 33,00 |
| Tổng trừ (kW) | 114,97 |
| Tiêu chuẩn còn lại (kW) | 358,98 |
| Sử dụng sinh hoạt (kW) | 350,00 |
| Sử dụng bơm nước (kW) | 115,83 |
| Tổng sử dụng (kW) | 465,83 |
| Thừa/Thiếu (kW) | thiếu 106,86 |
| Thành tiền (đồng) | 249.659 |

> **Điểm kiểm tra:** đầu mối thuộc Đơn vị B có tỷ lệ công cộng đơn vị 0% → cột Công cộng đơn vị = 0,00. Cột Khác hệ số dương (3 × quân số 11 = 33,00). Kết quả thiếu lớn nhất khu vực.

#### EN-KV1-SUMMARY-05 — Chỉ huy khu vực

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 570,00 |
| Tiêu chuẩn bơm nước (kW) | 9,45 |
| Tổng tiêu chuẩn (kW) | 579,45 |
| Tiết kiệm của Bộ (kW) | 28,97 |
| Tổn hao (kW) | 13,99 |
| Công cộng Sư đoàn (kW) | 57,95 |
| Công cộng đơn vị (kW) | 0,00 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 100,91 |
| Tiêu chuẩn còn lại (kW) | 478,54 |
| Sử dụng sinh hoạt (kW) | 450,00 |
| Sử dụng bơm nước (kW) | 61,87 |
| Tổng sử dụng (kW) | 511,87 |
| Thừa/Thiếu (kW) | thiếu 33,32 |
| Thành tiền (đồng) | 77.855 |

> **Điểm kiểm tra:** đầu mối thuộc khu vực trực tiếp (không có đơn vị) → không có `unit_configs` → cột Công cộng đơn vị = 0,00. Nhận đúng phần bơm nước 20% cố định 61,87. Kết quả thiếu.

### EN-KV1-TOTALS — Hàng tổng `[TỰ ĐỘNG]`

Hàng tổng cộng trên các đầu mối sinh hoạt của Khu vực 1. Quân số là tổng cột số nguyên; các đại lượng kW và tiền được engine cộng từ giá trị chính xác rồi mới làm tròn, nên có thể chênh tối đa 0,01 so với việc cộng tay các số hiển thị (hành vi đúng theo mục 0.2.3).

| Chỉ tiêu | Giá trị |
|---|---|
| Tổng quân số (người) | 22 |
| Tiêu chuẩn sinh hoạt (kW) | 1.644,00 |
| Tiêu chuẩn bơm nước (kW) | 207,90 |
| Tổng tiêu chuẩn (kW) | 1.851,90 |
| Tiết kiệm của Bộ (kW) | 92,60 |
| Tổn hao (kW) | 38,24 |
| Công cộng Sư đoàn (kW) | 185,19 |
| Công cộng đơn vị (kW) | 23,96 |
| Khác (kW) | 33,00 |
| Tổng trừ (kW) | 372,98 |
| Tiêu chuẩn còn lại (kW) | 1.478,92 |
| Sử dụng sinh hoạt (kW) | 1.340,00 |
| Sử dụng bơm nước (kW) | 283,00 |
| Tổng sử dụng (kW) | 1.623,00 |
| Tổng thừa (kW) | 33,34 |
| Tổng thiếu (kW) | 177,42 |
| Tổng thành tiền thừa (đồng) | 77.891 |
| Tổng thành tiền thiếu (đồng) | 414.517 |

Tổng thừa và tổng thiếu là tổng cột theo các đầu mối sinh hoạt (một đầu mối chỉ đóng góp vào thừa **hoặc** thiếu, không cả hai). Tổng quân số 22 = 5 (Ban Tác huấn) + 1 (Chỉ huy khu vực) + 3 (Kho vật tư) + 2 (Văn thư) + 11 (Đại đội 1).

---

## 2B. Khu vực 2 (EN-KV2)

### EN-KV2-LOSS — Tổn hao `[TỰ ĐỘNG]`

**Công thức:** giống EN-KV1-LOSS.

**Giá trị A, B, C của Khu vực 2:**

| Đại lượng | Giá trị |
|---|---|
| A (công tơ tổng − không tổn hao) | 1.100,00 |
| B (tổng sử dụng có tổn hao) | 1.070,00 |
| C (tổng tổn hao = A − B) | 30,00 |

Khu vực 2 không có công tơ không tổn hao nên A = sử dụng công tơ tổng = 1.100; B = tổng sử dụng năm công tơ = 1.070; C = 30. Tỷ lệ tổn hao C ÷ A ≈ 2,7273%.

**Tổn hao per công tơ:**

| Công tơ | Đầu mối | Sử dụng (kW) | Số chính xác | Tổn hao hiển thị (kW) |
|---|---|---|---|---|
| CT-QY | Quân y | 150 | 4,2056074766355140186915887850467 | 4,21 |
| CT-TS | Trinh sát | 300 | 8,4112149532710280373831775700935 | 8,41 |
| CT-CHKV2 | Chỉ huy khu vực 2 | 350 | 9,8130841121495327102803738317757 | 9,81 |
| CT-CC-C | Nhà ăn 2 | 120 | 3,3644859813084112149532710280374 | 3,36 |
| CT-BN2 | Trạm bơm 2 | 150 | 4,2056074766355140186915887850467 | 4,21 |

**Tổn hao per đầu mối sinh hoạt:**

| Đầu mối | Tổn hao hiển thị (kW) |
|---|---|
| Quân y | 4,21 |
| Trinh sát | 8,41 |
| Chỉ huy khu vực 2 | 9,81 |

(Tổn hao Nhà ăn 2 = 3,36 và Trạm bơm 2 = 4,21 không lên bảng tính tiền; tổn hao Trạm bơm 2 cộng vào D.)

### EN-KV2-PUMP — Phân bổ bơm nước `[TỰ ĐỘNG]`

**Công thức:** giống EN-KV1-PUMP. Khu vực 2 là phân bổ **thuần hệ số** — tổng phần trăm cố định bằng 0, toàn bộ D chia theo trọng số quân số × hệ số.

**Giá trị D của Khu vực 2:**

| Đại lượng | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| D (tổng điện bơm nước) | 154,2056074766355140186915887850467 | 154,21 |

D = 150 (sử dụng thô CT-BN2) + 4,2056074766355140186915887850467 (tổn hao CT-BN2) = 154,21 (hiển thị).

**Phân bổ per đối tượng** (không có phần trăm cố định; toàn bộ theo hệ số):

| Đối tượng phân bổ | Quy tắc | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|---|
| Đơn vị C | hệ số | (tổng đầu mối, xem dưới) | 55,07 |
| Đơn vị D | hệ số | (tổng đầu mối, xem dưới) | 88,12 |
| Chỉ huy khu vực 2 (đầu mối) | hệ số | 11,01468624833110814419225634178905 | 11,01 |

**Đơn vị C** (tổng 55,07 kW, chỉ có một đầu mối sinh hoạt là Quân y):

| Đầu mối | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| Quân y | 55,07343124165554072096128170894525 | 55,07 |
| **Tổng Đơn vị C** | — | **55,07** |

**Đơn vị D** (tổng 88,12 kW, chỉ có một đầu mối sinh hoạt là Trinh sát):

| Đầu mối | Số chính xác | Giá trị hiển thị (kW) |
|---|---|---|
| Trinh sát | 88,1174899866488651535380507343124 | 88,12 |
| **Tổng Đơn vị D** | — | **88,12** |

### EN-KV2-SUMMARY — Tổng hợp per đầu mối sinh hoạt `[TỰ ĐỘNG]`

#### EN-KV2-SUMMARY-01 — Quân y

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 226,00 |
| Tiêu chuẩn bơm nước (kW) | 47,25 |
| Tổng tiêu chuẩn (kW) | 273,25 |
| Tiết kiệm của Bộ (kW) | 13,66 |
| Tổn hao (kW) | 4,21 |
| Công cộng Sư đoàn (kW) | 27,33 |
| Công cộng đơn vị (kW) | 13,66 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 58,86 |
| Tiêu chuẩn còn lại (kW) | 214,39 |
| Sử dụng sinh hoạt (kW) | 150,00 |
| Sử dụng bơm nước (kW) | 55,07 |
| Tổng sử dụng (kW) | 205,07 |
| Thừa/Thiếu (kW) | thừa 9,32 |
| Thành tiền (đồng) | 21.777 |

> **Điểm kiểm tra:** đầu mối nằm trong nhóm "Tổ Quân y" trực tiếp dưới đơn vị, không thuộc khối — vị trí phân cấp thứ ba (lỗ hổng mà Khu vực 1 không có). Công cộng đơn vị 5% > 0. Kết quả thừa.

#### EN-KV2-SUMMARY-02 — Trinh sát

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 364,00 |
| Tiêu chuẩn bơm nước (kW) | 75,60 |
| Tổng tiêu chuẩn (kW) | 439,60 |
| Tiết kiệm của Bộ (kW) | 21,98 |
| Tổn hao (kW) | 8,41 |
| Công cộng Sư đoàn (kW) | 43,96 |
| Công cộng đơn vị (kW) | 0,00 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 74,35 |
| Tiêu chuẩn còn lại (kW) | 365,25 |
| Sử dụng sinh hoạt (kW) | 300,00 |
| Sử dụng bơm nước (kW) | 88,12 |
| Tổng sử dụng (kW) | 388,12 |
| Thừa/Thiếu (kW) | thiếu 22,87 |
| Thành tiền (đồng) | 53.430 |

> **Điểm kiểm tra:** đầu mối thuộc Đơn vị D có tỷ lệ công cộng đơn vị 0% → cột Công cộng đơn vị = 0,00. Đầu mối trực tiếp dưới đơn vị. Kết quả thiếu.

#### EN-KV2-SUMMARY-03 — Chỉ huy khu vực 2

| Chỉ tiêu | Giá trị |
|---|---|
| Tiêu chuẩn sinh hoạt (kW) | 440,00 |
| Tiêu chuẩn bơm nước (kW) | 9,45 |
| Tổng tiêu chuẩn (kW) | 449,45 |
| Tiết kiệm của Bộ (kW) | 22,47 |
| Tổn hao (kW) | 9,81 |
| Công cộng Sư đoàn (kW) | 44,95 |
| Công cộng đơn vị (kW) | 0,00 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 77,23 |
| Tiêu chuẩn còn lại (kW) | 372,22 |
| Sử dụng sinh hoạt (kW) | 350,00 |
| Sử dụng bơm nước (kW) | 11,01 |
| Tổng sử dụng (kW) | 361,01 |
| Thừa/Thiếu (kW) | thừa 11,20 |
| Thành tiền (đồng) | 26.179 |

> **Điểm kiểm tra:** đầu mối thuộc khu vực trực tiếp → không có `unit_configs` → cột Công cộng đơn vị = 0,00. Nhóm cấp bậc Chỉ huy Trung đoàn (định mức 440). Kết quả thừa.

### EN-KV2-TOTALS — Hàng tổng `[TỰ ĐỘNG]`

Hàng tổng cộng trên các đầu mối sinh hoạt của Khu vực 2.

| Chỉ tiêu | Giá trị |
|---|---|
| Tổng quân số (người) | 14 |
| Tiêu chuẩn sinh hoạt (kW) | 1.030,00 |
| Tiêu chuẩn bơm nước (kW) | 132,30 |
| Tổng tiêu chuẩn (kW) | 1.162,30 |
| Tiết kiệm của Bộ (kW) | 58,12 |
| Tổn hao (kW) | 22,43 |
| Công cộng Sư đoàn (kW) | 116,23 |
| Công cộng đơn vị (kW) | 13,66 |
| Khác (kW) | 0,00 |
| Tổng trừ (kW) | 210,44 |
| Tiêu chuẩn còn lại (kW) | 951,86 |
| Sử dụng sinh hoạt (kW) | 800,00 |
| Sử dụng bơm nước (kW) | 154,21 |
| Tổng sử dụng (kW) | 954,21 |
| Tổng thừa (kW) | 20,53 |
| Tổng thiếu (kW) | 22,87 |
| Tổng thành tiền thừa (đồng) | 47.956 |
| Tổng thành tiền thiếu (đồng) | 53.430 |

Tổng quân số 14 = 1 (Chỉ huy khu vực 2) + 5 (Quân y) + 8 (Trinh sát). Tổng thừa và tổng thiếu là tổng cột theo các đầu mối sinh hoạt.

---

## Phần 3 — Kịch bản giao điểm nguy hiểm (6 nhóm)

Phần này instance hóa **6 nhóm giao điểm nguy hiểm** của `V2_CHIEU_TEST.md` (mục "Giao điểm nguy hiểm") bằng dữ liệu thật của Phần 1 và golden numbers của Phần 2. Mỗi suite ứng với một nhóm. Mỗi kịch bản trình bày theo cấu trúc: **Điều kiện tiên quyết → Các bước → Kết quả mong đợi** (kiểm cả phía sau lẫn hiển thị khi liên quan), kết thúc bằng dòng **Chiều liên quan** trỏ tới chiều và nhóm trong `V2_CHIEU_TEST.md`.

Quy ước số liệu của Phần 3:

- Mọi con số tính toán trích dẫn đều **trỏ về Phần 2** (golden numbers engine-verified) hoặc là **công thức một bước** (quân số × định mức cấp bậc). Phần 3 không tính lại.
- Khi một thao tác sửa cấu trúc hoặc dữ liệu làm engine phải tính lại nhiều bước (xóa đầu mối, thay đổi quân số tổng, phân bổ lại bơm nước), Phần 3 chỉ mô tả **hướng và cấu trúc** thay đổi (tăng/giảm, biến mất, chia lại), kèm ghi chú "(tính lại bằng engine)" — không bịa số thập phân không có trong Phần 2.

### GD1 — Kỳ × Vai trò × Trạng thái entity

Suite này instance hóa Nhóm 1 (giao điểm chiều 1 × 2 × 4 của `V2_CHIEU_TEST.md`). Dùng Khu vực 1.

**Bối cảnh chung của suite (dựng một lần, dùng cho mọi kịch bản GD1):**

```
Kỳ N-1 (tháng 5 năm 2026): toàn bộ dữ liệu mẫu Khu vực 1 (Phần 1A).
                           Tạo thêm đầu mối sinh hoạt "Lái xe" thuộc Đơn vị A
                           (trực tiếp dưới đơn vị, không khối không nhóm).
                           Nhập liệu → tính toán → đóng kỳ N-1.
Kỳ N   (tháng 6 năm 2026): mở kỳ mới (kế thừa toàn bộ entity .kept, gồm "Lái xe").
                           Xóa đầu mối "Lái xe" ở kỳ N.
                           Nhập liệu các đầu mối còn lại → tính toán → đóng kỳ N.
Mở lại kỳ N-1            : kỳ N-1 mở lại (trạng thái C — kỳ cũ mở lại).
```

Sau bước này, "Lái xe" ở trạng thái discarded (`discarded_at` có giá trị), nhưng dữ liệu per kỳ của nó ở kỳ N-1 vẫn còn (không bị cleanup vì lúc xóa ở kỳ N, chỉ dữ liệu kỳ N bị hard delete). Đây là kịch bản xuyên kỳ quan trọng nhất theo `V2_CHIEU_TEST.md` chiều 4.

#### GD1-01 — Quản trị viên hệ thống xem bảng tính tiền kỳ N-1 (đầu mối đã xóa vẫn hiện) `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1; đăng nhập quanTri (SA); kỳ N-1 đang mở lại.
- **Các bước:**
  1. Vào `/billing`, dropdown kỳ chọn kỳ N-1, dropdown khu vực chọn Khu vực 1.
- **Kết quả mong đợi:**
  - Phía sau: `Calculation.where(period: kỳ_N_1)` còn record của "Lái xe" (dữ liệu kỳ N-1 không bị cleanup) → "Lái xe" có dòng trên bảng. Năm đầu mối gốc giữ nguyên golden numbers Phần 2: Ban Tác huấn thiếu 37,24 (EN-KV1-SUMMARY-01), Văn thư thừa 5,72 (EN-KV1-SUMMARY-02), Kho vật tư thừa 27,62, Đại đội 1 thiếu 106,86, Chỉ huy khu vực thiếu 33,32 — vì việc tạo "Lái xe" ở kỳ N-1 không làm thay đổi tiêu chuẩn, sử dụng hay tổn hao của năm đầu mối đã có (engine tính trên dữ liệu đã chốt của kỳ N-1).
  - Hiển thị: bảng hiện 6 dòng đầu mối sinh hoạt (5 gốc + "Lái xe"). SA chọn Khu vực 1 → cột Khu vực ẩn (thừa), cột Đơn vị hiện; "Lái xe" hiện ở Đơn vị A, cột Khối/Nhóm trống (vị trí trực tiếp đơn vị).
  - Số chính xác dòng "Lái xe" không trích dẫn (không có trong Phần 2) — đây là kịch bản kiểm "đầu mối đã xóa vẫn hiện ở kỳ cũ", không phải kiểm số.
- **Chiều liên quan:** `V2_CHIEU_TEST.md` chiều 1 (trạng thái C), chiều 2 (SA), chiều 4 (discarded vẫn hiện ở kỳ cũ); Nhóm 1.

#### GD1-02 — Quản trị viên hệ thống xem bảng tính tiền kỳ N (đầu mối đã xóa không hiện) `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1; đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/billing`, dropdown kỳ chọn kỳ N, dropdown khu vực chọn Khu vực 1.
- **Kết quả mong đợi:**
  - Phía sau: `Calculation.where(period: kỳ_N)` KHÔNG có record "Lái xe" (đã cleanup khi xóa ở kỳ N) → không có dòng.
  - Hiển thị: bảng hiện 5 dòng đầu mối sinh hoạt gốc, không có "Lái xe". Không có placeholder hay dòng trống cho đầu mối đã xóa.
- **Chiều liên quan:** chiều 1 (trạng thái B/đóng), chiều 4 (discarded + cleanup → không hiện ở kỳ xóa); Nhóm 1.

#### GD1-03 — Dropdown khu vực/đơn vị của SA khi xem kỳ N-1 dùng `with_discarded` `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1, có biến thể: thay vì xóa đầu mối, dựng thêm kịch bản đã xóa **Đơn vị B** ở kỳ N (sau khi đã xóa hết đầu mối của Đơn vị B theo ràng buộc 23.1) để kiểm dropdown đơn vị; đăng nhập quanTri (SA); xem kỳ N-1.
- **Các bước:**
  1. Vào `/billing`, dropdown kỳ chọn kỳ N-1.
  2. Mở dropdown khu vực và dropdown đơn vị.
- **Kết quả mong đợi:**
  - Hiển thị: dropdown đơn vị của SA vẫn liệt kê Đơn vị B (đã xóa) vì dropdown dùng `.with_discarded` (theo `V2_HANH_VI_HE_THONG.md` mục 7) — SA cần chọn được entity đã xóa để xem dữ liệu kỳ cũ. Chọn Đơn vị B → bảng hiện đầu mối Đơn vị B của kỳ N-1 với golden numbers Phần 2 (Đại đội 1 thiếu 106,86).
  - Đối chiếu: trang quản lý/khai báo (`/contact_points`, `/units`) dùng `.kept` nên KHÔNG hiện entity đã xóa trong dropdown tạo mới — chỉ trang xem dữ liệu lịch sử (billing, history) dùng `.with_discarded`.
- **Chiều liên quan:** chiều 7 (dropdown zone/unit SA only, `with_discarded`), chiều 4; Nhóm 1.

#### GD1-04 — Sáu vai trò nghiệp vụ thấy gì trên billing kỳ N-1 vs kỳ N `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1; lần lượt đăng nhập 6 vai trò có quyền xem nghiệp vụ.
- **Các bước:** mỗi vai trò vào `/billing`, xem kỳ N-1 rồi xem kỳ N.
- **Kết quả mong đợi (đầu mối "Lái xe" thuộc Đơn vị A):**

  | Vai trò | Kỳ N-1 | Kỳ N |
  |---|---|---|
  | SA (quanTri) | Thấy "Lái xe" (chọn Khu vực 1 + Đơn vị A) | Không thấy "Lái xe" |
  | DC (chiHuySuDoan) | Thấy "Lái xe" (chọn Khu vực 1 + Đơn vị A, chỉ xem) | Không thấy "Lái xe" |
  | UA-ZM (adminA) | Thấy "Lái xe" (đầu mối Đơn vị A nằm trong phạm vi) | Không thấy "Lái xe" |
  | UA (adminB) | Không thấy "Lái xe" (thuộc Đơn vị A, ngoài phạm vi Đơn vị B) | Không thấy |
  | CMD-ZM (chiHuyA) | Thấy "Lái xe" như adminA, nhưng nút Tính toán lại bị ẩn | Không thấy "Lái xe" |
  | CMD (chiHuyB) | Không thấy "Lái xe" như adminB | Không thấy |

  - TECH (kyThuat) bị chặn khỏi `/billing` (redirect `/users`) ở mọi kỳ — không nằm trong bảng vì không thấy dữ liệu nghiệp vụ.
  - Sáu đầu mối gốc: với SA/DC hiện toàn bộ (chọn filter); adminA/chiHuyA hiện đủ đầu mối Đơn vị A + đầu mối sinh hoạt thuộc khu vực (Chỉ huy khu vực thiếu 33,32); adminB/chiHuyB chỉ thấy Đại đội 1 thiếu 106,86.
- **Chiều liên quan:** chiều 1 × 2 × 4 đầy đủ; Nhóm 1.

#### GD1-05 — Nút Tính toán lại theo kỳ đang mở và vai trò `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1, kỳ N-1 đang mở lại (trạng thái C).
- **Các bước:** mỗi vai trò vào `/billing` xem kỳ N-1, kiểm nút Tính toán lại; sau đó SA xem kỳ N (đã đóng).
- **Kết quả mong đợi:**
  - Kỳ N-1 đang mở lại + kỳ đang xem = kỳ N-1: nút Tính toán lại **bật** cho SA, DC (chiHuySuDoan), UA-ZM (adminA), UA (adminB). Ẩn cho CMD-ZM (chiHuyA), CMD (chiHuyB).
  - SA xem kỳ N (đã đóng) trong khi kỳ N-1 đang mở: nút Tính toán lại **tắt** vì kỳ đang xem đã đóng (theo chiều 7 — recalculate gắn với kỳ đang xem, không phải kỳ đang mở).
- **Chiều liên quan:** chiều 1 (trạng thái C), chiều 2, chiều 7 (kỳ đang xem ≠ kỳ đang mở), chiều 8; Nhóm 1.

### GD2 — Kỳ × Loại đầu mối × Cleanup

Suite này instance hóa Nhóm 2 (giao điểm chiều 1 × 5). Mỗi kịch bản xóa một loại đầu mối **ở kỳ đang mở (kỳ mới nhất, trạng thái B)** và kiểm cleanup theo bảng `V2_HANH_VI_HE_THONG.md` mục 5, đồng thời kiểm dữ liệu kỳ đã đóng giữ nguyên. Dùng Khu vực 1.

**Bối cảnh chung của suite:** kỳ tháng 5 năm 2026 đã đóng với golden numbers Phần 2 (kỳ cũ). Mở kỳ mới tháng 6 năm 2026 (trạng thái B), kế thừa toàn bộ entity. Thao tác xóa diễn ra ở kỳ tháng 6 này; "kỳ cũ" = tháng 5.

#### GD2-01 — Xóa đầu mối sinh hoạt "Kho vật tư" `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** bối cảnh chung GD2; đăng nhập adminA (UA-ZM) hoặc quanTri (SA).
- **Các bước:**
  1. Vào `/contact_points`, xóa đầu mối sinh hoạt "Kho vật tư" ở kỳ tháng 6.
  2. Vào `/billing` xem kỳ tháng 6, bấm Tính toán lại.
- **Kết quả mong đợi:**
  - Phía sau (cleanup kỳ đang mở, loại residential): hard delete `meter_readings` (của CT-A3) + `personnel_entries` + `other_deductions` + `pump_allocations` của "Kho vật tư" trong kỳ tháng 6; công tơ CT-A3 bị discard. "Kho vật tư" chuyển trạng thái discarded.
  - Engine tính lại kỳ tháng 6 (hướng và cấu trúc):
    - CT-A3 là công tơ **không tổn hao**: khi biến mất, 110 kW của nó không còn bị trừ khỏi A (A của kỳ tháng 6 tăng so với khi còn CT-A3), và CT-A3 vốn không nằm trong mẫu số B nên B không đổi vì CT-A3 — nhưng tổng tổn hao C và tỷ lệ tổn hao thay đổi (tính lại bằng engine).
    - Tổng quân số Đơn vị A giảm 3 người (Kho vật tư 3 người) → trọng số phân bổ bơm nước của Đơn vị A giảm → Đơn vị A nhận ít hơn, phần còn lại chia lại cho Đơn vị B và Thợ xây theo trọng số mới (tính lại bằng engine). Phần 20% cố định của Chỉ huy khu vực không đổi (cố định theo D, không theo quân số) nhưng D thay đổi do tổn hao thay đổi (tính lại bằng engine).
    - "Kho vật tư" không còn dòng trên bảng tính tiền kỳ tháng 6.
  - Dữ liệu kỳ tháng 5 (đã đóng) giữ nguyên: dòng "Kho vật tư" vẫn thừa 27,62, thành tiền 64.523 (EN-KV1-SUMMARY-03); tổn hao CT-A3 = 0,00; A = 1.990,00, B = 1.930,00, C = 60,00 (EN-KV1-LOSS) không đổi.
- **Chiều liên quan:** chiều 1 (B), chiều 5 (residential cleanup); Nhóm 2.

#### GD2-02 — Xóa đầu mối công cộng "Nhà ăn" `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** bối cảnh chung GD2; đăng nhập adminA (UA-ZM) hoặc SA.
- **Các bước:**
  1. Vào `/contact_points`, xóa đầu mối công cộng "Nhà ăn" ở kỳ tháng 6.
  2. Tính toán lại kỳ tháng 6.
- **Kết quả mong đợi:**
  - Phía sau (cleanup loại public): hard delete `meter_readings` (của CT-CC-A) trong kỳ tháng 6 + discard công tơ CT-CC-A. Public không có `personnel_entries`, `other_deductions`, `pump_allocations` nên không có gì khác để xóa.
  - Engine tính lại kỳ tháng 6: CT-CC-A (220 kW) thuộc mẫu số B → B giảm khi CT-CC-A biến mất → C = A − B tăng, tỷ lệ tổn hao tăng, tổn hao phân bổ lại cho các công tơ còn lại (gồm công tơ sinh hoạt và bơm nước) tăng (tính lại bằng engine). Khoản trừ công cộng Sư đoàn và công cộng đơn vị của các đầu mối sinh hoạt thay đổi theo (tính lại bằng engine). "Nhà ăn" vốn không có dòng trên bảng tính tiền (public), nên bảng vẫn 5 dòng — thay đổi nằm ở các con số khoản trừ/tổn hao của các đầu mối sinh hoạt.
  - Dữ liệu kỳ tháng 5 (đã đóng) giữ nguyên: tổn hao CT-CC-A = 6,84 (EN-KV1-LOSS); A/B/C tháng 5 không đổi.
- **Chiều liên quan:** chiều 1 (B), chiều 5 (public cleanup); Nhóm 2.

#### GD2-03 — Xóa đầu mối bơm nước "Trạm bơm 1" `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** bối cảnh chung GD2; đăng nhập adminA (UA-ZM) hoặc SA (chỉ hai vai trò này thấy đầu mối bơm nước).
- **Các bước:**
  1. Vào `/contact_points`, xóa đầu mối bơm nước "Trạm bơm 1" ở kỳ tháng 6.
  2. Tính toán lại kỳ tháng 6.
- **Kết quả mong đợi:**
  - Phía sau (cleanup loại water_pump): hard delete `meter_readings` (của CT-BN1) trong kỳ tháng 6 + discard công tơ CT-BN1.
  - Engine tính lại kỳ tháng 6: CT-BN1 (300 kW) thuộc mẫu số B → B giảm, tỷ lệ tổn hao thay đổi (tính lại bằng engine). Quan trọng hơn: nguồn điện bơm nước D = sử dụng thô công tơ bơm nước + tổn hao công tơ bơm nước → mất CT-BN1, khu vực không còn công tơ bơm nước → D = 0 → toàn bộ Tiêu chuẩn bơm nước nhận về của các đối tượng (Đơn vị A, Đơn vị B, Chỉ huy khu vực, Thợ xây) về 0 (cấu hình phân bổ vẫn còn nhưng không có nguồn để chia). Cột Sử dụng bơm nước của mọi đầu mối sinh hoạt = 0 (tính lại bằng engine). Không có cảnh báo (theo chiều 9: khu vực không có trạm bơm là hợp lệ).
  - Dữ liệu kỳ tháng 5 (đã đóng) giữ nguyên: D = 309,33 (EN-KV1-PUMP); phân bổ Chỉ huy khu vực 61,87, Đơn vị A 105,30, Đơn vị B 115,83, Thợ xây 26,33.
- **Chiều liên quan:** chiều 1 (B), chiều 5 (water_pump cleanup + nguồn bơm nước); Nhóm 2.

#### GD2-04 — Xóa đầu mối ngoài biên chế "Thợ xây" `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** bối cảnh chung GD2; đăng nhập adminA (UA-ZM) hoặc SA.
- **Các bước:**
  1. Vào `/contact_points`, xóa đầu mối ngoài biên chế "Thợ xây" ở kỳ tháng 6.
  2. Tính toán lại kỳ tháng 6.
- **Kết quả mong đợi:**
  - Phía sau (cleanup loại non_establishment): hard delete `non_establishment_snapshots` + `pump_allocations` của "Thợ xây" trong kỳ tháng 6. Non_establishment không có công tơ nên không có `meter_readings`.
  - Engine tính lại kỳ tháng 6: "Thợ xây" là một đối tượng nhận phân bổ bơm nước theo hệ số (hệ số 0,5 × 5 người). Khi biến mất khỏi phân bổ, phần D còn lại sau 20% cố định của Chỉ huy khu vực được chia lại chỉ cho Đơn vị A và Đơn vị B theo trọng số quân số × hệ số → Đơn vị A và Đơn vị B nhận **nhiều hơn** so với khi còn Thợ xây (tính lại bằng engine). "Thợ xây" không có dòng trên bảng tính tiền (non_establishment), bảng vẫn 5 dòng. Tổng sử dụng bơm nước phân về các đầu mối sinh hoạt tăng.
  - Dữ liệu kỳ tháng 5 (đã đóng) giữ nguyên: Thợ xây nhận 26,33 kW bơm nước (EN-KV1-PUMP); Đơn vị A 105,30, Đơn vị B 115,83.
- **Chiều liên quan:** chiều 1 (B), chiều 5 (non_establishment cleanup); Nhóm 2.

#### GD2-05 — Bao quát: dữ liệu kỳ cũ giữ nguyên sau mọi loại xóa `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** đã chạy lần lượt GD2-01..04 (trên các nhánh dữ liệu độc lập); kỳ tháng 5 đã đóng.
- **Các bước:** với mỗi loại xóa, vào `/billing` xem kỳ tháng 5 (đã đóng), so sánh với Phần 2.
- **Kết quả mong đợi:** Hàng tổng kỳ tháng 5 luôn khớp EN-KV1-TOTALS: tổng quân số 22, tổng tiêu chuẩn 1.851,90, tổng trừ 372,98, tổng thừa 33,34, tổng thiếu 177,42, tổng thành tiền thừa 77.891, tổng thành tiền thiếu 414.517 — bất kể loại đầu mối nào bị xóa ở kỳ tháng 6. Đây là kiểm chứng "dữ liệu kỳ cũ giữ nguyên" của nghiệp vụ mục 23.1.
- **Chiều liên quan:** chiều 1 (kỳ đóng không bị ảnh hưởng), chiều 5; Nhóm 2.

### GD3 — Vai trò × Thuộc về × Trang

Suite này instance hóa Nhóm 3 (giao điểm chiều 2 × 6 × 3). Kiểm vai trò nào thấy đầu mối nào trên ba trang billing / meter_entries / unit_config, phân biệt đầu mối thuộc đơn vị và đầu mối thuộc khu vực trực tiếp. Dùng Khu vực 1 (đầu mối thuộc đơn vị: Ban Tác huấn, Văn thư, Kho vật tư thuộc Đơn vị A; Đại đội 1 thuộc Đơn vị B; đầu mối thuộc khu vực trực tiếp: Chỉ huy khu vực) và Khu vực 2 (kiểm cách ly cross-zone). Kỳ tháng 5 năm 2026 đang mở.

#### GD3-01 — UA (adminB) chỉ thấy đầu mối Đơn vị B `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminB (UA).
- **Các bước:** vào `/billing`, `/meter_entries`, `/unit_config`.
- **Kết quả mong đợi:**
  - `/billing`: chỉ 1 dòng đầu mối sinh hoạt là Đại đội 1 (thiếu 106,86, thành tiền 249.659 — EN-KV1-SUMMARY-04). Không thấy đầu mối Đơn vị A, không thấy Chỉ huy khu vực (đầu mối thuộc khu vực trực tiếp, ngoài phạm vi UA). Billing 28 cột (ẩn cả Khu vực + Đơn vị).
  - `/meter_entries`: thấy công tơ sinh hoạt + công cộng của Đơn vị B (CT-B1 Đại đội 1, CT-CC-B Trạm gác). Không thấy bơm nước. Không có cột Khu vực/Đơn vị (non-SA), không có dropdown filter.
  - `/unit_config`: cấu hình Đơn vị B (tỷ lệ công cộng đơn vị 0%) + cột Khác của đầu mối sinh hoạt Đơn vị B (Đại đội 1, hệ số 3). Không thấy cấu hình đầu mối khu vực.
- **Chiều liên quan:** chiều 2 (UA), chiều 6 (thuộc đơn vị), chiều 3 (3 trang); Nhóm 3.

#### GD3-02 — UA-ZM (adminA) thấy Đơn vị A + đầu mối sinh hoạt thuộc khu vực `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminA (UA-ZM, Đơn vị A quản lý Khu vực 1).
- **Các bước:** vào `/billing`, `/meter_entries`, `/unit_config`.
- **Kết quả mong đợi:**
  - `/billing`: thấy đầu mối sinh hoạt Đơn vị A (Ban Tác huấn thiếu 37,24; Văn thư thừa 5,72; Kho vật tư thừa 27,62) **cộng** đầu mối sinh hoạt thuộc khu vực trực tiếp (Chỉ huy khu vực thiếu 33,32). KHÔNG thấy Đại đội 1 (thuộc Đơn vị B). Billing 29 cột (có Đơn vị, ẩn Khu vực). Cột Đơn vị của dòng "Chỉ huy khu vực" **trống** (đầu mối thuộc khu vực trực tiếp — chiều 6).
  - `/meter_entries`: thấy công tơ sinh hoạt + công cộng Đơn vị A (CT-A1, CT-A2, CT-A3, CT-CC-A) + công tơ thuộc khu vực (CT-KV1 Chỉ huy khu vực, CT-CC-KV Đèn đường). Trên `/pump_entries` thấy CT-BN1 (bơm nước khu vực).
  - `/unit_config`: cấu hình Đơn vị A (tỷ lệ công cộng đơn vị 3%) + cột Khác đầu mối sinh hoạt Đơn vị A + cột Khác đầu mối sinh hoạt thuộc khu vực (Chỉ huy khu vực, cố định 0).
- **Chiều liên quan:** chiều 2 (UA-ZM), chiều 6 (thuộc đơn vị + thuộc khu vực), chiều 3; Nhóm 3.

#### GD3-03 — SA (quanTri) thấy tất cả + filter `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập quanTri (SA).
- **Các bước:** vào `/billing` không filter, rồi filter Khu vực 1, rồi filter Khu vực 1 + Đơn vị A.
- **Kết quả mong đợi:**
  - Không filter: thấy toàn bộ đầu mối sinh hoạt cả hai khu vực (5 của Khu vực 1 + 3 của Khu vực 2 = 8 dòng). Billing 30 cột (có Khu vực + Đơn vị).
  - Filter Khu vực 1: 5 dòng Khu vực 1; cột Khu vực ẩn (thừa khi đã chọn 1 zone), cột Đơn vị hiện; dòng "Chỉ huy khu vực" cột Đơn vị trống.
  - Filter Khu vực 1 + Đơn vị A: 3 dòng (Ban Tác huấn, Văn thư, Kho vật tư); cột Khu vực + Đơn vị đều ẩn. Dropdown đơn vị cascade theo khu vực đã chọn.
- **Chiều liên quan:** chiều 2 (SA), chiều 6, chiều 3; Nhóm 3.

#### GD3-04 — CMD và CMD-ZM thấy như UA/UA-ZM nhưng input bị vô hiệu hóa `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập lần lượt chiHuyB (CMD), chiHuyA (CMD-ZM).
- **Các bước:** mỗi vai trò vào `/billing`, `/meter_entries`, `/unit_config`.
- **Kết quả mong đợi:**
  - chiHuyB (CMD): phạm vi dữ liệu **giống adminB** (chỉ Đại đội 1 trên billing, 28 cột) nhưng nút Tính toán lại bị ẩn; ô nhập `/meter_entries` và `/unit_config` bị vô hiệu hóa (disabled), nút Lưu bị ẩn.
  - chiHuyA (CMD-ZM): phạm vi dữ liệu **giống adminA** (đầu mối Đơn vị A + đầu mối khu vực, 29 cột, cột Đơn vị của Chỉ huy khu vực trống) nhưng chỉ xem; nút Tính toán lại ẩn; mọi ô nhập disabled.
- **Chiều liên quan:** chiều 2 (CMD/CMD-ZM chỉ xem), chiều 6, chiều 3 (input state); Nhóm 3.

#### GD3-05 — Cách ly cross-zone: adminC (Khu vực 2) không thấy Khu vực 1 `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminC (UA-ZM, Đơn vị C quản lý Khu vực 2).
- **Các bước:** vào `/billing`, `/meter_entries`, `/unit_config`.
- **Kết quả mong đợi:**
  - `/billing`: thấy đúng **2 đầu mối sinh hoạt** mà adminC quản lý — Quân y (Đơn vị C) thừa 9,32 (EN-KV2-SUMMARY-01) và Chỉ huy khu vực 2 (thuộc khu vực trực tiếp) thừa 11,20 (EN-KV2-SUMMARY-03). **KHÔNG thấy Trinh sát**: đầu mối này thuộc Đơn vị D — một đơn vị khác trong cùng khu vực — nên nằm ngoài phạm vi của adminC (xem ghi chú phạm vi bên dưới). 29 cột (có Đơn vị, ẩn Khu vực vì cố định 1 khu vực); cột Đơn vị của hàng Chỉ huy khu vực 2 để trống.
  - Tuyệt đối không thấy bất kỳ đầu mối nào của Khu vực 1 (Ban Tác huấn, Đại đội 1, Chỉ huy khu vực...). Đây là kiểm cách ly cross-zone.
  - `/meter_entries`, `/unit_config`: chỉ entity Khu vực 2.
- **Ghi chú phạm vi (UA-ZM trên billing):** Phạm vi billing của UA-ZM = đầu mối đơn vị mình + đầu mối sinh hoạt **thuộc khu vực trực tiếp** (`unit_id` null, `zone_id` có giá trị) — KHÔNG bao gồm đầu mối của các đơn vị khác trong cùng khu vực. Nguồn: `V2_THIET_KE_HE_THONG.md` mục "Bảng tính tiền → Mapping filter theo vai trò" ("Đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực"), khớp với `accessible_by(current_ability)` (Ability: `contact_point.unit_id` = đơn vị mình HOẶC `contact_point.zone_id` thuộc khu vực mình quản lý). Vì ràng buộc XOR `unit_id`/`zone_id`, đầu mối thuộc Đơn vị D (Trinh sát) có `zone_id` null nên không lọt vào phạm vi này. Vậy adminC thấy đúng 2 đầu mối Khu vực 2 (Quân y + Chỉ huy khu vực 2), không thấy Trinh sát. Cụm "đầu mối sinh hoạt khu vực" trong `V2_HANH_VI_HE_THONG.md` mục 1 nghĩa là đầu mối thuộc khu vực trực tiếp, không phải mọi đầu mối trong khu vực. Điều cốt lõi của kịch bản: KHÔNG thấy bất kỳ đầu mối nào của Khu vực 1.
- **Chiều liên quan:** chiều 2 (UA-ZM ở khu vực khác), chiều 6, chiều 3, bối cảnh cross-zone (DATA-KV2); Nhóm 3.

### GD4 — Kỳ đang xem × Trạng thái tính toán × Vai trò

Suite này instance hóa Nhóm 4 (giao điểm chiều 7 × 8 × 2). Kiểm hành vi khi chưa tính, khi dữ liệu cũ (stale), và khi kỳ đang xem khác kỳ đang mở.

#### GD4-01 — Kỳ mới mở chưa bấm tính: bảng trống, không lỗi `[CẢ HAI]`

- **Điều kiện tiên quyết:** mở kỳ mới tháng 6 năm 2026 (kế thừa entity), chưa ai bấm Tính toán lại; đăng nhập adminA (UA-ZM).
- **Các bước:**
  1. Vào `/billing` xem kỳ tháng 6.
  2. Vào `/dashboard`.
- **Kết quả mong đợi:**
  - Phía sau: `Calculation.where(period: kỳ_tháng_6)` rỗng (chưa tính).
  - `/billing`: bảng hiện trạng thái rỗng (không có hàng dữ liệu), KHÔNG lỗi 500. Nút Tính toán lại bật (kỳ đang mở + adminA có quyền).
  - `/dashboard`: thâm điện / số dư hiển thị 0, không lỗi.
- **Chiều liên quan:** chiều 7 (kỳ đang xem = kỳ đang mở), chiều 8 (chưa tính lần nào), chiều 2; Nhóm 4.

#### GD4-02 — Sửa chỉ số rồi chưa tính lại: billing hiện số cache cũ (stale) `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở, đã tính một lần (golden numbers Phần 2 hiển thị đúng); đăng nhập adminA (UA-ZM).
- **Các bước:**
  1. Vào `/meter_entries`, sửa chỉ số cuối kỳ CT-A1 (Ban Tác huấn) từ 1.250 lên 1.400 (sử dụng tăng từ 250 lên 400). Lưu.
  2. KHÔNG bấm Tính toán lại. Quay lại `/billing`.
- **Kết quả mong đợi:**
  - Phía sau: `meter_readings` của CT-A1 đã cập nhật, nhưng `calculations` chưa đổi (chỉ thay đổi khi recalculate).
  - `/billing`: dòng Ban Tác huấn vẫn hiện số cũ — thiếu 37,24, thành tiền 87.004 (EN-KV1-SUMMARY-01) — KHÔNG phản ánh chỉ số mới. Đây là trạng thái stale: UA-ZM dễ tưởng chưa nhập hoặc tưởng số đã đúng. Cần bấm Tính toán lại để engine cập nhật (sau khi tính lại, số sẽ khác — không trích dẫn vì là kết quả nhiều bước, tính lại bằng engine).
  - Hiển thị nên kèm chỉ báo cần tính lại nếu thiết kế có (kiểm theo trang).
- **Chiều liên quan:** chiều 7, chiều 8 (stale), chiều 2; Nhóm 4.

#### GD4-03 — Xuất Excel khi stale: file chứa số cũ `[CẢ HAI]`

- **Điều kiện tiên quyết:** trạng thái stale của GD4-02 (đã sửa CT-A1, chưa tính lại); đăng nhập quanTri (SA) hoặc adminA.
- **Các bước:**
  1. Trên `/billing` (đang stale), bấm Xuất Excel.
- **Kết quả mong đợi:**
  - File Excel chứa **số cũ** (Ban Tác huấn thiếu 37,24, thành tiền 87.004 — EN-KV1-SUMMARY-01), giống hệt HTML đang hiển thị, vì cả hai render từ bảng `calculations` chưa được tính lại. Đây là rủi ro nghiệp vụ: file xuất ra không phản ánh chỉ số mới nhập.
  - Kiểm chứng: Excel khớp HTML stale (không phải khớp dữ liệu thô mới) — cùng nguồn `calculations`.
- **Chiều liên quan:** chiều 7, chiều 8 (stale), chiều 12 (Excel cùng nguồn calculations); Nhóm 4.

#### GD4-04 — SA mở lại kỳ N-2 nhưng xem kỳ N-1 (đã đóng): Tính toán lại bị tắt `[CẢ HAI]`

- **Điều kiện tiên quyết:** có ít nhất ba kỳ: N-2, N-1, N đều đã đóng. SA mở lại kỳ N-2 (trạng thái C — kỳ cũ mở lại; `current_period` = N-2). Đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/billing`, dropdown kỳ chọn xem kỳ N-1 (đã đóng), trong khi kỳ đang mở là N-2.
- **Kết quả mong đợi:**
  - Hiển thị dữ liệu kỳ N-1 (kỳ đang xem), nhưng nút Tính toán lại **tắt** vì kỳ N-1 đã đóng — recalculate gắn với kỳ đang xem, không phải kỳ đang mở (chiều 7).
  - Đối chiếu: nếu SA đổi dropdown kỳ về N-2 (kỳ đang mở lại), nút Tính toán lại **bật** (sửa được dữ liệu per kỳ ở trạng thái C). Đây là phân biệt cốt lõi: recalculate của kỳ đang mở (N-2) hoạt động, kỳ đóng (N-1) thì không.
- **Chiều liên quan:** chiều 7 (kỳ đang xem ≠ kỳ đang mở, hàng "N-2 mở lại / xem N-1"), chiều 8, chiều 2 (SA); Nhóm 4.

### GD5 — Vị trí phân cấp × Định dạng output

Suite này instance hóa Nhóm 5 (giao điểm chiều 10 × 12). Kiểm gộp ô (rowspan HTML / merge Excel) cho 5 vị trí phân cấp và số cột theo vai trò. Dùng cả 5 vị trí phân cấp: Khu vực 1 có 4 vị trí (1, 2, 4, 5 theo bảng chiều 10), Khu vực 2 bổ sung vị trí 3 (nhóm trực tiếp dưới đơn vị, không khối) qua "Quân y" trong nhóm "Tổ Quân y".

Năm vị trí phân cấp (theo `V2_CHIEU_TEST.md` chiều 10):

| Vị trí | Đầu mối ví dụ | Khu vực | Cột Khối | Cột Nhóm | Cột Đơn vị |
|---|---|---|---|---|---|
| 1. Trực tiếp đơn vị | Kho vật tư (Đơn vị A), Đại đội 1 (Đơn vị B) | KV1 | Trống | Trống | Có |
| 2. Trong khối, không nhóm | Văn thư (khối Phòng Tham mưu) | KV1 | Merge | Trống | Có |
| 3. Trong nhóm trực tiếp, không khối | Quân y (nhóm Tổ Quân y, Đơn vị C) | KV2 | Trống | Merge | Có |
| 4. Trong nhóm trong khối | Ban Tác huấn (khối Phòng Tham mưu, nhóm Ban Tác huấn) | KV1 | Merge | Merge | Có |
| 5. Thuộc khu vực trực tiếp | Chỉ huy khu vực (KV1), Chỉ huy khu vực 2 (KV2) | KV1/KV2 | Trống | Trống | Trống |

#### GD5-01 — Rowspan/merge HTML cho 5 vị trí phân cấp `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở, đã tính; đăng nhập quanTri (SA), không filter (xem gộp cả hai khu vực).
- **Các bước:** vào `/billing`, quan sát gộp ô bốn cột Khu vực / Đơn vị / Khối / Nhóm.
- **Kết quả mong đợi:**
  - Vị trí 1 (Kho vật tư, Đại đội 1): cột Khối và Nhóm trống; cột Đơn vị có giá trị.
  - Vị trí 2 (Văn thư): cột Khối "Phòng Tham mưu" gộp (cùng khối với Ban Tác huấn); cột Nhóm trống.
  - Vị trí 3 (Quân y): cột Nhóm "Tổ Quân y" gộp; cột Khối **trống** (nhóm trực tiếp dưới đơn vị, không khối) — đây là vị trí duy nhất Khu vực 1 không có.
  - Vị trí 4 (Ban Tác huấn): cột Khối "Phòng Tham mưu" gộp **và** cột Nhóm "Ban Tác huấn" gộp.
  - Vị trí 5 (Chỉ huy khu vực, Chỉ huy khu vực 2): cột Đơn vị **trống** (không hiện "—" hay placeholder); cột Khối và Nhóm trống.
  - Cột Khu vực: các dòng cùng Khu vực 1 gộp thành một ô, các dòng Khu vực 2 gộp thành một ô (SA xem gộp hai khu vực).
- **Chiều liên quan:** chiều 10 (5 vị trí), chiều 12 (HTML rowspan); Nhóm 5.

#### GD5-02 — Excel merge phản chiếu HTML rowspan `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** như GD5-01; SA bấm Xuất Excel.
- **Các bước:** mở tập tin Excel, đối chiếu merge bốn cột Khu vực / Đơn vị / Khối / Nhóm với HTML.
- **Kết quả mong đợi:**
  - Mỗi merge dọc của HTML (`rowspan`) có một `merge_cells` tương ứng trong Excel: khối "Phòng Tham mưu" merge qua Ban Tác huấn + Văn thư; nhóm "Tổ Quân y" merge qua các dòng Quân y; ô Đơn vị của dòng Chỉ huy khu vực để trống (không merge với đơn vị nào).
  - Sai merge → layout Excel vỡ (đây là điểm nguy hiểm của chiều 12). Kiểm trực quan từng cột.
- **Chiều liên quan:** chiều 10, chiều 12 (Excel merge_cells); Nhóm 5.

#### GD5-03 — Số cột theo vai trò: SA 30, UA-ZM 29, UA 28 `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở, đã tính.
- **Các bước:** lần lượt đăng nhập quanTri (SA), adminA (UA-ZM), adminB (UA), vào `/billing`, đếm cột.
- **Kết quả mong đợi:**
  - SA: 30 cột (có cả Khu vực + Đơn vị).
  - UA-ZM (adminA): 29 cột (có Đơn vị, ẩn Khu vực).
  - UA (adminB): 28 cột (ẩn cả Khu vực + Đơn vị).
  - SA khi đã chọn một khu vực trong dropdown: cột Khu vực ẩn → còn 29 cột (giống UA-ZM về số cột nhưng vẫn là phiên SA).
- **Chiều liên quan:** chiều 12 (số cột dynamic theo vai trò + filter), chiều 2; Nhóm 5.

#### GD5-04 — Chỉ số cột công thức Excel dịch theo số cột `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** như GD5-03; xuất Excel cho từng vai trò SA / UA-ZM / UA.
- **Các bước:** mở từng tập tin Excel, kiểm các ô công thức (hàng tổng `=SUM(...)`, tổng tiêu chuẩn `=residential + water_pump`, thành tiền `=kW × đơn giá`).
- **Kết quả mong đợi:**
  - File SA (30 cột) và file UA (28 cột) có cùng giá trị tính toán nhưng **chỉ số cột trong công thức dịch** theo số cột bị ẩn (ẩn Khu vực dịch 1 cột, ẩn cả Khu vực + Đơn vị dịch 2 cột). Công thức phải trỏ đúng ô — nếu trỏ sai ô thì Excel sai trong khi HTML đúng (điểm nguy hiểm chiều 12).
  - Đối chiếu hàng tổng Excel với EN-KV1-TOTALS (ví dụ tổng thành tiền thiếu 414.517 cho phiên SA xem Khu vực 1) — giá trị phải khớp dù chỉ số cột khác nhau giữa các vai trò.
- **Chiều liên quan:** chiều 12 (Excel formula column index dịch theo số cột); Nhóm 5.

### GD6 — Cách nhận dữ liệu × Kỳ × Loại đầu mối

Suite này instance hóa Nhóm 6 (giao điểm chiều 11 × 1 × 5). Kiểm ba đường nhận dữ liệu per kỳ (kế thừa khi mở kỳ mới, tạo giữa kỳ qua after_create, kỳ đầu tiên) theo `V2_HANH_VI_HE_THONG.md` mục 6. Dùng Khu vực 1.

#### GD6-01 — Tạo đầu mối sinh hoạt "Tổ xe" giữa kỳ đang mở `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở (trạng thái B); đăng nhập adminA (UA-ZM). Tạo "Tổ xe" thuộc Đơn vị A với quân số: 1 người nhóm "Chỉ huy Đại đội, Trung đội; cấp Úy" (định mức 130) + 4 người nhóm "Hạ sĩ quan, binh sĩ" (định mức 24), một công tơ CT-Tổxe với chỉ số cuối kỳ 200.
- **Các bước:**
  1. Vào `/contact_points`, tạo đầu mối sinh hoạt "Tổ xe" với cấu hình trên.
- **Kết quả mong đợi:**
  - Phía sau (after_create loại residential, theo chiều 11):
    - `meter_readings` của CT-Tổxe: `reading_start = 0` (tạo giữa kỳ), `reading_end` do user nhập (200), `no_loss` = giá trị no_loss của công tơ.
    - `personnel_entries`: tạo cho **mọi** nhóm cấp bậc hiện có (7 nhóm), count theo form (1 cho cấp Úy 130, 4 cho Hạ sĩ quan binh sĩ 24, 0 cho 5 nhóm còn lại).
    - `other_deductions`: tạo với type = fixed, value = 0.
  - Công thức một bước (chỉ tính tiêu chuẩn sinh hoạt = Σ quân số × định mức): **Tiêu chuẩn sinh hoạt = 1 × 130 + 4 × 24 = 130 + 96 = 226,00 kW.** (Chỉ tính tiêu chuẩn sinh hoạt vì là công thức một bước; các cột còn lại của dòng "Tổ xe" — tổn hao, bơm nước, khoản trừ, thừa/thiếu, thành tiền — là kết quả nhiều bước, tính lại bằng engine, không trích dẫn.)
  - Hiển thị: "Tổ xe" xuất hiện trên `/meter_entries` (CT-Tổxe, reading_start 0) và trên `/billing` sau khi Tính toán lại.
- **Chiều liên quan:** chiều 11 (tạo giữa kỳ), chiều 1 (B), chiều 5 (residential); Nhóm 6.

#### GD6-02 — Thêm nhóm cấp bậc mới giữa kỳ: personnel_entries count = 0 cho mọi đầu mối sinh hoạt `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở (trạng thái B); đăng nhập quanTri (SA) — nhóm cấp bậc là cấu hình chung, SA quản lý.
- **Các bước:**
  1. Vào `/ranks`, thêm một nhóm cấp bậc mới (ví dụ "Thử nghiệm", định mức 50).
- **Kết quả mong đợi:**
  - Phía sau (after_create Rank, theo chiều 11): tạo `personnel_entries` với count = 0 cho **mọi đầu mối sinh hoạt hiện có** của kỳ đang mở (Khu vực 1: Ban Tác huấn, Văn thư, Kho vật tư, Đại đội 1, Chỉ huy khu vực; Khu vực 2: Quân y, Trinh sát, Chỉ huy khu vực 2). Đầu mối ngoài biên chế (Thợ xây) KHÔNG bị ảnh hưởng (quân số tổng, không theo nhóm cấp bậc).
  - Engine: vì count = 0, tiêu chuẩn sinh hoạt của mọi đầu mối **không đổi** → mọi golden numbers Phần 2 giữ nguyên (Ban Tác huấn thiếu 37,24, ...). Nhóm cấp bậc mới chỉ có tác dụng khi user nhập quân số > 0 và tính lại.
  - Hiển thị: trên `/meter_entries` không đổi (rank không có công tơ); trên form sửa quân số đầu mối sinh hoạt xuất hiện thêm hàng nhóm "Thử nghiệm" với count 0.
- **Chiều liên quan:** chiều 11 (thêm rank giữa kỳ), chiều 1 (B), chiều 5; Nhóm 6.

#### GD6-03 — Mở kỳ mới: kế thừa dữ liệu, main_meter_readings KHÔNG kế thừa `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đã đóng với golden numbers Phần 2; đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/pricing`, mở kỳ mới tháng 6 năm 2026.
  2. Vào `/meter_entries`, `/unit_config`, `/electricity_supply` xem kỳ tháng 6.
- **Kết quả mong đợi (kế thừa, theo chiều 11 và `V2_HANH_VI_HE_THONG.md` mục 6):**
  - `meter_readings`: `reading_start` kỳ tháng 6 = `reading_end` kỳ tháng 5 (CT-A1: start = 1.250; CT-A2: start = 680; CT-B1: start = 2.350; ...) — editable, user sửa nếu cần. `reading_end` để trống chờ nhập.
  - `personnel_entries`: copy count từ kỳ tháng 5 (match theo position nhóm cấp bậc). `unit_configs`: copy unit_public_rate (Đơn vị A 3%, Đơn vị B 0%). `other_deductions`: copy type + value (Ban Tác huấn cố định 5, Văn thư hệ số −2,5, ...). `pump_allocations`: copy coefficient + fixed_percentage (Chỉ huy khu vực 20% cố định + hệ số 1; Đơn vị A/B hệ số 1; Thợ xây hệ số 0,5). `ranks`: copy name + quota + position (7 nhóm).
  - `main_meter_readings`: **KHÔNG kế thừa** — `/electricity_supply` kỳ tháng 6 hiện "Chưa nhập" cho CT-Tổng-KV1 (và CT-Tổng-KV2). Phải nhập lại số sử dụng mỗi kỳ.
  - Chỉ copy entity `.kept` — đầu mối/công tơ đã xóa không được copy sang kỳ tháng 6.
  - (Mô tả kế thừa theo cấu trúc; không trích dẫn số tính toán kỳ tháng 6 vì chưa nhập reading_end và chưa tính.)
- **Chiều liên quan:** chiều 11 (kế thừa khi mở kỳ mới + main_meter không kế thừa), chiều 1 (chuyển A→B); Nhóm 6.

#### GD6-04 — Đầu mối tạo giữa kỳ có reading_start = 0: sử dụng = reading_end `[CẢ HAI]`

- **Điều kiện tiên quyết:** "Tổ xe" tạo giữa kỳ ở GD6-01 (CT-Tổxe reading_start = 0); kỳ tháng 5 đang mở; đăng nhập adminA.
- **Các bước:**
  1. Vào `/meter_entries`, nhập `reading_end` của CT-Tổxe = 200.
  2. Tính toán lại.
- **Kết quả mong đợi:**
  - Cột Sử dụng của CT-Tổxe = `reading_end − reading_start` = 200 − 0 = **200,00 kW** (công thức một bước). Vì reading_start = 0 (công tơ tạo giữa kỳ, không kế thừa số đầu kỳ), sử dụng bằng nguyên reading_end — có thể rất lớn nếu công tơ không mới lắp mà nhập chỉ số tích lũy. Đây là điểm nguy hiểm chiều 11: đầu mối tạo giữa kỳ luôn có reading_start = 0, dễ gây sử dụng phình to nếu nhập reading_end là chỉ số tích lũy thực tế.
  - Các cột còn lại của dòng "Tổ xe" (tổn hao, bơm nước, thừa/thiếu, thành tiền) là kết quả nhiều bước → tính lại bằng engine, không trích dẫn.
- **Chiều liên quan:** chiều 11 (reading_start = 0 khi tạo giữa kỳ → sử dụng = reading_end), chiều 1, chiều 5; Nhóm 6.

---

## Phần 4 — Walkthrough theo trang × vai trò

Phần này instance hóa **ma trận 18 trang × 7 vai trò** của `V2_CHIEU_TEST.md` chiều 3 (cùng phần kiểm soát truy cập) và danh mục "Expected output hiển thị" (cột, nội dung ô, gộp ô, hàng tổng, nút, trạng thái ô nhập, dropdown, cảnh báo, sidebar, trạng thái rỗng, thông tin kỳ, phân trang, di chuột) bằng dữ liệu thật của Phần 1 và golden numbers của Phần 2. Đây là tài liệu kiểm thử thủ công cho QA: với mỗi trang, đăng nhập lần lượt 7 vai trò và đối chiếu đầu ra hiển thị cụ thể.

Tài liệu này **không chép lại** ma trận chiều 3; mỗi trang ghi phần giới thiệu ngắn (route + lớp bảo vệ + trỏ tới chiều 3) rồi đầu ra cụ thể per vai trò. Mã kịch bản: `TR-<trang>-<vaitro>` (ví dụ TR-billing-SA, TR-meter_entries-UAZM, TR-users-TECH).

Quy ước Phần 4:

- Mọi con số tính toán trích dẫn đều **trỏ về Phần 2** (golden numbers engine-verified), nêu rõ mã EN-* nguồn. Phần 4 không tính lại; với trang không mang số liệu, chỉ mô tả đầu ra hiển thị mong đợi.
- Cả hai khu vực dùng cùng kỳ tháng 5 năm 2026 đang mở (trạng thái B), đã tính toán (golden numbers Phần 2 hiển thị đúng) trừ khi kịch bản ghi khác.
- **Số mục sidebar theo vai trò:** xem bảng 4.0 bên dưới (nguồn: `V2_THIET_KE_HE_THONG.md` mục "Sidebar per role").
- **Phạm vi billing của UA-ZM (dùng nhất quán toàn Phần 4):** đầu mối đơn vị mình **cộng** đầu mối sinh hoạt **thuộc khu vực trực tiếp** (`unit_id` null, `zone_id` có giá trị) — **KHÔNG** bao gồm đầu mối của các đơn vị khác trong cùng khu vực. Cụ thể (theo GD3-05 và Phần 2):
  - adminA (UA-ZM Khu vực 1) thấy 4 hàng billing: Ban Tác huấn, Văn thư, Kho vật tư (Đơn vị A) cộng Chỉ huy khu vực (thuộc khu vực trực tiếp). KHÔNG thấy Đại đội 1 (Đơn vị B).
  - adminB (UA Khu vực 1) thấy 1 hàng: Đại đội 1 (Đơn vị B).
  - adminC (UA-ZM Khu vực 2) thấy 2 hàng: Quân y (Đơn vị C) cộng Chỉ huy khu vực 2 (thuộc khu vực trực tiếp). KHÔNG thấy Trinh sát (Đơn vị D).
  - adminD (UA Khu vực 2) thấy 1 hàng: Trinh sát (Đơn vị D).
  - SA xem gộp toàn bộ 8 đầu mối sinh hoạt (Khu vực 1: 5 hàng; Khu vực 2: 3 hàng).
- **CMD/CMD-ZM:** thấy **cùng trang và cùng phạm vi dữ liệu** như UA/UA-ZM tương ứng, nhưng chỉ xem — ô nhập bị vô hiệu hóa, các nút Sửa/Xóa/Lưu/Tính toán lại bị ẩn.
- **TECH:** bị chặn (redirect về `/users`) khỏi mọi trang nghiệp vụ; chỉ dùng `/users`, `/audit_logs`, `/backups`.
- Thẻ loại kiểm thử ghi per kịch bản theo mục 0.2.2.

### 4.0. Tổng quan sidebar theo vai trò `[CẢ HAI]`

Trước khi đi vào từng trang, bảng này chốt số mục sidebar và danh mục mục hiển thị per vai trò (nguồn: `V2_THIET_KE_HE_THONG.md` mục "Sidebar per role"). Mọi trang phía dưới giả định sidebar đã đúng theo bảng này.

| Vai trò | Số mục | Mục hiển thị |
|---|---|---|
| SA (quanTri) | 17 | XEM KẾT QUẢ (3): Tổng quan, Bảng tính tiền, Tra cứu lịch sử. NHẬP LIỆU (3): Nhập số điện lực, Chỉ số đầu mối, Chỉ số bơm nước. KHAI BÁO (4): Đầu mối, Khối, Nhóm, Cấu hình đơn vị. THIẾT LẬP (5): Khu vực, Đơn vị, Phân bổ bơm nước, Đơn giá điện, Nhóm cấp bậc. HỆ THỐNG (2): Tài khoản, Nhật ký hoạt động. (Không có Sao lưu.) |
| UA-ZM (adminA, adminC) | 11 | XEM KẾT QUẢ (3) + NHẬP LIỆU (3: cả điện lực và bơm nước) + KHAI BÁO (4) + THIẾT LẬP (1): Phân bổ bơm nước. (Không Khu vực, Đơn vị, Đơn giá, Nhóm cấp bậc, Hệ thống.) |
| UA (adminB, adminD) | 8 | XEM KẾT QUẢ (3) + NHẬP LIỆU (1: chỉ Chỉ số đầu mối) + KHAI BÁO (4). (Không điện lực, không bơm nước, không Thiết lập, không Hệ thống.) |
| CMD-ZM (chiHuyA, chiHuyC) | 11 | Khớp UA-ZM (cùng mục), nhưng mọi trang chỉ xem. |
| CMD (chiHuyB, chiHuyD) | 8 | Khớp UA (cùng mục), nhưng mọi trang chỉ xem. |
| TECH (kyThuat) | 3 | HỆ THỐNG (3): Tài khoản, Nhật ký hoạt động, Sao lưu dữ liệu. |

- **Chiều liên quan:** chiều 3 (ma trận quyền), danh mục Sidebar; `V2_HANH_VI_HE_THONG.md` mục 1.

---

## 4A. Nhóm XEM KẾT QUẢ

### TR-dashboard — Tổng quan (/dashboard)

**Route:** `/dashboard` (dashboard#show). **Lớp bảo vệ:** BusinessRoleRequired (xem `V2_CHIEU_TEST.md` chiều 3, hàng Tổng quan). 6 vai trò nghiệp vụ đều xem được; TECH bị chặn. Trang mang số liệu — trích từ Phần 2.

- **TR-dashboard-SA `[CẢ HAI]`:** quanTri thấy tổng quan toàn hệ thống — bảng đơn vị (thâm điện, thành tiền, trạng thái nhập liệu của Đơn vị A, B, C, D) cộng bảng khu vực (tổng điện công cộng và bơm nước per Khu vực 1, Khu vực 2) cộng vùng cảnh báo. Số liệu khớp Phần 2: tổng thiếu Khu vực 1 = 177,42 kW, tổng thừa 33,34 kW, tổng thành tiền thiếu 414.517 đồng, tổng thành tiền thừa 77.891 đồng (EN-KV1-TOTALS); Khu vực 2 tổng thiếu 22,87 kW, tổng thừa 20,53 kW, tổng thành tiền thiếu 53.430 đồng, tổng thành tiền thừa 47.956 đồng (EN-KV2-TOTALS). Cảnh báo phạm vi toàn hệ thống; kỳ tháng 5 năm 2026 đã tính đủ → không cảnh báo thiếu dữ liệu. Sidebar 17 mục.
- **TR-dashboard-DC `[CẢ HAI]`:** chiHuySuDoan thấy tổng quan toàn hệ thống (giống SA), chỉ xem. Sidebar 16 mục.
- **TR-dashboard-UAZM `[CẢ HAI]`:** adminA thấy tổng quan Đơn vị A cộng Khu vực 1 (phạm vi quản lý khu vực). Cảnh báo chỉ giới hạn Khu vực 1. adminC: Đơn vị C cộng Khu vực 2 (tổng Khu vực 2 theo EN-KV2-TOTALS). Sidebar 11 mục.
- **TR-dashboard-UA `[CẢ HAI]`:** adminB thấy tổng quan **chỉ Đơn vị B** (đầu mối Đại đội 1: thiếu 106,86 kW, thành tiền 249.659 đồng — EN-KV1-SUMMARY-04). Không thấy số liệu khu vực, không thấy đơn vị khác. adminD: chỉ Đơn vị D (Trinh sát thiếu 22,87 kW, thành tiền 53.430 đồng — EN-KV2-SUMMARY-02). Sidebar 8 mục.
- **TR-dashboard-CMDZM `[CẢ HAI]`:** chiHuyA hiển thị giống adminA (Đơn vị A + Khu vực 1), chiHuyC giống adminC, chỉ xem. Dashboard không có ô nhập hay nút thao tác nên khác biệt CMD/UA ở đây không đáng kể; sidebar 11 mục.
- **TR-dashboard-CMD `[CẢ HAI]`:** chiHuyB giống adminB (chỉ Đơn vị B), chiHuyD giống adminD, chỉ xem. Sidebar 8 mục.
- **TR-dashboard-TECH `[TỰ ĐỘNG]`:** kyThuat bị chặn — vào `/dashboard` redirect về `/users`. Dashboard không xuất hiện trên sidebar TECH (3 mục).

**Trạng thái rỗng/đặc biệt:** nếu kỳ chưa tính (xem GD4-01), dashboard hiển thị thâm điện và số dư bằng 0, không lỗi 500.

- **Chiều liên quan:** chiều 2 (7 vai trò), chiều 3 (Tổng quan), chiều 8 (trạng thái tính toán), chiều 9 (cảnh báo per phạm vi).

### TR-billing — Bảng tính tiền (/billing)

**Route:** `/billing` (billing#show). **Lớp bảo vệ:** BusinessRoleRequired + authorize! (chiều 3, hàng Bảng tính tiền). Thao tác: Xem, Tính toán lại (SA/DC/UA-ZM/UA), Xuất Excel (mọi vai trò nghiệp vụ). Đây là trang mang số liệu trọng tâm — mọi số trích từ Phần 2. Bảng chỉ hiển thị đầu mối **sinh hoạt**.

- **TR-billing-SA `[CẢ HAI]`:** quanTri xem gộp toàn bộ 8 đầu mối sinh hoạt khi không lọc — Khu vực 1: Ban Tác huấn thiếu 37,24; Văn thư thừa 5,72; Kho vật tư thừa 27,62; Đại đội 1 thiếu 106,86; Chỉ huy khu vực thiếu 33,32 (EN-KV1-SUMMARY-01..05). Khu vực 2: Quân y thừa 9,32; Trinh sát thiếu 22,87; Chỉ huy khu vực 2 thừa 11,20 (EN-KV2-SUMMARY-01..03). **30 cột** (có cả Khu vực + Đơn vị). Có dropdown kỳ + dropdown khu vực + dropdown đơn vị (cascade). Nút Tính toán lại + Xuất Excel hiện. Hàng tổng: EN-KV1-TOTALS khi lọc Khu vực 1 (tổng thiếu 177,42; tổng thành tiền thiếu 414.517). SA chọn Khu vực 1 → cột Khu vực ẩn → còn 29 cột; chọn thêm Đơn vị A → cột Đơn vị ẩn → còn 28 cột, hiện 3 hàng (Ban Tác huấn, Văn thư, Kho vật tư). Sidebar 17 mục.
- **TR-billing-UAZM `[CẢ HAI]`:** adminA thấy **4 hàng**: Ban Tác huấn thiếu 37,24; Văn thư thừa 5,72; Kho vật tư thừa 27,62; Chỉ huy khu vực thiếu 33,32 (đầu mối Đơn vị A cộng đầu mối thuộc khu vực trực tiếp). KHÔNG thấy Đại đội 1. **29 cột** (có Đơn vị, ẩn Khu vực). Cột Đơn vị của hàng "Chỉ huy khu vực" **trống** (đầu mối thuộc khu vực trực tiếp — chiều 6). Không có dropdown khu vực/đơn vị (chỉ SA có); có dropdown kỳ. Nút Tính toán lại + Xuất Excel hiện. adminC (Khu vực 2): **2 hàng** — Quân y thừa 9,32; Chỉ huy khu vực 2 thừa 11,20; KHÔNG thấy Trinh sát; 29 cột; cột Đơn vị hàng Chỉ huy khu vực 2 trống. Sidebar 11 mục.
- **TR-billing-UA `[CẢ HAI]`:** adminB thấy **1 hàng** — Đại đội 1 thiếu 106,86, thành tiền 249.659 (EN-KV1-SUMMARY-04). **28 cột** (ẩn cả Khu vực + Đơn vị). Không thấy đầu mối Đơn vị A, không thấy Chỉ huy khu vực. Nút Tính toán lại + Xuất Excel hiện (UA được tính toán lại). adminD: 1 hàng — Trinh sát thiếu 22,87, thành tiền 53.430 (EN-KV2-SUMMARY-02). Sidebar 8 mục.
- **TR-billing-CMDZM `[CẢ HAI]`:** chiHuyA phạm vi giống adminA (4 hàng, 29 cột, cột Đơn vị Chỉ huy khu vực trống) nhưng **nút Tính toán lại bị ẩn**; nút Xuất Excel vẫn hiện (CMD được xuất Excel theo chiều 3). chiHuyC giống adminC (2 hàng). Sidebar 11 mục.
- **TR-billing-CMD `[CẢ HAI]`:** chiHuyB phạm vi giống adminB (1 hàng Đại đội 1, 28 cột), nút Tính toán lại ẩn, Xuất Excel hiện. chiHuyD giống adminD. Sidebar 8 mục.
- **TR-billing-TECH `[TỰ ĐỘNG]`:** kyThuat vào `/billing` bị redirect về `/users`. Không có mục Bảng tính tiền trên sidebar TECH.

**Trạng thái rỗng:** kỳ mới mở chưa bấm tính → bảng trống (không hàng dữ liệu), không lỗi 500, nút Tính toán lại bật cho SA/UA/UA-ZM (xem GD4-01). **Stale:** sửa chỉ số chưa tính lại → bảng hiện số cũ (GD4-02); Xuất Excel khi stale → file chứa số cũ (GD4-03).

- **Chiều liên quan:** chiều 2, chiều 3 (Bảng tính tiền), chiều 6 (cột Đơn vị trống), chiều 7 (dropdown kỳ + dropdown zone/unit SA), chiều 8 (stale/chưa tính), chiều 12 (số cột + Excel). Tham chiếu GD3 (phạm vi), GD4 (tính toán), GD5 (số cột + gộp ô).

### TR-history — Tra cứu lịch sử (/history)

**Route:** `/history` (history#show). **Lớp bảo vệ:** BusinessRoleRequired (chiều 3, hàng Tra cứu lịch sử). Thao tác: Xem kỳ cũ, so sánh 2 kỳ, xem theo khoảng. 6 vai trò nghiệp vụ xem được; TECH chặn. Phạm vi dữ liệu per vai trò **giống billing** (SA toàn bộ, UA-ZM đơn vị + khu vực trực tiếp, UA đơn vị mình). Khác biệt với billing: trang so sánh **luôn hiện cả hai cột Khu vực và Đơn vị** (so sánh kỳ cần đủ ngữ cảnh — theo CLAUDE.md); dropdown khu vực/đơn vị khi xem kỳ cũ dùng `with_discarded` để hiện entity đã xóa.

| Vai trò | Truy cập | Dữ liệu so sánh | Sửa được | Ghi chú |
|---|---|---|---|---|
| TR-history-SA `[CẢ HAI]` | Xem | Toàn bộ 8 đầu mối sinh hoạt, lọc theo dropdown | Không (chỉ xem lịch sử) | Chọn kỳ A + kỳ B → bảng so sánh 2 cột + cột chênh lệch; đầu mối chỉ có ở 1 kỳ → cột kỳ thiếu trống + ghi chú. Dropdown zone/unit dùng `with_discarded`. Sidebar 17. |
| TR-history-UAZM `[CẢ HAI]` | Xem | adminA: 4 đầu mối (Đơn vị A + Chỉ huy khu vực); adminC: 2 (Quân y + Chỉ huy khu vực 2) | Không | Phạm vi như billing UA-ZM. Cả hai cột Khu vực + Đơn vị hiện. Sidebar 11. |
| TR-history-UA `[CẢ HAI]` | Xem | adminB: Đại đội 1; adminD: Trinh sát | Không | Phạm vi 1 đơn vị. Sidebar 8. |
| TR-history-CMDZM `[CẢ HAI]` | Xem | Như UA-ZM tương ứng | Không | Trang chỉ xem; không có ô nhập nên không khác CMD. Sidebar 11. |
| TR-history-CMD `[CẢ HAI]` | Xem | Như UA tương ứng | Không | Sidebar 8. |
| TR-history-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | Không có mục trên sidebar. |

- **Chiều liên quan:** chiều 2, chiều 3 (Tra cứu lịch sử), chiều 4 (`with_discarded` xem entity đã xóa), chiều 7 (chọn kỳ A/B, khoảng). Tham chiếu GD1 (entity đã xóa hiện ở kỳ cũ).

---

## 4B. Nhóm NHẬP LIỆU

### TR-electricity_supply — Nhập số điện lực (/electricity_supply)

**Route:** `/electricity_supply` (electricity_supply#show). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard + authorize! (chiều 3). Nhập số sử dụng công tơ tổng (main_meter_readings). Điểm mấu chốt: **chỉ vai trò gắn với khu vực (có main_meter) mới vào được** — UA và CMD (đơn vị không quản lý khu vực, không có công tơ tổng) bị redirect.

| Vai trò | Truy cập | Dữ liệu | Sửa được | Ghi chú |
|---|---|---|---|---|
| TR-electricity_supply-SA `[CẢ HAI]` | Vào được | Tất cả công tơ tổng (CT-Tổng-KV1 = 2.100; CT-Tổng-KV2 = 1.100) | Sửa | Ô nhập số sử dụng; nút Lưu hiện. Sidebar 17. |
| TR-electricity_supply-UAZM `[CẢ HAI]` | Vào được | Công tơ tổng khu vực mình (adminA: CT-Tổng-KV1; adminC: CT-Tổng-KV2) | Sửa | Sidebar 11. |
| TR-electricity_supply-UA `[TỰ ĐỘNG]` | **Redirect** | — | — | `authorize_or_redirect` chặn (đơn vị B/D không có main_meter). Không có mục trên sidebar UA (8 mục). |
| TR-electricity_supply-CMDZM `[CẢ HAI]` | Vào được (xem) | Công tơ tổng khu vực mình | Không (disabled) | Ô nhập disabled, nút Lưu ẩn. chiHuyA: CT-Tổng-KV1; chiHuyC: CT-Tổng-KV2. Sidebar 11. |
| TR-electricity_supply-CMD `[TỰ ĐỘNG]` | **Redirect** | — | — | Như UA. Không có mục trên sidebar CMD (8 mục). |
| TR-electricity_supply-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Đặc biệt:** main_meter_readings không kế thừa giữa kỳ — mỗi kỳ mới, trang hiện "Chưa nhập" cho mọi công tơ tổng (xem GD6-03). Khi không có kỳ mở: hiện "Không có kỳ đang mở", ô nhập disabled.

- **Chiều liên quan:** chiều 2, chiều 3 (Nhập số điện lực), chiều 11 (main_meter không kế thừa). Tham chiếu GD6-03.

### TR-meter_entries — Chỉ số đầu mối (/meter_entries)

**Route:** `/meter_entries` (meter_entries#show). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard (qua MeterReadingEntry) (chiều 3). Hiển thị công tơ **sinh hoạt + công cộng** (loại bỏ bơm nước). Có tìm kiếm theo tên đầu mối; **filter khu vực/đơn vị và cột Khu vực/Đơn vị chỉ SA** thấy. Số đầu kỳ editable mọi kỳ.

| Vai trò | Truy cập | Dữ liệu/Cột | Sửa được | Ghi chú |
|---|---|---|---|---|
| TR-meter_entries-SA `[CẢ HAI]` | Vào được | Tất cả công tơ sinh hoạt + công cộng cả 2 khu vực; có cột Khu vực + Đơn vị; có filter zone/unit cascade + search | Sửa | Nút Lưu hiện. Sidebar 17. |
| TR-meter_entries-UAZM `[CẢ HAI]` | Vào được | adminA: CT-A1, CT-A2, CT-A3, CT-CC-A (Đơn vị A) + CT-KV1, CT-CC-KV (khu vực trực tiếp). adminC: CT-QY, CT-CC-C + CT-CHKV2. Không cột Khu vực/Đơn vị, không filter | Sửa | Có search theo tên. Số đầu kỳ editable. Sidebar 11. |
| TR-meter_entries-UA `[CẢ HAI]` | Vào được | adminB: CT-B1 (Đại đội 1) + CT-CC-B (Trạm gác). adminD: CT-TS (Trinh sát). Chỉ công tơ đơn vị mình; không cột Khu vực/Đơn vị | Sửa | Sidebar 8. |
| TR-meter_entries-CMDZM `[CẢ HAI]` | Vào được (xem) | Như adminA/adminC tương ứng | Không (disabled) | Mọi ô nhập disabled, nút Lưu ẩn. Sidebar 11. |
| TR-meter_entries-CMD `[CẢ HAI]` | Vào được (xem) | Như adminB/adminD tương ứng | Không (disabled) | Sidebar 8. |
| TR-meter_entries-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Đầu vào danh sách (chỉ SA):** filter zone → unit cascade; đổi zone reset unit về "Tất cả"; search giữ nguyên khi đổi filter. Chỉ số cuối < chỉ số đầu → hiện thêm ô nhập thủ công số sử dụng + ghi chú (conditional, theo đặc tả đầu vào của V2_CHIEU_TEST). Số đầu kỳ kế thừa pre-fill từ reading_end kỳ trước nhưng sửa được (GD6-03); đầu mối tạo giữa kỳ có reading_start = 0 (GD6-01, GD6-04).

- **Chiều liên quan:** chiều 2, chiều 3 (Chỉ số đầu mối), chiều 6 (đầu mối thuộc đơn vị vs khu vực), chiều 11 (kế thừa/tạo giữa kỳ). Tham chiếu GD3 (phạm vi), GD6 (nhận dữ liệu).

### TR-pump_entries — Chỉ số bơm nước (/pump_entries)

**Route:** `/pump_entries` (pump_entries#show). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard (chiều 3). Hiển thị riêng công tơ **bơm nước**. Bơm nước luôn thuộc khu vực trực tiếp → chỉ vai trò khu vực thấy; UA và CMD **trống** (không có công tơ bơm nước trong phạm vi).

| Vai trò | Truy cập | Dữ liệu | Sửa được | Ghi chú |
|---|---|---|---|---|
| TR-pump_entries-SA `[CẢ HAI]` | Vào được | Tất cả công tơ bơm nước (CT-BN1 Khu vực 1; CT-BN2 Khu vực 2); có cột zone/unit + filter + search | Sửa | Sidebar 17. |
| TR-pump_entries-UAZM `[CẢ HAI]` | Vào được | adminA: CT-BN1 (Trạm bơm 1). adminC: CT-BN2 (Trạm bơm 2) | Sửa | Sidebar 11. |
| TR-pump_entries-UA `[CẢ HAI]` | Vào được | **Trống** (Đơn vị B/D không có công tơ bơm nước) | — | Hiển thị trạng thái rỗng "Không có bản ghi". Mục **không hiện** trên sidebar UA (8 mục) — UA không có trang này. |
| TR-pump_entries-CMDZM `[CẢ HAI]` | Vào được (xem) | Như UA-ZM tương ứng | Không (disabled) | Ô nhập disabled, nút Lưu ẩn. Sidebar 11. |
| TR-pump_entries-CMD `[CẢ HAI]` | — | **Trống** | — | Mục không hiện trên sidebar CMD (8 mục) — CMD không có data bơm nước. |
| TR-pump_entries-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

- **Chiều liên quan:** chiều 2, chiều 3 (Chỉ số bơm nước), chiều 5 (loại bơm nước), chiều 6. Tham chiếu GD3.

---

## 4C. Nhóm KHAI BÁO

### TR-contact_points — Đầu mối (/contact_points)

**Route:** `/contact_points` (CRUD). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard + StructureChangeGuard (chiều 3). CRUD 4 loại đầu mối + công tơ. Danh sách có filter theo loại; **dropdown loại hiển thị đúng per vai trò** (UA: 2 loại sinh hoạt + công cộng; UA-ZM/SA: 4 loại). Cột Khu vực + Đơn vị chỉ SA thấy (`show_zone_unit = current_user.system_admin?`).

| Vai trò | Truy cập | Dữ liệu/Cột | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-contact_points-SA `[CẢ HAI]` | CRUD | Tất cả đầu mối cả 2 khu vực; cột Khu vực + Đơn vị; filter loại 4 giá trị + filter zone/unit | Có | Form tạo có radio "Đơn vị/Khu vực" (assignment_mode). Sidebar 17. |
| TR-contact_points-UAZM `[CẢ HAI]` | CRUD | adminA: đầu mối Đơn vị A + đầu mối thuộc Khu vực 1 (Chỉ huy khu vực, Đèn đường, Trạm bơm 1, Thợ xây). adminC: đầu mối Đơn vị C + thuộc Khu vực 2. Không cột Khu vực/Đơn vị. Dropdown loại 4 giá trị | Có (4 loại khu vực mình) | Có radio "Đơn vị/Khu vực". Sidebar 11. |
| TR-contact_points-UA `[CẢ HAI]` | CRUD | adminB: chỉ đầu mối Đơn vị B (Đại đội 1, Trạm gác). adminD: Đơn vị D (Trinh sát). Dropdown loại **2 giá trị** (sinh hoạt, công cộng) | Có (sinh hoạt + công cộng đơn vị mình) | Không có radio "Đơn vị/Khu vực" (mặc định đơn vị). Không thấy loại bơm nước/ngoài biên chế. Sidebar 8. |
| TR-contact_points-CMDZM `[CẢ HAI]` | Xem | Như adminA/adminC | Không | Nút Thêm/Sửa/Xóa ẩn. Sidebar 11. |
| TR-contact_points-CMD `[CẢ HAI]` | Xem | Như adminB/adminD (đầu mối đơn vị) | Không | Nút Thêm/Sửa/Xóa ẩn. Sidebar 8. |
| TR-contact_points-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Vị trí phân cấp hiển thị (chiều 10):** danh sách hiện cột Khối/Nhóm theo vị trí — Ban Tác huấn (khối + nhóm), Văn thư (khối), Kho vật tư (trực tiếp đơn vị), Quân y (nhóm không khối — Khu vực 2), Chỉ huy khu vực (thuộc khu vực, cột Đơn vị trống). Trạng thái kỳ cũ mở lại (C): StructureChangeGuard chặn tạo/xóa/đổi tên, chỉ sửa số liệu per kỳ.

- **Chiều liên quan:** chiều 2, chiều 3 (Đầu mối), chiều 5 (4 loại), chiều 6, chiều 10 (vị trí phân cấp). Tham chiếu GD2 (cleanup khi xóa), GD6 (tạo giữa kỳ), GD5 (vị trí phân cấp).

### TR-blocks — Khối (/blocks)

**Route:** `/blocks` (CRUD). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard + StructureChangeGuard (chiều 3). CRUD khối, phạm vi đơn vị. Cột Khu vực + Đơn vị chỉ SA.

| Vai trò | Truy cập | Dữ liệu/Cột | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-blocks-SA `[CẢ HAI]` | CRUD | Tất cả khối (Khu vực 1: "Phòng Tham mưu" của Đơn vị A); cột Khu vực + Đơn vị; filter zone/unit | Có | Sidebar 17. |
| TR-blocks-UAZM `[CẢ HAI]` | CRUD | adminA: khối Đơn vị A ("Phòng Tham mưu"). adminC: khối Đơn vị C (Khu vực 2 không có khối → trống). Không cột Khu vực/Đơn vị | Có (đơn vị) | Khối thuộc đơn vị, không có khối "thuộc khu vực". Sidebar 11. |
| TR-blocks-UA `[CẢ HAI]` | CRUD | adminB/adminD: khối đơn vị mình (Đơn vị B/D không có khối → trạng thái rỗng "Không có bản ghi") | Có (đơn vị) | Sidebar 8. |
| TR-blocks-CMDZM `[CẢ HAI]` | Xem | Như adminA/adminC | Không | Nút ẩn. Sidebar 11. |
| TR-blocks-CMD `[CẢ HAI]` | Xem | Như adminB/adminD | Không | Nút ẩn. Sidebar 8. |
| TR-blocks-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Xóa cascade:** xóa khối "Phòng Tham mưu" → nhóm "Ban Tác huấn".block_id = null, đầu mối Văn thư.block_id = null (lên đơn vị) — theo chiều D (Delete).

- **Chiều liên quan:** chiều 2, chiều 3 (Khối), chiều 10 (cascade khi xóa khối).

### TR-groups — Nhóm (/groups)

**Route:** `/groups` (CRUD). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard + StructureChangeGuard (chiều 3). CRUD nhóm, phạm vi đơn vị. Cột Khu vực + Đơn vị chỉ SA. Form SA có cascade Đơn vị → Khối (`scoped_block_select`).

| Vai trò | Truy cập | Dữ liệu/Cột | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-groups-SA `[CẢ HAI]` | CRUD | Tất cả nhóm (Khu vực 1: "Ban Tác huấn" trong khối; Khu vực 2: "Tổ Quân y" không khối); cột Khu vực + Đơn vị; filter zone/unit | Có | Form cascade Đơn vị → Khối. Sidebar 17. |
| TR-groups-UAZM `[CẢ HAI]` | CRUD | adminA: nhóm Đơn vị A ("Ban Tác huấn"). adminC: nhóm Đơn vị C ("Tổ Quân y"). Không cột Khu vực/Đơn vị | Có (đơn vị) | "Tổ Quân y" là nhóm trực tiếp dưới đơn vị, không khối (vị trí phân cấp thứ 3). Sidebar 11. |
| TR-groups-UA `[CẢ HAI]` | CRUD | adminB/adminD: nhóm đơn vị mình (Đơn vị B/D không có nhóm → trạng thái rỗng) | Có (đơn vị) | Sidebar 8. |
| TR-groups-CMDZM `[CẢ HAI]` | Xem | Như adminA/adminC | Không | Nút ẩn. Sidebar 11. |
| TR-groups-CMD `[CẢ HAI]` | Xem | Như adminB/adminD | Không | Nút ẩn. Sidebar 8. |
| TR-groups-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Xóa cascade:** xóa nhóm "Ban Tác huấn" → đầu mối Ban Tác huấn.group_id = null (lên khối "Phòng Tham mưu" nếu có, hoặc lên đơn vị).

- **Chiều liên quan:** chiều 2, chiều 3 (Nhóm), chiều 10 (nhóm không khối + cascade).

### TR-unit_config — Cấu hình đơn vị (/unit_config)

**Route:** `/unit_config` (unit_config#show). **Lớp bảo vệ:** BusinessRoleRequired + PeriodGuard (chiều 3). Cấu hình tỷ lệ công cộng đơn vị (unit_public_rate) + cột "Khác" (other_deductions) per đầu mối **sinh hoạt**.

| Vai trò | Truy cập | Dữ liệu | Sửa được | Ghi chú |
|---|---|---|---|---|
| TR-unit_config-SA `[CẢ HAI]` | Vào được | Chọn đơn vị bất kỳ; cột Khác đầu mối đơn vị đó (cộng đầu mối khu vực nếu đơn vị là quản lý khu vực) | Sửa | Đơn vị A 3%, Đơn vị B 0%, Đơn vị C 5%, Đơn vị D 0%. Sidebar 17. |
| TR-unit_config-UAZM `[CẢ HAI]` | Vào được | adminA: Đơn vị A (3%) + cột Khác đầu mối Đơn vị A (Ban Tác huấn cố định 5; Văn thư hệ số −2,5; Kho vật tư cố định 0) + cột Khác đầu mối khu vực (Chỉ huy khu vực cố định 0). adminC: Đơn vị C (5%) + Quân y + Chỉ huy khu vực 2 | Sửa | Sidebar 11. |
| TR-unit_config-UA `[CẢ HAI]` | Vào được | adminB: Đơn vị B (0%) + cột Khác Đại đội 1 (hệ số 3). adminD: Đơn vị D (0%) + Trinh sát. Không thấy đầu mối khu vực | Sửa | Sidebar 8. |
| TR-unit_config-CMDZM `[CẢ HAI]` | Vào được (xem) | Như adminA/adminC | Không (disabled) | Ô nhập disabled, nút Lưu ẩn. Sidebar 11. |
| TR-unit_config-CMD `[CẢ HAI]` | Vào được (xem) | Như adminB/adminD | Không (disabled) | Sidebar 8. |
| TR-unit_config-TECH `[TỰ ĐỘNG]` | Chặn (redirect /users) | — | — | — |

**Conditional:** other_deduction loại "cố định" → giá trị là kW tuyệt đối (Ban Tác huấn +5); loại "hệ số" → giá trị nhân quân số đầu mối (Văn thư −2,5 × 2 người = −5,00; Đại đội 1: 3 × 11 = 33,00 — khớp cột Khác trong EN-KV1-SUMMARY-02 và -04).

- **Chiều liên quan:** chiều 2, chiều 3 (Cấu hình đơn vị), chiều 6, conditional field (cố định/hệ số). Tham chiếu EN-KV1-SUMMARY (cột Khác).

---

## 4D. Nhóm THIẾT LẬP

### TR-zones — Khu vực (/zones)

**Route:** `/zones` (CRUD). **Lớp bảo vệ:** SettingsAccessGuard (`require_system_admin!`) + PeriodGuard + StructureChangeGuard (chiều 3). CRUD khu vực + công tơ tổng (nested). Chỉ SA toàn quyền; mọi vai trò non-SA (kể cả đơn vị quản lý khu vực UA-ZM/CMD-ZM) bị **chặn** (page-level guard, sidebar cũng ẩn mục).

| Vai trò | Truy cập | Dữ liệu | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-zones-SA `[CẢ HAI]` | CRUD | Khu vực 1, Khu vực 2 (kèm công tơ tổng CT-Tổng-KV1, CT-Tổng-KV2) | Có | Sidebar 17. |
| TR-zones-UAZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | adminA/adminC không thấy mục Khu vực (11 mục); truy cập trực tiếp `/zones` bị `require_system_admin!` chặn. |
| TR-zones-UA `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | adminB/adminD không thấy mục Khu vực (8 mục); truy cập trực tiếp `/zones` bị `require_system_admin!` chặn. |
| TR-zones-CMDZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | chiHuyA/chiHuyC không thấy mục Khu vực (11 mục); truy cập trực tiếp bị chặn. |
| TR-zones-CMD `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | Như UA (8 mục); truy cập trực tiếp bị chặn. |
| TR-zones-TECH `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | — |

- **Chiều liên quan:** chiều 2, chiều 3 (Khu vực). Truy cập trực tiếp URL của mọi vai trò non-SA đã được `SettingsAccessGuard` chặn (CLAUDE.md).

### TR-units — Đơn vị (/units)

**Route:** `/units` (CRUD). **Lớp bảo vệ:** SettingsAccessGuard (`require_system_admin!`) + PeriodGuard + StructureChangeGuard (chiều 3). Chỉ SA toàn quyền; **mọi non-SA bị chặn** (page-level guard, sidebar cũng ẩn mục — Đơn vị là cấu trúc cấp Sư đoàn).

| Vai trò | Truy cập | Dữ liệu | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-units-SA `[CẢ HAI]` | CRUD | Đơn vị A, B (Khu vực 1), C, D (Khu vực 2); cột Khu vực | Có | Sidebar 17. |
| TR-units-UAZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | Mục không trên sidebar (11 mục không gồm Đơn vị); truy cập trực tiếp `/units` bị `require_system_admin!` chặn. |
| TR-units-UA `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | Như trên (8 mục). |
| TR-units-CMDZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (11 mục). |
| TR-units-CMD `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-units-TECH `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | — |

- **Chiều liên quan:** chiều 2, chiều 3 (Đơn vị). Truy cập trực tiếp URL của non-SA đã được `SettingsAccessGuard` chặn (CLAUDE.md).

### TR-pump_allocations — Phân bổ bơm nước (/pump_allocations)

**Route:** `/pump_allocations` (CRUD). **Lớp bảo vệ:** SettingsAccessGuard (`require_system_admin_or_zone_manager!`) + PeriodGuard (chiều 3). Cấu hình phân bổ per khu vực. SA + UA-ZM CRUD; CMD-ZM xem; UA + CMD bị **chặn** (page-level guard, sidebar cũng ẩn mục). Đối tượng nhận phân bổ: đơn vị, đầu mối sinh hoạt thuộc khu vực, đầu mối ngoài biên chế thuộc khu vực.

| Vai trò | Truy cập | Dữ liệu | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-pump_allocations-SA `[CẢ HAI]` | CRUD | Tất cả phân bổ (Khu vực 1: Trạm bơm 1 → Chỉ huy khu vực 20% + Đơn vị A/B hệ số 1 + Thợ xây hệ số 0,5; Khu vực 2: Trạm bơm 2 thuần hệ số) | Có | Cho sửa cả khi kỳ cũ mở lại. Form có toggle target (đơn vị/đầu mối) + toggle allocation (% cố định/hệ số). Sidebar 17. |
| TR-pump_allocations-UAZM `[CẢ HAI]` | CRUD | adminA: phân bổ Khu vực 1. adminC: phân bổ Khu vực 2 (thuần hệ số) | Có (khu vực mình) | Sidebar 11. |
| TR-pump_allocations-UA `[CẢ HAI]` | Chặn (redirect, errors.access_denied) | — | — | adminB/adminD không thấy mục (8 mục); truy cập trực tiếp bị `require_system_admin_or_zone_manager!` chặn. |
| TR-pump_allocations-CMDZM `[CẢ HAI]` | Xem | Như adminA/adminC | Không (chỉ đọc) | Nút Thêm/Sửa/Xóa ẩn. Sidebar 11. |
| TR-pump_allocations-CMD `[CẢ HAI]` | Chặn (redirect, errors.access_denied) | — | — | Như UA (8 mục); truy cập trực tiếp bị chặn. |
| TR-pump_allocations-TECH `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | — |

- **Chiều liên quan:** chiều 2, chiều 3 (Phân bổ bơm nước), toggle target/allocation. Tham chiếu EN-KV1-PUMP, EN-KV2-PUMP.

### TR-pricing — Đơn giá điện (/pricing)

**Route:** `/pricing` (pricing#show). **Lớp bảo vệ:** SettingsAccessGuard (`require_system_admin!`) + authorize! (chiều 3). Đơn giá per kỳ + mở/đóng/mở lại kỳ. **Chỉ SA toàn quyền**; non-SA bị **chặn** (page-level guard, sidebar cũng ẩn mục).

| Vai trò | Truy cập | Dữ liệu | Thao tác | Ghi chú |
|---|---|---|---|---|
| TR-pricing-SA `[CẢ HAI]` | Toàn quyền | Đơn giá kỳ tháng 5 năm 2026 = 2.336,4 đồng/kW; danh sách kỳ | Mở kỳ mới, đóng kỳ, mở lại kỳ cũ | Sidebar 17. Tham chiếu Phần 5 (vòng đời kỳ). |
| TR-pricing-UAZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | Không có mục (11 mục không gồm Đơn giá); truy cập trực tiếp bị `require_system_admin!` chặn. |
| TR-pricing-UA `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-pricing-CMDZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (11 mục). |
| TR-pricing-CMD `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-pricing-TECH `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | — |

- **Chiều liên quan:** chiều 1 (vòng đời kỳ), chiều 2, chiều 3 (Đơn giá điện). Tham chiếu Phần 5 (mở/đóng/mở lại kỳ).

### TR-ranks — Nhóm cấp bậc (/ranks)

**Route:** `/ranks` (CRUD). **Lớp bảo vệ:** SettingsAccessGuard (`require_system_admin!`) + PeriodGuard + StructureChangeGuard (chiều 3). 7 nhóm cấp bậc + định mức (cấu hình chung toàn hệ thống). SA CRUD; mọi non-SA bị **chặn** (page-level guard, sidebar cũng ẩn mục).

| Vai trò | Truy cập | Dữ liệu | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-ranks-SA `[CẢ HAI]` | CRUD | 7 nhóm với định mức 570, 440, 305, 130, 210, 110, 24 | Có | Sidebar 17. Thêm rank giữa kỳ → personnel_entries count 0 cho mọi đầu mối sinh hoạt (GD6-02). |
| TR-ranks-UAZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | Mục không trên sidebar (11 mục); truy cập trực tiếp bị `require_system_admin!` chặn. |
| TR-ranks-UA `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-ranks-CMDZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (11 mục). |
| TR-ranks-CMD `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-ranks-TECH `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | — | — |

> **Phạm vi /ranks (đã đối chiếu code):** trang /ranks giờ **chặn mọi non-SA** bằng `SettingsAccessGuard` (`require_system_admin!`) — UA, UA-ZM, CMD, CMD-ZM, TECH truy cập trực tiếp qua URL đều bị redirect (errors.access_denied). Quyền `can :read, Rank` **vẫn được giữ** trong `Ability` cho unit_admin/commander vì form khai báo nhân sự của đầu mối dùng `current_period.ranks` (không dùng trang /ranks) — chặn trang không làm hỏng form. Mục "Nhóm cấp bậc" cũng **ẩn trên sidebar** cho non-SA (`sidebar_helper.rb` chỉ thêm `ranks` vào danh mục của `system_admin`). Đây là đảo ngược so với mô tả cũ (non-SA xem được /ranks qua URL): việc thắt chặt này nhất quán với THIET_KE "Sidebar per role" và bảng quyền chiều 3 đã cập nhật.

- **Chiều liên quan:** chiều 2, chiều 3 (Nhóm cấp bậc), chiều 11 (thêm rank giữa kỳ). Tham chiếu GD6-02.

---

## 4E. Nhóm HỆ THỐNG

### TR-users — Tài khoản (/users)

**Route:** `/users` (CRUD). **Lớp bảo vệ:** SettingsAccessGuard (`require_account_manager!` — chỉ SA hoặc TECH) + authorize! (CanCanCan) (chiều 3). **SA CRUD tất cả trừ tài khoản TECH; TECH CRUD tất cả tài khoản; non-SA-non-TECH bị chặn** (page-level guard, sidebar cũng ẩn mục).

| Vai trò | Truy cập | Dữ liệu | Tạo/Sửa/Xóa | Ghi chú |
|---|---|---|---|---|
| TR-users-SA `[CẢ HAI]` | CRUD (trừ TECH) | Tất cả tài khoản trừ tài khoản technician | Có (không quản lý kyThuat) | Form có toggle Role → Unit (`role_unit_toggle`). Reset mật khẩu. Sidebar 17. |
| TR-users-TECH `[CẢ HAI]` | CRUD (tất cả) | Tất cả tài khoản (gồm cả SA và TECH khác) | Có | TECH là vai trò duy nhất quản lý được mọi tài khoản. Sidebar 3 mục. |
| TR-users-UAZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | Mục không trên sidebar (11 mục); truy cập trực tiếp `/users` bị `require_account_manager!` chặn. |
| TR-users-UA `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |
| TR-users-CMDZM `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (11 mục). |
| TR-users-CMD `[TỰ ĐỘNG]` | Chặn (redirect, errors.access_denied) | — | Không | (8 mục). |

**Validation:** tạo/sửa tài khoản — mật khẩu phải đủ phức tạp (1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt); không tự xóa mình; không xóa tài khoản mặc định (chi tiết Phần 5). Toggle Role → Unit: chọn role unit_admin/commander → hiện field Đơn vị; chọn system_admin/technician → ẩn field Đơn vị.

- **Chiều liên quan:** chiều 2, chiều 3 (Tài khoản), toggle Role → Unit. Tham chiếu Phần 5 (validation, reset mật khẩu).

### TR-audit_logs — Nhật ký hoạt động (/audit_logs)

**Route:** `/audit_logs` (audit_logs#index). **Lớp bảo vệ:** authorize!(:read, PaperTrail::Version) (chiều 3). **Chỉ SA + TECH xem; UA/UA-ZM/CMD/CMD-ZM bị chặn.**

| Vai trò | Truy cập | Dữ liệu | Ghi chú |
|---|---|---|---|
| TR-audit_logs-SA `[CẢ HAI]` | Xem | Toàn bộ log PaperTrail; filter loại thao tác (tạo/sửa/xóa) + đối tượng (model) + người thao tác + khoảng thời gian | Sidebar 17. |
| TR-audit_logs-TECH `[CẢ HAI]` | Xem | Như SA | Sidebar 3 mục. |
| TR-audit_logs-UAZM `[TỰ ĐỘNG]` | **Chặn** | — | Bị chặn (không phải redirect /users — authorize! từ chối). Mục không trên sidebar (11). |
| TR-audit_logs-UA `[TỰ ĐỘNG]` | **Chặn** | — | (8 mục). |
| TR-audit_logs-CMDZM `[TỰ ĐỘNG]` | **Chặn** | — | (11 mục). |
| TR-audit_logs-CMD `[TỰ ĐỘNG]` | **Chặn** | — | (8 mục). |

**Filter kết hợp:** chọn nhiều filter (event + item_type + whodunnit + date range) → kết quả chỉ chứa record match tất cả điều kiện (theo đặc tả mục R "trang danh sách" — input đặc thù audit_logs — của V2_CHIEU_TEST).

- **Chiều liên quan:** chiều 2, chiều 3 (Nhật ký hoạt động), mục R "trang danh sách" của V2_CHIEU_TEST (filter kết hợp).

### TR-backups — Sao lưu dữ liệu (/backups)

**Route:** `/backups` (backups). **Lớp bảo vệ:** authorize!(:manage, Backup) (chiều 3). **Chỉ TECH** — mọi vai trò khác kể cả SA bị chặn.

| Vai trò | Truy cập | Thao tác | Ghi chú |
|---|---|---|---|
| TR-backups-TECH `[CẢ HAI]` | CRUD | Tạo backup (tối đa 3 bản), xóa backup. Restore **qua dòng lệnh** (không qua giao diện) | Backup khi đã 3 bản → flash "đã đạt tối đa". Sidebar 3 mục. |
| TR-backups-SA `[TỰ ĐỘNG]` | **Chặn** | — | SA cũng không quản lý sao lưu. Mục không trên sidebar SA (17 mục không gồm Sao lưu). |
| TR-backups-UAZM `[TỰ ĐỘNG]` | **Chặn** | — | Mục không trên sidebar (11). |
| TR-backups-UA `[TỰ ĐỘNG]` | **Chặn** | — | (8 mục). |
| TR-backups-CMDZM `[TỰ ĐỘNG]` | **Chặn** | — | (11 mục). |
| TR-backups-CMD `[TỰ ĐỘNG]` | **Chặn** | — | (8 mục). |

- **Chiều liên quan:** chiều 2, chiều 3 (Sao lưu dữ liệu). Tham chiếu Phần 5 (backup tối đa 3, restore qua dòng lệnh).

---

> **Tổng kết Phần 4:** 18 trang × 7 vai trò được instance hóa cụ thể bằng dữ liệu Phần 1 và golden numbers Phần 2. Phạm vi billing/history của UA-ZM nhất quán là **đầu mối đơn vị mình cộng đầu mối sinh hoạt thuộc khu vực trực tiếp** (KHÔNG gồm đầu mối các đơn vị khác cùng khu vực): adminA 4 hàng, adminC 2 hàng, adminB/adminD 1 hàng, SA gộp 8 hàng. CMD/CMD-ZM khớp UA/UA-ZM về phạm vi nhưng chỉ xem. TECH chặn khỏi mọi trang nghiệp vụ. Design issue truy cập trực tiếp URL `/zones`, `/units`, `/pricing`, `/pump_allocations`, `/ranks`, `/users` qua thừa quyền `can :read, Zone/Unit` (CLAUDE.md) **đã được fix** bằng concern `SettingsAccessGuard` (page-level guard chặn theo vai trò) và việc thu hẹp `can :read, Zone` còn khu vực do đơn vị quản lý — không còn là điểm cần xác nhận khi triển khai. Sau khi fix, **không còn điểm mở nào cần xác nhận khi triển khai** trong Phần 4.

---

## Phần 5 — Vận hành

Phần này kiểm thử các thao tác vận hành nằm ngoài bảng tính tiền: vòng đời kỳ tính toán, ràng buộc CRUD và validation, xác thực, sao lưu và nhật ký. Mỗi kịch bản trình bày theo cấu trúc: **Điều kiện tiên quyết → Các bước → Kết quả mong đợi** rồi dòng **Tham chiếu** trỏ tới `V2_CHIEU_TEST.md` và mục nghiệp vụ. Mã kịch bản `VH-<nhóm>-<số>`.

Quy ước Phần 5:

- Mọi con số tính toán trích dẫn đều **trỏ về Phần 2** hoặc là **công thức một bước**. Phần 5 không tính lại; với thao tác làm engine tính lại nhiều bước, chỉ mô tả hướng và cấu trúc thay đổi kèm ghi chú "(tính lại bằng engine)".
- Số kế thừa cụ thể duy nhất được trích dẫn là `reading_start` kỳ kế tiếp = `reading_end` kỳ trước (golden numbers Phần 1A.5: ví dụ CT-A1 = 1.250).
- Phần 5 không chép lại đặc tả "Thao tác đặc biệt", "C/U/D" hay "Conditional field" của `V2_CHIEU_TEST.md` — chỉ trỏ tới và instance hóa bằng dữ liệu thật.

### 5A. Vòng đời kỳ (VH-period-*)

Suite này instance hóa "Thao tác đặc biệt" (mở/đóng/mở lại kỳ) của `V2_CHIEU_TEST.md` cùng 3 trạng thái kỳ của `V2_HANH_VI_HE_THONG.md` mục 3. Trừ khi ghi khác, mọi thao tác kỳ do SA (quanTri) thực hiện trên `/pricing`. Nghiệp vụ nguồn: `V2_XAC_NHAN_NGHIEP_VU.md` mục 12, 25, 27.6.

#### VH-period-01 — Mở kỳ đầu tiên `[CẢ HAI]`

- **Điều kiện tiên quyết:** hệ thống chưa có kỳ nào (trạng thái A — không có kỳ mở); đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/pricing`, chọn năm và tháng (kỳ đầu tiên SA tự chọn năm/tháng, không kế thừa), nhập đơn giá điện. Bấm Mở kỳ.
- **Kết quả mong đợi:**
  - Phía sau (theo `V2_HANH_VI_HE_THONG.md` mục 6, cột "Mặc định nếu không có kỳ trước"): tạo `period` với `closed = false`, năm/tháng SA chọn, đơn giá SA nhập. Tạo **7 nhóm cấp bậc mặc định** (định mức 570, 440, 305, 130, 210, 110, 24 — Phần 1A.2). Tỷ lệ mặc định: tiết kiệm của Bộ 5%, công cộng Sư đoàn 10%, tiêu chuẩn bơm nước 9,45 kW/người/tháng, công cộng đơn vị 0%, cột Khác 0.
  - Vì kỳ đầu chưa có entity nghiệp vụ nào: chưa có `meter_readings`, `personnel_entries`, `unit_configs`, `other_deductions` — chúng chỉ được tạo qua after_create khi SA/UA khai báo zone/unit/đầu mối sau đó (chiều 11). `meter_readings.reading_start` của công tơ tạo trong kỳ đầu phải nhập thủ công cả đầu kỳ lẫn cuối kỳ (không có kỳ trước để kế thừa — mục 27.2).
  - Đơn giá bắt buộc nhập trước khi mở (không có giá trị mặc định — mục 25), và phải > 0 (mục 27.6, VH-validation-02).
  - Sau khi mở: chuyển sang trạng thái B (kỳ mới nhất đang mở), mọi thao tác nghiệp vụ được phép.
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Mở kỳ mới), chiều 1 (A→B), chiều 11 (kỳ đầu/defaults); nghiệp vụ mục 12, 13, 25.

#### VH-period-02 — Mở kỳ mới khi đã có kỳ trước: kế thừa đầy đủ `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 năm 2026 (Khu vực 1, Phần 1) đã nhập liệu, đã tính (golden numbers Phần 2), đã **đóng**; trạng thái A; đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/pricing`, bấm Mở kỳ mới (SA không nhập năm/tháng — hệ thống tự tính kỳ trước + 1 tháng = tháng 6 năm 2026).
  2. Vào `/meter_entries`, `/unit_config`, `/pump_allocations`, `/ranks`, `/electricity_supply` xem kỳ tháng 6.
- **Kết quả mong đợi (kế thừa, theo `V2_HANH_VI_HE_THONG.md` mục 6 + nghiệp vụ mục 25):**
  - Năm/tháng tự xác định: tháng 6 năm 2026. SA chỉ bấm nút, không nhập.
  - `meter_readings`: `reading_start` kỳ tháng 6 = `reading_end` kỳ tháng 5 — **CT-A1 reading_start = 1.250** (= reading_end kỳ tháng 5, Phần 1A.5); tương tự CT-A2 = 680, CT-A3 = 310, CT-B1 = 2.350, CT-KV1 = 1.250. Editable, user sửa nếu cần. `reading_end` để trống chờ nhập mới.
  - `personnel_entries`: copy count theo nhóm cấp bậc từ kỳ tháng 5. `unit_configs`: copy unit_public_rate (Đơn vị A 3%, Đơn vị B 0%). `other_deductions`: copy cả dạng nhập lẫn giá trị (Ban Tác huấn cố định 5; Văn thư hệ số −2,5; Kho vật tư cố định 0; Đại đội 1 hệ số 3; Chỉ huy khu vực cố định 0 — Phần 1A.6). `pump_allocations`: copy coefficient + fixed_percentage (Chỉ huy khu vực 20% cố định + hệ số 1; Đơn vị A/B hệ số 1; Thợ xây hệ số 0,5 — Phần 1A.7). `ranks`: copy tên + định mức + position (7 nhóm).
  - **Đơn giá 2.336,4 kế thừa** tự động từ kỳ tháng 5 (mục 27.6); cùng tỷ lệ tiết kiệm 5%, công cộng Sư đoàn 10%, tiêu chuẩn bơm nước 9,45.
  - **`main_meter_readings` KHÔNG kế thừa:** `/electricity_supply` kỳ tháng 6 hiện "Chưa nhập" cho CT-Tổng-KV1 (và CT-Tổng-KV2). Phải nhập lại số sử dụng mỗi kỳ.
  - Chỉ copy entity `.kept` — đầu mối/công tơ đã xóa không được copy sang kỳ tháng 6.
  - `calculations` kỳ tháng 6 chưa có (chưa nhập reading_end và chưa bấm Tính toán lại) → bảng billing tháng 6 trống cho tới khi tính (xem GD4-01). Không trích dẫn số tính toán tháng 6 vì là kết quả nhiều bước (tính lại bằng engine).
  - Kỳ tháng 5 (đã đóng) giữ nguyên golden numbers Phần 2 — thao tác mở kỳ mới không ảnh hưởng kỳ cũ (mục 27.6).
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Mở kỳ mới), chiều 11 (kế thừa + main_meter không kế thừa), chiều 1; nghiệp vụ mục 12, 25. Trùng nội dung với GD6-03 (cùng cơ chế kế thừa).

#### VH-period-03 — Chặn mở kỳ mới khi đang có kỳ mở `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 năm 2026 **đang mở** (trạng thái B); đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/pricing`, thử Mở kỳ mới (hoặc Mở lại kỳ cũ).
- **Kết quả mong đợi:**
  - Bị chặn: flash cảnh báo "phải đóng kỳ hiện tại trước". Không tạo kỳ mới. Ràng buộc chỉ 1 kỳ mở tại 1 thời điểm (database partial unique index — `V2_HANH_VI_HE_THONG.md` mục 3, nghiệp vụ mục 12, 27.6).
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Mở kỳ mới khi có kỳ đang mở; Mở lại kỳ cũ khi có kỳ đang mở); nghiệp vụ mục 12, 27.6.

#### VH-period-04 — Đóng kỳ chặn nhập liệu (PeriodGuard) `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 năm 2026 đang mở; SA đóng kỳ → chuyển sang trạng thái A (không có kỳ mở).
- **Các bước:**
  1. SA đóng kỳ tháng 5 trên `/pricing`.
  2. Đăng nhập adminA (UA-ZM), vào `/meter_entries`, `/unit_config`, `/pump_entries`, thử sửa và lưu.
  3. Vào `/billing` xem kỳ tháng 5.
- **Kết quả mong đợi:**
  - Sau khi đóng: `period.closed = true`. Trạng thái A — dữ liệu nghiệp vụ chỉ đọc.
  - PeriodGuard: trên trang nhập liệu các ô nhập bị vô hiệu hóa (disabled), hiển thị thông báo "Không có kỳ đang mở". Thử POST trực tiếp bị chặn (redirect + thông báo).
  - **Trang xem vẫn truy cập:** `/billing`, `/history`, `/dashboard` xem kỳ tháng 5 bình thường với golden numbers Phần 2 — đóng kỳ chỉ chặn sửa, không chặn xem.
  - Quản trị hệ thống (tài khoản, sao lưu, nhật ký) vẫn hoạt động ở trạng thái A.
- **Tham chiếu:** `V2_CHIEU_TEST.md` chiều 1 (trạng thái A), Thao tác đặc biệt (Đóng kỳ); `V2_HANH_VI_HE_THONG.md` mục 3 (trạng thái A, PeriodGuard); nghiệp vụ mục 12.

#### VH-period-05 — Mở lại kỳ cũ: StructureChangeGuard chặn thay đổi cấu trúc `[CẢ HAI]`

- **Điều kiện tiên quyết:** có ít nhất hai kỳ đều đã đóng (tháng 5 và tháng 6 năm 2026); trạng thái A. SA mở lại kỳ tháng 5 (kỳ cũ, không phải kỳ mới nhất) → trạng thái C. Đăng nhập quanTri (SA).
- **Các bước:**
  1. Nếu đang có kỳ mở: SA phải đóng trước (theo VH-period-03). Sau đó SA mở lại kỳ tháng 5 trên `/pricing`.
  2. Thử thay đổi **cấu trúc**: tạo/xóa/sửa zone, unit, đầu mối, công tơ, khối, nhóm, nhóm cấp bậc (ví dụ `/contact_points/new`, `/zones/new`, `/ranks` tạo mới).
  3. Thử sửa **số liệu per kỳ**: chỉ số công tơ (`/meter_entries`), quân số, cấu hình đơn vị (`/unit_config`), phân bổ bơm nước (`/pump_allocations`).
- **Kết quả mong đợi:**
  - Mở lại thành công: `period` tháng 5 `closed = false`, StructureChangeGuard active.
  - Thay đổi cấu trúc bị chặn: StructureChangeGuard chặn + flash "đang mở kỳ cũ, chỉ cho phép sửa số liệu". Lý do: thực thể cấu trúc không có bản sao riêng per kỳ, thay đổi sẽ ảnh hưởng mọi kỳ (nghiệp vụ mục 12).
  - Sửa số liệu per kỳ **được phép**: cập nhật reading_end, quân số, unit_public_rate, phân bổ bơm nước của kỳ tháng 5 — chỉ ảnh hưởng kỳ tháng 5, không ảnh hưởng kỳ khác. Bấm Tính toán lại được (recalculate hoạt động ở trạng thái C).
- **Tham chiếu:** `V2_CHIEU_TEST.md` chiều 1 (trạng thái C), U-update (kỳ cũ mở lại: sửa data per kỳ được, sửa cấu trúc bị chặn), Thao tác đặc biệt (Mở lại kỳ cũ); `V2_HANH_VI_HE_THONG.md` mục 3 (trạng thái C); nghiệp vụ mục 12.

#### VH-period-06 — Đóng lại kỳ đã mở lại: cảnh báo lệch reading_end `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở lại (trạng thái C, từ VH-period-05); kỳ tháng 6 đã đóng và `reading_start` kỳ tháng 6 đã kế thừa từ `reading_end` kỳ tháng 5 lúc mở (ví dụ CT-A1 = 1.250). Đăng nhập quanTri (SA).
- **Các bước:**
  1. Ở kỳ tháng 5, sửa `reading_end` CT-A1 từ 1.250 thành 1.300 (lệch so với reading_start tháng 6 = 1.250). Lưu.
  2. SA đóng lại kỳ tháng 5.
- **Kết quả mong đợi:**
  - Khi đóng, hệ thống kiểm tra `reading_end` kỳ tháng 5 (1.300) so với `reading_start` kỳ tháng 6 (1.250) → lệch → **hiển thị cảnh báo** liệt kê công tơ lệch. Đóng kỳ vẫn thành công (`period.closed = true`).
  - Hệ thống **không tự sửa** kỳ tháng 6 (đúng nguyên tắc kỳ này không ảnh hưởng kỳ khác). User phải mở từng kỳ kế tiếp sửa thủ công nếu muốn đồng bộ.
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Đóng kỳ — cảnh báo mismatch reading_end); `V2_HANH_VI_HE_THONG.md` mục 6 (đóng kỳ cũ sau khi sửa); nghiệp vụ mục 12.

#### VH-period-07 — Mở kỳ mới qua mốc năm: tháng 12 → tháng 1 năm sau `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 12 năm 2026 đã đóng; trạng thái A; đăng nhập quanTri (SA).
- **Các bước:**
  1. Vào `/pricing`, bấm Mở kỳ mới.
- **Kết quả mong đợi:**
  - Hệ thống tự tính kỳ trước + 1 tháng: tháng 12 năm 2026 → **tháng 1 năm 2027** (year + 1, month về 1). SA không nhập năm/tháng. Kế thừa số liệu như VH-period-02.
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Mở kỳ mới — auto year/month); nghiệp vụ mục 12 (tháng 12 → tháng 1 năm sau).

#### VH-period-08 — Ba trạng thái kỳ: tổng hợp hành vi `[CẢ HAI]`

- **Điều kiện tiên quyết:** dữ liệu Khu vực 1 + Khu vực 2 (Phần 1); SA lần lượt đưa hệ thống về 3 trạng thái.
- **Các bước:** với mỗi trạng thái, kiểm khả năng thay đổi cấu trúc, sửa số liệu, tính toán lại.
- **Kết quả mong đợi (theo `V2_HANH_VI_HE_THONG.md` mục 3):**

  | Trạng thái | Cách đạt | Cấu trúc | Số liệu per kỳ | Tính toán lại |
  |---|---|---|---|---|
  | A — không có kỳ mở | Mọi kỳ đã đóng | Chặn (PeriodGuard) | Chặn (chỉ đọc) | Chặn (không kỳ mở) |
  | B — kỳ mới nhất mở | Mở kỳ mới hoặc kỳ mới nhất chưa đóng | Cho phép | Cho phép | Cho phép |
  | C — kỳ cũ mở lại | Mở lại kỳ không phải kỳ mới nhất | Chặn (StructureChangeGuard) | Cho phép | Cho phép |

  - Trạng thái A: trang nghiệp vụ chỉ đọc; chỉ tài khoản/sao lưu/nhật ký hoạt động.
  - Không có trạng thái "gap": PeriodGuard chặn mọi thay đổi nghiệp vụ khi không có kỳ mở.
- **Tham chiếu:** `V2_CHIEU_TEST.md` chiều 1; `V2_HANH_VI_HE_THONG.md` mục 3; nghiệp vụ mục 12.

### 5B. CRUD và validation (VH-validation-*)

Suite này instance hóa các bảng "C/U/D" và "Conditional field" của `V2_CHIEU_TEST.md` cùng ràng buộc cụ thể của nghiệp vụ mục 23, 24, 27. Trừ khi ghi khác, kỳ tháng 5 năm 2026 đang mở (trạng thái B); thao tác do SA hoặc UA-ZM trong phạm vi quyền. Mọi thông báo lỗi tiếng Việt; validation realtime (Stimulus) + server-side (model), không dùng HTML5 validation.

#### VH-validation-01 — Ràng buộc giá trị số khi nhập liệu `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập theo phạm vi quyền.
- **Các bước:** nhập từng giá trị biên rồi lưu.
- **Kết quả mong đợi (theo nghiệp vụ mục 24):**

  | Trường | Nhập | Kết quả |
  |---|---|---|
  | Chỉ số công tơ (đầu/cuối kỳ) | −5 | Lỗi: phải ≥ 0. Không lưu. |
  | Số sử dụng công tơ tổng | −1 | Lỗi: phải ≥ 0. |
  | Đơn giá | 0 | Lỗi: phải > 0. |
  | Định mức cấp bậc | 0 | Lỗi: phải > 0. |
  | Tiêu chuẩn bơm nước | 0 | Lỗi: phải > 0. |
  | Tỷ lệ % (tiết kiệm, công cộng) | 105 | Lỗi: phải ≥ 0 và ≤ 100. |
  | Quân số một nhóm cấp bậc | −1 | Lỗi: phải ≥ 0. |
  | Tổng quân số đầu mối sinh hoạt | 0 (mọi nhóm = 0) | Lỗi: tổng quân số phải ≥ 1. |

  - Giá trị hợp lệ ở biên: chỉ số = 0 hợp lệ; tỷ lệ = 0% hợp lệ (khoản trừ tương ứng = 0 — mục 27.7); tỷ lệ = 100% hợp lệ.
  - Đầu mối sinh hoạt phải có ≥ 1 công tơ (mục 22, 27.2): tạo đầu mối không kèm công tơ → lỗi "phải có ít nhất 1 công tơ".
- **Tham chiếu:** `V2_CHIEU_TEST.md` C-create (Giá trị biên; Personnel tổng = 0; Không có meter), Expected output hiển thị (Validation error); nghiệp vụ mục 24, 27.2, 27.3, 27.7.

#### VH-validation-02 — Cột Khác cho phép âm `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminA (UA-ZM); `/unit_config` Đơn vị A.
- **Các bước:** nhập cột Khác của một đầu mối sinh hoạt dạng hệ số = −2,5 (như Văn thư, Phần 1A.6) và dạng cố định = −5; lưu.
- **Kết quả mong đợi:**
  - Cho phép âm (mục 24, 27.7): cột Khác âm = cộng ngược vào tiêu chuẩn → tổng trừ giảm → tiêu chuẩn còn lại tăng. Đây là cơ chế golden number Văn thư thừa 5,72 (EN-KV1-SUMMARY-02: Khác = −5,00 từ hệ số −2,5 × quân số 2). Không báo lỗi.
- **Tham chiếu:** `V2_CHIEU_TEST.md` C-create (Giá trị biên — cho phép âm cho other_deduction); nghiệp vụ mục 24, 27.7. Trỏ golden number EN-KV1-SUMMARY-02.

#### VH-validation-03 — Phân bổ bơm nước: bốn ràng buộc tổng phần trăm và hệ số `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminA (UA-ZM) hoặc adminC; `/pump_allocations`.
- **Các bước:** nhập từng cấu hình phân bổ rồi lưu.
- **Kết quả mong đợi (theo nghiệp vụ mục 24, 27.5):**

  | Cấu hình | Kết quả |
  |---|---|
  | Tổng phần trăm cố định = 110 | Lỗi: tổng phần trăm cố định ≤ 100. Không lưu. |
  | Tổng phần trăm cố định = 100 | Hợp lệ. Toàn bộ điện bơm nước phân theo phần trăm, **bỏ qua** phân bổ theo hệ số. |
  | Tổng phần trăm cố định < 100 nhưng không có đối tượng nào nhận theo hệ số | Lỗi: phải có ≥ 1 đối tượng nhận theo hệ số (tránh mất phần điện bơm nước). |
  | Mọi đối tượng hệ số có tổng (quân số × hệ số) = 0 | Lỗi: tổng (quân số × hệ số) phải > 0 (tránh chia cho 0). |
  | Một đối tượng hệ số = 0 riêng lẻ (các đối tượng khác > 0) | Hợp lệ: đối tượng đó tạm không nhận bơm nước. |
  | Hệ số = −0,5 | Lỗi: hệ số phải ≥ 0. |

  - Khu vực 1 (Phần 1A.7) là nhánh **có phần trăm cố định** (Chỉ huy khu vực 20%); Khu vực 2 (Phần 1B.5) là nhánh **thuần hệ số** (tổng phần trăm cố định = 0) — cả hai hợp lệ, kiểm hai code path khác nhau.
- **Tham chiếu:** `V2_CHIEU_TEST.md` C-create (Giá trị biên); nghiệp vụ mục 24, 27.5. Trỏ DATA-KV1 (1A.7), DATA-KV2 (1B.5).

#### VH-validation-04 — Trùng tên trong cùng phạm vi `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminA (UA-ZM).
- **Các bước:** tạo các đầu mối/đơn vị/khu vực với tên trùng và khác loại.
- **Kết quả mong đợi (theo nghiệp vụ mục 24, 27.3):**
  - Trùng tên **cùng loại** trong cùng phạm vi → lỗi "đã tồn tại". Ví dụ: tạo thêm đầu mối sinh hoạt "Văn thư" thứ hai trong Đơn vị A → lỗi.
  - Trùng tên **khác loại** cùng phạm vi → **cho phép**. Ví dụ: đầu mối sinh hoạt "Nhà ăn" và đầu mối công cộng "Nhà ăn" trong cùng đơn vị → hợp lệ (chỉ cấm trùng giữa các đầu mối cùng loại).
  - Áp dụng tương tự cho tên công tơ, đơn vị, khu vực, khối, nhóm trong cùng phạm vi.
- **Tham chiếu:** `V2_CHIEU_TEST.md` C-create (Tên trùng trong cùng phạm vi); nghiệp vụ mục 24, 27.3.

#### VH-validation-05 — Ràng buộc xóa entity `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở (trạng thái B — chỉ trạng thái này cho xóa cấu trúc); đăng nhập theo phạm vi quyền.
- **Các bước:** thử xóa từng entity theo bảng dưới.
- **Kết quả mong đợi (theo nghiệp vụ mục 23.1, 27.2, 27.4):**

  | Thao tác xóa | Kết quả |
  |---|---|
  | Công tơ cuối cùng của đầu mối (ví dụ CT-B1 của Đại đội 1 khi chỉ có 1 công tơ) | Chặn: "phải có ít nhất 1 công tơ". |
  | Đơn vị đang có đầu mối (Đơn vị A) | Chặn: "phải xóa hết đầu mối trước". |
  | Đơn vị đang có tài khoản (Đơn vị A có adminA) | Chặn: "phải xóa hết tài khoản trước". |
  | Khu vực đang có đơn vị (Khu vực 1) | Chặn: "phải xóa hết đơn vị trước". |
  | Nhóm cấp bậc đang có quân số > 0 (Hạ sĩ quan, binh sĩ) | Chặn: "phải chuyển hết quân số trước". |
  | Tài khoản mặc định (kyThuat, quanTri ban đầu) | Chặn. |
  | Tự xóa chính mình | Chặn. |
  | Khối "Phòng Tham mưu" (có nhóm + đầu mối) | Cho phép: khối discarded; nhóm/đầu mối bên trong chuyển lên trực tiếp đơn vị (block_id = null). |
  | Nhóm "Ban Tác huấn" (có đầu mối) | Cho phép: nhóm discarded; đầu mối lên khối nếu nhóm thuộc khối, lên đơn vị nếu nhóm trực tiếp dưới đơn vị (group_id = null). |
  | Đơn vị quản lý khu vực (Đơn vị A, sau khi đã xóa hết đầu mối + tài khoản) | Cho phép + **cảnh báo**: `zones.manager_unit_id = null`; SA tự quản lý phần khu vực cho đến khi chỉ định đơn vị khác. |

  - Xóa đầu mối/công tơ có dữ liệu kỳ cũ: cho phép; cleanup dữ liệu kỳ đang mở (hard delete), dữ liệu kỳ cũ giữ nguyên (xem GD2 chi tiết per loại đầu mối).
- **Tham chiếu:** `V2_CHIEU_TEST.md` D-delete; nghiệp vụ mục 23.1, 27.2, 27.4. Trùng cơ chế cleanup với GD2.

#### VH-validation-06 — Ràng buộc sửa entity `[TỰ ĐỘNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở (trạng thái B); đăng nhập theo phạm vi quyền.
- **Các bước:** thử sửa từng thuộc tính theo bảng.
- **Kết quả mong đợi (theo nghiệp vụ mục 23.2, 27.2, 27.3):**

  | Thao tác sửa | Kết quả |
  |---|---|
  | Sửa loại đầu mối (sinh hoạt → công cộng) | Chặn: phải xóa tạo lại (mỗi loại cấu trúc khác nhau). Server bỏ qua field immutable `contact_point_type`. |
  | Chuyển đơn vị sang khu vực khác | Chặn: `unit.zone_id` immutable, server bỏ qua. |
  | Sửa tên khu vực/đơn vị/đầu mối/công tơ/khối/nhóm | Cho phép (tên chỉ là nhãn). |
  | Sửa thuộc tính không tổn hao của công tơ | Cho phép; chỉ ảnh hưởng kỳ đang mở (cập nhật `meter_readings.no_loss`). |
  | Di chuyển đầu mối giữa các khối/nhóm | Cho phép; chỉ thay đổi hiển thị, không ảnh hưởng tính toán. |
  | Đổi đơn vị quản lý khu vực sang đơn vị khác cùng khu vực | Cho phép; chuyển quyền khai báo/nhập liệu khu vực. |

- **Tham chiếu:** `V2_CHIEU_TEST.md` U-update (Field immutable); nghiệp vụ mục 23.2, 27.3.

#### VH-validation-07 — Chỉ số cuối kỳ < đầu kỳ: nhập thủ công số sử dụng + ghi chú `[CẢ HAI]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; đăng nhập adminA (UA-ZM); `/meter_entries`.
- **Các bước:**
  1. Nhập `reading_end` CT-A1 = 900 trong khi `reading_start` = 1.000 (cuối < đầu — công tơ bị thay mới/reset).
- **Kết quả mong đợi (theo nghiệp vụ mục 27.2, 28 + conditional field):**
  - View hiện thêm 2 trường: **manual_usage** (bắt buộc) và **ghi chú** (tùy chọn, ví dụ "thay công tơ mới"). Engine dùng `manual_usage` thay vì `reading_end − reading_start`.
  - Khi `reading_end ≥ reading_start`: hai trường này ẩn, engine dùng `end − start`.
- **Tham chiếu:** `V2_CHIEU_TEST.md` Conditional field (reading_end < reading_start → manual_usage + note); nghiệp vụ mục 27.2, 28.

### 5C. Xác thực, sao lưu, nhật ký (VH-auth-*, VH-backup-*)

Suite này instance hóa "Thao tác đặc biệt" (mật khẩu, backup) và yêu cầu kỹ thuật của nghiệp vụ mục 28, 20, 21. Nhiều kịch bản nhóm này **chỉ kiểm thủ công** (session 2 giờ, đa thiết bị, xung đột hai trình duyệt, restore dòng lệnh).

#### VH-auth-01 — Phiên tự thoát sau 2 giờ và đăng nhập đa thiết bị `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** một tài khoản (ví dụ adminA) đã đăng nhập.
- **Các bước:**
  1. Đăng nhập adminA trên thiết bị 1 và thiết bị 2 cùng lúc.
  2. Để thiết bị 1 không hoạt động > 2 giờ.
- **Kết quả mong đợi (theo nghiệp vụ mục 28):**
  - Một tài khoản đăng nhập **nhiều thiết bị cùng lúc** được — cả hai phiên hoạt động bình thường.
  - Sau 2 giờ không hoạt động, phiên tự thoát (timeout) — thao tác tiếp theo redirect về trang đăng nhập.
- **Tham chiếu:** nghiệp vụ mục 28 (tự thoát sau 2 giờ; đa thiết bị).

#### VH-auth-02 — Đổi mật khẩu: ràng buộc độ phức tạp `[CẢ HAI]`

- **Điều kiện tiên quyết:** đăng nhập bất kỳ tài khoản nào (người dùng tự đổi mật khẩu mình được).
- **Các bước:** vào form đổi mật khẩu, nhập mật khẩu mới.
- **Kết quả mong đợi (theo nghiệp vụ mục 28):**
  - Mật khẩu hợp lệ (≥ 8 ký tự, có ≥ 1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt) → đổi thành công, `force_password_change = false`, redirect.
  - Mật khẩu thiếu độ phức tạp (ví dụ "abcdefgh" thiếu hoa/số/đặc biệt, hoặc < 8 ký tự) → re-render form + lỗi tiếng Việt "phải có ít nhất 1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt".
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Đổi mật khẩu hợp lệ; Đổi mật khẩu không đủ phức tạp); nghiệp vụ mục 28.

#### VH-auth-03 — Reset mật khẩu (SA/TECH) đặt force_password_change `[CẢ HAI]`

- **Điều kiện tiên quyết:** đăng nhập quanTri (SA) hoặc kyThuat (TECH); một tài khoản đích (ví dụ adminB).
- **Các bước:** SA/TECH reset mật khẩu cho adminB trên `/users`.
- **Kết quả mong đợi (theo nghiệp vụ mục 28):**
  - Mật khẩu mới được đặt; `force_password_change = true`. Lần đăng nhập tiếp theo của adminB bị buộc đổi mật khẩu.
  - Không có tính năng quên mật khẩu qua email (hệ thống offline — chỉ SA/TECH reset).
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Reset mật khẩu — force_password_change = true); nghiệp vụ mục 28.

#### VH-auth-04 — Thông báo "Kỳ tháng X đã mở" khi đăng nhập `[CẢ HAI]`

- **Điều kiện tiên quyết:** SA vừa mở kỳ tháng 6 năm 2026; adminA chưa đăng nhập lại từ lúc đó.
- **Các bước:** adminA đăng nhập.
- **Kết quả mong đợi:**
  - Hiển thị thông báo "Kỳ tháng 6 đã mở, vui lòng nhập liệu" (nghiệp vụ mục 28).
- **Tham chiếu:** nghiệp vụ mục 28 (thông báo khi đăng nhập có kỳ mới).

#### VH-auth-05 — Xung đột nhập liệu (optimistic locking) `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** kỳ tháng 5 đang mở; hai người (hoặc hai trình duyệt) cùng mở form sửa của cùng một đơn vị — ví dụ cùng sửa `/meter_entries` Đơn vị A, hoặc cùng `/unit_config`.
- **Các bước:**
  1. Người A và người B cùng tải form (cùng `lock_version`).
  2. Người A sửa và lưu trước → thành công.
  3. Người B sửa (dựa trên `lock_version` cũ) và lưu sau.
- **Kết quả mong đợi (theo nghiệp vụ mục 28):**
  - Người A lưu trước **thành công** bình thường.
  - Người B lưu sau nhận cảnh báo "**dữ liệu đã bị thay đổi bởi người khác**"; hệ thống hiển thị **dữ liệu mới nhất** để người B xem lại rồi quyết định lưu lại hay không. Không ghi đè âm thầm.
- **Tham chiếu:** `V2_CHIEU_TEST.md` U-update (lock_version cũ → flash "dữ liệu đã bị thay đổi bởi người khác" + hiện data mới nhất); nghiệp vụ mục 28. Bảng nhập liệu có cột `lock_version` (CLAUDE.md).

#### VH-backup-01 — Backup: TECH tạo, tối đa 3 bản `[CẢ HAI]`

- **Điều kiện tiên quyết:** đăng nhập kyThuat (TECH); `/backups`.
- **Các bước:** tạo backup lần lượt.
- **Kết quả mong đợi (theo nghiệp vụ mục 21 + chiều 3):**
  - TECH tạo backup → file tạo + flash "đã tạo". Tạo được tối đa **3 bản**.
  - Tạo bản thứ 4 (đã có 3 bản) → bị chặn + flash "đã đạt tối đa". Phải xóa bớt bản cũ trước.
  - **SA KHÔNG có quyền backup:** vào `/backups` bị chặn (mục Sao lưu không trên sidebar SA — TR-backups-SA). Chỉ TECH quản lý sao lưu.
- **Tham chiếu:** `V2_CHIEU_TEST.md` Thao tác đặc biệt (Backup TECH; Backup khi đã 3 bản), chiều 3 (Sao lưu — chỉ TECH); nghiệp vụ mục 11.1, 21. Trỏ TR-backups (Phần 4E).

#### VH-backup-02 — Restore chỉ qua dòng lệnh (không có nút giao diện) `[THỦ CÔNG]`

- **Điều kiện tiên quyết:** đăng nhập kyThuat (TECH); đã có bản backup.
- **Các bước:** quan sát trang `/backups`.
- **Kết quả mong đợi (theo nghiệp vụ mục 21, 11.1):**
  - Trang `/backups` **không có nút Restore** — restore thực hiện qua dòng lệnh trên server (ghi đè toàn bộ database nên quá rủi ro để đặt nút giao diện). Đây là thay đổi v2.13.0 nghiệp vụ.
  - Kiểm thủ công: dòng lệnh restore khôi phục database về bản backup đã chọn.
- **Tham chiếu:** nghiệp vụ mục 21, 11.1 (restore qua dòng lệnh, không qua giao diện).

#### VH-backup-03 — Nhật ký hoạt động: SA + TECH xem, ghi mọi thao tác `[CẢ HAI]`

- **Điều kiện tiên quyết:** đã thực hiện nhiều thao tác (tạo/sửa/xóa entity, mở/đóng kỳ); đăng nhập quanTri (SA) hoặc kyThuat (TECH).
- **Các bước:** vào `/audit_logs`, lọc theo loại thao tác/đối tượng/người thao tác/khoảng thời gian.
- **Kết quả mong đợi (theo nghiệp vụ mục 20 + chiều 3):**
  - Mọi thao tác được ghi lại (PaperTrail). Chỉ **SA và TECH** xem được nhật ký; UA/UA-ZM/CMD/CMD-ZM bị chặn (TR-audit_logs).
  - Filter kết hợp (event + đối tượng + người + khoảng thời gian) → kết quả chỉ chứa record match tất cả điều kiện.
- **Tham chiếu:** `V2_CHIEU_TEST.md` chiều 3 (Nhật ký — SA + TECH); nghiệp vụ mục 20. Trỏ TR-audit_logs (Phần 4E).

> **Tổng kết Phần 5:** 3 nhóm, 23 kịch bản. 5A vòng đời kỳ (VH-period-01..08, 8 kịch bản) phủ mở kỳ đầu/mở kỳ mới kế thừa/chặn mở khi đang mở/đóng kỳ chặn nhập/mở lại kỳ cũ với StructureChangeGuard/cảnh báo lệch reading_end/mốc năm/3 trạng thái. 5B CRUD và validation (VH-validation-01..07, 7 kịch bản) phủ ràng buộc số, cột Khác âm, phân bổ bơm nước, trùng tên, xóa, sửa, cuối < đầu kỳ. 5C xác thực/sao lưu/nhật ký (VH-auth-01..05 + VH-backup-01..03, 8 kịch bản) phủ session/đa thiết bị/mật khẩu/reset/thông báo kỳ/xung đột/backup tối đa 3/restore dòng lệnh/nhật ký.

---

## Phần 6 — Bản đồ truy vết

Phần này lập bản đồ từ mỗi **nhóm kịch bản** (không phải từng kịch bản 1:1) tới chiều kiểm thử liên quan của `V2_CHIEU_TEST.md`, nhóm giao điểm nguy hiểm (nếu có), và tập tin RSpec automation hiện có. Mọi tập tin RSpec liệt kê đều **tồn tại thật** trong `spec/` (đã xác minh bằng `grep -rln "RSpec.describe"`). Nhóm nào chưa có spec rõ ràng được đánh dấu "thủ công" hoặc "chưa có".

### 6.1. Bảng truy vết

| Nhóm kịch bản | Chiều `V2_CHIEU_TEST.md` | Nhóm giao điểm | Tập tin RSpec automation hiện có |
|---|---|---|---|
| DATA (dữ liệu mẫu, Phần 1) | — (nền cho mọi chiều) | — | `spec/support/sample_data.rb` (helper, không phải spec); dùng bởi mọi spec dưới |
| EN — engine tổn hao (EN-KV1/KV2-LOSS) | chiều 5, 8 | — | `spec/services/loss_calculator_spec.rb`, `spec/services/calculation_orchestrator_spec.rb` |
| EN — engine bơm nước (EN-KV1/KV2-PUMP) | chiều 5, 8 | — | `spec/services/pump_allocation_calculator_spec.rb`, `spec/services/calculation_orchestrator_spec.rb` |
| EN — engine tổng hợp + hàng tổng (EN-*-SUMMARY/TOTALS) | chiều 8, 12 | — | `spec/services/summary_calculator_spec.rb`, `spec/services/calculation_orchestrator_spec.rb`, `spec/models/calculation_spec.rb` |
| GD1 — Kỳ × Vai trò × Trạng thái entity | chiều 1, 2, 4, 7 | Nhóm 1 | `spec/requests/discarded_entity_visibility_spec.rb`, `spec/services/discarded_entity_visibility_spec.rb`, `spec/services/period_isolation_spec.rb`, `spec/requests/billing_spec.rb` |
| GD2 — Kỳ × Loại đầu mối × Cleanup | chiều 1, 5 | Nhóm 2 | `spec/models/contact_point_spec.rb`, `spec/models/meter_spec.rb`, `spec/services/period_isolation_spec.rb`, `spec/requests/contact_points_spec.rb` |
| GD3 — Vai trò × Thuộc về × Trang | chiều 2, 3, 6 | Nhóm 3 | `spec/requests/role_access_matrix_spec.rb`, `spec/requests/billing_spec.rb`, `spec/requests/meter_entries_spec.rb`, `spec/requests/unit_config_spec.rb`, `spec/services/zone_query_spec.rb`, `spec/requests/dimension_coverage_spec.rb` |
| GD4 — Kỳ đang xem × Trạng thái tính toán × Vai trò | chiều 2, 7, 8, 12 | Nhóm 4 | `spec/requests/billing_spec.rb`, `spec/services/period_isolation_spec.rb`, `spec/services/period_comparison_spec.rb`, `spec/system/billing_spec.rb` |
| GD5 — Vị trí phân cấp × Định dạng output | chiều 10, 12 | Nhóm 5 | `spec/requests/billing_spec.rb`, `spec/system/billing_spec.rb` (gộp ô + số cột); merge/Excel mở file: **thủ công** |
| GD6 — Cách nhận data × Kỳ × Loại đầu mối | chiều 1, 5, 11 | Nhóm 6 | `spec/models/contact_point_spec.rb`, `spec/models/rank_spec.rb`, `spec/models/meter_reading_spec.rb`, `spec/services/period_service_spec.rb` |
| TR — dashboard | chiều 2, 3, 8, 9 | — | `spec/requests/dashboard_spec.rb`, `spec/services/dashboard_summary_spec.rb`, `spec/services/zone_warning_collector_spec.rb` |
| TR — billing | chiều 2, 3, 6, 7, 8, 12 | Nhóm 3, 4, 5 | `spec/requests/billing_spec.rb`, `spec/system/billing_spec.rb` |
| TR — history | chiều 2, 3, 4, 7 | Nhóm 1 | `spec/requests/history_spec.rb`, `spec/services/period_comparison_spec.rb` |
| TR — electricity_supply | chiều 2, 3, 11 | — | `spec/requests/electricity_supply_spec.rb`, `spec/models/main_meter_reading_spec.rb` |
| TR — meter_entries | chiều 2, 3, 6, 11 | Nhóm 3, 6 | `spec/requests/meter_entries_spec.rb`, `spec/models/meter_reading_spec.rb` |
| TR — pump_entries | chiều 2, 3, 5, 6 | — | `spec/requests/pump_entries_spec.rb` |
| TR — contact_points | chiều 2, 3, 5, 6, 10, 11 | Nhóm 2, 3, 6 | `spec/requests/contact_points_spec.rb`, `spec/system/contact_points_spec.rb`, `spec/models/contact_point_spec.rb` |
| TR — blocks / groups | chiều 2, 3, 10 | Nhóm 5 | `spec/requests/blocks_spec.rb`, `spec/system/blocks_spec.rb`, `spec/models/block_spec.rb`, `spec/requests/groups_spec.rb`, `spec/system/groups_spec.rb`, `spec/models/group_spec.rb` |
| TR — unit_config | chiều 2, 3, 6 | Nhóm 3 | `spec/requests/unit_config_spec.rb`, `spec/system/unit_config_spec.rb`, `spec/models/unit_config_spec.rb`, `spec/models/other_deduction_spec.rb` |
| TR — zones / units | chiều 2, 3 | — | `spec/requests/zones_spec.rb`, `spec/system/zones_spec.rb`, `spec/models/zone_spec.rb`, `spec/requests/units_spec.rb`, `spec/system/units_spec.rb`, `spec/models/unit_spec.rb` |
| TR — pump_allocations | chiều 2, 3 | — | `spec/requests/pump_allocations_spec.rb`, `spec/system/pump_allocations_spec.rb`, `spec/models/pump_allocation_spec.rb` |
| TR — pricing | chiều 2, 3 | — | `spec/requests/pricing_spec.rb`, `spec/system/pricing_spec.rb` |
| TR — ranks | chiều 2, 3, 11 | Nhóm 6 | `spec/requests/ranks_spec.rb`, `spec/system/ranks_spec.rb`, `spec/models/rank_spec.rb` |
| TR — users | chiều 2, 3 | — | `spec/requests/users_spec.rb`, `spec/system/users_spec.rb`, `spec/models/user_spec.rb` |
| TR — audit_logs | chiều 2, 3 | — | `spec/requests/audit_logs_spec.rb`, `spec/requests/audit_pr_137_spec.rb`, `spec/system/audit_logs_spec.rb` |
| TR — backups | chiều 2, 3 | — | `spec/requests/backups_spec.rb`, `spec/models/backup_spec.rb`, `spec/services/backup_service_spec.rb` |
| Phân quyền chung (7 vai trò × mọi trang) | chiều 2, 3 | Nhóm 1, 3 | `spec/requests/role_access_matrix_spec.rb`, `spec/requests/business_role_required_integration_spec.rb`, `spec/requests/dimension_coverage_spec.rb` |
| VH-period — vòng đời kỳ | chiều 1, 11 | — | `spec/services/period_service_spec.rb`, `spec/services/period_isolation_spec.rb`, `spec/models/period_spec.rb`, `spec/requests/pricing_spec.rb`, `spec/system/pricing_spec.rb`, `spec/requests/period_indicator_spec.rb` |
| VH-period — mở lại kỳ cũ / StructureChangeGuard | chiều 1 (C) | — | `spec/requests/v230_structure_change_guard_integration_spec.rb`, `spec/requests/old_period_contact_point_edit_spec.rb` |
| VH-validation — ràng buộc CRUD | chiều C/U/D | — | `spec/models/meter_reading_spec.rb`, `spec/models/pump_allocation_spec.rb`, `spec/models/unit_config_spec.rb`, `spec/models/personnel_entry_spec.rb`, `spec/models/other_deduction_spec.rb`, `spec/models/contact_point_spec.rb`, `spec/models/zone_spec.rb`, `spec/models/unit_spec.rb`, `spec/models/rank_spec.rb`, `spec/models/user_spec.rb`; ràng buộc xóa: `spec/requests/zones_spec.rb`, `spec/requests/units_spec.rb`, `spec/requests/contact_points_spec.rb` |
| VH-validation — cuối kỳ < đầu kỳ (manual_usage) | Conditional field | — | `spec/models/meter_reading_spec.rb`, `spec/requests/meter_entries_spec.rb` |
| VH-auth — đổi/reset mật khẩu | Thao tác đặc biệt (mật khẩu) | — | `spec/requests/password_changes_spec.rb`, `spec/requests/sessions_spec.rb`, `spec/models/user_spec.rb` |
| VH-auth — session 2 giờ, đa thiết bị, thông báo kỳ | mục 28 nghiệp vụ | — | đăng nhập/đăng xuất: `spec/requests/sessions_spec.rb`; thông báo kỳ: `spec/requests/period_indicator_spec.rb`; timeout 2h + đa thiết bị: **thủ công** |
| VH-auth — xung đột nhập liệu (lock_version) | U-update (lock_version) | — | `spec/requests/meter_entries_spec.rb`, `spec/requests/unit_config_spec.rb`, `spec/requests/pump_entries_spec.rb`, `spec/requests/electricity_supply_spec.rb` (logic optimistic locking); hai trình duyệt đồng thời: **thủ công** |
| VH-backup — backup tối đa 3 | Thao tác đặc biệt (Backup) | — | `spec/requests/backups_spec.rb`, `spec/models/backup_spec.rb`, `spec/services/backup_service_spec.rb`; restore dòng lệnh: **thủ công** |
| VH-backup — nhật ký | chiều 3 (Nhật ký) | — | `spec/requests/audit_logs_spec.rb`, `spec/requests/audit_pr_137_spec.rb`, `spec/system/audit_logs_spec.rb` |

### 6.2. Ghi chú automation

**Nhóm phù hợp viết RSpec `[TỰ ĐỘNG]` (ưu tiên cao nhất, là lõi đúng/sai của hệ thống):**

- **Engine tính toán** (EN-*, GD2, GD4 phần số): golden numbers Phần 2 verify trực tiếp bằng `loss_calculator_spec`, `pump_allocation_calculator_spec`, `summary_calculator_spec`, `calculation_orchestrator_spec`. Đây là tầng phải tự động hóa trước nhất — số sai là sai nghiêm trọng nhất.
- **Cách ly kỳ** (period isolation, GD1, GD2, GD4, VH-period): `period_isolation_spec`, `period_service_spec`, `period_comparison_spec`, `discarded_entity_visibility_spec` (cả request lẫn service) — kiểm dữ liệu kỳ cũ giữ nguyên, entity đã xóa hiện ở kỳ cũ, cleanup kỳ đang mở.
- **Phân quyền** (GD3, TR-*, phân quyền chung): `role_access_matrix_spec`, `business_role_required_integration_spec`, `dimension_coverage_spec` + request spec per trang — kiểm 7 vai trò thấy/không thấy/bị chặn đúng.
- **Validation** (VH-validation): model spec per model (`meter_reading_spec`, `pump_allocation_spec`, `unit_config_spec`, `personnel_entry_spec`, `other_deduction_spec`...) cho ràng buộc giá trị; request spec (`zones_spec`, `units_spec`, `contact_points_spec`) cho ràng buộc xóa cascade.
- **Edge cases** (StructureChangeGuard, mở lại kỳ cũ, cuối < đầu kỳ, lock_version logic): `v230_structure_change_guard_integration_spec`, `old_period_contact_point_edit_spec`, `meter_entries_spec`, `unit_config_spec`.
- **Vòng đời kỳ + mật khẩu + backup logic**: `pricing_spec` (request + system), `period_service_spec`, `password_changes_spec`, `sessions_spec`, `backups_spec`, `backup_service_spec`.

**Nhóm chỉ kiểm thủ công `[THỦ CÔNG]` (không phù hợp hoặc khó automation):**

- **Gộp ô / merge** dọc HTML rowspan và Excel merge_cells cho 5 vị trí phân cấp (GD5-01, GD5-02): kiểm trực quan layout.
- **Xuất Excel mở tập tin** (GD5-02, GD5-04, GD4-03): mở file xlsx kiểm công thức, chỉ số cột dịch theo vai trò, merge — phải mở bằng phần mềm bảng tính.
- **Di chuột highlight dòng** (yêu cầu giao diện chung): kiểm bằng mắt.
- **Phiên tự thoát sau 2 giờ** (VH-auth-01): cần chờ thời gian thực, kiểm thủ công.
- **Xung đột hai trình duyệt đồng thời** (VH-auth-05): logic optimistic locking đã có spec, nhưng mô phỏng hai trình duyệt thật là thủ công.
- **Restore qua dòng lệnh** (VH-backup-02): không có nút giao diện — kiểm bằng lệnh trên server.
- **Việt hóa 100%** (mọi trang): rà soát ngôn ngữ giao diện/thông báo/xuất file bằng mắt.

**Thứ tự ưu tiên automation:** (1) engine golden numbers → (2) cách ly kỳ + cleanup → (3) phân quyền 7 vai trò → (4) validation + ràng buộc xóa → (5) edge cases (StructureChangeGuard, mở lại kỳ cũ, lock_version) → (6) vòng đời kỳ + auth + backup logic. Tầng giao diện/Excel/merge để kiểm thủ công sau cùng theo Phần 4 và GD5.

---

## Lịch sử thay đổi

### v2.2.2 (25/06/2026)

- Mục 1C: thay đoạn copy đầy đủ định nghĩa 7 vai trò (chép từ V2_HANH_VI) bằng 1 câu tóm + back-reference tới `V2_HANH_VI_HE_THONG.md` mục 1 và `docs/THUAT_NGU.md` mục 1. Giảm trùng lặp cross-file (Issue #432).
- Mục 4.0 header: thay liệt kê inline sidebar counts 7 vai trò bằng pointer tới bảng 4.0. Giảm trùng lặp (Issue #432).

### v2.2.1 (23/06/2026)

- TR-billing: thêm DC vào danh sách Tính toán lại "(SA/UA/UA-ZM)" → "(SA/DC/UA-ZM/UA)".

### v2.2.0 (23/06/2026)

- GD1-04: "5 vai trò nghiệp vụ" → "6 vai trò", thêm hàng DC vào bảng (chiHuySuDoan xem toàn hệ thống, chỉ đọc).
- GD1-05: thêm DC vào danh sách nút Tính toán lại "bật" (DC có quyền recalculate).
- TR-dashboard: "5 vai trò" → "6 vai trò", thêm TR-dashboard-DC (chiHuySuDoan thấy toàn hệ thống, sidebar 16 mục).
- TR-dashboard-UAZM: sidebar 12 → 11 mục. TR-billing-UAZM, TR-billing-CMDZM: tương tự.
- TR-units-UAZM, TR-pricing-UAZM: sidebar "12 mục không gồm" → "11 mục không gồm".
- TR-history: "5 vai trò nghiệp vụ" → "6 vai trò".

### v2.1.0 (22/06/2026)

- **Thêm vai trò DC (Chỉ huy Sư đoàn, `division_commander`):** cập nhật toàn bộ "6 vai trò" → "7 vai trò", "4 enum" → "5 enum". Phần 1C: thêm tài khoản chiHuySuDoan, thêm mô tả DC (scope toàn hệ thống, chỉ xem + tính toán lại, sidebar 16 mục, 1 tài khoản không phân biệt khu vực). Phần 4: cập nhật mô tả ma trận, sidebar count, tổng kết. Phần 6: cập nhật bảng truy vết và ghi chú automation.
- Lịch sử v2.0.0: ghi rõ "(chưa có DC)" ở hai entry viết tại thời điểm chỉ 6 vai trò.

### v2.0.3 (31/05/2026)

- **Thắt chặt trang Khu vực (/zones) còn chỉ SA:** `SettingsAccessGuard` đổi từ `require_system_admin_or_zone_manager!` sang `require_system_admin!` (giống /units). Đơn vị quản lý khu vực (UA-ZM/CMD-ZM) nay cũng bị chặn — chỉ SA vào được /zones. /pump_allocations giữ nguyên `require_system_admin_or_zone_manager!` (zone-manager vẫn cần dùng).
- Cập nhật các hàng TR-zones Phần 4: TR-zones-UAZM và TR-zones-CMDZM đổi từ "Xem (khu vực mình)" → **"Chặn (redirect, errors.access_denied)"**. Cập nhật route guard và mô tả lớp bảo vệ của TR-zones.
- **Sidebar zone-manager 12 → 11 mục:** UA-ZM và CMD-ZM bỏ mục "Khu vực" khỏi nhóm THIẾT LẬP (còn THIẾT LẬP 1 mục: Phân bổ bơm nước). Cập nhật dòng tổng số mục sidebar Phần 4, bảng tổng quan số mục, và mọi ghi chú "Sidebar 12" / "(12 mục)" của hàng UA-ZM/CMD-ZM thành 11. Giữ nguyên SA (17), UA (8), CMD (8), TECH (3).

### v2.0.2 (31/05/2026)

- **Thắt chặt truy cập các trang thiết lập/hệ thống theo vai trò:** concern `SettingsAccessGuard` thêm page-level guard chặn truy cập trực tiếp qua URL — `/zones` và `/pump_allocations` chỉ SA hoặc đơn vị quản lý khu vực (`require_system_admin_or_zone_manager!`); `/units`, `/pricing`, `/ranks` chỉ SA (`require_system_admin!`); `/users` chỉ SA hoặc TECH (`require_account_manager!`). Đồng thời `ability.rb` thu hẹp `can :read, Zone` còn khu vực do đơn vị quản lý.
- Cập nhật các hàng TR Phần 4 của 6 trang trên: các vai trò non-SA giờ bị chặn ghi **"Chặn (redirect, errors.access_denied)"** thay cho "xem/trống/sidebar ẩn". Giữ nguyên SA toàn quyền; UA-ZM/CMD-ZM với /zones và /pump_allocations; TECH với /users.
- **Đảo ngược ghi chú "Phạm vi /ranks":** trang /ranks giờ chặn mọi non-SA (`require_system_admin!`); quyền `can :read, Rank` vẫn giữ trong `Ability` vì form khai báo nhân sự của đầu mối dùng `current_period.ranks` (không dùng trang /ranks) — chặn trang không làm hỏng form.
- **Ghi chú design issue đã được giải quyết:** truy cập trực tiếp URL qua thừa quyền `can :read, Zone/Unit` đã fix bằng `SettingsAccessGuard`; không còn điểm mở cần xác nhận khi triển khai trong Phần 4. Cập nhật version nguồn CHIEU_TEST v1.2.1 → v1.2.2.

### v2.0.1 (31/05/2026)

- Xử lý ghi chú "cần xác nhận" về `/ranks`: đối chiếu code (`Ability` `can :read, Rank` cho non-SA, `RanksController#index` `authorize!(:read, Rank)`, `sidebar_helper.rb` chỉ thêm `ranks` cho `system_admin`) → xác nhận hai tài liệu nguồn KHÔNG mâu thuẫn (THIET_KE ✗ = ẩn mục sidebar; CHIEU_TEST "Xem" = quyền truy cập đọc qua URL). Non-SA xem được /ranks là có chủ đích, không phải lỗi thừa quyền. Cập nhật ghi chú TR-ranks và phần tổng kết Phần 4 (còn 1 điểm cần xác nhận: design issue `can :read, Zone/Unit`).

### v2.0.0 (31/05/2026)

- **Viết lại toàn bộ** tài liệu theo cấu trúc 6 phần (Phần 0 Mở đầu → Phần 6 Bản đồ truy vết), thay cho cấu trúc T01–T113 cũ (v1.2.0, lỗi thời).
- **Chuyển từ 4 vai trò sang 6 vai trò thực tế (chưa có DC):** bổ sung phân biệt UA-ZM/UA và CMD-ZM/CMD; CMD/CMD-ZM thấy trang chỉ-xem (ô nhập vô hiệu hóa, nút ẩn) thay vì bị chặn hoàn toàn như mô tả 4 vai trò cũ.
- **Thêm Khu vực 2 (đa khu vực):** dữ liệu mẫu mới lấp lỗ hổng Khu vực 1 chưa có — vị trí phân cấp thứ ba (nhóm trực tiếp dưới đơn vị, không khối), bối cảnh đa khu vực (lọc theo khu vực, cách ly cross-zone, phân biệt vai trò giữa hai khu vực), phân bổ bơm nước thuần hệ số.
- **Golden numbers kiểm chứng bằng engine:** mọi con số tính toán (tổn hao, phân bổ bơm nước, tổng hợp, hàng tổng) của cả hai khu vực xuất ra từ `CalculationOrchestrator` chạy trên dữ liệu mẫu, không tính tay. Phần 2 là nguồn số duy nhất.
- **6 nhóm giao điểm nguy hiểm (GD1–GD6):** instance hóa cụ thể bằng dữ liệu thật và golden numbers.
- **Walkthrough 18 trang × 6 vai trò (Phần 4, chưa có DC):** đầu ra hiển thị cụ thể per vai trò (số cột, số hàng dữ liệu, trạng thái ô nhập, nút, sidebar, cảnh báo, trạng thái rỗng).
- **Phần 5 Vận hành:** vòng đời kỳ (VH-period), CRUD/validation (VH-validation), xác thực/sao lưu/nhật ký (VH-auth, VH-backup).
- **Phần 6 Bản đồ truy vết:** map mỗi nhóm kịch bản → chiều `V2_CHIEU_TEST.md` + nhóm giao điểm + tập tin RSpec hiện có (đã xác minh tồn tại); ghi chú ưu tiên automation.
- Cập nhật version nguồn: NGHIEP_VU v2.13.0, THIET_KE v2.13.0, HANH_VI v1.2.1, CHIEU_TEST v1.2.1.
- Nội dung khớp bản reconcile v1.2.1 của `V2_HANH_VI_HE_THONG.md` và `V2_CHIEU_TEST.md` (PR #266): phạm vi billing UA-ZM = đầu mối đơn vị mình + đầu mối thuộc khu vực trực tiếp (không gồm đơn vị khác cùng khu vực); radio `assignment_mode` hiện cho SA và UA-ZM.
