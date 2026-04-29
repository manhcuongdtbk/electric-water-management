# 13. Quy tắc nghiệp vụ / Business Rules — v1.0.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì, phục vụ ai. Tra thuật ngữ tại 02_GLOSSARY.
>
> **Mục đích file này:** Ghi lại **toàn bộ nghiệp vụ đã xác nhận** — tức các quy tắc tính toán, công thức, điều kiện, edge case mà phần mềm phải tuân thủ. Mỗi mục đều ghi rõ nguồn xác nhận.
>
> **Trạng thái:** Toàn bộ nghiệp vụ tính toán đã được khách hàng xác nhận. Không còn mục chờ xác nhận về mặt nghiệp vụ.
>
> **Quy ước trích dẫn nguồn:** `[Nguồn: tên file hoặc kênh, ngày]` — không rút gọn, không đổi tên file gốc.

---

## Mục lục

1. [Cấu trúc tổ chức](#1-cấu-trúc-tổ-chức)
2. [Phân quyền theo vai trò](#2-phân-quyền-theo-vai-trò)
3. [Bảng định mức 7 nhóm cấp bậc](#3-bảng-định-mức-7-nhóm-cấp-bậc)
4. [Bảng 24 cột — cấu trúc và công thức](#4-bảng-24-cột--cấu-trúc-và-công-thức)
5. [4 khoản trừ](#5-4-khoản-trừ)
6. [Tổn hao — công thức và ví dụ số thật](#6-tổn-hao--công-thức-và-ví-dụ-số-thật)
7. [Bơm nước — 2 khái niệm và phân bổ](#7-bơm-nước--2-khái-niệm-và-phân-bổ)
8. [Kế thừa tháng và khoá dữ liệu](#8-kế-thừa-tháng-và-khoá-dữ-liệu)
9. [Edge cases](#9-edge-cases)
10. [Ví dụ tính toán end-to-end từ data tháng 02/2026](#10-ví-dụ-tính-toán-end-to-end-từ-data-tháng-022026)
11. [Lịch sử xác nhận nghiệp vụ](#11-lịch-sử-xác-nhận-nghiệp-vụ)

---

## 1. Cấu trúc tổ chức

Hệ thống quản lý điện nước của một Sư đoàn quân đội Việt Nam (xem 02_GLOSSARY mục 1 cho thuật ngữ chi tiết).

**Mô hình 2 cấp:**

- **Cấp 1 — Sư đoàn:** 1 đơn vị duy nhất, quản lý toàn hệ thống. Đại diện bởi Ban Doanh trại.
- **Cấp 2 — Đơn vị trực thuộc:** 13 đơn vị: Sư đoàn bộ, 3 Trung đoàn (101, 18, 95), 7 Tiểu đoàn (14, 15, 16, 17, 18, 24, 25), 2 Đại đội (26, 29). Có thể thêm đơn vị cấp 2 mới.

**Bên trong mỗi đơn vị cấp 2:**

- N đầu mối (xem 02_GLOSSARY mục 1), mỗi đầu mối có quân số riêng (chia theo 7 nhóm cấp bậc) và ít nhất 1 công tơ.
- Sư đoàn bộ có 79 đầu mối (data tháng 02/2026, đã tăng từ 46 ban đầu — do tách đầu mối thành công tơ chi tiết hơn).
- Đầu mối thêm bớt linh động do thay đổi tổ chức.

`[Nguồn: y_kien_cua_325.docx, mục "Sơ đồ phân cấp" + Zalo 06/04/2026]`

---

## 2. Phân quyền theo vai trò

4 vai trò (xem 02_GLOSSARY mục 7 cho chi tiết từng vai trò):

| Vai trò | Phạm vi | Quyền chính |
|---|---|---|
| Quản trị viên cấp 1 (`admin_level1`) | Toàn Sư đoàn | Cấu hình đơn giá, tỷ lệ tiết kiệm, tỷ lệ công cộng Sư đoàn, định mức cấp bậc. Xem dữ liệu tất cả đơn vị. Mở khoá kỳ cũ. |
| Quản trị viên đơn vị (`admin_unit`) | 1 đơn vị cấp 2 | Khai báo đầu mối, công tơ, quân số. Nhập liệu hàng tháng. Cấu hình tỷ lệ công cộng đơn vị, cột "Khác". Chỉ thấy data đơn vị mình. |
| Chỉ huy đơn vị (`commander`) | 1 đơn vị cấp 2 | Chỉ xem, không thao tác. Kiểm tra số liệu do quản trị viên đơn vị nhập. Chỉ thấy data đơn vị mình. |
| Kỹ thuật (`tech`) | Toàn Sư đoàn | Quản lý tài khoản, nhật ký hoạt động, sao lưu & phục hồi. Không truy cập dữ liệu nghiệp vụ. |

**Quy tắc phân quyền cấu hình:**

- Tiết kiệm của Bộ: do cấp 1 quy định, áp dụng chung tất cả đơn vị.
- Công cộng dùng chung Sư đoàn: do cấp 1 quy định, áp dụng chung tất cả đơn vị.
- Công cộng dùng chung đơn vị: do quản trị viên đơn vị tự cấu hình, tỷ lệ riêng cho đơn vị mình.
- Cột "Khác": do quản trị viên đơn vị cấu hình theo từng đầu mối.

`[Nguồn: y_kien_cua_325.docx, "Câu hỏi 1" + Zalo 06/04/2026, câu hỏi 1]`

---

## 3. Bảng định mức 7 nhóm cấp bậc

Mỗi nhóm cấp bậc có định mức điện (kW/tháng/người) theo Nghị định 02 của Bộ Quốc phòng.

| Nhóm | Tên đầy đủ | `rank_field` | Định mức (kW/tháng) |
|---|---|---|---|
| 1 | Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá | `rank1_count` | 570 |
| 2 | Chỉ huy Trung đoàn; SQ có trần quân hàm là Thượng tá | `rank2_count` | 440 |
| 3 | Chỉ huy tiểu đoàn; SQ có trần quân hàm là Trung tá, Thiếu tá | `rank3_count` | 305 |
| 4 | Chỉ huy đại đội, trung đội; SQ có trần quân hàm là cấp Úy | `rank4_count` | 130 |
| 5 | Cơ quan sư đoàn, trung đoàn | `rank5_count` | 210 |
| 6 | Tiểu đoàn, đại đội | `rank6_count` | 110 |
| 7 | Hạ sĩ quan, binh sĩ | `rank7_count` | 24 |

**Lưu ý quan trọng:**

- Tên nhóm cấp bậc lưu trong database (`RankQuota.rank_name`), không hardcode trong i18n. Quản trị viên cấp 1 có thể sửa tên và định mức qua F21 khi có nghị định mới.
- "SQ" = Sĩ quan. Viết tắt duy nhất được chấp nhận (xem 02_GLOSSARY mục 13).
- Tên nhóm theo bảng mẫu cập nhật do khách gửi, không phải theo tên nghị định gốc (dài hơn).
- Data tháng 02/2026 dùng bảng định mức **cũ** (ví dụ nhóm 3/4 = 115 kW, bơm nước 6,3 kW). Bảng trên là định mức **hiện hành** (áp dụng từ tháng 03/2026).

`[Nguồn: bảng mẫu cập nhật MẪU THEO DÕI SỬ DỤNG ĐIỆN, Zalo 21/04/2026 + Zalo 06/04/2026, ảnh bảng mẫu mới]`

---

## 4. Bảng 24 cột — cấu trúc và công thức

Bảng tổng hợp 24 cột là bảng tính toán chính của hệ thống. Gốc là 22 cột theo mẫu Excel khách cung cấp, đã tách thành 24 cột (PR#62): cột "Chênh lệch" tách thành "Thừa" + "Thiếu", cột "Thành tiền" cũng tách thành "Thừa" + "Thiếu". Xem 02_GLOSSARY mục 3.2 cho danh sách đầy đủ 24 cột.

### 4.1 Tóm tắt công thức từng cột

| Cột | Tên | Công thức / Nguồn |
|---|---|---|
| 1 | TT | Tự động đánh số thứ tự |
| 2 | Đơn vị | Tên đầu mối, từ `ContactPoint.name` |
| 3 | Tổng quân số | = Σ(quân số 7 nhóm) |
| 4 | (phân cách) | Cột trống giữ layout khớp mẫu giấy |
| 5–11 | 7 nhóm cấp bậc | Từ `Personnel.rank1_count` ... `rank7_count` |
| 12 | Điện bơm nước (tiêu chuẩn) | = tổng quân số × 9,45 kW |
| 13 | Quân số | = cột 3 (lặp lại theo layout mẫu gốc) |
| 14 | Cộng được hưởng theo NĐ 02 | = Σ(số người nhóm i × định mức nhóm i) + cột 12 |
| 15 | Tiết kiệm của Bộ | = cột 14 × tỷ lệ tiết kiệm (5–10%) |
| 16 | Tổn hao | Phân bổ tổn hao cho đầu mối (xem mục 6) |
| 17 | Công cộng | = cột 14 × (tỷ lệ công cộng Sư đoàn + tỷ lệ công cộng đơn vị) |
| 18 | Khác + Cộng | Nhập số cụ thể hoặc hệ số × số người. **Cho phép giá trị âm** (xem mục 9) |
| 19 | Tiêu chuẩn còn lại | = cột 14 − cột 15 − cột 16 − cột 17 − cột 18 |
| 20 | Sử dụng (kW) | = sử dụng công tơ + bơm nước thực tế. **Không** cộng tổn hao |
| 21 | Thừa (kW) | = max(cột 19 − cột 20, 0). Chỉ dương hoặc 0 |
| 22 | Thiếu (kW) | = max(cột 20 − cột 19, 0). Chỉ dương hoặc 0 |
| 23 | Thừa (đồng) | = cột 21 × đơn giá |
| 24 | Thiếu (đồng) | = cột 22 × đơn giá |

### 4.2 Quy tắc dòng tổng

- Tổng Thừa = Σ(tất cả Thừa của các đầu mối). Tổng Thiếu = Σ(tất cả Thiếu của các đầu mối).
- **Không bù trừ:** tổng Thừa và tổng Thiếu tính riêng biệt, không lấy hiệu.

### 4.3 Lịch sử tách cột

Mẫu Excel gốc có 22 cột với: cột "Chênh lệch" (= tiêu chuẩn còn lại − sử dụng, giá trị có thể dương hoặc âm) và cột "Thành tiền" (= chênh lệch × đơn giá). Phần mềm tách thành 4 cột (21–24) để tránh nhầm lẫn khi đọc số âm/dương, và để dòng tổng không bù trừ.

`[Nguồn: MẪU THEO DÕI SỬ DỤNG ĐIỆN F BỘ.xls + bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx + Zalo 21/04/2026 (xác nhận gộp bảng sử dụng)]`

---

## 5. 4 khoản trừ

4 khoản trừ nằm ở cột 15–18, gom chung gọi là "Số phải trừ". Trừ khỏi tiêu chuẩn **trước** khi so sánh với sử dụng thực tế. Xem 02_GLOSSARY mục 4 cho chi tiết từng khoản.

### 5.1 Tiết kiệm của Bộ (cột 15)

- **Công thức:** = cột 14 × tỷ lệ tiết kiệm
- **Tỷ lệ:** 5–10%, thay đổi theo năm. Data tháng 02/2026: 5%.
- **Ai cấu hình:** quản trị viên cấp 1, áp dụng chung tất cả đơn vị.
- **Ví dụ:** tiêu chuẩn 121,3 kW × 5% = 6,065 kW.

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", cột K "(3)=(1+2)*5%"]`

### 5.2 Tổn hao (cột 16)

Phần mềm tự tính hàng tháng. Không cần khai báo. Chi tiết xem mục 6.

**Điểm khác trực giác:** Tổn hao **trừ khỏi tiêu chuẩn** (nằm trong "Số phải trừ"), **không** cộng vào sử dụng. Nghĩa là tổn hao làm giảm lượng điện đầu mối được hưởng, chứ không tăng lượng điện tính là đã dùng.

`[Nguồn: Zalo 06/04/2026, câu hỏi 3]`

### 5.3 Công cộng (cột 17)

- **Công thức:** = cột 14 × (tỷ lệ công cộng Sư đoàn + tỷ lệ công cộng đơn vị)
- **Tỷ lệ công cộng Sư đoàn:** 5–10%, do cấp 1 cấu hình. Data tháng 02: 10% (gộp cả 2 cấp trong file Excel, nhưng phần mềm tách riêng).
- **Tỷ lệ công cộng đơn vị:** 10–20%, mỗi đơn vị tự cấu hình.
- **Nghiệp vụ:** khi thu mỗi người % công cộng, tiền đó dùng để trả cho các vị trí điện công cộng (hội trường, trường bắn, đèn đường...). Vì vậy công tơ "công cộng" (`public_use`) **không xuất hiện trong bản thu tiền**.

`[Nguồn: y_kien_cua_325.docx, "Câu hỏi 12" + Zalo 06/04/2026, câu hỏi 1]`

### 5.4 Khác + Cộng (cột 18)

- **Nhập liệu:** số kW cụ thể, hoặc hệ số × số người.
- **Cho phép giá trị âm** (xem mục 9.1).
- **Ví dụ dương:** Đầu mối X có khoản "Khác" = 30 kW → tiêu chuẩn còn lại giảm 30 kW (trừ như bình thường).
- **Ví dụ âm:** Đầu mối "Bảo đảm" có "Khác" = −296 kW → tiêu chuẩn còn lại **tăng** 296 kW (vì trừ số âm = cộng). Xem ví dụ chi tiết ở mục 10.

`[Nguồn: Zalo 21/04/2026 (xác nhận cột "Khác" âm) + bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", đầu mối "Bảo đảm"]`

---

## 6. Tổn hao — công thức và ví dụ số thật

### 6.1 Khái niệm

Tổn hao = điện thất thoát trên đường dây từ đồng hồ tổng (điện lực) đến các công tơ đầu mối. Phần mềm tự tính hàng tháng.

### 6.2 Công thức

```
Tổng tổn hao = Số điện lực (đồng hồ tổng) − Tổng kW tất cả công tơ

Tổn hao đầu mối X = Tổng tổn hao × (kW công tơ X ÷ Tổng kW các công tơ tham gia tính tổn hao)
```

**Quan trọng:** Công tơ "vị trí không tổn hao" (`no_loss`) bị loại khỏi **cả tử số** (kW đầu mối) **lẫn mẫu số** (tổng kW) khi phân bổ tổn hao, nhưng **vẫn trừ** khỏi số điện lực khi tính tổng tổn hao.

### 6.3 Ví dụ với data tháng 02/2026

Data thật từ file `bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx`, sheet "Sheet1":

- Số điện lực (đồng hồ tổng): **45.960 kW**
- Vị trí không tổn hao (Tiểu đoàn 18 — công tơ đặt tại trạm biến áp): **4.020 kW**
- Số sử dụng sau khi trừ vị trí không tổn hao (A): 45.960 − 4.020 = **41.940 kW**
- Tổng sử dụng các công tơ (B — không bao gồm trạm bơm, hội trường, công cộng... tất cả công tơ trong đơn vị): **40.188 kW**
- **Tổng tổn hao (C) = A − B = 41.940 − 40.188 = 1.752 kW**

Phân bổ tổn hao cho từng đầu mối:

- Công tơ TMP Trường sử dụng 99 kW. Tổn hao = 1.752 × (99 ÷ 40.188) ≈ **4,32 kW**.
- Công tơ Ban Quân lực (ĐH TB Q. Lực) sử dụng 109 kW. Tổn hao = 1.752 × (109 ÷ 40.188) ≈ **4,75 kW**.
- Tiểu đoàn 18 (công tơ `no_loss`): **0 kW tổn hao** — bị loại khỏi phép tính phân bổ.

Tổng kiểm tra: tổng tổn hao phân bổ cho tất cả công tơ (trừ no_loss) = 1.752 kW ✓

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1", rows 4–9 + rows 154–157]`

---

## 7. Bơm nước — 2 khái niệm và phân bổ

### 7.1 Phân biệt 2 khái niệm (xem 02_GLOSSARY mục 5)

| | Tiêu chuẩn bơm nước | Sử dụng bơm nước (thực tế) |
|---|---|---|
| **Giá trị** | 9,45 kW/người/tháng | Thay đổi hàng tháng |
| **Nguồn** | Cố định theo Nghị định 02 | Phân bổ từ trạm bơm thực tế |
| **Vị trí trong bảng** | Cột 12, cộng vào cột 14 | Cột 20, cộng vào tổng sử dụng |
| **Ý nghĩa** | Tăng tiêu chuẩn được hưởng | Tăng lượng điện đã dùng |

**Lịch sử thay đổi:** Trước tháng 03/2026, tiêu chuẩn bơm nước là 6,3 kW/người (nghị định cũ). Data tháng 02/2026 dùng 6,3 kW. Từ tháng 03/2026, cập nhật thành 9,45 kW theo bảng mẫu mới.

### 7.2 Phân bổ bơm nước thực tế — ví dụ tháng 02/2026

Data từ sheet "Sheet1", phần II. 3 trạm bơm:

| Trạm bơm | Điện bơm (kW) |
|---|---|
| Trạm nước bên sông | 3.086 |
| Trạm nước cấp 1 (sau khi trừ nhà ở trạm nước) | 2.158 |
| Trạm nước cấp 2 | 908 |
| **Tổng cộng** | **6.152 kW** (tổng thực tế 3 trạm) |

Tổng điện bơm phân bổ: **6.420 kW** (bao gồm cả tổn hao trạm bơm).

**Cách chia:**

1. Chỉ huy Sư đoàn + nhà khách được **30%** riêng = 1.926 kW.
2. Phần **70%** còn lại = 4.494 kW, chia đều theo quân số:

| Đơn vị sử dụng | Quân số | Điện bơm (kW) |
|---|---|---|
| Chỉ huy Sư đoàn + nhà khách | — | 1.926 (30% riêng) |
| Cơ quan Sư đoàn bộ | 251 | 2.025 |
| Tiểu đoàn 18 | 149 | 1.202 |
| Đại đội 20, 23 | 109 | 879 |
| Trạm chế biến | 18 | 145 |
| Thợ xây | 30 | 242 |
| **Tổng** | **557** | **6.420 kW** |

**Bơm nước/người** (phần 70%): 4.494 ÷ 557 ≈ **8,07 kW/người** trong tháng 02.

**Lưu ý:** 8,07 kW/người là sử dụng thực tế tháng 02, khác với tiêu chuẩn 9,45 kW (hoặc 6,3 kW tháng 02). Hai con số này xuất hiện ở hai cột khác nhau trong bảng 24 cột.

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1", phần II + rows 161–169]`

### 7.3 Quy tắc chỉ định trạm bơm

Quản trị viên có thể chỉ định trạm bơm phục vụ nhóm đối tượng cụ thể (model `PumpStationAssignment`). Ví dụ: 30% cho Chỉ huy Sư đoàn + nhà khách, 70% chia đều theo quân số cho phần còn lại.

`[Nguồn: Zalo 06/04/2026, câu hỏi 2]`

---

## 8. Kế thừa tháng và khoá dữ liệu

### 8.1 Kế thừa tháng

Khi mở kỳ mới (xem 02_GLOSSARY mục 6), dữ liệu tự sao chép từ tháng trước: đầu mối, công tơ, quân số, cấu hình. Quản trị viên đơn vị chỉ cần sửa chỗ có thay đổi. Chỉ số đầu kỳ = chỉ số cuối kỳ tháng trước (tự động).

### 8.2 Khoá dữ liệu

- Khi khoá, quản trị viên đơn vị không sửa được dữ liệu tháng đó.
- Chỉ quản trị viên cấp 1 mở khoá.
- Nghiệp vụ: tránh sửa dữ liệu đã báo cáo lên trên.

`[Nguồn: y_kien_cua_325.docx, "Câu hỏi 3" + "Phần khai báo hàng tháng"]`

---

## 9. Edge cases

### 9.1 Cột "Khác" cho phép giá trị âm

**Vấn đề:** Đầu mối "Bảo đảm" trong Sư đoàn bộ có giá trị cột Khác = −296 kW (âm). Ban đầu phần mềm chặn giá trị < 0.

**Xác nhận:** Cho phép nhập giá trị âm. Âm = cộng ngược vào tiêu chuẩn — tức lấy tiêu chuẩn ở các đầu mối khác cho về đầu mối đó.

**Công thức:** Tiêu chuẩn còn lại = cột 14 − cột 15 − cột 16 − cột 17 − cột 18. Khi cột 18 âm (ví dụ −296), phép trừ số âm = cộng: tiêu chuẩn tăng thêm 296.

**Ví dụ từ data thật:** Bảo đảm có 1 người cấp 1, 6 người cấp 2, 26 người nhóm 7. Tổng tiêu chuẩn = 629 + 207,9 = 836,9 kW. Tiết kiệm 5% = 41,845. Công cộng 10% = 83,69. Khác = −296. Tiêu chuẩn còn lại = 836,9 − 41,845 − 83,69 − (−296) = **1.007,365 kW**.

`[Nguồn: Zalo 21/04/2026 + bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", row 41]`

### 9.2 Vị trí không tổn hao (`no_loss`)

**Vấn đề:** Tiểu đoàn 18 có công tơ đặt tại trạm biến áp (4.020 kW tháng 02), đo trực tiếp nên không có tổn hao đường dây. Trong file Excel gốc, Tiểu đoàn 18 không nằm trong công thức tổn hao.

**Xác nhận:** Thêm tuỳ chọn "Vị trí không tổn hao" trên màn hình quản lý công tơ (meter_type: `no_loss`). Khi đánh dấu, phần mềm bỏ qua công tơ đó khi tính tổn hao phân bổ. Công tơ `no_loss` vẫn được trừ khỏi số điện lực khi tính tổng tổn hao (xem mục 6.2).

`[Nguồn: Zalo 21/04/2026 + bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1", rows 4–7]`

### 9.3 Gộp bảng sử dụng vào bảng 24 cột

**Vấn đề:** Trong file Excel gốc, bảng sử dụng điện (đầu kỳ, cuối kỳ, sử dụng) nằm ở sheet riêng ("SD điện"). Phần mềm đã gộp thông tin này vào cùng bảng 24 cột.

**Xác nhận:** Giữ nguyên cách gộp trong phần mềm (1 bảng thay vì 2 sheet riêng).

`[Nguồn: Zalo 21/04/2026]`

### 9.4 Đầu mối không có quân số (nhóm IV "Khác")

Một số đầu mối không có quân số (nhà xe dân sự, xưởng in, trạm sửa chữa, cây ATM, chuồng lợn...). Với các đầu mối này: tổng quân số = 0, tiêu chuẩn = 0, bơm nước tiêu chuẩn = 0, các khoản trừ = 0, tiêu chuẩn còn lại = 0. Toàn bộ sử dụng = thiếu (phải trả toàn bộ tiền).

**Ví dụ:** Nhà xe dân sự: quân số 0, tiêu chuẩn 0, sử dụng 48 kW → thiếu 48 kW × 2.336,4 = 112.160 đồng.

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", rows 85–89]`

### 9.5 Đầu mối có thừa điện (tiêu chuẩn > sử dụng)

Khi tiêu chuẩn còn lại > tổng sử dụng: cột 21 (Thừa kW) = tiêu chuẩn còn lại − sử dụng, cột 22 (Thiếu kW) = 0.

**Ví dụ:** Ban Bảo vệ - TB + Hiếu: tiêu chuẩn còn lại 106,965 kW, sử dụng 95,303 kW → thừa 11,662 kW. (Giá trị âm trong file Excel gốc ở cột "Số thâm điện" nghĩa là thừa.)

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", row 51]`

### 9.6 Đơn giá thay đổi hàng tháng

Đơn giá điện (đồng/kW) thay đổi hàng tháng theo quy định nhà nước. Quản trị viên cấp 1 nhập qua F20. Data tháng 02/2026: **2.336,4 đồng/kW**.

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", row 7, cột S]`

---

## 10. Ví dụ tính toán end-to-end từ data tháng 02/2026

### 10.1 TMP Trường (đầu mối thiếu điện)

Data từ `bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx`, sheet "Sheet1" (row 21) và sheet "Sheet1 (2)" (row 9).

**Lưu ý:** Data tháng 02 dùng định mức **cũ** (nhóm 3/4 = 115 kW sinh hoạt, bơm nước 6,3 kW/người). Số liệu dưới đây là giá trị **verbatim** từ file Excel, không áp dụng bảng định mức mới.

| Bước | Chi tiết | Giá trị |
|---|---|---|
| 1. Công tơ | Đầu kỳ 13.223, cuối kỳ 13.322. Sử dụng = 13.322 − 13.223 | 99 kW |
| 2. Quân số | 1 người cấp 3/4 (cột "3//4//" trong file = nhóm cấp bậc 3 hoặc 4) | 1 người |
| 3. Tiêu chuẩn sinh hoạt | 115 kW (định mức cũ) | 115 kW |
| 4. Bơm nước tiêu chuẩn | 1 × 6,3 kW (tiêu chuẩn cũ) | 6,3 kW |
| 5. Tổng tiêu chuẩn (cột 14) | 115 + 6,3 | 121,3 kW |
| 6. Tiết kiệm 5% (cột 15) | 121,3 × 5% | 6,065 kW |
| 7. Tổn hao (cột 16) | Phân bổ: 1.752 × (99 ÷ 40.188) | ≈ 4,316 kW |
| 8. Công cộng 10% (cột 17) | 121,3 × 10% | 12,13 kW |
| 9. Khác (cột 18) | 0 | 0 kW |
| 10. Tiêu chuẩn còn lại (cột 19) | 121,3 − 6,065 − 4,316 − 12,13 − 0 | ≈ 98,789 kW |
| 11. Sử dụng công tơ (cột 20 — **không** cộng tổn hao) | 99 kW | 99 kW |
| 12. Bơm nước thực tế | Phân bổ theo quân số (xem mục 7.2) | 10,548 kW |
| 13. Tổng sử dụng (cột 20) | 99 + 10,548 | 109,548 kW |
| 14. Thiếu (cột 22) | 109,548 − 98,789 | ≈ 10,759 kW |
| 15. Thành tiền thiếu (cột 24) | 10,759 × 2.336,4 | ≈ 25.137 đồng |

**Lưu ý về sai số:** Giá trị trong file Excel tính trung gian với nhiều chữ số thập phân (ví dụ tổn hao = 4,315915198566737). Ví dụ trên làm tròn cho dễ đọc. Phần mềm dùng `BigDecimal` để tính chính xác.

**So sánh với cách tính trong file Excel gốc:** File Excel cộng tổn hao vào sử dụng (cột "Số sử dụng thực tế bao gồm cả tổn hao" = 99 + 4,316 = 103,316 kW) và **không** trừ tổn hao từ tiêu chuẩn (tiêu chuẩn còn lại = 103,105 kW). Kết quả: 113,864 − 103,105 = 10,759 kW. Phần mềm trừ tổn hao ở cột 16 (tiêu chuẩn) thay vì cộng vào cột 20 (sử dụng). Kết quả: 109,548 − 98,789 = 10,759 kW. **Cùng kết quả cuối cùng** — chỉ khác vị trí đặt tổn hao. Phần mềm tuân theo quy tắc "tổn hao nằm trong Số phải trừ".

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1" row 21 + sheet "Sheet1 (2)" row 9. Số liệu verbatim.]`

### 10.2 Bảo đảm (đầu mối có cột "Khác" âm)

Data từ sheet "Sheet1 (2)", row 41.

| Bước | Chi tiết | Giá trị |
|---|---|---|
| 1. Quân số | 1 cấp 1 + 6 cấp 2 + 26 nhóm 7 | 33 người |
| 2. Tiêu chuẩn sinh hoạt | (đọc từ file: 629 kW — dùng định mức cũ) | 629 kW |
| 3. Bơm nước tiêu chuẩn | 33 × 6,3 | 207,9 kW |
| 4. Tổng tiêu chuẩn | 629 + 207,9 | 836,9 kW |
| 5. Tiết kiệm 5% | 836,9 × 5% | 41,845 kW |
| 6. Công cộng 10% | 836,9 × 10% | 83,69 kW |
| 7. **Khác = −296 kW** | Âm → cộng ngược | −296 kW |
| 8. Tiêu chuẩn còn lại | 836,9 − 41,845 − tổn hao − 83,69 − (−296) | **1.007,365 kW** (không tính tổn hao ở đây) |

**Giải thích:** Đầu mối "Bảo đảm" phục vụ nhiều đầu mối khác → nhận thêm tiêu chuẩn điện bằng cách nhập giá trị âm ở cột "Khác".

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", row 41]`

### 10.3 Nhà xe dân sự (đầu mối không có quân số)

Data từ sheet "Sheet1 (2)", row 85.

| Bước | Chi tiết | Giá trị |
|---|---|---|
| 1. Quân số | 0 | 0 |
| 2. Tiêu chuẩn | 0 | 0 kW |
| 3. Bơm nước tiêu chuẩn | 0 × 6,3 | 0 kW |
| 4. Các khoản trừ | Tất cả 0 | 0 kW |
| 5. Tiêu chuẩn còn lại | 0 | 0 kW |
| 6. Sử dụng | 48,005 kW (bao gồm tổn hao) | 48,005 kW |
| 7. Bơm nước thực tế | 0 (không có quân số → không phân bổ) | 0 kW |
| 8. Thiếu | 48,005 − 0 | 48,005 kW |
| 9. Thành tiền | 48,005 × 2.336,4 | 112.160 đồng |

`[Nguồn: bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx, sheet "Sheet1 (2)", row 85]`

---

## 11. Lịch sử xác nhận nghiệp vụ

| Ngày | Sự kiện | Nguồn |
|---|---|---|
| 02–06/04/2026 | Nhiều vòng trao đổi qua Zalo. Phân tích file Excel khách. Phát hiện: Sư đoàn (không phải Lữ đoàn), 13 đơn vị, bảng 22 cột, 7 nhóm cấp bậc, bơm nước 2 khái niệm, 4 khoản trừ. | Zalo, y_kien_cua_325.docx |
| 06/04/2026 | Khách hàng xác nhận "Ok" cho toàn bộ nghiệp vụ v5. Đề xuất thêm tra cứu lịch sử + so sánh cùng kỳ. | Zalo |
| 21/04/2026 | Xác nhận 3 câu hỏi bổ sung: vị trí không tổn hao, cột "Khác" âm, gộp bảng sử dụng. Duyệt tài liệu phạm vi dự án v3.0.1. | Zalo |
| 21/04/2026 | Gửi ảnh bảng mẫu cập nhật MẪU THEO DÕI SỬ DỤNG ĐIỆN — tên 7 nhóm cấp bậc rút gọn. | Zalo |

**Trạng thái hiện tại:** Toàn bộ nghiệp vụ tính toán đã xác nhận. Không còn mục chờ xác nhận.

**Nguồn file gốc:**

1. y_kien_cua_325.docx — phản hồi của đơn vị, gồm sơ đồ phân cấp, mô tả quy trình khai báo, trả lời 14 câu hỏi, kèm 3 ảnh bảng mẫu mới.
2. bang tính điện thảo tháng 02 làm lại — THU CƠ QUAN.xlsx — bảng tính thực tế tháng 02/2026 của Sư đoàn bộ.
3. MẪU THEO DÕI SỬ DỤNG ĐIỆN F BỘ.xls — mẫu cũ (nay chuyển 7 nhóm + cột bơm nước).
4. Trao đổi Zalo ngày 02–06/04/2026 — tin nhắn, ảnh bảng mẫu mới, phản hồi xác nhận.
5. Trao đổi Zalo ngày 21/04/2026 — xác nhận 3 câu hỏi + duyệt tài liệu.
6. Ảnh bảng mẫu cập nhật MẪU THEO DÕI SỬ DỤNG ĐIỆN — Zalo 21/04/2026.

---

## TODO — Cần Claude Code verify

Các mục này có thể ảnh hưởng đến tính chính xác của file:

1. **Cách tổn hao xử lý trong code:** File Excel cộng tổn hao vào "sử dụng thực tế" (cột 8 sheet "Sheet1"). Phần mềm trừ tổn hao ở cột 16 (Số phải trừ). Cần verify CalculationEngine xử lý chính xác — tổn hao chỉ xuất hiện ở 1 nơi (cột 16), không cộng vào cột 20.
2. **Bơm nước phân bổ:** Cần verify model `PumpStationAssignment` có hỗ trợ chia tỷ lệ % riêng (ví dụ 30% cho Chỉ huy f) hay chỉ chia đều theo quân số.
3. **Đơn giá trong file Excel:** Row 7 sheet "Sheet1 (2)" ghi giá trị 2.336,4 ở cột bơm nước thực tế, không phải cột đơn giá. Cần xác nhận 2.336,4 đúng là đơn giá tháng 02.
