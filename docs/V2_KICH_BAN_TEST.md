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
