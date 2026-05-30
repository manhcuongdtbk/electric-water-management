# V2 — Kịch bản kiểm thử (số liệu cụ thể)

> **Phiên bản:** 2.0.0
> **Ngày:** 31/05/2026
> **Nguồn nghiệp vụ:** `docs/V2_XAC_NHAN_NGHIEP_VU.md` v2.13.0
> **Nguồn thiết kế:** `docs/V2_THIET_KE_HE_THONG.md` v2.13.0
> **Nguồn hành vi runtime:** `docs/V2_HANH_VI_HE_THONG.md` v1.2.0
> **Nguồn không gian kiểm thử:** `docs/V2_CHIEU_TEST.md` v1.2.0
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

### 1C. Tài khoản (6 vai trò × 2 khu vực)

| Tên đăng nhập | role | Đơn vị | Vai trò thực tế |
|---|---|---|---|
| kyThuat | technician | — | TECH |
| quanTri | system_admin | — | SA |
| adminA | unit_admin | Đơn vị A (quản lý Khu vực 1) | UA-ZM |
| adminB | unit_admin | Đơn vị B | UA |
| chiHuyA | commander | Đơn vị A | CMD-ZM |
| chiHuyB | commander | Đơn vị B | CMD |
| adminC | unit_admin | Đơn vị C (quản lý Khu vực 2) | UA-ZM |
| adminD | unit_admin | Đơn vị D | UA |
| chiHuyC | commander | Đơn vị C | CMD-ZM |
| chiHuyD | commander | Đơn vị D | CMD |

Hệ thống có 6 vai trò thực tế dù model User chỉ có 4 enum (`system_admin`, `unit_admin`, `commander`, `technician`). Hai role `unit_admin` và `commander` mỗi role tách thành 2 biến thể tùy đơn vị có quản lý khu vực hay không:

- **UA-ZM** (quản trị viên đơn vị quản lý khu vực): là `unit_admin` mà đơn vị của họ được chỉ định quản lý một khu vực (`Zone.kept.exists?(manager_unit_id: unit_id)`). Phạm vi: đơn vị mình cộng toàn bộ đầu mối và công tơ của khu vực mình quản lý. Ví dụ: adminA (Đơn vị A quản lý Khu vực 1), adminC (Đơn vị C quản lý Khu vực 2).
- **UA** (quản trị viên đơn vị không quản lý khu vực): là `unit_admin` mà đơn vị không quản lý khu vực nào. Phạm vi: chỉ đơn vị mình. Ví dụ: adminB, adminD.
- **CMD-ZM** (chỉ huy đơn vị quản lý khu vực): là `commander` mà đơn vị quản lý khu vực. Phạm vi xem giống UA-ZM, chỉ xem (các ô nhập liệu bị vô hiệu hóa, nút lưu bị ẩn). Ví dụ: chiHuyA, chiHuyC.
- **CMD** (chỉ huy đơn vị không quản lý khu vực): là `commander` mà đơn vị không quản lý khu vực. Phạm vi xem giống UA, chỉ xem. Ví dụ: chiHuyB, chiHuyD.

Khu vực 1 cung cấp đủ cả 6 vai trò; Khu vực 2 lặp lại bốn vai trò UA-ZM, UA, CMD-ZM, CMD để kiểm thử cách ly dữ liệu và lọc theo khu vực giữa hai khu vực.

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

#### GD1-04 — Năm vai trò nghiệp vụ thấy gì trên billing kỳ N-1 vs kỳ N `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1; lần lượt đăng nhập 5 vai trò có quyền xem nghiệp vụ.
- **Các bước:** mỗi vai trò vào `/billing`, xem kỳ N-1 rồi xem kỳ N.
- **Kết quả mong đợi (đầu mối "Lái xe" thuộc Đơn vị A):**

  | Vai trò | Kỳ N-1 | Kỳ N |
  |---|---|---|
  | SA (quanTri) | Thấy "Lái xe" (chọn Khu vực 1 + Đơn vị A) | Không thấy "Lái xe" |
  | UA-ZM (adminA) | Thấy "Lái xe" (đầu mối Đơn vị A nằm trong phạm vi) | Không thấy "Lái xe" |
  | UA (adminB) | Không thấy "Lái xe" (thuộc Đơn vị A, ngoài phạm vi Đơn vị B) | Không thấy |
  | CMD-ZM (chiHuyA) | Thấy "Lái xe" như adminA, nhưng nút Tính toán lại bị ẩn | Không thấy "Lái xe" |
  | CMD (chiHuyB) | Không thấy "Lái xe" như adminB | Không thấy |

  - TECH (kyThuat) bị chặn khỏi `/billing` (redirect `/users`) ở mọi kỳ — không nằm trong bảng vì không thấy dữ liệu nghiệp vụ.
  - Năm đầu mối gốc: với adminA/chiHuyA hiện đủ đầu mối Đơn vị A + đầu mối sinh hoạt thuộc khu vực (Chỉ huy khu vực thiếu 33,32); adminB/chiHuyB chỉ thấy Đại đội 1 thiếu 106,86.
- **Chiều liên quan:** chiều 1 × 2 × 4 đầy đủ; Nhóm 1.

#### GD1-05 — Nút Tính toán lại theo kỳ đang mở và vai trò `[CẢ HAI]`

- **Điều kiện tiên quyết:** bối cảnh chung GD1, kỳ N-1 đang mở lại (trạng thái C).
- **Các bước:** mỗi vai trò vào `/billing` xem kỳ N-1, kiểm nút Tính toán lại; sau đó SA xem kỳ N (đã đóng).
- **Kết quả mong đợi:**
  - Kỳ N-1 đang mở lại + kỳ đang xem = kỳ N-1: nút Tính toán lại **bật** cho SA, UA-ZM (adminA), UA (adminB). Ẩn cho CMD-ZM (chiHuyA), CMD (chiHuyB).
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
