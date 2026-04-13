# Phân tích Bảng 22 cột — Tháng 02/2026

> **Nguồn**: `test/fixtures/files/bang_tinh_thang_02.xlsx`, Sheet "Sheet1 (2)"
> **Đối chiếu**: `docs/XAC_NHAN_NGHIEP_VU_v5.html`

---

## 1. Cấu trúc file Excel

File Excel gồm 3 sheet:
- **Sheet1**: Bảng I (Tổn hao & sử dụng thực tế) + Bảng II (Điện công cộng SĐ bộ)
- **Sheet1 (2)**: Bảng III (Bảng tính sử dụng điện) — **đây là bảng 22 cột chính**
- **Kangatang**: Trống

---

## 2. Bảng 22 cột — Cấu trúc cột trong Excel

| # | Cột Excel | Tên cột | Công thức | Ghi chú |
|---|-----------|---------|-----------|---------|
| 1 | B | STT | Thủ công | Đánh số theo ban/đầu mối |
| 2 | C | Đơn vị | Text | Tên ban/bộ phận |
| 3 | D | Chi tiết đầu mối | Text | Tên cụ thể (TMP Trường, TB Ngọc…) |
| 4 | E | Đại tá/Thượng tá (3★/4★) | Số người | Nhóm cấp bậc cao nhất |
| 5 | F | Trung tá/Thiếu tá (1★/2★) | Số người | Nhóm cấp bậc trung |
| 6 | G | Cấp úy | Số người | Sĩ quan cấp úy |
| 7 | H | HSQ-CS | Số người | Hạ sĩ quan + Chiến sĩ |
| 8 | I | Tổng TC sinh hoạt (kW) | `=E*115 + F*38 + G*28 + H*11` | **(1)** |
| 9 | J | TC bơm nước (kW) | `=SUM(E:H) * 6.3` | **(2)** ⚠ Xem mục 5.1 |
| 10 | K | Tiết kiệm 5% | `=(I+J) * 5%` | **(3)** = (1+2)*5% |
| 11 | L | Công cộng SĐ 10% | `=(I+J) * 10%` | **(4)** = (1+2)*10% |
| 12 | M | Nhà ăn + bếp (Khác) | `=SUM(E:H) * 2` hoặc cố định | **(5)** Tương đương "Khác" trong v5 |
| 13 | N | Tiêu chuẩn còn lại | `=I + J - K - L - M` | **(6)** = (1+2-3-4-5) |
| 14 | O | Sử dụng thực tế (gồm tổn hao) | `=Sheet1!I{row}` | ⚠ Xem mục 5.2 |
| 15 | P | Điện bơm nước thực tế | `=SUM(E:H) * P8 / P92` | Phân bổ theo quân số |
| 16 | Q | Tổng sử dụng | `=O + P` | |
| 17 | R | Số thâm điện | `=Q - N` | Âm = thừa, Dương = thâm |
| 18 | S | Đơn giá (đồng) | `2336.4` (cố định tháng 02) | |
| 19 | T | Thành tiền (đồng) | `=R * S` | |
| 20 | U | Tổng nhóm (đồng) | `=SUM(T)` theo nhóm ban | |
| 21 | V | Người phụ trách | Text | |
| 22 | W | Ký nhận | Text | |

---

## 3. Bảng phụ trợ — Sheet1

### 3.1 Bảng I: Tổn hao & Sử dụng thực tế

Tính cho từng công tơ (đồng hồ điện):

| Cột | Tên | Công thức |
|-----|-----|-----------|
| C-D | Nhà ở: Số đầu kỳ / cuối kỳ | Chỉ số công tơ |
| E-F | NLV: Số đầu kỳ / cuối kỳ | Chỉ số công tơ |
| G | Số sử dụng | `= D + F - C - E` (cuối kỳ - đầu kỳ, cả nhà ở + NLV) |
| H | Số tổn hao | `= G * D157 / G153` (phân bổ theo tỷ lệ kW) |
| I | Sử dụng thực tế (gồm tổn hao) | `= G + H` |

