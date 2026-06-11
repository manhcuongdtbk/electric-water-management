# Xác nhận nghiệp vụ bổ sung — Hệ thống quản lý điện nội bộ Sư đoàn (Hệ thống v2)

> **Phiên bản:** 2.1.1
> **Ngày:** 11/06/2026
> **Bối cảnh:** Quản trị viên hệ thống test trên staging kỳ 4/2026 và đưa ra 3 mong muốn mới.

---

## Mục lục

1. [Xác nhận hệ thống hiện tại hoạt động đúng](#1-xác-nhận-hệ-thống-hiện-tại-hoạt-động-đúng)
2. [Tính năng mới 1 — Cột "Khác" kiểu hệ số tổng đơn vị](#2-tính-năng-mới-1--cột-khác-kiểu-hệ-số-tổng-đơn-vị)
3. [Tính năng mới 2 — Phân bổ bơm nước theo từng trạm bơm](#3-tính-năng-mới-2--phân-bổ-bơm-nước-theo-từng-trạm-bơm)
4. [Tính năng mới 3 — Hiển thị chi tiết tổn hao](#4-tính-năng-mới-3--hiển-thị-chi-tiết-tổn-hao)
5. [Tổng hợp cần xác nhận](#5-tổng-hợp-cần-xác-nhận)

---

## 1. Xác nhận hệ thống hiện tại hoạt động đúng

Ngày 26/05/2026, đội phát triển đã kiểm tra toàn bộ bảng tính tiền kỳ 4/2026 trên staging bằng cách **tính tay từng bước** và so sánh với kết quả hệ thống xuất ra. Kết quả: **tất cả số liệu khớp chính xác**.

Cụ thể đã kiểm tra:

- Tiêu chuẩn điện sinh hoạt (quân số × định mức từng cấp bậc): 6/6 đầu mối đúng.
- Tiêu chuẩn điện bơm nước (quân số × 9,45): 6/6 đầu mối đúng.
- Các khoản trừ (tiết kiệm Bộ 5%, công cộng Sư đoàn 10%, công cộng đơn vị 10%, cột Khác): đúng.
- Tổn hao: tính từ công tơ tổng (20.000 kWh), 12 công tơ con (tổng 5.350 kWh) → tổn hao 14.650 kWh → phân bổ theo tỷ lệ sử dụng từng công tơ. 6/6 đầu mối đúng.
- Phân bổ bơm nước: 2 trạm bơm (800 kWh thô + 2.190,65 kWh tổn hao = 2.990,65 kWh) → chia đều theo quân số (74 người) → 40,41 kWh/người. 6/6 đầu mối đúng.
- Thừa/thiếu và thành tiền: 6/6 đầu mối đúng.

File kiểm chứng Excel (có công thức từng bước, bấm vào ô bất kỳ để thấy cách tính) đã được gửi kèm.

**3 mong muốn dưới đây là tính năng mới, nằm ngoài phạm vi nghiệp vụ đã thống nhất.**

---

## 2. Tính năng mới 1 — Cột "Khác" kiểu hệ số tổng đơn vị

> **Trạng thái: Đã xác nhận** (phản hồi ngày 31/05/2026, kèm điều chỉnh công thức loại trừ quân số đầu mối đang nhập).

### Vấn đề thực tế

Trong đơn vị có bếp ăn chung phục vụ tất cả mọi người. Bếp dùng điện nấu ăn. Quản trị viên đơn vị muốn:

- **Mỗi người trong đơn vị góp 1 phần tiêu chuẩn điện cho bếp** (ví dụ: mỗi người góp 2 kWh).
- **Bếp được nhận lại tổng số đó** để bù vào tiêu chuẩn (vì bếp nấu cho cả đơn vị, không phải bếp tự dùng).

### Hệ thống hiện tại làm được gì

Cột "Khác" trên trang Cấu hình đơn vị có 2 cách nhập:

| Cách nhập | Hệ thống tính | Ví dụ |
|---|---|---|
| **Số cụ thể** | Dùng đúng số đã nhập | Nhập 10 → trừ 10 kWh |
| **Theo hệ số** | Hệ số × quân số **đầu mối đó** | Nhập 2, đầu mối 3 người → trừ 2 × 3 = 6 kWh |

- Phần "mỗi người góp 2 kWh": **làm được** — dùng kiểu "Theo hệ số" với giá trị 2 cho tất cả đầu mối.
- Phần "bếp nhận lại tổng": **làm được** bằng cách nhập "Số cụ thể" = -132 cho bếp. Tuy nhiên khi quân số thay đổi (người chuyển đi/đến) thì cần tự tính lại con số này.

### Giải pháp đề xuất

Thêm 1 cách nhập thứ 3:

| Cách nhập | Hệ thống tính | Ví dụ |
|---|---|---|
| Số cụ thể | Dùng đúng số đã nhập | (giữ nguyên) |
| Theo hệ số | Hệ số × quân số **đầu mối đó** | (giữ nguyên) |
| **Theo hệ số (đơn vị)** | **Hệ số × (tổng quân số đơn vị − quân số đầu mối đó)** | **Nhập -2, đơn vị 74 người, bếp 8 người → -2 × (74 − 8) = -132 kWh (cộng ngược 132 vào tiêu chuẩn bếp)** |

Chỉ cần nhập hệ số 1 lần. Khi quân số thay đổi, hệ thống tự tính lại.

### Ví dụ minh họa

Đơn vị có 74 người, chia thành 6 đầu mối. Mỗi người góp 2 kWh cho bếp:

| Đầu mối | Quân số | Cách nhập cột Khác | Giá trị nhập | Hệ thống tính |
|---|---|---|---|---|
| Sư trưởng | 3 | Theo hệ số | 2 | 2 × 3 = **6 kWh bị trừ** |
| nhà ở 20-23 | 51 | Theo hệ số | 2 | 2 × 51 = **102 kWh bị trừ** |
| Trưởng ban Doanh trại | 7 | Theo hệ số | 2 | 2 × 7 = **14 kWh bị trừ** |
| TL-NV | 3 | Theo hệ số | 2 | 2 × 3 = **6 kWh bị trừ** |
| Trưởng ban | 2 | Theo hệ số | 2 | 2 × 2 = **4 kWh bị trừ** |
| **Bếp f bộ** | **8** | **Theo hệ số (đơn vị)** | **-2** | **-2 × (74 − 8) = -132 kWh (cộng ngược)** |

Kết quả: 5 đầu mối khác bị trừ tổng 132 kWh. Bếp được cộng 132 kWh. 8 người bếp không bị trừ vì họ ở ngay bếp.

Nếu tháng sau có thêm 5 người mới vào đơn vị (tổng thành 79 người), hệ thống tự tính lại: -2 × (79 − 8) = -142 kWh cho bếp. Không cần sửa gì.

### Quy tắc

- "Tổng quân số đơn vị" trong công thức = tổng quân số tất cả đầu mối sinh hoạt trong đơn vị, **không bao gồm** quân số của chính đầu mối đang nhập.
- Giá trị âm: cho phép (âm = cộng ngược vào tiêu chuẩn, tức đầu mối được hưởng thêm).
- Giá trị dương: cho phép (dương = trừ khỏi tiêu chuẩn, giống 2 cách nhập cũ).
- Chỉ áp dụng cho đầu mối thuộc đơn vị. Đầu mối thuộc khu vực trực tiếp (không có đơn vị) không dùng cách nhập này.
- Kế thừa kỳ mới: kế thừa cả cách nhập lẫn hệ số, hệ thống tự tính lại theo quân số mới của kỳ mới.

---

## 3. Tính năng mới 2 — Phân bổ bơm nước theo từng trạm bơm

> **Trạng thái: Đã xác nhận** (phản hồi ngày 31/05/2026, xác nhận cả 3 loại đối tượng nhận mới: khối, nhóm, đầu mối sinh hoạt thuộc đơn vị).

### Vấn đề thực tế

Trong 1 khu vực có nhiều trạm bơm nước. Mỗi trạm bơm phục vụ 1 vùng khác nhau trong khu vực:

- Trạm bơm 1 bơm nước cho vùng A (ví dụ: Khối 1).
- Trạm bơm 2 bơm nước cho vùng B (ví dụ: Khối 2).

Hệ thống hiện tại gộp điện của tất cả trạm bơm thành 1 tổng, rồi chia cho tất cả mọi người. Nếu muốn tách riêng trạm nào cho vùng nào thì cần thêm tính năng mới.

### Hệ thống hiện tại làm được gì

Hiện tại phân bổ bơm nước hoạt động như sau:

```
Tất cả trạm bơm trong khu vực
        ↓ gộp thành 1 tổng
   Tổng điện bơm nước
        ↓ chia cho
   Các đối tượng nhận (đơn vị, đầu mối khu vực, ngoài biên chế)
        ↓ đơn vị chia đều xuống
   Tất cả đầu mối sinh hoạt trong đơn vị (theo quân số)
```

### Giải pháp đề xuất

Thay đổi cơ chế phân bổ: **mỗi trạm bơm có danh sách đối tượng nhận riêng**, thay vì gộp tất cả trạm bơm thành 1 tổng.

```
Trạm bơm 1 (500 kWh + tổn hao)          Trạm bơm 2 (300 kWh + tổn hao)
        ↓                                         ↓
Đối tượng nhận của trạm 1                Đối tượng nhận của trạm 2
(ví dụ: Khối 1)                          (ví dụ: Khối 2, Đơn vị B)
        ↓                                         ↓
Đầu mối trong Khối 1                    Đầu mối trong Khối 2 + Đơn vị B
```

Trên trang **Phân bổ bơm nước**, thay vì 1 bảng chung cho cả khu vực, hiển thị **1 bảng riêng cho mỗi trạm bơm**. Quản trị viên hệ thống hoặc quản trị viên đơn vị quản lý khu vực cấu hình từng trạm bơm phân bổ cho ai.

### Đối tượng nhận phân bổ

Mở rộng danh sách đối tượng có thể nhận phân bổ bơm nước:

| Đối tượng | Đã có | Mới | Khi nhận, hệ thống chia xuống |
|---|---|---|---|
| Đơn vị | Có | Giữ | Chia đều theo quân số cho tất cả đầu mối sinh hoạt trong đơn vị |
| Đầu mối sinh hoạt thuộc khu vực | Có | Giữ | Nhận trực tiếp |
| Đầu mối ngoài biên chế | Có | Giữ | Nhận trực tiếp |
| **Khối** | — | **Thêm** | **Chia đều theo quân số cho tất cả đầu mối sinh hoạt trong khối** |
| **Nhóm** | — | **Thêm** | **Chia đều theo quân số cho tất cả đầu mối sinh hoạt trong nhóm** |
| **Đầu mối sinh hoạt thuộc đơn vị** | — | **Thêm** | **Nhận trực tiếp** |

Tổng điện bơm nước toàn khu vực không thay đổi — chỉ tách ra theo từng trạm thay vì gộp chung. Ví dụ: trạm 1 dùng 500 kWh + tổn hao 200 kWh = 700 kWh, trạm 2 dùng 300 kWh + tổn hao 120 kWh = 420 kWh → tổng vẫn là 1.120 kWh như cũ, nhưng 700 kWh chỉ phân bổ cho đối tượng của trạm 1, 420 kWh chỉ phân bổ cho đối tượng của trạm 2.

Cách phân bổ (phần trăm cố định hoặc hệ số nhân quân số) giữ nguyên. Thay đổi chính: phạm vi phân bổ từ "cả khu vực" thành "từng trạm bơm", và thêm đối tượng nhận mới (khối, nhóm, đầu mối thuộc đơn vị).

### Ví dụ minh họa

Khu vực có 2 trạm bơm, 2 đơn vị (mỗi đơn vị có 2 khối):

**Trạm bơm cấp 1** (điện: 500 kWh + tổn hao) phục vụ:

| Đối tượng | Cách phân bổ | Giá trị |
|---|---|---|
| Khối "Phòng Tham mưu" (Đơn vị A) | Theo hệ số | 1 |
| Khối "Phòng Hậu cần" (Đơn vị A) | Theo hệ số | 1 |

→ 2 khối chia theo tỷ lệ quân số. Các đầu mối trong mỗi khối chia đều theo quân số.

**Trạm bơm cấp 2** (điện: 300 kWh + tổn hao) phục vụ:

| Đối tượng | Cách phân bổ | Giá trị |
|---|---|---|
| Đơn vị B | Theo hệ số | 1 |
| Đầu mối "Chỉ huy khu vực" (thuộc khu vực) | Phần trăm cố định | 10% |

→ Chỉ huy khu vực nhận 10% cố định. Đơn vị B nhận phần còn lại, chia đều theo quân số.

### Quy tắc

- Mỗi trạm bơm phải có ít nhất 1 đối tượng nhận. Trạm bơm chưa cấu hình đối tượng nhận → hệ thống hiển thị cảnh báo.
- Các ràng buộc hiện tại giữ nguyên cho từng trạm bơm: tổng phần trăm cố định ≤ 100%, phải có đối tượng nhận hệ số nếu chưa đạt 100%, tổng (quân số × hệ số) > 0.
- Tổn hao vẫn tính chung toàn khu vực (không thay đổi). Tổn hao của từng công tơ bơm nước được gán về trạm bơm tương ứng.
- Kế thừa kỳ mới: kế thừa cấu hình phân bổ từng trạm bơm (đối tượng nhận, phần trăm, hệ số).
- Kỳ cũ (trước khi có tính năng mới): giữ nguyên cơ chế cũ (gộp tất cả trạm bơm). Kỳ mới mở sau khi cập nhật hệ thống sẽ dùng cơ chế mới.
- "Chia đều theo quân số" khi nhận qua đơn vị, khối, hoặc nhóm: đối tượng nhận X kWh → mỗi đầu mối sinh hoạt bên trong nhận X ÷ tổng quân số × quân số đầu mối đó.

---

## 4. Tính năng mới 3 — Hiển thị chi tiết tổn hao

> **Trạng thái: Đã xác nhận sơ bộ** (khách yêu cầu xem chi tiết tổn hao, không phản đối phương án đề xuất — xác nhận hoàn toàn khi dùng thử).

### Vấn đề thực tế

Hệ thống tính tổn hao chính xác (đã kiểm chứng ở mục 1), nhưng hiện tại chỉ hiển thị kết quả tổn hao dưới dạng 1 con số ở cột "Tổn hao" trong khoản trừ trên bảng tính tiền. Quản trị viên hệ thống muốn xem được chi tiết cách tính tổn hao để kiểm tra và đối chiếu — tương tự bảng "Tính tổn hao và sử dụng thực tế" trong file Excel cũ.

### Giải pháp đề xuất

Hiển thị thông tin chi tiết tổn hao trên các trang đã có sẵn, không cần tạo trang mới:

**Trang Chỉ số đầu mối** — thêm 2 cột (chỉ đọc, không nhập):

| Cột hiện tại | Cột mới |
|---|---|
| Đầu kỳ, Cuối kỳ, Sử dụng | + **Tổn hao**, **Sử dụng thực tế** |

- Tổn hao = phần tổn hao phân bổ cho công tơ đó (kết quả tính toán).
- Sử dụng thực tế = Sử dụng + Tổn hao.
- Áp dụng cho tất cả công tơ trên trang (sinh hoạt và công cộng).

**Trang Chỉ số bơm nước** — thêm 2 cột tương tự:

| Cột hiện tại | Cột mới |
|---|---|
| Đầu kỳ, Cuối kỳ, Sử dụng | + **Tổn hao**, **Sử dụng thực tế** |

**Trang Bảng tính tiền** — thêm phần tóm tắt tổn hao phía trên bảng (cạnh đơn giá và cảnh báo hiện tại):

| Thông tin | Ý nghĩa |
|---|---|
| Công tơ tổng (A) | Số sử dụng trên công tơ tổng − tổng công tơ không tổn hao |
| Tổng sử dụng (B) | Tổng sử dụng tất cả công tơ có tổn hao |
| Tổng tổn hao (C = A − B) | Phần điện "mất" trên đường truyền toàn khu vực |

### Quy tắc

- 2 cột mới trên trang Chỉ số đầu mối và Chỉ số bơm nước là **chỉ đọc** — hiển thị kết quả từ lần tính toán gần nhất.
- Nếu chưa bấm "Tính toán lại" (chưa có kết quả tính toán), 2 cột này để trống.
- Phần tóm tắt A, B, C trên trang Bảng tính tiền hiển thị theo khu vực đang chọn (quản trị viên hệ thống chọn khu vực nào thì thấy A, B, C của khu vực đó).

---

## 5. Tổng hợp cần xác nhận

---

**Câu 1 — Cột "Khác" kiểu mới: Đã xác nhận ✓**

Thêm cách nhập "Theo hệ số (đơn vị)" — hệ số × (tổng quân số đơn vị − quân số đầu mối đó). Công thức loại trừ quân số của chính đầu mối đang nhập. Chi tiết và ví dụ ở mục 2.

---

**Câu 2 — Phân bổ bơm nước theo trạm: Đã xác nhận ✓**

Mỗi trạm bơm phân bổ riêng cho đối tượng mà trạm đó phục vụ. Chi tiết và ví dụ ở mục 3.

---

**Câu 3 — Đối tượng nhận bơm nước: Đã xác nhận ✓**

Thêm cả 3 loại: khối, nhóm, và đầu mối sinh hoạt thuộc đơn vị. Chi tiết ở bảng đối tượng trong mục 3.

---

**Câu 4 — Hiển thị chi tiết tổn hao: Đã xác nhận sơ bộ ✓**

Thêm 2 cột "Tổn hao" và "Sử dụng thực tế" trên trang Chỉ số đầu mối và Chỉ số bơm nước. Thêm phần tóm tắt A, B, C trên trang Bảng tính tiền. Giúp kiểm tra và đối chiếu cách tính tổn hao. Chi tiết ở mục 4. Xác nhận hoàn toàn khi dùng thử.

---

## Lịch sử thay đổi

### v2.1.1 (11/06/2026)

- Mục 4: cập nhật trạng thái tính năng 3 (hiển thị chi tiết tổn hao) thành "Đã xác nhận sơ bộ" — khách yêu cầu xem chi tiết tổn hao, không phản đối phương án đề xuất, xác nhận hoàn toàn khi dùng thử.
- Mục 5 câu 4: cập nhật trạng thái tương ứng.

### v2.1.0 (06/06/2026)

- Mục 2: sửa công thức cột Khác từ -148 thành -132 — loại trừ quân số đầu mối đang nhập theo phản hồi khách (31/05/2026).
- Mục 2, 3: cập nhật trạng thái "Đã xác nhận" theo phản hồi khách (31/05/2026).
- Mục 4: thêm tính năng mới 3 — hiển thị chi tiết tổn hao trên trang Chỉ số đầu mối, Chỉ số bơm nước, Bảng tính tiền. Dựa trên bảng Excel cũ của khách.
- Mục 5: cập nhật câu 1-3 đã xác nhận, thêm câu 4 cho tính năng mới 3.
- Đổi "2 mong muốn" → "3 mong muốn", cập nhật ngày.

### v2.0.0 (30/05/2026)

- Tài liệu ban đầu với 2 tính năng mới: cột Khác kiểu hệ số tổng đơn vị, phân bổ bơm nước theo từng trạm bơm.
- Mục 1: xác nhận hệ thống hiện tại tính toán đúng, kèm dẫn chứng kiểm tra ngày 26/05/2026.
