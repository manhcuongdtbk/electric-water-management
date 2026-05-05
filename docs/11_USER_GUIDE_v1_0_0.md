# 11. Hướng dẫn sử dụng — User Guide

> Version: v1.0.0 | Date: 2026-05-05
> Audience: End users (Vietnamese military division staff)
> Cross-references: 02_GLOSSARY_v1_3_0, 06_AUTH_SECURITY_v1_0_0, 07_UI_CONTROLLERS_v1_0_0, 13_BUSINESS_RULES_v1_1_0

---

## Mục lục

1. [Giới thiệu chung](#1-giới-thiệu-chung)
2. [Đăng nhập và bảo mật](#2-đăng-nhập-và-bảo-mật)
3. [Khai báo ban đầu](#3-khai-báo-ban-đầu)
4. [Nhập liệu hàng tháng](#4-nhập-liệu-hàng-tháng)
5. [Báo cáo và tra cứu](#5-báo-cáo-và-tra-cứu)
6. [Quản trị hệ thống](#6-quản-trị-hệ-thống)
7. [Quy trình nghiệp vụ hàng tháng](#7-quy-trình-nghiệp-vụ-hàng-tháng)
8. [Câu hỏi thường gặp](#8-câu-hỏi-thường-gặp)

---

## 1. Giới thiệu chung

**Phần mềm Quản lý Điện Nước** là ứng dụng web nội bộ thay thế phần mềm WinForms cũ, dùng để quản lý tiêu chuẩn và tiêu thụ điện cho Sư đoàn và 13 đơn vị trực thuộc. Hệ thống cho phép nhiều người dùng truy cập đồng thời, phân quyền theo vai trò, ghi nhật ký thay đổi và sao lưu dữ liệu tự động.

**URL truy cập:** `https://<server-ip>` (liên hệ nhóm kỹ thuật để biết địa chỉ cụ thể)

### 1.1 Bốn vai trò người dùng

| Vai trò | Tên hiển thị | Phạm vi | Quyền chính |
|---|---|---|---|
| `admin_level1` | Quản trị viên cấp 1 | Toàn Sư đoàn (13 đơn vị) | Toàn quyền: khai báo, nhập liệu, báo cáo, cấu hình hệ thống |
| `admin_unit` | Quản trị viên đơn vị | 1 đơn vị | Khai báo và nhập liệu cho đơn vị mình; xem báo cáo |
| `commander` | Chỉ huy đơn vị | 1 đơn vị | Chỉ xem dữ liệu và báo cáo; không nhập liệu |
| `tech` | Kỹ thuật | Toàn hệ thống | Quản lý tài khoản, xem nhật ký, sao lưu & phục hồi; không truy cập dữ liệu nghiệp vụ |

### 1.2 Bảng quyền tổng quan

| Chức năng | admin_level1 | admin_unit | commander | tech |
|---|:---:|:---:|:---:|:---:|
| Xem báo cáo, tra cứu | ✓ | ✓ | ✓ | — |
| Khai báo đầu mối, công tơ, quân số | ✓ | ✓ | — | — |
| Nhập liệu hàng tháng (F05–F07) | ✓ | ✓ | — | — |
| Chạy tính toán, xem bảng tổng hợp | ✓ | ✓ | ✓ | — |
| Xuất CSV | ✓ | ✓ | ✓ | — |
| Quản lý tài khoản (F15) | ✓ | — | — | ✓ |
| Cấu hình đơn giá (F20), định mức (F21) | ✓ | — | — | — |
| Nhật ký hoạt động (F19) | ✓ | — | — | ✓ |
| Sao lưu & phục hồi | — | — | — | ✓ |

---

## 2. Đăng nhập và bảo mật

<!-- Screenshot: Trang đăng nhập — form email + mật khẩu, nút "Đăng nhập", không có nút đăng ký -->

### 2.1 Đăng nhập (F16)

1. Mở trình duyệt, truy cập `https://<server-ip>`
2. Nhập **Địa chỉ email** và **Mật khẩu**
3. Nhấn **Đăng nhập**
4. Hệ thống chuyển về **Trang chủ** (Dashboard)

> Nếu muốn ở lại phiên làm việc lâu hơn, tích vào ô **Ghi nhớ đăng nhập** — hệ thống sẽ duy trì phiên trong 2 tuần.

### 2.2 Đăng nhập lần đầu — Bắt buộc đổi mật khẩu (F18)

Khi tài khoản mới được tạo, lần đăng nhập đầu tiên hệ thống sẽ yêu cầu đổi mật khẩu ngay:

1. Đăng nhập bằng mật khẩu tạm do quản trị viên cấp
2. Hệ thống tự động chuyển sang trang **Đổi mật khẩu**
3. Nhập **Mật khẩu hiện tại**, **Mật khẩu mới**, **Xác nhận mật khẩu mới**
4. Nhấn **Lưu mật khẩu mới**
5. Hệ thống chuyển về Trang chủ — phiên làm việc bắt đầu

**Quy tắc mật khẩu:**
- Từ 8 đến 128 ký tự
- Phải có ít nhất 1 chữ cái và 1 chữ số
- Ví dụ hợp lệ: `Donvi2026`, `abc12345`

### 2.3 Tự động đăng xuất khi không hoạt động

Hệ thống tự động đăng xuất sau **2 giờ** không thao tác. Trước khi hết hạn **2 phút**, sẽ hiện cửa sổ cảnh báo:

- Nhấn **Tiếp tục làm việc** → phiên được gia hạn thêm 2 giờ
- Nhấn **Đăng xuất** hoặc bỏ qua → hệ thống đăng xuất, dữ liệu chưa lưu có thể bị mất

> Luôn nhấn **Lưu** trước khi rời khỏi màn hình nhập liệu.

### 2.4 Khóa tài khoản (F17)

Tài khoản bị khóa tự động sau **5 lần** nhập sai mật khẩu liên tiếp. Thông báo hiện: _"Tài khoản đã bị khóa do nhập sai mật khẩu quá nhiều lần. Vui lòng liên hệ quản trị viên."_

Để mở khóa: liên hệ **admin_level1** hoặc **tech** thực hiện mở khóa qua menu **Quản lý tài khoản** (F15). Hệ thống không tự động mở khóa theo thời gian.

### 2.5 Đổi mật khẩu chủ động

Người dùng có thể đổi mật khẩu bất kỳ lúc nào qua trang **Đổi mật khẩu** (truy cập qua menu tài khoản hoặc đường dẫn `/password_change/edit`).

### 2.6 Đăng xuất

Nhấn **Đăng xuất** ở cuối menu điều hướng bên trái.

---

## 3. Khai báo ban đầu

Phần này thực hiện một lần khi triển khai hệ thống, hoặc khi có thay đổi cơ cấu tổ chức.

### 3.1 Quản lý đơn vị cấp 2

**Chỉ admin_level1.** 13 đơn vị trực thuộc được cài đặt sẵn trong hệ thống: Sư đoàn bộ, Trung đoàn 101, Trung đoàn 18, Trung đoàn 95, Tiểu đoàn 14, Tiểu đoàn 15, Tiểu đoàn 16, Tiểu đoàn 17, Tiểu đoàn 18, Tiểu đoàn 24, Tiểu đoàn 25, Đại đội 26, Đại đội 29.

> **Lưu ý:** Thêm hoặc sửa đơn vị cấp 2 không thực hiện được qua giao diện web — không có trang quản lý tổ chức. Nếu cần thêm/sửa/xóa đơn vị, liên hệ **nhóm kỹ thuật (tech)** để thực hiện qua công cụ quản trị hệ thống.

### 3.2 Khai báo đầu mối (F01)

**admin_level1 + admin_unit.** Đầu mối là bộ phận nhỏ nhất trong đơn vị, có công tơ điện và quân số riêng (ví dụ: Ban chỉ huy, Đại đội 1, Nhà ăn).

<!-- Screenshot: Danh sách đầu mối — bảng tên, mã, đơn vị, nút Thêm đầu mối -->

**Thêm đầu mối mới:**
1. Menu → **Đầu mối** → trang `/contact_points`
2. Nhấn nút **Thêm đầu mối**
3. Điền thông tin: Tên đầu mối, Mã đầu mối, Đơn vị trực thuộc
4. Nhấn **Lưu**

<!-- Screenshot: Form thêm đầu mối — các trường tên, mã, đơn vị -->

**Sửa / Xóa đầu mối:**
- Nhấn **Sửa** hoặc **Xóa** tương ứng trong danh sách
- Xóa đầu mối sẽ xóa toàn bộ công tơ và quân số liên quan — cần xác nhận trước khi thực hiện

### 3.3 Khai báo công tơ (F02)

**admin_level1 + admin_unit.** Mỗi đầu mối có thể có nhiều công tơ.

<!-- Screenshot: Trang chi tiết đầu mối — tab/danh sách Công tơ, nút Thêm công tơ -->

**Thêm công tơ:**
1. Vào trang chi tiết đầu mối (nhấn vào tên đầu mối trong danh sách)
2. Nhấn **Thêm công tơ**
3. Nhập: Tên công tơ, Mã công tơ, Loại công tơ
4. Nhấn **Lưu**

**Bốn loại công tơ:**

| Loại | Mô tả | Ghi chú |
|---|---|---|
| Công tơ thông thường | Công tơ đo điện tiêu thụ bình thường | Phổ biến nhất |
| Công tơ công cộng | Đo điện dùng chung (hành lang, sân, chiếu sáng công cộng) | Tính vào khoản trừ Công cộng |
| Công tơ trạm bơm | Đo điện trạm bơm nước | Dùng để tính sử dụng bơm nước thực tế |
| Không tính tổn hao | Công tơ trạm biến áp nội bộ không tính vào tổn hao | Loại trừ khỏi phân bổ tổn hao |

### 3.4 Khai báo quân số 7 nhóm cấp bậc (F03)

**admin_level1 + admin_unit.** Quân số được khai báo theo 7 nhóm cấp bậc quy định tại Nghị định 02 của Bộ Quốc phòng.

<!-- Screenshot: Trang quân số đầu mối — bảng 7 dòng nhóm cấp bậc, cột số lượng -->

**Nhập quân số:**
1. Vào trang chi tiết đầu mối → nhấn **Quân số** (hoặc truy cập `/contact_points/:id/personnel`)
2. Nhập số lượng cho từng nhóm cấp bậc
3. Nhấn **Lưu**

**7 nhóm cấp bậc và định mức tiêu chuẩn điện:**

| Nhóm | Tên nhóm cấp bậc | Định mức (kW/người/tháng) |
|:---:|---|:---:|
| 1 | Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá | 570 |
| 2 | Chỉ huy Trung đoàn; SQ có trần quân hàm là Thượng tá | 440 |
| 3 | Chỉ huy tiểu đoàn; SQ có trần quân hàm là Trung tá, Thiếu tá | 305 |
| 4 | Chỉ huy đại đội, trung đội; SQ có trần quân hàm là cấp Úy | 130 |
| 5 | Cơ quan sư đoàn, trung đoàn | 210 |
| 6 | Tiểu đoàn, đại đội | 110 |
| 7 | Hạ sĩ quan, binh sĩ | 24 |

> Định mức có thể thay đổi khi có nghị định mới — admin_level1 cập nhật qua F21.

### 3.5 Cấu hình tỷ lệ và cột "Khác" (F04)

**admin_level1 + admin_unit.** Mỗi đơn vị nhập cấu hình tỷ lệ riêng cho kỳ tính. admin_level1 còn nhập thêm cấu hình cấp Sư đoàn.

<!-- Screenshot: Trang Cấu hình — 2 khối: Cấu hình Sư đoàn (admin_level1) và Cấu hình đơn vị -->

**Truy cập:** Menu → **Cấu hình** → `/unit_config`

**Cấu hình đơn vị** (admin_unit + admin_level1 cho đơn vị mình):
- **Tỷ lệ tiết kiệm (%):** Phần trăm tiết kiệm điện theo quy định Ban Doanh trại
- **Tỷ lệ công cộng đơn vị (%):** Phần trăm điện dùng chung trong đơn vị
- **Cột "Khác":** Nhập giá trị kW cố định, hoặc hệ số nhân với quân số. Cho phép giá trị âm (âm nghĩa là tăng tiêu chuẩn, ví dụ: bảo đảm điện cho bộ phận khác)

**Cấu hình Sư đoàn** (chỉ admin_level1):
- **Tỷ lệ tiết kiệm Sư đoàn (%):** Áp dụng cho toàn bộ đơn vị
- **Tỷ lệ công cộng Sư đoàn (%):** Điện dùng chung cấp Sư đoàn (hội trường, khu hành chính...)

> **Bốn khoản trừ trong bảng 24 cột** (cột 13–16): Tiết kiệm, Tổn hao, Công cộng Sư đoàn, Công cộng đơn vị.
> **Cột "Khác"** (cột 18) là cột riêng biệt, không phải khoản trừ thứ 5.

---

## 4. Nhập liệu hàng tháng

Mỗi tháng thực hiện theo thứ tự các bước dưới đây. Xem thêm [Mục 7 — Quy trình nghiệp vụ hàng tháng](#7-quy-trình-nghiệp-vụ-hàng-tháng).

### 4.1 Tạo kỳ tính mới

**Chỉ admin_level1.** Đây là bước đầu tiên, phải thực hiện trước tất cả các bước còn lại.

<!-- Screenshot: Trang Đơn giá điện — danh sách kỳ tính, nút Tạo kỳ mới -->

1. Menu → **Đơn giá điện** → `/monthly_periods`
2. Nhấn **Tạo kỳ mới**
3. Chọn tháng/năm, nhập **đơn giá điện** (đồng/kWh) áp dụng cho kỳ này
4. Nhấn **Lưu**

**Điều xảy ra sau khi tạo kỳ mới:**
- Kỳ tính cũ bị **khóa tự động** — không thể sửa số liệu kỳ cũ (trừ khi admin_level1 mở khóa)
- Hệ thống **kế thừa dữ liệu**: chỉ số đầu kỳ mới = chỉ số cuối kỳ cũ; quân số copy sang với trạng thái "chưa soát"
- Cấu hình tỷ lệ cần nhập lại cho kỳ mới

### 4.2 Nhập số điện lực — đồng hồ tổng (F05)

**Chỉ admin_level1.** Nhập tổng số kWh điện lực giao cho đơn vị trong kỳ tính (lấy từ hóa đơn điện lực).

<!-- Screenshot: Trang Nhập số điện lực — form nhập kWh cho từng đơn vị -->

1. Menu → **Nhập số điện lực** → `/electricity_supply`
2. Chọn kỳ tính (nếu chưa tự động chọn kỳ hiện tại)
3. Nhập số kWh điện lực cho từng đơn vị
4. Nhấn **Lưu**

### 4.3 Nhập chỉ số công tơ đầu kỳ/cuối kỳ (F06)

**admin_level1 + admin_unit.** Nhập chỉ số trên công tơ vật lý tại đầu và cuối kỳ tính.

<!-- Screenshot: Trang Chỉ số công tơ — bảng danh sách công tơ, cột chỉ số đầu kỳ, cuối kỳ, tiêu thụ -->

1. Menu → **Chỉ số công tơ** → `/meter_readings`
2. Chọn kỳ tính và đơn vị (admin_level1 có thể chọn bất kỳ đơn vị; admin_unit thấy đơn vị mình)
3. Với mỗi công tơ: nhập **Chỉ số đầu kỳ** và **Chỉ số cuối kỳ**
4. Cột **Tiêu thụ** tự tính = Cuối kỳ − Đầu kỳ
5. Nhấn **Lưu**

> Chỉ số đầu kỳ thường được kế thừa tự động từ chỉ số cuối kỳ trước — kiểm tra lại trước khi nhập cuối kỳ.

### 4.4 Soát lại quân số (F07)

**admin_level1 + admin_unit.** Xác nhận quân số kế thừa từ tháng trước là đúng, hoặc điều chỉnh nếu có thay đổi nhân sự.

<!-- Screenshot: Trang Soát lại quân số — bảng tổng hợp quân số các đầu mối, trạng thái Đã soát/Chưa soát -->

1. Menu → **Soát lại quân số** → `/personnel_review`
2. Xem lại quân số từng đầu mối
3. Nếu cần điều chỉnh: nhấn vào đầu mối → sửa số lượng từng nhóm → Lưu
4. Đánh dấu **Đã soát** cho từng đầu mối sau khi xác nhận
5. Khi tất cả đầu mối đã soát, quân số sẵn sàng cho tính toán

### 4.5 Chạy tính toán (F08–F10)

**admin_level1 + admin_unit.** Sau khi hoàn thành F05–F07, chạy engine tính toán để cập nhật bảng tổng hợp.

<!-- Screenshot: Bảng tổng hợp — nút Tính lại ở góc trên -->

1. Menu → **Bảng tổng hợp** → `/monthly_summary`
2. Nhấn nút **Tính lại**
3. Hệ thống tự động thực hiện 3 bước tính toán:
   - **F08** — Tính tiêu chuẩn theo Nghị định 02: Σ(quân số × định mức) + bơm nước tiêu chuẩn
   - **F09** — Tính sử dụng và so sánh: so sánh sử dụng thực tế với tiêu chuẩn → thừa/thiếu → quy thành tiền
   - **F10** — Phân bổ bơm nước: chia điện bơm thực tế cho các đầu mối theo quân số
4. Trang tải lại và hiển thị kết quả mới

> Nếu thay đổi bất kỳ số liệu đầu vào (chỉ số công tơ, quân số, cấu hình), cần nhấn **Tính lại** để bảng tổng hợp cập nhật.

### 4.6 Xem bảng tổng hợp 24 cột (F11)

**Tất cả vai trò.** Bảng tổng hợp hiển thị toàn bộ kết quả tính toán tháng theo chuẩn mẫu 24 cột.

<!-- Screenshot: Bảng tổng hợp 24 cột — header nhiều tầng, dòng tổng cộng, nút Xuất CSV -->

**Truy cập:** Menu → **Bảng tổng hợp** → `/monthly_summary`

**Cấu trúc 24 cột:**

| Nhóm cột | Cột | Nội dung |
|---|---|---|
| Thông tin | 1 | Số thứ tự |
| Thông tin | 2 | Tên đầu mối |
| Quân số | 3–9 | Số lượng theo 7 nhóm cấp bậc |
| Quân số | 10 | Tổng quân số |
| Tiêu chuẩn | 11 | Tiêu chuẩn điện (kW) |
| Tiêu chuẩn | 12 | Tiêu chuẩn bơm nước (kW) |
| Khoản trừ | 13 | Tiết kiệm (kW) |
| Khoản trừ | 14 | Tổn hao (kW) |
| Khoản trừ | 15 | Công cộng Sư đoàn (kW) |
| Khoản trừ | 16 | Công cộng đơn vị (kW) |
| Tiêu chuẩn | 17 | Tiêu chuẩn còn lại sau trừ (kW) |
| Điều chỉnh | 18 | Cột Khác (kW, có thể âm) |
| Tiêu chuẩn | 19 | Tiêu chuẩn cuối (kW) |
| Sử dụng | 20 | Sử dụng thực tế (kWh) |
| Thừa/Thiếu | 21 | Thừa tiêu chuẩn (kW) |
| Thừa/Thiếu | 22 | Thiếu tiêu chuẩn (kW) |
| Thừa/Thiếu | 23 | Thừa tiêu chuẩn (đồng) |
| Thừa/Thiếu | 24 | Thiếu tiêu chuẩn (đồng) |

---

## 5. Báo cáo và tra cứu

Tất cả vai trò đều truy cập được các chức năng trong mục này (trong phạm vi đơn vị mình).

### 5.1 Dashboard tổng quan (F12)

<!-- Screenshot: Trang chủ Dashboard — biểu đồ cột/đường, bảng tổng kết tháng/quý/năm, chọn kỳ -->

**Truy cập:** Menu → **Trang chủ** → `/dashboard`

Trang chủ hiển thị tổng quan tiêu thụ điện:
- **Chế độ xem:** Tháng / Quý / Năm (chọn từ tab hoặc bộ lọc)
- **Biểu đồ:** So sánh tiêu chuẩn và sử dụng thực tế
- **Bảng tổng kết:** Tổng thừa/thiếu theo đơn vị hoặc đầu mối
- admin_level1 xem được toàn bộ 13 đơn vị; admin_unit và commander chỉ thấy đơn vị mình

### 5.2 Tra cứu lịch sử (F13)

<!-- Screenshot: Trang Tra cứu lịch sử — bộ lọc kỳ, đơn vị, so sánh cùng kỳ năm trước -->

**Truy cập:** Menu → **Tra cứu lịch sử** → `/history`

Tra cứu số liệu các kỳ đã hoàn thành:
- Chọn **kỳ tính** và **đơn vị** cần tra cứu
- Xem số liệu chi tiết từng cột
- So sánh với cùng kỳ năm trước (nếu có dữ liệu)

### 5.3 Xuất CSV (F14)

Xuất dữ liệu ra file CSV để xử lý trong Excel hoặc lưu trữ báo cáo. Nút **Xuất CSV** có trên 3 trang:
- **Bảng tổng hợp** (`/monthly_summary`) — toàn bộ 24 cột kỳ hiện tại
- **Tra cứu lịch sử** (`/history`) — số liệu kỳ đang xem
- **Trang chủ** (`/dashboard`) — số liệu tổng kết

---

## 6. Quản trị hệ thống

### 6.1 Quản lý tài khoản (F15)

**admin_level1 + tech.**

<!-- Screenshot: Trang Quản lý tài khoản — bảng danh sách người dùng, trạng thái khóa/hoạt động, nút Thêm -->

**Truy cập:** Menu → **Quản lý tài khoản** → `/users`

**Thêm tài khoản mới:**
1. Nhấn **Thêm tài khoản**
2. Điền: Họ tên, Địa chỉ email, Vai trò, Đơn vị (không áp dụng cho `admin_level1` và `tech`)
3. Hệ thống tạo mật khẩu tạm, đặt cờ bắt buộc đổi mật khẩu (F18)
4. Thông báo mật khẩu tạm cho người dùng

**Sửa thông tin tài khoản:**
- Nhấn **Sửa** → thay đổi họ tên, vai trò, đơn vị → Lưu

**Khóa / Mở khóa tài khoản:**
- Nhấn **Khóa** để vô hiệu hóa tài khoản (người dùng không thể đăng nhập)
- Nhấn **Mở khóa** để khôi phục tài khoản bị khóa (do sai mật khẩu hoặc do admin khóa thủ công)

> Không thể khóa tài khoản admin_level1 duy nhất còn hoạt động — hệ thống sẽ báo lỗi để bảo vệ tính liên tục.

### 6.2 Cấu hình đơn giá điện (F20)

**Chỉ admin_level1.**

<!-- Screenshot: Trang Đơn giá điện — bảng kỳ tính, đơn giá, trạng thái khóa/mở -->

**Truy cập:** Menu → **Đơn giá điện** → `/monthly_periods`

- **Tạo kỳ mới:** Xem [Mục 4.1](#41-tạo-kỳ-tính-mới)
- **Sửa đơn giá kỳ hiện tại:** Nhấn **Sửa** → cập nhật đơn giá (đồng/kWh) → Lưu
- **Mở khóa kỳ đã khóa:** Nhấn **Mở khóa** trên kỳ tương ứng → xác nhận. Dùng khi cần sửa số liệu kỳ cũ đã bị khóa.

> Mở khóa kỳ cũ chỉ thực hiện khi thực sự cần thiết. Sau khi sửa xong, nhớ chạy lại tính toán (F08–F10).

### 6.3 Cấu hình bảng định mức cấp bậc (F21)

**Chỉ admin_level1.**

<!-- Screenshot: Trang Định mức cấp bậc — bảng 7 nhóm, tên cấp bậc, định mức kW, nút Sửa -->

**Truy cập:** Menu → **Định mức cấp bậc** → `/rank_quotas`

Khi có nghị định mới của Bộ Quốc phòng thay đổi định mức tiêu chuẩn điện:
1. Nhấn **Sửa** trên nhóm cấp bậc cần cập nhật
2. Điều chỉnh **Tên cấp bậc** và/hoặc **Định mức (kW/người/tháng)**
3. Nhấn **Lưu**

> Sau khi cập nhật định mức, cần chạy lại tính toán (F08–F10) cho các kỳ áp dụng định mức mới.

### 6.4 Nhật ký hoạt động (F19)

**admin_level1 + tech.**

<!-- Screenshot: Trang Nhật ký hoạt động — bộ lọc người dùng/loại/ngày, bảng sự kiện, cột giá trị cũ/mới -->

**Truy cập:** Menu → **Nhật ký hoạt động** → `/audit_logs`

Nhật ký ghi lại mọi thay đổi dữ liệu trong hệ thống (tạo mới, sửa, xóa):
- **Bộ lọc:** Theo người thực hiện, loại dữ liệu (Đầu mối, Công tơ, Quân số...), khoảng thời gian
- **Xem chi tiết:** Mỗi dòng hiển thị: thời gian, người thực hiện, loại thao tác, giá trị cũ, giá trị mới
- Nhật ký chỉ đọc — không thể hoàn tác từ đây

### 6.5 Sao lưu và phục hồi

**Chỉ tech.**

<!-- Screenshot: Trang Sao lưu dữ liệu — danh sách file backup, nút Sao lưu ngay, nút Phục hồi, nút Tải về -->

**Truy cập:** Menu → **Sao lưu dữ liệu** → `/backups`

**Sao lưu dữ liệu:**
1. Nhấn **Sao lưu ngay**
2. Hệ thống tạo file sao lưu toàn bộ cơ sở dữ liệu (định dạng pg_dump)
3. File mới xuất hiện trong danh sách kèm thời gian tạo và kích thước

**Tải về bản sao lưu:**
- Nhấn **Tải về** trên dòng bản sao lưu cần tải — lưu file về máy để bảo quản ngoài hệ thống

**Phục hồi dữ liệu:**
1. Nhấn **Phục hồi**
2. Chọn file sao lưu (tải lên từ máy tính)
3. Xác nhận — toàn bộ dữ liệu hiện tại sẽ bị **thay thế** bởi dữ liệu trong file sao lưu
4. Hệ thống thực hiện phục hồi và thông báo kết quả

> Phục hồi dữ liệu là thao tác không thể hoàn tác. Chỉ thực hiện khi thực sự cần thiết và đã có bản sao lưu của dữ liệu hiện tại.

**Xóa bản sao lưu cũ:**
- Nhấn **Xóa** trên dòng tương ứng để giải phóng dung lượng lưu trữ

---

## 7. Quy trình nghiệp vụ hàng tháng

Dưới đây là thứ tự thực hiện chuẩn mỗi tháng. Các bước **phải thực hiện đúng thứ tự** — không thể tính toán nếu chưa có đủ dữ liệu đầu vào.

| Bước | Thao tác | Chức năng | Người thực hiện | Lưu ý |
|:---:|---|:---:|---|---|
| 1 | Tạo kỳ tính mới, nhập đơn giá | F20 | admin_level1 | Kỳ cũ tự động khóa |
| 2 | Cấu hình tỷ lệ cấp Sư đoàn (tiết kiệm, công cộng Sư đoàn) | F04 | admin_level1 | Nhập lại mỗi kỳ |
| 3 | Nhập số điện lực đồng hồ tổng | F05 | admin_level1 | Lấy từ hóa đơn điện lực |
| 4 | Cấu hình tỷ lệ đơn vị (tiết kiệm, công cộng đơn vị, cột Khác) | F04 | admin_unit | Nhập lại mỗi kỳ |
| 5 | Nhập chỉ số công tơ đầu kỳ và cuối kỳ | F06 | admin_unit (+ admin_level1) | Đầu kỳ thường kế thừa tự động |
| 6 | Soát lại quân số, đánh dấu Đã soát | F07 | admin_unit (+ admin_level1) | Điều chỉnh nếu có thay đổi nhân sự |
| 7 | Chạy tính toán | F08–F10 | admin_unit (+ admin_level1) | Nhấn nút "Tính lại" |
| 8 | Kiểm tra bảng tổng hợp 24 cột | F11 | Tất cả | Xem kết quả thừa/thiếu |
| 9 | Xuất CSV báo cáo | F14 | Tất cả | Lưu trữ hoặc gửi Ban Doanh trại |

**Lưu ý quan trọng:**

- Chỉ **admin_level1** tạo kỳ mới và mở khóa kỳ cũ
- Sau khi tạo kỳ mới, kỳ cũ bị khóa — mọi sửa đổi kỳ cũ cần admin_level1 mở khóa trước
- Nếu sửa bất kỳ số liệu nào sau bước 7, phải chạy lại **Tính lại** để bảng tổng hợp cập nhật
- Bước 4, 5, 6 có thể thực hiện song song bởi các đơn vị khác nhau

---

## 8. Câu hỏi thường gặp

**Q1: Quên mật khẩu, làm thế nào?**

Hệ thống không hỗ trợ tự đặt lại mật khẩu qua email. Liên hệ **admin_level1** hoặc **tech** để đặt lại mật khẩu tạm qua menu Quản lý tài khoản (F15). Khi đăng nhập lại, hệ thống sẽ yêu cầu đổi mật khẩu mới (F18).

---

**Q2: Tài khoản bị khóa, làm thế nào?**

Liên hệ **admin_level1** hoặc **tech**. Họ vào menu **Quản lý tài khoản** (F15), tìm tài khoản và nhấn **Mở khóa**. Sau khi mở khóa, đăng nhập lại bình thường.

---

**Q3: Nhập sai số liệu của kỳ đã khóa, sửa lại được không?**

Được, nhưng cần **admin_level1** vào menu **Đơn giá điện** (F20), tìm kỳ tương ứng và nhấn **Mở khóa**. Sau khi mở khóa, sửa số liệu rồi nhấn **Tính lại** để cập nhật bảng tổng hợp.

---

**Q4: Đã nhập đủ số liệu nhưng bảng tổng hợp chưa thay đổi?**

Bảng tổng hợp không tự cập nhật. Vào menu **Bảng tổng hợp** → nhấn nút **Tính lại** để engine tính toán chạy lại và cập nhật kết quả.

---

**Q5: Cột "Khác" hiển thị số âm — có bị lỗi không?**

Không. Giá trị âm trong cột "Khác" là hoàn toàn bình thường. Giá trị âm có nghĩa là tăng tiêu chuẩn cho đầu mối đó (ví dụ: phân bổ thêm tiêu chuẩn điện cho bộ phận bảo đảm). Đây là tính năng nghiệp vụ có chủ đích.

---

**Q6: Không thấy menu "Đơn giá điện" và "Định mức cấp bậc" trong thanh điều hướng?**

Hai menu này chỉ hiển thị với **admin_level1**. Nếu bạn là admin_unit, commander hoặc tech, hai mục này sẽ bị ẩn. Tương tự, menu **Sao lưu dữ liệu** chỉ hiện với **tech**.

---

**Q7: Nên sao lưu dữ liệu bao nhiêu lần và khi nào?**

Không giới hạn số lần sao lưu. Khuyến nghị:
- Sao lưu **trước khi tạo kỳ tính mới** mỗi tháng
- Sao lưu **trước khi phục hồi dữ liệu** từ file cũ
- Sao lưu **trước khi thay đổi cấu hình lớn**

---

**Q8: Xuất CSV ở đâu?**

Nút **Xuất CSV** có mặt trên 3 trang:
- **Bảng tổng hợp** (`/monthly_summary`) — xuất toàn bộ 24 cột kỳ hiện tại
- **Tra cứu lịch sử** (`/history`) — xuất số liệu kỳ đang xem
- **Trang chủ** (`/dashboard`) — xuất số liệu tổng kết

File CSV có thể mở trực tiếp bằng Microsoft Excel hoặc LibreOffice Calc.