**Công thức tổn hao tổng**:
```
Tổn hao (C) = Công tơ tổng điện lực (A) - Tổng công tơ sử dụng (B)
            = 45,960 - 40,188 = 1,752 kW (tháng 02/2026)

Tổn hao công tơ X = Tổng tổn hao × (kW công tơ X ÷ Tổng kW tất cả công tơ)
                   = 1,752 × (G_x / 40,188)
```

### 3.2 Bảng II: Điện công cộng Sư đoàn bộ

Phân bổ điện bơm nước cho các đơn vị sử dụng chung trạm bơm:

| STT | Đơn vị | Quân số | SĐ bơm nước |
|-----|--------|---------|-------------|
| 1 | Chỉ huy f + nhà khách | — | 1,926.06 |
| 2 | Cơ quan SĐ bộ | 251 | 2,025.19 |
| 3 | Tiểu đoàn 18 | 149 | 1,202.20 |
| 4 | Đại đội 20, 23 | 109 | 879.46 |
| 5 | Trạm chế biến | 18 | 145.23 |
| 6 | Thợ xây | 30 | 242.05 |
| **Tổng** | | **557** | **6,420.20** |

Công thức: Phân bổ theo quân số từ trạm lọc nước sinh hoạt.

---

## 4. Giá trị mẫu — 5 đầu mối đầu tiên

### Dữ liệu gốc từ Excel (Sheet1(2), rows 10–16):

| # | Đầu mối | E(3★4★) | F(1★2★) | G(Úy) | H(HSQ) | I(TC SH) | J(Bơm) | K(TK 5%) | L(CC 10%) | M(Khác) | N(TC còn lại) |
|---|---------|---------|---------|-------|--------|----------|--------|----------|-----------|---------|---------------|
| 1 | TMP Trường | 1 | — | — | — | 115 | 6.3 | 6.065 | 12.13 | — | 103.105 |
| 2 | TMP Hưng | 1 | — | — | — | 115 | 6.3 | 6.065 | 12.13 | — | 103.105 |
| 3 | TMP Hiếu | 1 | — | — | — | 115 | 6.3 | 6.065 | 12.13 | — | 103.105 |
| 4 | TB Q.Lực | — | 1 | — | 1 | 49 | 12.6 | 3.08 | 6.16 | 4 | 48.36 |
| 5 | Ban Tác Huấn (TB+Quý) | — | 2 | — | — | 76 | 12.6 | 4.43 | 8.86 | 4 | 71.31 |

| # | O(SĐ+TH) | P(Bơm TT) | Q(Tổng SĐ) | R(Thâm) | S(Giá) | T(Tiền) |
|---|-----------|-----------|-------------|---------|--------|---------|
| 1 | 103.32 | 10.55 | 113.86 | 10.76 | 2,336.4 | 25,136.76 |
| 2 | 130.45 | 10.55 | 140.99 | 37.89 | 2,336.4 | 88,531.41 |
| 3 | 105.40 | 10.55 | 115.95 | 12.85 | 2,336.4 | 82,704.00* |
| 4 | 113.75 | 21.10 | 134.85 | 86.49 | 2,336.4 | 202,069.52 |
| 5 | 507.19 | 21.10 | 528.28 | 456.97 | 2,336.4 | 1,067,671.50 |

*\* Giá trị T12 trong Excel bị hardcode = 82,704 (không dùng công thức), có thể là chỉnh tay.*

### Kiểm chứng công thức (đầu mối 1 — TMP Trường):
```
I = 1*115 + 0*38 + 0*28 + 0*11 = 115
J = 1 * 6.3 = 6.3
K = (115 + 6.3) * 5% = 6.065
L = (115 + 6.3) * 10% = 12.13
M = 0 (không có nhà ăn)
N = 115 + 6.3 - 6.065 - 12.13 - 0 = 103.105 ✓

O = 103.316 (từ Sheet1: sử dụng 99 kW + tổn hao 4.316 kW)
P = 1 * 2025.186 / 192 = 10.548
Q = 103.316 + 10.548 = 113.864
R = 113.864 - 103.105 = 10.759
T = 10.759 * 2336.4 = 25,136.76 ✓
```

