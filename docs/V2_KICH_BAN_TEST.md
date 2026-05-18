# Kịch bản test — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Phiên bản:** 1.2.0
> **Ngày:** 18/05/2026
> **Nguồn nghiệp vụ:** V2_XAC_NHAN_NGHIEP_VU (v2.8.0)
> **Nguồn thiết kế:** V2_THIET_KE_HE_THONG (v2.1.0)
> **Đối tượng sử dụng:** Test thủ công (development + staging) và tham khảo cho automation test (RSpec).

### Quy ước

- **[THỦ CÔNG]** — chỉ test thủ công được (kiểm tra bằng mắt: giao diện, gộp dọc, hover, xuất Excel mở file kiểm tra).
- **[TỰ ĐỘNG]** — phù hợp automation test (RSpec: model, service, controller, request spec).
- **[CẢ HAI]** — test thủ công để verify giao diện + automation test để verify logic.
- Mã test case: `Txx` (xx = số thứ tự liên tục từ 01 đến hết).
- Kết quả mong đợi làm tròn 2 chữ số thập phân cho kW, 0 chữ số thập phân cho tiền (đồng) — đúng quy tắc hiển thị. Số liệu chính xác (chưa làm tròn) ghi trong phần dữ liệu mẫu.
- Giá trị "tổng trừ" và "hàng tổng" được tính từ giá trị chính xác rồi làm tròn, không phải cộng các giá trị đã làm tròn. Do đó có thể chênh ±0,01 so với khi cộng tay các giá trị hiển thị — đây là hành vi đúng.

---

## Mục lục

