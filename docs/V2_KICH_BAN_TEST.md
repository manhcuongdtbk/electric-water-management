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