---

## 5. Điểm khác biệt giữa Excel tháng 02 và Nghiệp vụ v5

### ⚠ 5.1 BƠM NƯỚC — Tiêu chuẩn khác nhau

| | Excel tháng 02 | Nghiệp vụ v5 (ĐÚNG) |
|---|---|---|
| **Tiêu chuẩn** | **6.3 kW/người/tháng** | **9.45 kW/người/tháng** |
| **Công thức** | `J = SUM(E:H) * 6.3` | `J = SUM(E:H) * 9.45` |
| **Nguồn xác nhận** | File Excel cũ (tháng 02) | Khách xác nhận 2 lần: Zalo 06/04 + phản hồi sửa v4→v5 |

**Tác động**: Cột J (tiêu chuẩn bơm nước) sẽ cao hơn 50% khi dùng 9.45, kéo theo thay đổi cột K, L, N, R, T.

**Quyết định**: Engine tính toán **PHẢI dùng 9.45 kW/người/tháng**, không dùng 6.3 từ Excel.

### ⚠ 5.2 TỔN HAO — Vị trí trong bảng khác nhau

| | Excel tháng 02 | Nghiệp vụ v5 (ĐÚNG) |
|---|---|---|
| **Vị trí** | **CỘNG VÀO SỬ DỤNG** | **TRỪ KHỎI TIÊU CHUẨN** |
| **Cách tính** | Cột O = sử dụng + tổn hao phân bổ | Cột "Tổn hao" nằm trong "Số phải trừ" |
| **Cột bị ảnh hưởng** | O (sử dụng cao hơn) | K-area (tiêu chuẩn giảm) |
| **Kết quả thâm điện** | **Bằng nhau** | **Bằng nhau** |

**Giải thích**:

Trong **Excel** (cách cũ):
```
Tiêu chuẩn còn lại = TC - Tiết kiệm - CC SĐ - Khác     (KHÔNG trừ tổn hao)
Sử dụng = Sử dụng thực tế + Tổn hao phân bổ             (CỘNG tổn hao)
Thâm điện = Sử dụng - TC còn lại
```

Trong **Nghiệp vụ v5** (cách đúng):
```
Tiêu chuẩn còn lại = TC - Tiết kiệm - Tổn hao - CC SĐ - Khác  (TRỪ tổn hao)
Sử dụng = Sử dụng thực tế                                       (KHÔNG cộng tổn hao)
Thâm điện = Sử dụng - TC còn lại
```

Kết quả thâm điện (R) bằng nhau vì tổn hao chỉ "đổi vế" giữa 2 cách. Nhưng **v5 đúng về mặt nghiệp vụ**: tổn hao là khoản trừ khỏi tiêu chuẩn (đơn vị không được hưởng phần tổn hao), không phải phần sử dụng thêm.

**Quyết định**: Engine tính toán **PHẢI đặt tổn hao vào "Số phải trừ"**, không cộng vào sử dụng.

---

## 6. Mapping: Excel 22 cột → Nghiệp vụ v5 22 cột

