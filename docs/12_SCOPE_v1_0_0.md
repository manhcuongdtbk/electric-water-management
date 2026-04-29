# 12. Phạm vi dự án / Project Scope — v1.0.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì, phục vụ ai. Tra thuật ngữ tại 02_GLOSSARY.
>
> **Mục đích file này:** Ghi lại phạm vi dự án đã thống nhất — chức năng nào trong scope, chức năng nào ngoài scope, điều kiện thanh toán, bảo hành, và định hướng phase 2. File này thay thế SCOPE_DOCUMENT_v3_0_3.html.
>
> **Đối tượng đọc:** Developer đọc code, hoặc bất kỳ ai cần biết ranh giới dự án.
>
> **Nghiệp vụ chi tiết:** Xem 13_BUSINESS_RULES cho công thức, ví dụ số, edge cases.

---

## Mục lục

1. [Mục tiêu dự án](#1-mục-tiêu-dự-án)
2. [Danh sách chức năng F01–F21](#2-danh-sách-chức-năng-f01f21)
3. [Sao lưu và phục hồi](#3-sao-lưu-và-phục-hồi)
4. [Trong phạm vi](#4-trong-phạm-vi)
5. [Ngoài phạm vi](#5-ngoài-phạm-vi)
6. [Tiến độ và các mốc bàn giao](#6-tiến-độ-và-các-mốc-bàn-giao)
7. [Thanh toán](#7-thanh-toán)
8. [Bảo hành và hỗ trợ](#8-bảo-hành-và-hỗ-trợ)
9. [Định hướng phase 2](#9-định-hướng-phase-2)
10. [Lịch sử phiên bản scope](#10-lịch-sử-phiên-bản-scope)

---

## 1. Mục tiêu dự án

Xây dựng phần mềm web thay thế phần mềm quản lý điện nước hiện tại (ứng dụng Windows/WinForms), phục vụ quản lý tiêu chuẩn và tiêu thụ điện cho các đơn vị trực thuộc Sư đoàn. Phần mềm mới cho phép nhiều đơn vị cùng truy cập trên mạng nội bộ, mỗi đơn vị quản lý dữ liệu riêng, phân quyền theo cấp.

**Quy trình nghiệp vụ tổng quan:** Khai báo (đầu mối, công tơ, quân số, tỷ lệ) → Nhập hàng tháng (đồng hồ tổng, chỉ số công tơ) → Tính toán (tiêu chuẩn, trừ, so sánh, thu tiền) → Báo cáo (xem, xuất file, tra cứu lịch sử).

---

## 2. Danh sách chức năng F01–F21

### 2.1 Khai báo ban đầu

Quản trị viên đơn vị (xem 02_GLOSSARY mục 7) thực hiện 1 lần khi bắt đầu sử dụng, sửa khi cần.

| F# | Tên | Mô tả |
|---|---|---|
| F01 | Khai báo đầu mối trong đơn vị | Khai báo các đầu mối sử dụng điện (xem 02_GLOSSARY mục 1). Thêm, bớt linh động khi có thay đổi tổ chức. |
| F02 | Khai báo công tơ trong mỗi đầu mối | Mỗi đầu mối có nhiều công tơ, mỗi công tơ có tên riêng. Đánh dấu loại: thường, công cộng (không xuất hiện trong bản thu tiền), trạm bơm nước, hoặc vị trí không tổn hao (xem 02_GLOSSARY mục 2). |
| F03 | Khai báo quân số theo 7 nhóm cấp bậc | Nhập số người theo từng nhóm (xem 02_GLOSSARY mục 9). Phần mềm tự tính tiêu chuẩn. |
| F04 | Cấu hình tỷ lệ và cột "Khác" | Tiết kiệm của Bộ (5–10%, cấp 1), Công cộng dùng chung Sư đoàn (5–10%, cấp 1), Công cộng dùng chung đơn vị (10–20%, đơn vị tự cấu hình), cột "Khác" (cho phép giá trị âm). Tổn hao: phần mềm tự tính, không cần khai báo. Chi tiết 4 khoản trừ xem 13_BUSINESS_RULES mục 5. |

### 2.2 Nhập liệu hàng tháng

Quản trị viên đơn vị thực hiện mỗi tháng.

| F# | Tên | Mô tả |
|---|---|---|
| F05 | Nhập số điện lực (đồng hồ tổng) | Số liệu điện lực cung cấp cho đơn vị trong tháng. Quản trị viên đơn vị tự nhập. |
| F06 | Nhập chỉ số công tơ đầu kỳ, cuối kỳ | Nhập chỉ số cho từng công tơ. Phần mềm tự tính sử dụng = cuối kỳ − đầu kỳ. Chỉ số đầu kỳ tháng sau tự động = cuối kỳ tháng trước. |
| F07 | Soát lại quân số | Tháng sau tự kế thừa tháng trước (đầu mối, công tơ, quân số). Chỉ sửa chỗ thay đổi. Dữ liệu tháng cũ bị khoá — chỉ quản trị viên cấp 1 mở khoá. |

### 2.3 Tính toán và báo cáo

Phần mềm tự động tính toán khi có đủ dữ liệu đầu vào. Chi tiết công thức xem 13_BUSINESS_RULES mục 4–7.

| F# | Tên | Mô tả |
|---|---|---|
| F08 | Tính toán tiêu chuẩn theo Nghị định 02 | Tiêu chuẩn = Σ(quân số × định mức) + bơm nước tiêu chuẩn. Trừ 4 khoản. Kết quả: tiêu chuẩn còn lại. |
| F09 | Tính toán sử dụng và so sánh | Tổng sử dụng = sử dụng công tơ + bơm nước thực tế. So sánh với tiêu chuẩn còn lại → thừa/thiếu → thành tiền. |
| F10 | Phân bổ điện bơm nước thực tế | Trạm bơm có đồng hồ riêng. Tổng điện bơm chia theo quân số. Quản trị viên chỉ định trạm bơm phục vụ nhóm đối tượng cụ thể. |
| F11 | Bảng tổng hợp theo tháng (bảng 24 cột) | Hiển thị bảng tính chi tiết từng đầu mối. Gốc 22 cột theo mẫu Excel khách, đã tách thành 24 cột (xem 02_GLOSSARY mục 3.2). |
| F12 | Báo cáo tổng hợp (tháng/quý/năm) | Biểu đồ so sánh tiêu chuẩn và sử dụng. Nhận biết đơn vị, đầu mối vượt tiêu chuẩn. |
| F13 | Tra cứu lịch sử và so sánh cùng kỳ | Tra cứu dữ liệu tháng bất kỳ. So sánh cùng kỳ theo từng đầu mối (không phải từng công tơ). |
| F14 | Xuất báo cáo ra file CSV | Xuất bảng tổng hợp ra file CSV. |

### 2.4 Quản trị hệ thống và bảo mật

| F# | Tên | Mô tả | Vai trò |
|---|---|---|---|
| F15 | Quản lý tài khoản người dùng | Tạo, khoá, mở khoá tài khoản. Gán vai trò + đơn vị. Không có đăng ký tự do. | tech |
| F16 | Đăng nhập bằng tài khoản, mật khẩu | Mỗi người dùng có tài khoản riêng. | Tất cả |
| F17 | Khoá tài khoản khi nhập sai mật khẩu | Sau 5 lần nhập sai liên tiếp, tài khoản bị khoá. Cần quản trị viên mở lại. | Tự động |
| F18 | Tự động đăng xuất khi không thao tác | Sau 2 giờ không sử dụng, phiên đăng nhập hết hạn. | Tự động |
| F19 | Nhật ký thay đổi dữ liệu | Ghi lại mọi thay đổi: ai sửa, sửa gì, lúc nào, giá trị cũ/mới. | tech, admin_level1 (xem) |
| F20 | Cấu hình đơn giá điện | Nhập đơn giá theo tháng. Giá thay đổi hàng tháng theo quy định. | admin_level1 |
| F21 | Cấu hình bảng định mức cấp bậc | Sửa tên nhóm cấp bậc và định mức kW khi có nghị định mới. | admin_level1 |

**Bắt buộc đổi mật khẩu lần đầu:** Tài khoản mới phải đổi mật khẩu khi đăng nhập lần đầu (F16, custom flag `force_password_change`). Đây không phải F-number riêng mà là hành vi của F16.

---

## 3. Sao lưu và phục hồi

Sao lưu và phục hồi (backup/restore) **không có F-number riêng** — đây là tính năng hạ tầng, không phải chức năng nghiệp vụ. Vai trò `tech` thao tác qua giao diện riêng.

- **Sao lưu:** `pg_dump` toàn bộ database PostgreSQL. File `.dump`. Lưu trong `db/backups/` (bind mount trong Docker).
- **Phục hồi:** `pg_restore` từ file backup. Sign out tất cả user, redirect về login. Database quay về trạng thái tại thời điểm backup.
- **Quản trị viên cấp 1 không có quyền** sao lưu/phục hồi — chỉ `tech`.

Xem 02_GLOSSARY mục 10 và 12 cho chi tiết kỹ thuật.

---

## 4. Trong phạm vi

- Toàn bộ chức năng F01–F21 ở mục 2
- Sao lưu và phục hồi (mục 3)
- Phân quyền theo cấp đơn vị (4 vai trò: admin_level1, admin_unit, commander, tech)
- Tính toán tiêu chuẩn theo Nghị định 02, bảng 24 cột (xem 13_BUSINESS_RULES)
- Phân bổ điện bơm nước từ trạm bơm
- Kế thừa dữ liệu tháng sang tháng, khoá dữ liệu tháng cũ
- Biểu đồ so sánh tiêu chuẩn và sử dụng (F12)
- Tra cứu lịch sử và so sánh cùng kỳ theo đầu mối (F13)
- Xuất báo cáo ra file CSV (F14)
- Nhật ký thay đổi dữ liệu (F19)
- Đóng gói phần mềm (Docker), hỗ trợ triển khai trên mạng nội bộ
- Tài liệu hướng dẫn sử dụng
- Tài liệu hướng dẫn vận hành cho đội kỹ thuật
- Đào tạo sử dụng cơ bản

---

## 5. Ngoài phạm vi

- Tính năng xem sơ đồ bản vẽ cấp điện (có trong phần mềm cũ, không đưa vào phiên bản mới)
- Tải lên hình ảnh hoặc tài liệu
- Kết nối internet hoặc hệ thống bên ngoài
- Ứng dụng trên điện thoại
- Thông báo lịch cắt điện (xem phase 2, mục 9)
- Gửi báo cáo lên cấp trên (xem phase 2, mục 9)
- Tiếp nhận thông tin từ cấp trên xuống (xem phase 2, mục 9)
- Xuất file đúng mẫu Excel của Cục Doanh trại (cần cung cấp file mẫu — xem phase 2, mục 9)
- Phát triển thêm tính năng mới sau bàn giao
- Chuyển dữ liệu từ phần mềm cũ sang phần mềm mới

**Lưu ý:** Các tính năng ngoài phạm vi đã được ghi nhận và có thể triển khai trong phase 2 (mục 9).

---

## 6. Tiến độ và các mốc bàn giao

Dự án triển khai từ 14/4/2026, mục tiêu bàn giao 15/5/2026 (mong muốn khách hàng), hard deadline 25/5/2026.

| Giai đoạn | Tên | Thời gian | Sản phẩm | Trạng thái |
|---|---|---|---|---|
| M1 | Nền tảng | 14/4 – 23/4 | Database + CRUD khai báo F01–F04 + Docker dev | ✅ Hoàn thành |
| M2 | Nghiệp vụ | 21/4 – 5/5 | Nhập liệu F05–F07 + Engine tính toán F08–F10 + Bảng 24 cột F11 | ✅ Hoàn thành |
| M3 | Phân quyền | 2/5 – 9/5 | Đăng nhập F15–F18 + Phân quyền 4 vai trò | ✅ Hoàn thành |
| M4 | Báo cáo | 7/5 – 16/5 | Dashboard F12 + Tra cứu lịch sử F13 + Xuất CSV F14 | ✅ Hoàn thành |
| M5 | Vận hành | 14/5 – 19/5 | F19 nhật ký + F20 đơn giá + F21 định mức + Sao lưu/phục hồi + Docker production | ✅ Hoàn thành |
| M6 | Bàn giao | 17/5 – 25/5 | Staging + Fix bug + Tài liệu + Đào tạo + Nghiệm thu | 🔄 Đang làm |

**Cách làm việc:** Phần mềm bàn giao theo từng giai đoạn để khách xem và phản hồi sớm, không chờ đến cuối mới gửi.

**Điều kiện:** Mốc thời gian trên có thể thay đổi nếu có yêu cầu bổ sung hoặc thay đổi nghiệp vụ. Mọi sự chậm trễ trong việc cung cấp thông tin từ phía khách hàng sẽ đẩy lùi thời gian bàn giao tương ứng.

---

## 7. Thanh toán

**100% trả sau.** Thanh toán toàn bộ sau khi ký biên bản nghiệm thu, khi bên đặt hàng đã kiểm tra và xác nhận phần mềm hoạt động đúng.

---

## 8. Bảo hành và hỗ trợ

- **30 ngày sửa lỗi** sau khi ký biên bản nghiệm thu — nếu phần mềm hoạt động không đúng so với mô tả trong tài liệu scope, sẽ được sửa miễn phí.
- **Hỗ trợ triển khai** — hỗ trợ đội kỹ thuật trong quá trình cài đặt và vận hành ban đầu.
- **Không bao gồm** phát triển tính năng mới, thay đổi nghiệp vụ, hoặc mở rộng phạm vi sau bàn giao.

---

## 9. Định hướng phase 2

Các tính năng dưới đây đã được ghi nhận trong quá trình trao đổi và có thể triển khai sau khi hoàn thành phase 1. Phạm vi, thời gian và chi phí sẽ được thoả thuận riêng cho từng hạng mục.

| # | Tính năng | Người đề xuất | Ghi chú |
|---|---|---|---|
| 1 | Thông báo lịch cắt điện | Anh Hưng | Điện lực thông báo lịch cắt điện, hệ thống hiển thị cho các đơn vị biết |
| 2 | Gửi báo cáo lên cấp trên | Anh Thảo | Đơn vị cấp 2 đẩy báo cáo lên cấp 1 qua hệ thống |
| 3 | Tiếp nhận thông tin từ cấp trên | Anh Thảo | Cấp 1 gửi thông báo, chỉ đạo xuống các đơn vị cấp 2 |
| 4 | Xuất báo cáo đúng mẫu Excel | — | Xuất file đúng mẫu Cục Doanh trại hoặc Tổng cục Hậu cần (cần cung cấp file mẫu) |

---

## 10. Lịch sử phiên bản scope

Tài liệu scope trải qua nhiều phiên bản do nghiệp vụ được làm rõ dần:

| Phiên bản | Thay đổi chính |
|---|---|
| v2.0 | Phiên bản đầu tiên gửi khách. Gọi cấp 1 là "Lữ đoàn 164", 15 đơn vị phẳng, 27 chức năng, nhiều mục "chờ xác nhận". |
| v3.0 | Cập nhật sau khi xác nhận nghiệp vụ: cấp 1 là Sư đoàn, 13 đơn vị, 2 cấp, 21 chức năng, 7 nhóm cấp bậc, bơm nước 2 khái niệm, 4 khoản trừ. |
| v3.0.1 | Sửa F18 (30 phút → 2 giờ). Viết đầy đủ tên 4 khoản trừ. Thanh toán: chỉ còn trả sau. Gộp bảng sử dụng vào bảng 22 cột (thêm cột Sử dụng + Chênh lệch). |
| v3.0.2 | Cập nhật sau xác nhận 3 câu hỏi mở (vị trí không tổn hao, cột "Khác" âm, gộp bảng sử dụng). Khách hàng duyệt. |
| v3.0.3 | Đổi tên 7 nhóm cấp bậc theo bảng mẫu cập nhật (rút gọn, không dùng tên nghị định gốc). |

**Trạng thái hiện tại:** Scope v3.0.3 đã được khách hàng duyệt (Zalo 21/04/2026). Phần mềm triển khai theo scope này.