1. [Dữ liệu mẫu](#1-dữ-liệu-mẫu)
2. [Engine tính toán](#2-engine-tính-toán)
3. [Cách ly kỳ](#3-cách-ly-kỳ)
4. [Kỳ tính toán — mở, đóng, mở lại](#4-kỳ-tính-toán--mở-đóng-mở-lại)
5. [CRUD và validation](#5-crud-và-validation)
6. [Phân quyền](#6-phân-quyền)
7. [Nhập liệu hàng tháng](#7-nhập-liệu-hàng-tháng)
8. [Bảng tính tiền](#8-bảng-tính-tiền)
9. [Tổng quan](#9-tổng-quan)
10. [Tra cứu lịch sử và so sánh](#10-tra-cứu-lịch-sử-và-so-sánh)
11. [Xuất Excel](#11-xuất-excel)
12. [Xác thực và bảo mật](#12-xác-thực-và-bảo-mật)
13. [Nhật ký hệ thống](#13-nhật-ký-hệ-thống)
14. [Sao lưu và phục hồi](#14-sao-lưu-và-phục-hồi)
15. [Giao diện chung](#15-giao-diện-chung)
16. [Edge cases](#16-edge-cases)
17. [Ghi chú cho automation test](#17-ghi-chú-cho-automation-test)

---

## 1. Dữ liệu mẫu

Bộ dữ liệu dùng xuyên suốt kịch bản test. Thiết lập 1 lần, dùng cho tất cả test case.

**Thứ tự setup dữ liệu mẫu:**

1. Đăng nhập tài khoản quản trị viên hệ thống mặc định (quanTri).
2. Tạo khu vực "Khu vực 1" kèm công tơ tổng "CT-Tổng-KV1" (mục 1.3).
3. Tạo Đơn vị A, Đơn vị B trong Khu vực 1. Chỉ định Đơn vị A làm đơn vị quản lý khu vực.
4. Tạo tài khoản: adminA, adminB, chiHuyA, chiHuyB (mục 1.8).
5. Đăng nhập adminA, tạo đầu mối sinh hoạt + công tơ + quân số cho Đơn vị A (mục 1.3-1.5). Tạo khối "Phòng Tham mưu", nhóm "Ban Tác huấn". Tạo đầu mối công cộng "Nhà ăn".
6. Đăng nhập adminB, tạo đầu mối cho Đơn vị B.
7. Đăng nhập quanTri, tạo đầu mối thuộc khu vực: "Chỉ huy khu vực", "Đèn đường", "Trạm bơm 1", "Thợ xây". Cấu hình phân bổ bơm nước (mục 1.7). Cấu hình cột Khác (mục 1.6).
8. Mở kỳ tháng 5/2026, nhập đơn giá 2.336,4.
9. Nhập chỉ số công tơ theo mục 1.5. Nhập số sử dụng công tơ tổng = 2.100.
10. Bấm "Tính toán lại" → verify kết quả khớp T01-T04.

### 1.1. Cấu hình chung

| Thông số | Giá trị |
|---|---|
| Đơn giá điện | 2.336,4 đồng/kW |
| Tiết kiệm của Bộ | 5% |
| Công cộng dùng chung Sư đoàn | 10% |
| Tiêu chuẩn điện bơm nước | 9,45 kW/người/tháng |

### 1.2. Nhóm cấp bậc (7 nhóm mặc định)

| Nhóm cấp bậc | Định mức (kW/người/tháng) |
|---|---|
| Chỉ huy Sư đoàn; sĩ quan có trần quân hàm là Đại tá | 570 |
| Chỉ huy Trung đoàn; sĩ quan có trần quân hàm là Thượng tá | 440 |
| Chỉ huy Tiểu đoàn; sĩ quan có trần quân hàm là Trung tá, Thiếu tá | 305 |
| Chỉ huy Đại đội, Trung đội; sĩ quan có trần quân hàm là cấp Úy | 130 |
| Cơ quan Sư đoàn, Trung đoàn | 210 |
| Tiểu đoàn, Đại đội | 110 |
| Hạ sĩ quan, binh sĩ | 24 |

### 1.3. Cấu trúc tổ chức

```
Khu vực 1
├── Công tơ tổng: CT-Tổng-KV1 (số sử dụng: 2.100)
├── Đơn vị A (đơn vị quản lý khu vực, công cộng đơn vị: 3%)
│   ├── Khối "Phòng Tham mưu"
│   │   ├── Nhóm "Ban Tác huấn"
│   │   │   └── Đầu mối sinh hoạt "Ban Tác huấn" ← CT-A1
│   │   └── (không nhóm)
│   │       └── Đầu mối sinh hoạt "Văn thư" ← CT-A2
│   ├── (không khối, không nhóm)
│   │   └── Đầu mối sinh hoạt "Kho vật tư" ← CT-A3 (KHÔNG tổn hao)
│   └── Đầu mối công cộng "Nhà ăn" ← CT-CC-A
├── Đơn vị B (công cộng đơn vị: 0%)
│   ├── Đầu mối sinh hoạt "Đại đội 1" ← CT-B1
│   └── Đầu mối công cộng "Trạm gác" ← CT-CC-B
├── Đầu mối sinh hoạt khu vực "Chỉ huy khu vực" ← CT-KV1
├── Đầu mối công cộng khu vực "Đèn đường" ← CT-CC-KV
├── Đầu mối bơm nước "Trạm bơm 1" ← CT-BN1
└── Đầu mối ngoài biên chế "Thợ xây" (quân số: 5)
```

### 1.4. Quân số đầu mối sinh hoạt

| Đầu mối | Thuộc | Tiểu đoàn, Đại đội (110) | Cơ quan Sư đoàn, Trung đoàn (210) | Chỉ huy Đại đội, Trung đội; cấp Úy (130) | Hạ sĩ quan, binh sĩ (24) | Chỉ huy Sư đoàn; Đại tá (570) | Tổng |
|---|---|---|---|---|---|---|---|
| Ban Tác huấn | Đơn vị A | 2 | — | — | 3 | — | 5 |
| Văn thư | Đơn vị A | — | 1 | — | 1 | — | 2 |
| Kho vật tư | Đơn vị A | — | — | 1 | 2 | — | 3 |
| Đại đội 1 | Đơn vị B | — | — | 1 | 10 | — | 11 |
| Chỉ huy khu vực | Khu vực 1 | — | — | — | — | 1 | 1 |

Tổng quân số Đơn vị A: 5 + 2 + 3 = 10. Tổng quân số Đơn vị B: 11.

### 1.5. Chỉ số công tơ (kỳ tháng 5/2026)

| Công tơ | Loại | Không tổn hao | Đầu kỳ | Cuối kỳ | Sử dụng |
|---|---|---|---|---|---|
| CT-A1 | Sinh hoạt | Không (có tổn hao) | 1.000 | 1.250 | 250 |
| CT-A2 | Sinh hoạt | Không | 500 | 680 | 180 |
| CT-A3 | Sinh hoạt | **Có (không tổn hao)** | 200 | 310 | 110 |
| CT-CC-A | Công cộng | Không | 300 | 520 | 220 |
| CT-B1 | Sinh hoạt | Không | 2.000 | 2.350 | 350 |
| CT-CC-B | Công cộng | Không | 100 | 150 | 50 |
| CT-KV1 | Sinh hoạt | Không | 800 | 1.250 | 450 |
| CT-CC-KV | Công cộng | Không | 400 | 530 | 130 |
| CT-BN1 | Bơm nước | Không | 600 | 900 | 300 |
| CT-Tổng-KV1 | Công tơ tổng | — | — | — | 2.100 (nhập số sử dụng) |

### 1.6. Cấu hình cột "Khác"

| Đầu mối | Dạng nhập | Giá trị |
|---|---|---|
| Ban Tác huấn | Số cụ thể | 5 |
| Văn thư | Hệ số | −2,5 (âm — cộng ngược vào tiêu chuẩn) |
| Kho vật tư | Số cụ thể | 0 |
| Đại đội 1 | Hệ số | 3 |
| Chỉ huy khu vực | Số cụ thể | 0 |

### 1.7. Cấu hình phân bổ bơm nước (Khu vực 1)

| Đối tượng | Cách phân bổ | Giá trị | Quân số |
|---|---|---|---|
| Chỉ huy khu vực (đầu mối sinh hoạt khu vực) | Phần trăm cố định | 20% | 1 |
| Đơn vị A | Hệ số | 1 | 10 |
| Đơn vị B | Hệ số | 1 | 11 |
| Thợ xây (ngoài biên chế) | Hệ số | 0,5 | 5 |

### 1.8. Tài khoản test

| Tên đăng nhập | Vai trò | Đơn vị | Ghi chú |
|---|---|---|---|
| kyThuat | Kỹ thuật viên | — | Mặc định |
| quanTri | Quản trị viên hệ thống | — | Mặc định |
| adminA | Quản trị viên đơn vị | Đơn vị A | Đơn vị A là đơn vị quản lý khu vực |
| adminB | Quản trị viên đơn vị | Đơn vị B | |
| chiHuyA | Chỉ huy đơn vị | Đơn vị A | |
| chiHuyB | Chỉ huy đơn vị | Đơn vị B | |

---

## 2. Engine tính toán

Nhóm test quan trọng nhất. Sử dụng dữ liệu mẫu ở mục 1.

### T01 — Tổn hao (LossCalculator) [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Dữ liệu mẫu đã nhập đầy đủ. Kỳ tháng 5/2026 đang mở.

**Kết quả mong đợi:**

Tổng sử dụng công tơ không tổn hao = 110 (CT-A3).

A = 2.100 − 110 = 1.990

B = 250 + 180 + 220 + 350 + 50 + 450 + 130 + 300 = 1.930

C = 1.990 − 1.930 = 60 (tổng tổn hao khu vực, tỷ lệ ~3,11%)

Tổn hao per công tơ = sử dụng × C ÷ B = sử dụng × 60 ÷ 1.930:

| Công tơ | Sử dụng | Tổn hao (chính xác) | Tổn hao (hiển thị) |
|---|---|---|---|
| CT-A1 | 250 | 250 × 60 ÷ 1.930 | 7,77 |
| CT-A2 | 180 | 180 × 60 ÷ 1.930 | 5,60 |
| CT-CC-A | 220 | 220 × 60 ÷ 1.930 | 6,84 |
| CT-B1 | 350 | 350 × 60 ÷ 1.930 | 10,88 |
| CT-CC-B | 50 | 50 × 60 ÷ 1.930 | 1,55 |
| CT-KV1 | 450 | 450 × 60 ÷ 1.930 | 13,99 |
| CT-CC-KV | 130 | 130 × 60 ÷ 1.930 | 4,04 |
| CT-BN1 | 300 | 300 × 60 ÷ 1.930 | 9,33 |
| CT-A3 | 110 | 0 (không tổn hao) | 0,00 |

Tổn hao per đầu mối sinh hoạt (= tổng tổn hao các công tơ trong đầu mối):

| Đầu mối | Tổn hao (hiển thị) |
|---|---|
| Ban Tác huấn | 7,77 |
| Văn thư | 5,60 |
| Kho vật tư | 0,00 |
| Đại đội 1 | 10,88 |
| Chỉ huy khu vực | 13,99 |

**Điểm kiểm tra:**
- Tổng tổn hao tất cả công tơ có tổn hao = C = 60 (verify tổng).
- CT-A3 (không tổn hao) có tổn hao = 0.
- Tổn hao tỷ lệ thuận với sử dụng: CT-KV1 dùng nhiều nhất (450) → tổn hao cao nhất.

### T02 — Bơm nước (PumpAllocationCalculator) [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kết quả tổn hao từ T01.

**Kết quả mong đợi:**

D = sử dụng thô bơm nước + tổn hao bơm nước = 300 + 9,33 = 309,33 (chính xác: 300 + 300 × 60 ÷ 1.930)

Phần cố định:
- Chỉ huy khu vực: 309,33 × 20% = 61,87

Phần còn lại: 309,33 × 80% = 247,46

Trọng số: Đơn vị A = 10 × 1 = 10; Đơn vị B = 11 × 1 = 11; Thợ xây = 5 × 0,5 = 2,5. Tổng = 23,5.

| Đối tượng | Phân bổ (hiển thị) |
|---|---|
| Chỉ huy khu vực (20% cố định) | 61,87 |
| Đơn vị A (hệ số) | 247,46 × 10 ÷ 23,5 = 105,30 |
| Đơn vị B (hệ số) | 247,46 × 11 ÷ 23,5 = 115,83 |
| Thợ xây (hệ số) | 247,46 × 2,5 ÷ 23,5 = 26,33 |

Kiểm tra: 61,87 + 105,30 + 115,83 + 26,33 = 309,33 ✓

Từ đơn vị xuống đầu mối (chia đều theo quân số):

Đơn vị A nhận 105,30 kW, tổng quân số 10:
- Ban Tác huấn (5 người): 105,30 × 5 ÷ 10 = 52,65
- Văn thư (2 người): 105,30 × 2 ÷ 10 = 21,06
- Kho vật tư (3 người): 105,30 × 3 ÷ 10 = 31,59

Đơn vị B nhận 115,83 kW, tổng quân số 11:
- Đại đội 1 (11 người): 115,83

Chỉ huy khu vực: 61,87 (nhận trực tiếp theo % cố định)

**Điểm kiểm tra:**
- D bao gồm tổn hao bơm nước (không chỉ sử dụng thô).
- Tổng phân bổ = D.
- Thợ xây (ngoài biên chế) nhận bơm nước nhưng không có trên bảng tính tiền.
- Chia từ đơn vị xuống đầu mối theo quân số, không theo cấp bậc.

### T03 — Tổng hợp (SummaryCalculator) [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kết quả tổn hao từ T01, bơm nước từ T02.

**Kết quả mong đợi:**

Per đầu mối sinh hoạt:

**Ban Tác huấn (Đơn vị A):**

| Mục | Công thức | Kết quả (hiển thị) |
|---|---|---|
| Tiêu chuẩn sinh hoạt | (2 × 110) + (3 × 24) | 292,00 |
| Tiêu chuẩn bơm nước | 5 × 9,45 | 47,25 |
| Tổng tiêu chuẩn | 292 + 47,25 | 339,25 |
| Tiết kiệm của Bộ | 5% × 339,25 | 16,96 |
| Tổn hao | (từ T01) | 7,77 |
| Công cộng Sư đoàn | 10% × 339,25 | 33,93 |
| Công cộng đơn vị | 3% × 339,25 | 10,18 |
| Khác | 5 (số cụ thể) | 5,00 |
| Tổng trừ | 16,96 + 7,77 + 33,93 + 10,18 + 5 | 73,84 |
| Tiêu chuẩn còn lại | 339,25 − 73,84 | 265,41 |
| Sử dụng sinh hoạt | (từ công tơ) | 250,00 |
| Sử dụng bơm nước | (từ T02) | 52,65 |
| Tổng sử dụng | 250 + 52,65 | 302,65 |
| **Thiếu** | 302,65 − 265,41 | **37,24** |
| **Thành tiền thiếu** | 37,24 × 2.336,4 | **87.004** |

**Văn thư (Đơn vị A) — cột Khác âm:**

| Mục | Công thức | Kết quả (hiển thị) |
|---|---|---|
| Tiêu chuẩn sinh hoạt | (1 × 210) + (1 × 24) | 234,00 |
| Tiêu chuẩn bơm nước | 2 × 9,45 | 18,90 |
| Tổng tiêu chuẩn | 234 + 18,9 | 252,90 |
| Tiết kiệm của Bộ | 5% × 252,9 | 12,65 |
| Tổn hao | (từ T01) | 5,60 |
| Công cộng Sư đoàn | 10% × 252,9 | 25,29 |
| Công cộng đơn vị | 3% × 252,9 | 7,59 |
| Khác | −2,5 × 2 = −5 (hệ số × quân số) | −5,00 |
| Tổng trừ | 12,65 + 5,60 + 25,29 + 7,59 + (−5) | 46,12 |
| Tiêu chuẩn còn lại | 252,9 − 46,12 | 206,78 |
| Sử dụng sinh hoạt | | 180,00 |
| Sử dụng bơm nước | (từ T02) | 21,06 |
| Tổng sử dụng | 180 + 21,06 | 201,06 |
| **Thừa** | 206,78 − 201,06 | **5,72** |
| **Thành tiền thừa** | 5,72 × 2.336,4 | **13.368** (tham khảo) |

Điểm kiểm tra: cột Khác = −5 làm tổng trừ giảm → tiêu chuẩn còn lại tăng → đầu mối thừa.

**Kho vật tư (Đơn vị A) — không tổn hao:**

| Mục | Công thức | Kết quả (hiển thị) |
|---|---|---|
| Tiêu chuẩn sinh hoạt | (1 × 130) + (2 × 24) | 178,00 |
| Tiêu chuẩn bơm nước | 3 × 9,45 | 28,35 |
| Tổng tiêu chuẩn | 178 + 28,35 | 206,35 |
| Tiết kiệm của Bộ | 5% × 206,35 | 10,32 |
| Tổn hao | 0 (công tơ không tổn hao) | 0,00 |
| Công cộng Sư đoàn | 10% × 206,35 | 20,64 |
| Công cộng đơn vị | 3% × 206,35 | 6,19 |
| Khác | 0 | 0,00 |
| Tổng trừ | 10,32 + 0 + 20,64 + 6,19 + 0 | 37,14 |
| Tiêu chuẩn còn lại | 206,35 − 37,14 | 169,21 |
| Sử dụng sinh hoạt | | 110,00 |
| Sử dụng bơm nước | (từ T02) | 31,59 |
| Tổng sử dụng | 110 + 31,59 | 141,59 |
| **Thừa** | 169,21 − 141,59 | **27,62** |
| **Thành tiền thừa** | 27,62 × 2.336,4 | **64.523** (tham khảo) |

Điểm kiểm tra: tổn hao = 0 vì công tơ không tổn hao.

**Đại đội 1 (Đơn vị B) — công cộng đơn vị 0%, cột Khác hệ số dương:**

| Mục | Công thức | Kết quả (hiển thị) |
|---|---|---|
| Tiêu chuẩn sinh hoạt | (1 × 130) + (10 × 24) | 370,00 |
| Tiêu chuẩn bơm nước | 11 × 9,45 | 103,95 |
| Tổng tiêu chuẩn | 370 + 103,95 | 473,95 |
| Tiết kiệm của Bộ | 5% × 473,95 | 23,70 |
| Tổn hao | (từ T01) | 10,88 |
| Công cộng Sư đoàn | 10% × 473,95 | 47,40 |
| Công cộng đơn vị | 0% × 473,95 | 0,00 |
| Khác | 3 × 11 = 33 (hệ số × quân số) | 33,00 |
| Tổng trừ | 23,70 + 10,88 + 47,40 + 0 + 33 | 114,97 |
| Tiêu chuẩn còn lại | 473,95 − 114,97 | 358,98 |
| Sử dụng sinh hoạt | | 350,00 |
| Sử dụng bơm nước | (từ T02) | 115,83 |
| Tổng sử dụng | 350 + 115,83 | 465,83 |
| **Thiếu** | 465,83 − 358,98 | **106,86** |
| **Thành tiền thiếu** | 106,86 × 2.336,4 | **249.659** |

Điểm kiểm tra: công cộng đơn vị = 0 vì Đơn vị B cấu hình 0%.

**Chỉ huy khu vực (thuộc khu vực, không thuộc đơn vị):**

| Mục | Công thức | Kết quả (hiển thị) |
|---|---|---|
| Tiêu chuẩn sinh hoạt | 1 × 570 | 570,00 |
| Tiêu chuẩn bơm nước | 1 × 9,45 | 9,45 |
| Tổng tiêu chuẩn | 570 + 9,45 | 579,45 |
| Tiết kiệm của Bộ | 5% × 579,45 | 28,97 |
| Tổn hao | (từ T01) | 13,99 |
| Công cộng Sư đoàn | 10% × 579,45 | 57,95 |
| Công cộng đơn vị | 0 (thuộc khu vực, không có unit_config) | 0,00 |
| Khác | 0 | 0,00 |
| Tổng trừ | 28,97 + 13,99 + 57,95 + 0 + 0 | 100,91 |
| Tiêu chuẩn còn lại | 579,45 − 100,91 | 478,54 |
| Sử dụng sinh hoạt | | 450,00 |
| Sử dụng bơm nước | (từ T02) | 61,87 |
| Tổng sử dụng | 450 + 61,87 | 511,87 |
| **Thiếu** | 511,87 − 478,54 | **33,32** |
| **Thành tiền thiếu** | 33,32 × 2.336,4 | **77.855** |

Điểm kiểm tra: đầu mối thuộc khu vực → công cộng đơn vị = 0 (không có đơn vị → không có unit_config).

### T04 — Hàng tổng bảng tính tiền [CẢ HAI]

**Kết quả mong đợi:** Hàng tổng = tổng 5 đầu mối sinh hoạt.

| Cột | Tổng (hiển thị) |
|---|---|
| Tổng quân số | 22 |
| Tiêu chuẩn sinh hoạt | 1.644,00 |
| Tiêu chuẩn bơm nước | 207,90 |
| Tổng tiêu chuẩn | 1.851,90 |
| Tiết kiệm của Bộ | 92,60 |
| Tổn hao | 38,24 |
| Công cộng Sư đoàn | 185,19 |
| Công cộng đơn vị | 23,96 |
| Khác | 33,00 |
| Tổng trừ | 372,98 |
| Tiêu chuẩn còn lại | 1.478,92 |
| Sử dụng sinh hoạt | 1.340,00 |
| Sử dụng bơm nước | 283,00 |
| Tổng sử dụng | 1.623,00 |

---

## 3. Cách ly kỳ

Nhóm test quan trọng, đảm bảo nguyên tắc "sửa kỳ này tuyệt đối không ảnh hưởng kỳ khác." Mọi test case đều yêu cầu verify dữ liệu kỳ khác không bị thay đổi.

### T05 — Snapshot quân số cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5/2026 đã nhập liệu đầy đủ, đã tính toán (kết quả từ T03). Đóng kỳ tháng 5.

**Các bước:**

1. Quản trị viên hệ thống mở kỳ tháng 6/2026.
2. Quản trị viên đơn vị A sửa quân số "Ban Tác huấn": thay đổi từ (2 Tiểu đoàn Đại đội + 3 Hạ sĩ quan binh sĩ = 5 người) thành (2 Tiểu đoàn Đại đội + 5 Hạ sĩ quan binh sĩ = 7 người).
3. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: "Ban Tác huấn" có tổng quân số = 7, tiêu chuẩn sinh hoạt = (2 × 110) + (5 × 24) = 340.
- **Kỳ tháng 5 (đã đóng): "Ban Tác huấn" vẫn có tổng quân số = 5, tiêu chuẩn sinh hoạt = 292. Toàn bộ calculations tháng 5 không thay đổi.**

**Cách verify:** Mở xem bảng tính tiền kỳ tháng 5, kiểm tra quân số và tiêu chuẩn sinh hoạt của "Ban Tác huấn" vẫn đúng giá trị cũ.

### T06 — Snapshot cấu hình đơn vị cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A sửa công cộng đơn vị từ 3% thành 8% (kỳ tháng 6).
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: công cộng đơn vị "Ban Tác huấn" = 8% × tổng tiêu chuẩn.
- **Kỳ tháng 5: công cộng đơn vị "Ban Tác huấn" vẫn = 3% × 339,25 = 10,18. Calculations tháng 5 không đổi.**

### T07 — Snapshot định mức cấp bậc cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống sửa định mức "Hạ sĩ quan, binh sĩ" từ 24 thành 30 (kỳ tháng 6).
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: "Ban Tác huấn" tiêu chuẩn sinh hoạt dùng định mức mới (30 thay vì 24).
- **Kỳ tháng 5: "Ban Tác huấn" tiêu chuẩn sinh hoạt vẫn dùng định mức 24. Calculations tháng 5 không đổi.**

### T08 — Snapshot đơn giá cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống sửa đơn giá kỳ tháng 6 từ 2.336,4 thành 2.500.
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: thành tiền tính theo đơn giá 2.500.
- **Kỳ tháng 5: thành tiền vẫn tính theo đơn giá 2.336,4. Calculations tháng 5 không đổi.**

### T09 — Snapshot tỷ lệ tiết kiệm và công cộng Sư đoàn cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống sửa tiết kiệm của Bộ từ 5% thành 7%, công cộng Sư đoàn từ 10% thành 12% (kỳ tháng 6).
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: khoản trừ tiết kiệm = 7%, công cộng Sư đoàn = 12%.
- **Kỳ tháng 5: tiết kiệm vẫn 5%, công cộng Sư đoàn vẫn 10%. Calculations tháng 5 không đổi.**

### T10 — Snapshot phân bổ bơm nước cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống sửa phân bổ bơm nước kỳ tháng 6: đổi "Chỉ huy khu vực" từ 20% cố định thành 30% cố định.
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: Chỉ huy khu vực nhận 30% tổng bơm nước.
- **Kỳ tháng 5: Chỉ huy khu vực vẫn nhận 20% (= 61,87 kW). Calculations tháng 5 không đổi.**

### T11 — Snapshot thuộc tính không tổn hao cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Sửa thuộc tính CT-A3 từ "không tổn hao" thành "có tổn hao" (kỳ tháng 6).
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: CT-A3 tham gia tính tổn hao (B bao gồm CT-A3, A không trừ CT-A3).
- **Kỳ tháng 5: CT-A3 vẫn là "không tổn hao" trong meter_readings.no_loss. Tính toán lại kỳ tháng 5 vẫn cho kết quả cũ.**

### T12 — Snapshot cột "Khác" cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A sửa cột Khác của "Ban Tác huấn" kỳ tháng 6: từ số cụ thể 5 thành hệ số 10.
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: Khác "Ban Tác huấn" = 10 × quân số kỳ 6.
- **Kỳ tháng 5: Khác "Ban Tác huấn" vẫn = 5 (số cụ thể). Calculations tháng 5 không đổi.**

### T13 — Mở lại kỳ cũ, sửa, đóng lại — không ảnh hưởng kỳ sau [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng, đã tính toán. Kỳ tháng 6 đã đóng, đã tính toán. Không có kỳ nào đang mở.

**Các bước:**

1. Quản trị viên hệ thống mở lại kỳ tháng 5.
2. Quản trị viên đơn vị A sửa số cuối kỳ CT-A1 từ 1.250 thành 1.300 (sử dụng tăng từ 250 lên 300).
3. Tính toán lại kỳ tháng 5.
4. Đóng kỳ tháng 5.

**Kết quả mong đợi:**

- Kỳ tháng 5 (sau sửa): "Ban Tác huấn" sử dụng sinh hoạt = 300 (tăng 50). Tất cả calculations kỳ 5 tính lại với giá trị mới.
- **Kỳ tháng 6: toàn bộ dữ liệu và calculations tháng 6 không thay đổi gì. Số đầu kỳ CT-A1 kỳ tháng 6 vẫn giữ nguyên giá trị cũ (1.250, không bị đổi thành 1.300).**
- Hệ thống hiển thị cảnh báo khi đóng kỳ 5: "Số cuối kỳ CT-A1 (1.300) không khớp số đầu kỳ CT-A1 kỳ tháng 6 (1.250)." Chỉ cảnh báo, không tự sửa.

### T14 — Mở lại kỳ cũ khi có kỳ đang mở [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống mở lại kỳ tháng 5.

**Kết quả mong đợi:**

- Hệ thống hiển thị cảnh báo: "Kỳ tháng 6/2026 đang mở. Phải đóng kỳ tháng 6/2026 trước khi mở lại kỳ cũ."
- Không cho mở kỳ tháng 5.

### T15 — Thêm đầu mối mới ở kỳ sau, kỳ trước không bị ảnh hưởng [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt mới "Lái xe" thuộc Đơn vị A, quân số 2 người "Hạ sĩ quan, binh sĩ", 1 công tơ "CT-LX".
2. Nhập chỉ số CT-LX kỳ tháng 6.
3. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: "Lái xe" xuất hiện trên bảng tính tiền, có dữ liệu.
- **Kỳ tháng 5: "Lái xe" không xuất hiện (không có meter_readings, personnel_entries cho kỳ tháng 5). Calculations tháng 5 không đổi.**

### T16 — Xóa đầu mối ở kỳ sau, kỳ trước vẫn hiển thị đầu mối đó [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng, đã tính toán. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A xóa (soft delete) đầu mối "Kho vật tư".

**Kết quả mong đợi:**

- Kỳ tháng 6: "Kho vật tư" không xuất hiện trên bảng tính tiền, không tham gia tính toán.
- **Kỳ tháng 5: "Kho vật tư" vẫn xuất hiện trên bảng tính tiền, calculations vẫn giữ nguyên giá trị cũ (thừa 27,62 kW).**

### T17 — Snapshot tiêu chuẩn bơm nước cách ly giữa các kỳ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. Kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên hệ thống sửa tiêu chuẩn bơm nước từ 9,45 thành 12 kW/người/tháng (kỳ tháng 6).
2. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: tiêu chuẩn bơm nước tính theo 12 kW/người/tháng.
- **Kỳ tháng 5: tiêu chuẩn bơm nước vẫn tính theo 9,45. Calculations tháng 5 không đổi.**

### T18 — Tính toán lại kỳ đã đóng dùng snapshot, không dùng dữ liệu hiện tại [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng, đã tính toán với đầy đủ dữ liệu mẫu. Kỳ tháng 6 đang mở, đã sửa nhiều cấu hình (quân số, định mức, đơn giá, phân bổ bơm nước...).

**Các bước:**

1. Đóng kỳ tháng 6.
2. Mở lại kỳ tháng 5.
3. Bấm "Tính toán lại" kỳ tháng 5.
4. So sánh kết quả với calculations ban đầu của kỳ tháng 5.

**Kết quả mong đợi:**

- Kết quả tính toán lại kỳ tháng 5 **phải giống hệt** kết quả ban đầu (T03). Engine dùng snapshot (ranks, personnel_entries, unit_configs, meter_readings.no_loss, pump_allocations, other_deductions đều có period_id trỏ tới kỳ tháng 5), không dùng dữ liệu hiện tại hay dữ liệu kỳ tháng 6.

Đây là test case quan trọng nhất cho nguyên tắc cách ly kỳ: chứng minh engine idempotent khi dùng snapshot.

---

## 4. Kỳ tính toán — mở, đóng, mở lại

### T19 — Mở kỳ đầu tiên [CẢ HAI]

**Điều kiện tiên quyết:** Hệ thống vừa cài đặt, chưa có kỳ nào. Đã tạo khu vực, đơn vị, đầu mối, công tơ.

**Các bước:**

1. Quản trị viên hệ thống vào trang "Đơn giá điện".
2. Nhập đơn giá 2.336,4. Chọn tháng 5, năm 2026.
3. Bấm "Mở kỳ mới".

**Kết quả mong đợi:**

- Kỳ tháng 5/2026 được tạo, trạng thái: đang mở.
- 7 nhóm cấp bậc được tạo cho kỳ này với định mức mặc định (570, 440, 305, 130, 210, 110, 24).
- meter_readings được tạo cho mỗi công tơ: reading_start = null (phải nhập thủ công), reading_end = null, no_loss từ meters.no_loss.
- personnel_entries được tạo cho mỗi đầu mối sinh hoạt × 7 nhóm cấp bậc, count = quân số đã nhập khi tạo đầu mối.
- non_establishment_snapshots được tạo cho đầu mối ngoài biên chế.
- unit_configs: công cộng đơn vị = 0% (mặc định).
- other_deductions: fixed, 0 (mặc định).
- pump_allocations: hệ số = 1 (mặc định, nếu đã có cấu hình).
- Tiết kiệm Bộ = 5%, công cộng Sư đoàn = 10%, tiêu chuẩn bơm nước = 9,45 (mặc định).
- Thông báo đăng nhập hiển thị: "Kỳ tháng 5/2026 đã mở, vui lòng nhập liệu."

### T20 — Mở kỳ mới (có kỳ trước) [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5/2026 đã đóng. Đã nhập đầy đủ dữ liệu mẫu.

**Các bước:**

1. Quản trị viên hệ thống bấm "Mở kỳ mới".

**Kết quả mong đợi:**

- Kỳ tháng 6/2026 được tạo tự động (hệ thống tự xác định year/month).
- Kế thừa từ kỳ tháng 5:
  - meter_readings: reading_start = reading_end kỳ tháng 5 (ví dụ: CT-A1 reading_start = 1.250).
  - personnel_entries: count kế thừa từ kỳ tháng 5.
  - unit_configs: công cộng đơn vị A = 3%, đơn vị B = 0%.
  - other_deductions: kế thừa dạng + giá trị.
  - pump_allocations: kế thừa cấu hình.
  - ranks: kế thừa tên + quota + position.
  - Đơn giá, tiết kiệm, công cộng Sư đoàn, tiêu chuẩn bơm nước: kế thừa.
- Không kế thừa: main_meter_readings (nhập mới), meter_readings.reading_end (nhập mới), calculations (tính mới).

### T21 — Không cho mở kỳ mới khi có kỳ đang mở [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5/2026 đang mở.

**Các bước:**

1. Quản trị viên hệ thống bấm "Mở kỳ mới".

**Kết quả mong đợi:**

- Hệ thống không cho mở. Hiển thị thông báo: "Kỳ tháng 5/2026 đang mở. Phải đóng kỳ hiện tại trước khi mở kỳ mới."

### T22 — Đóng kỳ chặn nhập liệu [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5/2026 đang mở.

**Các bước:**

1. Quản trị viên hệ thống đóng kỳ tháng 5.
2. Quản trị viên đơn vị A thử sửa chỉ số công tơ CT-A1.

**Kết quả mong đợi:**

- Bước 2 bị chặn. Hiển thị thông báo: "Không có kỳ đang mở. Vui lòng liên hệ quản trị viên hệ thống."
- Tất cả ô nhập trên trang nhập liệu bị disable.
- Trang xem (bảng tính tiền, tổng quan) vẫn truy cập được bình thường.

### T23 — Đóng kỳ cũ sau khi sửa — cảnh báo không khớp [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5 và tháng 6 đã đóng. CT-A1 kỳ tháng 5 cuối kỳ = 1.250, CT-A1 kỳ tháng 6 đầu kỳ = 1.250.

**Các bước:**

1. Mở lại kỳ tháng 5.
2. Sửa cuối kỳ CT-A1 từ 1.250 thành 1.300.
3. Đóng kỳ tháng 5.

**Kết quả mong đợi:**

- Hệ thống hiển thị cảnh báo: "Công tơ CT-A1: số cuối kỳ tháng 5 (1.300) không khớp số đầu kỳ tháng 6 (1.250)."
- Vẫn cho đóng (chỉ cảnh báo, không chặn).
- Kỳ tháng 6 không bị ảnh hưởng.

### T24 — Kỳ tháng 12 sang tháng 1 năm sau [TỰ ĐỘNG]

**Các bước:**

1. Tạo và đóng kỳ tháng 12/2026.
2. Mở kỳ mới.

**Kết quả mong đợi:**

- Kỳ mới = tháng 1/2027 (year tăng 1).

### T25 — Thêm đầu mối mới khi kỳ đang mở [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt mới "Tổ xe" với 3 người "Hạ sĩ quan, binh sĩ", 1 công tơ "CT-TX".

**Kết quả mong đợi:**

- Hệ thống tự tạo cho kỳ tháng 5 đang mở:
  - meter_readings cho CT-TX: reading_start = 0 (công tơ mới lắp bắt đầu từ 0, quản trị viên có thể sửa nếu cần), reading_end = null, no_loss từ meters.no_loss.
  - personnel_entries cho "Tổ xe" × 7 nhóm cấp bậc: count = 3 cho "Hạ sĩ quan, binh sĩ", count = 0 cho 6 nhóm còn lại.
  - other_deductions: fixed, 0.
- "Tổ xe" xuất hiện trên bảng tính tiền kỳ tháng 5 sau khi nhập liệu.

### T26 — Thêm đầu mối mới khi không có kỳ đang mở [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Tất cả kỳ đã đóng.

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt mới "Tổ bảo vệ".

**Kết quả mong đợi:**

- Đầu mối được tạo thành công (CRUD không bị chặn bởi PeriodGuard — chỉ nhập liệu bị chặn).
- Không có meter_readings, personnel_entries cho bất kỳ kỳ nào đã đóng.
- Đầu mối sẽ có dữ liệu từ kỳ tiếp theo khi mở kỳ mới.

---

## 5. CRUD và validation

### T27 — Tạo khu vực [CẢ HAI]

**Các bước:**

1. Quản trị viên hệ thống tạo khu vực "Khu vực 1", tên công tơ tổng "CT-Tổng-KV1".

**Kết quả mong đợi:**

- Khu vực được tạo thành công.
- Công tơ tổng "CT-Tổng-KV1" được tạo cùng lúc.
- Hiển thị cảnh báo "Khu vực chưa có đơn vị".

### T28 — Tạo khu vực thiếu công tơ tổng [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống tạo khu vực "Khu vực 2", không nhập tên công tơ tổng.

**Kết quả mong đợi:**

- Hệ thống không cho tạo. Thông báo lỗi: trường công tơ tổng là bắt buộc.

### T29 — Tạo đơn vị [CẢ HAI]

**Các bước:**

1. Quản trị viên hệ thống tạo đơn vị "Đơn vị A", gán vào "Khu vực 1".

**Kết quả mong đợi:**

- Đơn vị được tạo thành công.
- Đơn vị thuộc khu vực 1.
- Cảnh báo "Khu vực chưa có đơn vị" biến mất.

### T30 — Không cho chuyển đơn vị sang khu vực khác [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống tạo khu vực "Khu vực 2".
2. Thử sửa "Đơn vị A" để chuyển sang "Khu vực 2".

**Kết quả mong đợi:**

- Hệ thống không cho sửa khu vực. Trường khu vực bị khóa (không đổi được sau khi tạo).

### T31 — Chỉ định và đổi đơn vị quản lý khu vực [CẢ HAI]

**Các bước:**

1. Quản trị viên hệ thống tạo thêm "Đơn vị B" thuộc "Khu vực 1".
2. Chỉ định "Đơn vị A" làm đơn vị quản lý khu vực.
3. Đổi đơn vị quản lý khu vực từ "Đơn vị A" sang "Đơn vị B".

**Kết quả mong đợi:**

- Bước 2: Đơn vị A được đánh dấu là đơn vị quản lý khu vực. Quản trị viên đơn vị A (adminA) có thêm quyền nhập liệu phần khu vực.
- Bước 3: Đơn vị B trở thành đơn vị quản lý khu vực. adminA mất quyền nhập liệu khu vực. adminB có thêm quyền nhập liệu khu vực.

### T32 — Khu vực chỉ có 1 đơn vị — tự động là đơn vị quản lý [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống tạo khu vực mới, chỉ tạo 1 đơn vị trong đó.

**Kết quả mong đợi:**

- Đơn vị đó tự động là đơn vị quản lý khu vực.

### T33 — Tạo đầu mối sinh hoạt [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A (adminA) tạo đầu mối sinh hoạt "Ban Tác huấn", quân số: 2 người "Tiểu đoàn, Đại đội" + 3 người "Hạ sĩ quan, binh sĩ", 1 công tơ "CT-A1".

**Kết quả mong đợi:**

- Đầu mối được tạo thành công, thuộc Đơn vị A.
- Công tơ CT-A1 được tạo kèm, mặc định có tổn hao.
- personnel_entries: 7 bản ghi (1 per nhóm cấp bậc), count = 2 cho "Tiểu đoàn, Đại đội", count = 3 cho "Hạ sĩ quan, binh sĩ", count = 0 cho 5 nhóm còn lại.

### T34 — Đầu mối sinh hoạt phải có ít nhất 1 người [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt "Test", quân số tất cả nhóm = 0.

**Kết quả mong đợi:**

- Hệ thống không cho tạo. Thông báo lỗi: tổng quân số đầu mối sinh hoạt phải ≥ 1.

### T35 — Đầu mối phải có ít nhất 1 công tơ [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt "Test", quân số hợp lệ, không tạo công tơ.

**Kết quả mong đợi:**

- Hệ thống không cho tạo. Thông báo lỗi: đầu mối phải có ít nhất 1 công tơ.

### T36 — Tạo đầu mối ngoài biên chế [CẢ HAI]

**Các bước:**

1. Quản trị viên hệ thống tạo đầu mối ngoài biên chế "Thợ xây" thuộc Khu vực 1, quân số = 5.

**Kết quả mong đợi:**

- Đầu mối được tạo thành công, không có công tơ.
- Quân số = 5 (1 con số tổng, không phân theo nhóm cấp bậc).
- Đầu mối không xuất hiện trên bảng tính tiền.

### T37 — Không trùng tên trong cùng phạm vi [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối sinh hoạt "Ban Tác huấn" (đã tồn tại).

**Kết quả mong đợi:**

- Hệ thống không cho tạo. Thông báo lỗi: tên đầu mối đã tồn tại trong đơn vị.

### T38 — Xóa công tơ cuối cùng của đầu mối [TỰ ĐỘNG]

**Các bước:**

1. Đầu mối "Ban Tác huấn" chỉ có 1 công tơ CT-A1.
2. Quản trị viên đơn vị A xóa CT-A1.

**Kết quả mong đợi:**

- Hệ thống không cho xóa. Thông báo lỗi: đầu mối phải có ít nhất 1 công tơ.

### T39 — Xóa đơn vị đang có đầu mối [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống xóa "Đơn vị A" (đang có đầu mối).

**Kết quả mong đợi:**

- Hệ thống không cho xóa. Thông báo lỗi: phải xóa hết đầu mối trong đơn vị trước.

### T40 — Xóa khu vực đang có đơn vị [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống xóa "Khu vực 1" (đang có Đơn vị A, Đơn vị B).

**Kết quả mong đợi:**

- Hệ thống không cho xóa. Thông báo lỗi: phải xóa hết đơn vị trong khu vực trước.

### T41 — Xóa đơn vị quản lý khu vực [CẢ HAI]

**Điều kiện tiên quyết:** Đơn vị A là đơn vị quản lý khu vực. Đơn vị A không có đầu mối (đã xóa hết để test). Đơn vị A không có tài khoản (đã xóa adminA, chiHuyA để test).

**Các bước:**

1. Quản trị viên hệ thống xóa "Đơn vị A".

**Kết quả mong đợi:**

- Hiển thị cảnh báo: Đơn vị A là đơn vị quản lý khu vực.
- Nếu xác nhận xóa: đơn vị bị xóa. Quản trị viên hệ thống tự quản lý khu vực cho đến khi chỉ định đơn vị khác.

### T42 — Xóa khối đang có nhóm và đầu mối [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Khối "Phòng Tham mưu" chứa nhóm "Ban Tác huấn" (có đầu mối bên trong) và đầu mối "Văn thư" (không có nhóm).

**Các bước:**

1. Quản trị viên đơn vị A xóa khối "Phòng Tham mưu".

**Kết quả mong đợi:**

- Khối bị xóa.
- Nhóm "Ban Tác huấn" và đầu mối "Văn thư" chuyển thành trực tiếp thuộc Đơn vị A.
- Tính toán không bị ảnh hưởng (khối chỉ phục vụ hiển thị).

### T43 — Xóa nhóm đang có đầu mối [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A xóa nhóm "Ban Tác huấn" (thuộc khối "Phòng Tham mưu").

**Kết quả mong đợi:**

- Nhóm bị xóa.
- Đầu mối "Ban Tác huấn" chuyển lên khối "Phòng Tham mưu" (vì nhóm thuộc khối).

### T44 — Xóa nhóm cấp bậc đang có đầu mối sử dụng [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Nhóm cấp bậc "Hạ sĩ quan, binh sĩ" đang có quân số > 0 ở nhiều đầu mối.

**Các bước:**

1. Quản trị viên hệ thống xóa nhóm cấp bậc "Hạ sĩ quan, binh sĩ".

**Kết quả mong đợi:**

- Hệ thống không cho xóa. Thông báo lỗi: phải chuyển hết quân số sang nhóm cấp bậc khác trước.

### T45 — Xóa tài khoản mặc định [TỰ ĐỘNG]

**Các bước:**

1. Kỹ thuật viên hệ thống xóa tài khoản quản trị viên hệ thống mặc định.

**Kết quả mong đợi:**

- Hệ thống không cho xóa. 2 tài khoản mặc định (kỹ thuật viên và quản trị viên hệ thống) không xóa được.

### T46 — Không cho tự xóa chính mình [TỰ ĐỘNG]

**Các bước:**

1. Kỹ thuật viên hệ thống (kyThuat) đang đăng nhập, thử xóa tài khoản kyThuat.

**Kết quả mong đợi:**

- Hệ thống không cho xóa. Không cho tự xóa chính mình.

### T47 — Xóa tài khoản đang đăng nhập (của người khác) [THỦ CÔNG]

**Các bước:**

1. Tài khoản adminA đang đăng nhập trên trình duyệt khác.
2. Kỹ thuật viên hệ thống xóa tài khoản adminA.

**Kết quả mong đợi:**

- Tài khoản adminA bị xóa.
- Session của adminA trên trình duyệt kia bị buộc thoát ngay.

### T48 — Sửa loại đầu mối [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A thử sửa loại đầu mối "Ban Tác huấn" từ sinh hoạt sang công cộng.

**Kết quả mong đợi:**

- Hệ thống không cho sửa. Trường loại đầu mối bị khóa. Phải xóa và tạo lại.

### T49 — Di chuyển đầu mối giữa khối và nhóm [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A chuyển đầu mối "Ban Tác huấn" từ nhóm "Ban Tác huấn" (trong khối "Phòng Tham mưu") sang trực tiếp thuộc Đơn vị A (không thuộc khối/nhóm nào).

**Kết quả mong đợi:**

- Đầu mối di chuyển thành công.
- Chỉ thay đổi hiển thị trên bảng tính tiền (không gộp dọc nữa).
- Tính toán không bị ảnh hưởng.

### T50 — Validation chỉ số công tơ [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A nhập chỉ số cuối kỳ CT-A1 = −5.

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: chỉ số công tơ phải ≥ 0.

### T51 — Validation đơn giá [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống nhập đơn giá = 0.

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: đơn giá phải > 0.

### T52 — Validation tỷ lệ phần trăm [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống nhập tỷ lệ tiết kiệm của Bộ = 105%.

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: tỷ lệ phần trăm phải ≥ 0 và ≤ 100.

### T53 — Validation phân bổ bơm nước: tổng phần trăm cố định > 100% [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống cấu hình phân bổ bơm nước: "Chỉ huy khu vực" nhận 80% cố định, thêm đối tượng mới nhận 30% cố định (tổng = 110%).

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: tổng phần trăm cố định không được vượt quá 100%.

### T54 — Validation phân bổ bơm nước: tổng phần trăm < 100% nhưng không có đối tượng hệ số [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống cấu hình phân bổ bơm nước: chỉ có "Chỉ huy khu vực" nhận 50% cố định, không có đối tượng nào nhận theo hệ số.

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: phải có ít nhất 1 đối tượng nhận theo hệ số khi tổng phần trăm cố định chưa đạt 100%.

### T55 — Validation phân bổ bơm nước: tất cả hệ số = 0 [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống cấu hình: "Chỉ huy khu vực" nhận 20% cố định, Đơn vị A hệ số = 0, Đơn vị B hệ số = 0, Thợ xây hệ số = 0.

**Kết quả mong đợi:**

- Hệ thống không cho lưu. Thông báo lỗi: tổng (quân số × hệ số) của các đối tượng theo hệ số phải > 0 để tránh chia cho 0.

### T56 — Phân bổ bơm nước: tổng phần trăm = 100% [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống cấu hình: "Chỉ huy khu vực" nhận 60% cố định, thêm đối tượng mới nhận 40% cố định (tổng = 100%). Đơn vị A có hệ số = 1.

**Kết quả mong đợi:**

- Hệ thống cho lưu. Toàn bộ điện bơm nước phân bổ theo phần trăm cố định.
- Đơn vị A không nhận bơm nước (phần theo hệ số = 0% vì tổng cố định đã = 100%).

### T57 — 2 tài khoản mặc định khi cài đặt [CẢ HAI]

**Điều kiện tiên quyết:** Hệ thống vừa cài đặt xong.

**Kết quả mong đợi:**

- Hệ thống có sẵn 2 tài khoản: kỹ thuật viên hệ thống và quản trị viên hệ thống.
- Cả 2 đều có mật khẩu mặc định (cần đổi sau khi đăng nhập lần đầu).

### T58 — Công tơ cuối kỳ nhỏ hơn đầu kỳ [CẢ HAI]

**Các bước:**

1. CT-A1 có đầu kỳ = 1.000. Quản trị viên đơn vị A nhập cuối kỳ = 500.

**Kết quả mong đợi:**

- Hệ thống cho nhập. Hiển thị trường ghi chú optional (ví dụ: "thay công tơ mới").
- Cho phép nhập thủ công số sử dụng thay vì tính tự động (cuối − đầu = âm).

### T59 — Xóa đầu mối có dữ liệu kỳ cũ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** "Kho vật tư" có dữ liệu kỳ tháng 5 (đã đóng).

**Các bước:**

1. Quản trị viên đơn vị A xóa đầu mối "Kho vật tư".

**Kết quả mong đợi:**

- Đầu mối bị xóa (soft delete). Công tơ CT-A3 cũng bị xóa theo.
- Dữ liệu kỳ tháng 5 giữ nguyên. Bảng tính tiền kỳ tháng 5 vẫn hiển thị "Kho vật tư".
- Kỳ hiện tại và sau: "Kho vật tư" không xuất hiện, CT-A3 không tham gia tính toán.
- Tính toán lại kỳ hiện tại: CT-A3 (không tổn hao, sử dụng 110) bị xóa → A = công tơ tổng (không trừ CT-A3 nữa), B không bao gồm CT-A3, tổn hao toàn khu vực thay đổi. Tổng quân số Đơn vị A giảm 3 → bơm nước per đầu mối thay đổi.

---

## 6. Phân quyền

### T60 — Quản trị viên hệ thống toàn quyền [CẢ HAI]

**Các bước:**

1. Đăng nhập quanTri.
2. Thử truy cập: tạo khu vực, tạo đơn vị, tạo đầu mối trong Đơn vị A, tạo đầu mối trong Đơn vị B, mở/đóng kỳ, cấu hình chung, phân bổ bơm nước, xem bảng tính tiền tất cả đơn vị.

**Kết quả mong đợi:**

- Tất cả thao tác đều thành công. Quản trị viên hệ thống quản lý tất cả, trên tất cả đơn vị và khu vực.

### T61 — Quản trị viên đơn vị chỉ quản lý đơn vị mình [CẢ HAI]

**Các bước:**

1. Đăng nhập adminB (quản trị viên Đơn vị B, không phải đơn vị quản lý khu vực).
2. Thử tạo đầu mối trong Đơn vị A.
3. Thử xem bảng tính tiền Đơn vị A.
4. Thử sửa cấu hình chung (đơn giá, tiết kiệm Bộ).
5. Thử mở/đóng kỳ.
6. Tạo đầu mối trong Đơn vị B.

**Kết quả mong đợi:**

- Bước 2, 3, 4, 5: bị chặn, không có quyền.
- Bước 6: thành công.

### T62 — Quản trị viên đơn vị quản lý khu vực [CẢ HAI]

**Các bước:**

1. Đăng nhập adminA (quản trị viên Đơn vị A, là đơn vị quản lý khu vực).
2. Nhập số sử dụng công tơ tổng khu vực.
3. Nhập chỉ số công tơ đầu mối sinh hoạt thuộc khu vực ("Chỉ huy khu vực").
4. Nhập chỉ số công tơ đầu mối công cộng thuộc khu vực ("Đèn đường").
5. Nhập chỉ số công tơ bơm nước ("Trạm bơm 1").
6. Cập nhật quân số đầu mối ngoài biên chế ("Thợ xây").
7. Thử sửa cấu hình phân bổ bơm nước.
8. Thử sửa đầu mối thuộc Đơn vị B.

**Kết quả mong đợi:**

- Bước 2-6: thành công (quyền ủy quyền nhập liệu khu vực).
- Bước 7: bị chặn (phân bổ bơm nước do quản trị viên hệ thống quản lý, không phải nhập liệu).
- Bước 8: bị chặn (không quản lý được đơn vị khác).

### T63 — Chỉ huy đơn vị chỉ xem [CẢ HAI]

**Các bước:**

1. Đăng nhập chiHuyA (chỉ huy Đơn vị A).
2. Xem bảng tính tiền Đơn vị A.
3. Xem tổng quan Đơn vị A.
4. Thử sửa chỉ số công tơ.
5. Thử tạo đầu mối.

**Kết quả mong đợi:**

- Bước 2, 3: thành công, xem được.
- Bước 4, 5: bị chặn, chỉ huy chỉ xem.

### T64 — Chỉ huy đơn vị quản lý khu vực xem đầu mối thuộc khu vực [CẢ HAI]

**Các bước:**

1. Đăng nhập chiHuyA (chỉ huy Đơn vị A, đơn vị quản lý khu vực).
2. Xem bảng tính tiền.

**Kết quả mong đợi:**

- Bảng tính tiền hiển thị đầu mối sinh hoạt Đơn vị A và đầu mối sinh hoạt thuộc khu vực ("Chỉ huy khu vực").

### T65 — Kỹ thuật viên không xem dữ liệu nghiệp vụ [CẢ HAI]

**Các bước:**

1. Đăng nhập kyThuat (kỹ thuật viên hệ thống).
2. Thử truy cập bảng tính tiền, tổng quan.
3. Truy cập quản lý tài khoản, nhật ký, sao lưu.

**Kết quả mong đợi:**

- Bước 2: bị chặn, không xem được dữ liệu nghiệp vụ.
- Bước 3: thành công.

### T66 — Quản trị viên hệ thống quản lý tài khoản — không quản lý kỹ thuật viên [TỰ ĐỘNG]

**Các bước:**

1. Đăng nhập quanTri.
2. Thử sửa hoặc xóa tài khoản kyThuat.

**Kết quả mong đợi:**

- Bị chặn. Quản trị viên hệ thống không quản lý được tài khoản kỹ thuật viên.

---

## 7. Nhập liệu hàng tháng

### T67 — Nhập chỉ số cuối kỳ công tơ [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5/2026 đang mở. Đầy đủ dữ liệu mẫu.

**Các bước:**

1. Quản trị viên đơn vị A nhập cuối kỳ CT-A1 = 1.250 (đầu kỳ = 1.000).

**Kết quả mong đợi:**

- Hệ thống tự tính sử dụng = 1.250 − 1.000 = 250.
- Hiển thị sử dụng = 250 trên giao diện.

### T68 — Nhập số sử dụng công tơ tổng [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị quản lý khu vực (adminA) nhập số sử dụng công tơ tổng = 2.100.

**Kết quả mong đợi:**

- Chỉ nhập 1 con số (không có đầu kỳ, cuối kỳ). Giá trị 2.100 được lưu thành công.

### T69 — Cập nhật quân số [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A sửa quân số "Ban Tác huấn": thêm 1 người "Hạ sĩ quan, binh sĩ" (từ 3 lên 4).

**Kết quả mong đợi:**

- Tổng quân số "Ban Tác huấn" = 6 (2 + 4).
- Tiêu chuẩn sinh hoạt tính lại: (2 × 110) + (4 × 24) = 316.
- Tiêu chuẩn bơm nước tính lại: 6 × 9,45 = 56,70.
- Tổng tiêu chuẩn thay đổi → các khoản trừ theo phần trăm (tiết kiệm Bộ, công cộng Sư đoàn, công cộng đơn vị) tính lại theo tổng tiêu chuẩn mới.
- Tổng quân số Đơn vị A tăng từ 10 lên 11 → bơm nước per đầu mối Đơn vị A chia lại (Văn thư, Kho vật tư cũng bị ảnh hưởng).
- Nếu cột Khác dạng hệ số: hệ thống tự tính lại = hệ số × quân số mới.

### T70 — Nhập liệu khi không có kỳ đang mở [CẢ HAI]

**Điều kiện tiên quyết:** Tất cả kỳ đã đóng.

**Các bước:**

1. Quản trị viên đơn vị A truy cập trang nhập liệu.

**Kết quả mong đợi:**

- Tất cả ô nhập bị disable.
- Hiển thị thông báo: "Không có kỳ đang mở. Vui lòng liên hệ quản trị viên hệ thống."

### T71 — Tính toán lần đầu và cache [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5 đang mở, đã nhập đầy đủ dữ liệu, chưa mở bảng tính tiền lần nào.

**Các bước:**

1. Mở bảng tính tiền.

**Kết quả mong đợi:**

- Hệ thống tính lần đầu, hiển thị kết quả (khớp T03).
- Kết quả được cache.

### T72 — Tính toán lại sau khi sửa dữ liệu [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A sửa cuối kỳ CT-A1 từ 1.250 thành 1.300.
2. Mở lại bảng tính tiền.

**Kết quả mong đợi:**

- Bảng tính tiền vẫn hiển thị kết quả cache cũ (sử dụng = 250).
- Bấm "Tính toán lại" → hệ thống tính lại với sử dụng = 300. Kết quả thay đổi.

### T73 — Cảnh báo thiếu dữ liệu [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5 đang mở. Đơn vị B chưa nhập chỉ số công tơ. Công tơ tổng chưa nhập.

**Các bước:**

1. Quản trị viên hệ thống mở bảng tính tiền.

**Kết quả mong đợi:**

- Hiển thị cảnh báo: "Đơn vị B chưa nhập chỉ số công tơ", "Khu vực 1 chưa nhập số sử dụng công tơ tổng".
- Hệ thống vẫn tính toán với dữ liệu hiện có (Đơn vị A đã nhập), hiển thị kết quả kèm cảnh báo rõ ràng rằng kết quả chưa đầy đủ.

### T74 — Xung đột nhập liệu đồng thời [THỦ CÔNG]

**Các bước:**

1. adminA đăng nhập trên trình duyệt 1, mở trang nhập liệu Đơn vị A.
2. quanTri đăng nhập trên trình duyệt 2, mở trang nhập liệu Đơn vị A.
3. adminA nhập cuối kỳ CT-A1 = 1.250, lưu.
4. quanTri nhập cuối kỳ CT-A1 = 1.300, lưu.

**Kết quả mong đợi:**

- Bước 3: adminA lưu thành công (lock_version tăng).
- Bước 4: quanTri nhận cảnh báo "Dữ liệu đã bị thay đổi bởi người khác." Hệ thống hiển thị dữ liệu mới nhất (cuối kỳ CT-A1 = 1.250 do adminA vừa lưu). quanTri xem lại rồi quyết định lưu lại hay không.

---

## 8. Bảng tính tiền

### T75 — Hiển thị đúng cấu trúc khối và nhóm [THỦ CÔNG]

**Điều kiện tiên quyết:** Dữ liệu mẫu đầy đủ.

**Các bước:**

1. Quản trị viên đơn vị A xem bảng tính tiền Đơn vị A.

**Kết quả mong đợi:**

- Bảng hiển thị theo cấu trúc:
  - Khối "Phòng Tham mưu" (ô merge dọc):
    - Nhóm "Ban Tác huấn" (ô merge dọc): dòng "Ban Tác huấn"
    - Đầu mối trực tiếp trong khối: dòng "Văn thư"
  - Đầu mối trực tiếp thuộc đơn vị: dòng "Kho vật tư"
- Hàng tổng ở cuối bảng.
- Đơn giá hiển thị ở đầu bảng: 2.336,4 đồng/kW.

### T76 — Bảng tính tiền đơn vị quản lý khu vực bao gồm đầu mối khu vực [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A (đơn vị quản lý khu vực) xem bảng tính tiền.

**Kết quả mong đợi:**

- Bảng hiển thị đầu mối Đơn vị A và đầu mối sinh hoạt thuộc khu vực ("Chỉ huy khu vực").
- Không hiển thị đầu mối Đơn vị B.

### T77 — Bảng gộp tất cả đơn vị [CẢ HAI]

**Các bước:**

1. Quản trị viên hệ thống xem bảng gộp tất cả đơn vị.

**Kết quả mong đợi:**

- Bảng nối tất cả đơn vị thành 1 bảng lớn, vẫn hiển thị từng đầu mối.
- Bao gồm cả đầu mối sinh hoạt thuộc khu vực.
- Có hàng tổng cuối bảng.

### T78 — Số liệu hiển thị đúng quy tắc phân cách và làm tròn [THỦ CÔNG]

**Kết quả mong đợi:**

- kW: 2 chữ số thập phân (ví dụ: 37,24).
- Tiền: 0 chữ số thập phân (ví dụ: 87.004).
- Phân cách tiếng Việt: dấu chấm hàng nghìn, dấu phẩy thập phân (ví dụ: 1.644,00 kW; 249.659 đồng).
- Đầu mối thừa: hiển thị ở cột thừa, cột thiếu để trống.
- Đầu mối thiếu: hiển thị ở cột thiếu, cột thừa để trống.

### T79 — Thông báo khi đăng nhập có kỳ mới [THỦ CÔNG]

**Điều kiện tiên quyết:** Quản trị viên hệ thống vừa mở kỳ tháng 6.

**Các bước:**

1. Quản trị viên đơn vị A đăng nhập.

**Kết quả mong đợi:**

- Hiển thị thông báo: "Kỳ tháng 6/2026 đã mở, vui lòng nhập liệu."

---

## 9. Tổng quan

### T80 — Tổng quan hệ thống [CẢ HAI]

**Điều kiện tiên quyết:** Dữ liệu mẫu đầy đủ, kỳ tháng 5/2026 đã tính toán.

**Các bước:**

1. Quản trị viên hệ thống xem trang tổng quan.

**Kết quả mong đợi:**

- Tổng thâm điện theo từng đơn vị (chỉ cộng phần thiếu, không trừ thừa — vì mục đích là xem tổng tiền phải thu). Thành tiền phải thu theo từng đơn vị. Sắp xếp theo thứ tự thâm điện từ nhiều đến ít.
- Tổng sử dụng điện công cộng toàn khu vực (Nhà ăn 220 + Trạm gác 50 + Đèn đường 130 = 400 kW sử dụng thô).
- Tổng sử dụng điện bơm nước toàn khu vực (300 kW sử dụng thô).
- Trạng thái nhập liệu từng đơn vị: "đã nhập" hoặc "chưa nhập".
- Cảnh báo nếu có dữ liệu thiếu.

### T81 — Tổng quan đơn vị [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A xem trang tổng quan.

**Kết quả mong đợi:**

- Tổng thâm điện Đơn vị A (kW), tổng thành tiền phải thu.
- Số đầu mối thiếu, số đầu mối thừa. Vì Đơn vị A là đơn vị quản lý khu vực, tổng quan bao gồm cả đầu mối khu vực (nhất quán với bảng tính tiền T76): Ban Tác huấn thiếu, Chỉ huy khu vực thiếu, Văn thư thừa, Kho vật tư thừa → 2 thiếu, 2 thừa.
- Trạng thái nhập liệu kỳ hiện tại.

### T82 — Cảnh báo tổn hao bất thường trên tổng quan [CẢ HAI]

**Điều kiện tiên quyết:** Dữ liệu mẫu nhưng sửa công tơ tổng = 1.900 (A = 1.900 − 110 = 1.790, C = 1.790 − 1.930 = −140, tổn hao âm).

**Kết quả mong đợi:**

- Trang tổng quan hiển thị cảnh báo: "Tổn hao khu vực 1 bất thường (âm). Tổng công tơ con lớn hơn công tơ tổng."

---

## 10. Tra cứu lịch sử và so sánh

### T83 — Xem bảng tính tiền kỳ cũ [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng, kỳ tháng 6 đang mở.

**Các bước:**

1. Quản trị viên đơn vị A chọn xem bảng tính tiền kỳ tháng 5.

**Kết quả mong đợi:**

- Bảng tính tiền kỳ tháng 5 hiển thị đúng dữ liệu đã lưu (snapshot kỳ 5), không bị ảnh hưởng bởi dữ liệu kỳ 6.

### T84 — So sánh 2 kỳ [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 5 và kỳ tháng 6 đều đã tính toán.

**Các bước:**

1. Quản trị viên hệ thống chọn so sánh kỳ tháng 5 và kỳ tháng 6.

**Kết quả mong đợi:**

- Hiển thị cạnh nhau: mỗi đầu mối có 2 cột số liệu (kỳ 5, kỳ 6) và cột chênh lệch.
- Nếu quân số "Ban Tác huấn" thay đổi giữa 2 kỳ: cột chênh lệch phản ánh sự khác biệt.

### T85 — So sánh 2 kỳ — đầu mối chỉ có ở 1 kỳ [CẢ HAI]

**Điều kiện tiên quyết:** Kỳ tháng 6 có thêm đầu mối "Lái xe" (T15). Kỳ tháng 5 không có "Lái xe".

**Các bước:**

1. Quản trị viên hệ thống so sánh kỳ tháng 5 và kỳ tháng 6.

**Kết quả mong đợi:**

- Dòng "Lái xe": cột kỳ 5 để trống, cột kỳ 6 có số liệu, cột chênh lệch để trống, kèm ghi chú "mới ở kỳ 6".
- Nếu đầu mối bị xóa ở kỳ 6: cột kỳ 6 để trống, ghi chú "chỉ có ở kỳ 5".

### T86 — Xem tổng quan theo khoảng thời gian [THỦ CÔNG]

**Các bước:**

1. Quản trị viên hệ thống chọn xem tổng quan quý 2/2026 (tháng 4-6).

**Kết quả mong đợi:**

- Dữ liệu hiển thị theo các kỳ tương ứng (tháng 4, 5, 6 nếu đã có dữ liệu).

### T87 — Quyền xem lịch sử theo vai trò [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên đơn vị A xem lịch sử Đơn vị B.
2. Chỉ huy đơn vị A xem lịch sử Đơn vị B.
3. Quản trị viên hệ thống xem lịch sử Đơn vị B.

**Kết quả mong đợi:**

- Bước 1, 2: bị chặn, không có quyền.
- Bước 3: thành công.

---

## 11. Xuất Excel

### T88 — Xuất bảng tính tiền ra Excel [THỦ CÔNG]

**Các bước:**

1. Quản trị viên đơn vị A bấm "Xuất Excel" trên bảng tính tiền kỳ tháng 5.
2. Mở file Excel đã tải.

**Kết quả mong đợi:**

- File Excel giống hệt hiển thị trên hệ thống: cùng cấu trúc, cùng dữ liệu, cùng định dạng số.
- File Excel có công thức tính toán, không chỉ giá trị tĩnh. Ví dụ:
  - Ô tổng tiêu chuẩn chứa công thức = tiêu chuẩn sinh hoạt + tiêu chuẩn bơm nước.
  - Ô thành tiền chứa công thức = thâm điện × đơn giá.
  - Ô hàng tổng chứa công thức SUM.
- Sửa 1 giá trị quân số trong Excel → các công thức tính lại tự động.

### T89 — Excel phân cách số tiếng Việt [THỦ CÔNG]

**Kết quả mong đợi:**

- File Excel sử dụng phân cách số tiếng Việt: dấu chấm hàng nghìn, dấu phẩy thập phân.

---

## 12. Xác thực và bảo mật

### T90 — Session tự thoát sau 2 giờ không hoạt động [THỦ CÔNG]

**Các bước:**

1. Đăng nhập, không thao tác gì trong 2 giờ.

**Kết quả mong đợi:**

- Hệ thống tự thoát, chuyển về trang đăng nhập.

### T91 — Đăng nhập nhiều thiết bị cùng lúc [THỦ CÔNG]

**Các bước:**

1. Đăng nhập tài khoản adminA trên trình duyệt 1.
2. Đăng nhập tài khoản adminA trên trình duyệt 2.

**Kết quả mong đợi:**

- Cả 2 phiên đều hoạt động bình thường. Hệ thống cho phép đăng nhập nhiều thiết bị cùng lúc.

### T92 — Đổi mật khẩu [CẢ HAI]

**Các bước:**

1. Đăng nhập adminA.
2. Vào trang đổi mật khẩu, nhập mật khẩu cũ đúng, nhập mật khẩu mới.

**Kết quả mong đợi:**

- Đổi mật khẩu thành công. Đăng nhập lại bằng mật khẩu mới.

### T93 — Reset mật khẩu bởi kỹ thuật viên hoặc quản trị viên hệ thống [CẢ HAI]

**Các bước:**

1. Kỹ thuật viên hệ thống reset mật khẩu tài khoản adminA.

**Kết quả mong đợi:**

- Mật khẩu adminA được reset. adminA đăng nhập bằng mật khẩu mới do kỹ thuật viên cấp.
- Không có tính năng quên mật khẩu qua email (hệ thống offline).

---

## 13. Nhật ký hệ thống

### T94 — Ghi nhật ký mọi thao tác [CẢ HAI]

**Các bước:**

1. Quản trị viên đơn vị A tạo đầu mối mới.
2. Quản trị viên đơn vị A nhập chỉ số công tơ.
3. Quản trị viên hệ thống mở kỳ.
4. Quản trị viên hệ thống xem nhật ký.

**Kết quả mong đợi:**

- Nhật ký ghi lại tất cả thao tác: ai, làm gì, khi nào.

### T95 — Quyền xem nhật ký [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống xem nhật ký.
2. Kỹ thuật viên hệ thống xem nhật ký.
3. Quản trị viên đơn vị A xem nhật ký.

**Kết quả mong đợi:**

- Bước 1, 2: thành công.
- Bước 3: bị chặn, quản trị viên đơn vị không có quyền xem nhật ký.

---

## 14. Sao lưu và phục hồi

### T96 — Tạo backup [CẢ HAI]

**Các bước:**

1. Kỹ thuật viên hệ thống tạo backup.

**Kết quả mong đợi:**

- Backup toàn bộ data được tạo thành công.

### T97 — Tối đa 3 bản backup [TỰ ĐỘNG]

**Các bước:**

1. Kỹ thuật viên tạo 3 bản backup.
2. Kỹ thuật viên tạo bản backup thứ 4.

**Kết quả mong đợi:**

- Bước 2: hệ thống không cho tạo, hoặc yêu cầu xóa bản cũ trước. Tối đa 3 bản backup.

### T98 — Restore từ backup [THỦ CÔNG]

**Các bước:**

1. Kỹ thuật viên tạo backup tại thời điểm T1.
2. Quản trị viên hệ thống nhập liệu thêm.
3. Kỹ thuật viên restore hệ thống về bản backup T1.

**Kết quả mong đợi:**

- Hệ thống trở về trạng thái tại T1. Dữ liệu nhập sau T1 bị mất.

### T99 — Quyền backup/restore [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống thử tạo backup.

**Kết quả mong đợi:**

- Bị chặn. Chỉ kỹ thuật viên hệ thống mới có quyền backup/restore.

---

## 15. Giao diện chung

### T100 — Việt hóa 100% [THỦ CÔNG]

**Các bước:**

1. Duyệt qua tất cả trang trong hệ thống.

**Kết quả mong đợi:**

- Tất cả giao diện, thông báo, cảnh báo, nút bấm, nhãn, xuất file đều bằng tiếng Việt. Không có tiếng Anh nào.

### T101 — Trang danh sách đầy đủ tính năng [THỦ CÔNG]

**Các bước:**

1. Mở trang danh sách đầu mối.

**Kết quả mong đợi:**

- Có tìm kiếm, sắp xếp, lọc, phân trang, hiển thị tổng số bản ghi, chọn số dòng mỗi trang.

### T102 — Hover highlight dòng [THỦ CÔNG]

**Các bước:**

1. Di chuột qua 1 dòng trên bảng tính tiền.

**Kết quả mong đợi:**

- Dòng được highlight.

### T103 — Hàng tổng cuối bảng [THỦ CÔNG]

**Kết quả mong đợi:**

- Tất cả trang có danh sách số liệu (bảng tính tiền, tổng quan, so sánh) đều có hàng tổng ở cuối.

---

## 16. Edge cases

### T104 — Tổn hao âm (C < 0) [TỰ ĐỘNG]

**Các bước:**

1. Nhập công tơ tổng = 1.900 (nhỏ hơn tổng sử dụng 1.930 + 110 = 2.040).
2. Tính toán.

**Kết quả mong đợi:**

- A = 1.900 − 110 = 1.790, C = 1.790 − 1.930 = −140. Hệ thống clamp tổn hao về 0.
- Hiển thị cảnh báo trên bảng tính tiền và trang tổng quan: "Tổn hao khu vực bất thường (âm). Tổng công tơ con lớn hơn công tơ tổng."
- Tất cả đầu mối có tổn hao = 0.

### T105 — Tất cả công tơ đều không tổn hao (B = 0) [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Sửa tất cả công tơ trong khu vực thành "không tổn hao".

**Kết quả mong đợi:**

- B = 0, không chia tổn hao được.
- Hệ thống clamp tổn hao về 0 và hiển thị cảnh báo.

### T106 — Không có trạm bơm trong khu vực [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Xóa đầu mối bơm nước "Trạm bơm 1".

**Kết quả mong đợi:**

- Bơm nước = 0 cho tất cả đối tượng.
- Bỏ qua phân bổ bơm nước.
- Sử dụng điện bơm nước = 0 cho tất cả đầu mối sinh hoạt.
- Tính toán vẫn hoạt động bình thường (chỉ không có phần bơm nước).

### T107 — Tiêu chuẩn còn lại ra âm [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Sửa tỷ lệ tiết kiệm Bộ = 50%, công cộng Sư đoàn = 40% (tổng trừ rất lớn, tiêu chuẩn còn lại chắc chắn âm).

**Kết quả mong đợi:**

- Hệ thống tính bình thường. Tiêu chuẩn còn lại = âm.
- Tất cả đầu mối chắc chắn thiếu (tổng sử dụng > tiêu chuẩn còn lại vì tiêu chuẩn còn lại âm).

### T108 — Tỷ lệ tiết kiệm, công cộng = 0% [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống sửa tiết kiệm Bộ = 0%, công cộng Sư đoàn = 0%.

**Kết quả mong đợi:**

- Cho phép. Khoản trừ tiết kiệm = 0, khoản trừ công cộng Sư đoàn = 0.
- Tính toán vẫn hoạt động bình thường.

### T109 — Khu vực chưa có đầu mối nào [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Tạo khu vực mới, chỉ có đơn vị, chưa có đầu mối.

**Kết quả mong đợi:**

- Hiển thị cảnh báo "Khu vực chưa có đầu mối".
- Không tính tổn hao (B = 0).

### T110 — Đầu mối có nhiều công tơ [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Thêm công tơ "CT-A1b" (có tổn hao) cho đầu mối "Ban Tác huấn" (đã có CT-A1). Kỳ đang mở.

**Các bước:**

1. Nhập chỉ số CT-A1: đầu kỳ 1.000, cuối kỳ 1.250 (sử dụng 250).
2. Nhập chỉ số CT-A1b: đầu kỳ 0, cuối kỳ 100 (sử dụng 100).
3. Tính toán.

**Kết quả mong đợi:**

- Sử dụng sinh hoạt "Ban Tác huấn" = 250 + 100 = 350 (tổng sử dụng các công tơ).
- Tổn hao "Ban Tác huấn" = tổn hao CT-A1 + tổn hao CT-A1b (mỗi công tơ tính tổn hao riêng rồi cộng lại thành tổn hao đầu mối).
- B bao gồm cả CT-A1 và CT-A1b.

### T111 — Công tơ sử dụng = 0 (đầu kỳ = cuối kỳ) [TỰ ĐỘNG]

**Các bước:**

1. Nhập chỉ số CT-A1: đầu kỳ = 1.000, cuối kỳ = 1.000 (sử dụng = 0).
2. Tính toán.

**Kết quả mong đợi:**

- Sử dụng sinh hoạt "Ban Tác huấn" = 0.
- Tổn hao CT-A1 = 0 (sử dụng = 0 → tổn hao = 0 × C ÷ B = 0).
- "Ban Tác huấn" chắc chắn thừa (sử dụng = 0 + bơm nước, tiêu chuẩn còn lại > 0 trong điều kiện bình thường).

### T112 — Hệ số bơm nước = 0 cho 1 đối tượng riêng lẻ [TỰ ĐỘNG]

**Các bước:**

1. Quản trị viên hệ thống cấu hình: "Chỉ huy khu vực" nhận 20% cố định, Đơn vị A hệ số = 0, Đơn vị B hệ số = 1, Thợ xây hệ số = 0,5.
2. Tính toán.

**Kết quả mong đợi:**

- Hệ thống cho lưu (hệ số = 0 riêng lẻ hợp lệ, tổng quân số × hệ số > 0 vì Đơn vị B và Thợ xây vẫn > 0).
- Đơn vị A nhận 0 kW bơm nước (hệ số = 0 → trọng số = 0).
- Tất cả đầu mối sinh hoạt Đơn vị A: sử dụng bơm nước = 0.
- Đơn vị B và Thợ xây chia hết phần còn lại.

### T113 — Kế thừa cột Khác dạng hệ số tự tính lại theo quân số mới [TỰ ĐỘNG]

**Điều kiện tiên quyết:** Kỳ tháng 5 đã đóng. "Đại đội 1" có cột Khác dạng hệ số = 3, quân số = 11 → Khác kỳ 5 = 3 × 11 = 33.

**Các bước:**

1. Quản trị viên hệ thống mở kỳ tháng 6.
2. Quản trị viên đơn vị B sửa quân số "Đại đội 1" từ 11 thành 15.
3. Tính toán kỳ tháng 6.

**Kết quả mong đợi:**

- Kỳ tháng 6: cột Khác "Đại đội 1" kế thừa dạng hệ số = 3 từ kỳ 5. Hệ thống tự tính lại = 3 × 15 = 45 (theo quân số mới).
- Kỳ tháng 5: Khác "Đại đội 1" vẫn = 33 (3 × 11). Không bị ảnh hưởng.

---

## 17. Ghi chú cho automation test

### 17.1. Test case phù hợp automation (RSpec)

Các test case đánh dấu [TỰ ĐỘNG] và [CẢ HAI] phù hợp viết RSpec. Ưu tiên automation theo thứ tự:

1. **Engine tính toán (T01-T04):** service spec, verify số liệu chính xác đến decimal. Đây là lõi hệ thống, sai ở đây là sai toàn bộ.
2. **Cách ly kỳ (T05-T18):** model/service spec, verify snapshot independence. Đây là yếu tố quan trọng nhất — mỗi test case tạo 2 kỳ, sửa kỳ mới, assert kỳ cũ không đổi.
3. **Kỳ tính toán (T19-T26):** model/controller spec, verify mở/đóng/kế thừa.
4. **Validation (T28, T34-T35, T37-T40, T44-T46, T48, T50-T55):** model spec, verify ràng buộc dữ liệu.
5. **Phân quyền (T60-T66):** request spec hoặc controller spec, verify CanCanCan abilities.
6. **Edge cases (T104-T113):** service spec, verify các trường hợp biên.

### 17.2. Test case chỉ thủ công

Các test case đánh dấu [THỦ CÔNG] không phù hợp hoặc rất khó automation:

- Giao diện: hover highlight (T102), merge dọc khối/nhóm (T75), phân cách số (T78, T89), Việt hóa (T100).
- Xuất Excel: mở file kiểm tra công thức (T88).
- Session timeout 2 giờ (T90).
- Xung đột đồng thời — 2 trình duyệt (T74, T91).
- Restore backup (T98).
- Tổng quan theo khoảng thời gian (T86).

### 17.3. Bổ sung cho RSpec ngoài kịch bản thủ công

Kịch bản test này tập trung vào test thủ công end-to-end. RSpec cần bổ sung thêm các unit test không cover trực tiếp trong kịch bản:

- **Model validations:** tất cả trường trong bảng 24 nghiệp vụ (kiểu dữ liệu, giới hạn, uniqueness scoped).
- **Association integrity:** foreign key, dependent destroy/nullify.
- **Service edge cases:** input rỗng, input cực lớn, chia cho 0 nội bộ.
- **Controller authorization:** verify từng action × từng role (matrix test).
- **Period guard:** verify mọi controller action bị chặn khi không có kỳ mở (trừ CRUD danh mục).
- **Kế thừa kỳ:** verify từng field kế thừa đúng giá trị (bảng mục 25 nghiệp vụ).
- **Calculation precision:** verify Decimal precision, không dùng float, kết quả khớp Python output. Quy tắc làm tròn khi hiển thị: ROUND_HALF_UP (5 → làm tròn lên), không dùng ROUND_HALF_EVEN (banker's rounding). Ví dụ: 33,925 → hiển thị 33,93 (không phải 33,92).

---

## 18. Lịch sử thay đổi

### v1.2.0 (18/05/2026)

- T41: bổ sung điều kiện tiên quyết "Đơn vị A không có tài khoản (đã xóa adminA, chiHuyA để test)" — nhất quán với validation "xóa đơn vị đang có tài khoản" (nghiệp vụ mục 23).

### v1.1.0 (18/05/2026)

- Phiên bản đầu tiên.