| # v5 | Tên cột v5 | # Excel | Tên cột Excel | Khác biệt |
|------|-----------|---------|---------------|-----------|
| 1 | TT | B(1) | STT | — |
| 2 | Đơn vị | C(2) | Đơn vị | — |
| 3 | Tổng quân số | — | — | v5 thêm cột này, Excel không có riêng |
| 4 | Nhóm 1 (570 kW) | E(4) | 3★/4★ (115 kW) | v5: 7 nhóm, Excel: 4 nhóm, định mức KHÁC |
| 5 | Nhóm 2 (440 kW) | | | |
| 6 | Nhóm 3 (305 kW) | F(5) | 1★/2★ (38 kW) | |
| 7 | Nhóm 4 (130 kW) | G(6) | Cấp úy (28 kW) | |
| 8 | Nhóm 5 (210 kW) | | | |
| 9 | Nhóm 6 (110 kW) | | | |
| 10 | Nhóm 7 (24 kW) | H(7) | HSQ-CS (11 kW) | |
| 11 | Điện bơm nước TC | J(9) | TC bơm nước | v5: 9.45, Excel: 6.3 |
| 12 | Quân số đầu mối | — | — | v5 thêm |
| 13 | Cộng được hưởng (NĐ 02) | I(8) | Tổng TC SH | v5 = tổng 7 nhóm + bơm nước |
| 14 | Tiết kiệm | K(10) | TK 5% | Tỷ lệ có thể thay đổi |
| 15 | Tổn hao | — | — | v5 THÊM cột này vào "Số phải trừ" |
| 16 | Công cộng | L(11) | CC SĐ 10% | v5 gộp CC SĐ + CC đơn vị |
| 17 | Khác | M(12) | Nhà ăn + bếp | Tương đương |
| 18 | Tiêu chuẩn còn lại | N(13) | TC còn lại | v5 trừ thêm tổn hao |
| 19 | Sử dụng (kW) | O+P(14+15) → Q(16) | Tổng SĐ | v5 KHÔNG cộng tổn hao |
| 20 | Đơn giá | S(18) | Đơn giá | — |
| 21 | Thành tiền | T(19) | Thành tiền | — |
| 22 | Ghi chú | W(22) | Ký nhận | v5 đổi tên |

**Lưu ý quan trọng về nhóm cấp bậc**:
- Excel dùng **4 nhóm** với định mức: 115 / 38 / 28 / 11 kW
- Nghiệp vụ v5 dùng **7 nhóm** với định mức: 570 / 440 / 305 / 130 / 210 / 110 / 24 kW
- Đây là do v5 phân loại chi tiết hơn theo chức danh (chỉ huy SĐ, chỉ huy trung đoàn, chỉ huy tiểu đoàn…), không gộp theo cấp bậc quân hàm

---

## 7. Tổng hợp dữ liệu tham chiếu tháng 02/2026

| Chỉ số | Giá trị |
|--------|---------|
| Tổng quân số (SĐ bộ) | 192 (E92=16, F92=106, G92=35, H92=35) |
| Công tơ tổng điện lực (A) | 45,960 kW |
| Tổng công tơ sử dụng (B) | 40,188 kW |
| Tổn hao tổng (C = A - B) | 1,752 kW |
| Tổng sử dụng + tổn hao | 41,940 kW |
| Điện bơm nước (trạm cấp 1+2+sông) | 6,420.20 kW |
| Đơn giá | 2,336.4 đồng/kW |
| Tổng thành tiền | ~25,406,049 đồng |
| Tỷ lệ tiết kiệm | 5% |
| Tỷ lệ công cộng SĐ | 10% |

---

## 8. Kết luận cho Engine tính toán

Engine tính toán (M2) **PHẢI tuân theo nghiệp vụ v5**, cụ thể:

1. **7 nhóm cấp bậc** với định mức 570 / 440 / 305 / 130 / 210 / 110 / 24 kW (không dùng 4 nhóm 115/38/28/11 của Excel)
2. **Bơm nước tiêu chuẩn = 9.45 kW/người/tháng** (không dùng 6.3 của Excel)
3. **Tổn hao nằm trong "Số phải trừ"** — trừ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng
4. **Bơm nước sử dụng thực tế** phân bổ từ trạm bơm theo quân số (giống Excel)
5. **Công cộng** gồm 2 cấp: CC Sư đoàn + CC đơn vị (Excel chỉ có CC SĐ)
6. **Không làm tròn số** ở bất cứ bước tính nào

File Excel tháng 02 vẫn là nguồn dữ liệu test hữu ích cho:
- Dữ liệu quân số, chỉ số công tơ, sử dụng thực tế
- Logic tính tổn hao (phân bổ theo tỷ lệ kW)
- Logic phân bổ bơm nước
- Kết quả thâm điện (sau khi điều chỉnh 2 điểm khác biệt)
