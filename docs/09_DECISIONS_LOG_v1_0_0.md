# 09. Nhật ký quyết định / Decisions Log — v1.0.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án. Tra thuật ngữ tại 02_GLOSSARY.
>
> **Mục đích file này:** Ghi lại các quyết định kỹ thuật và nghiệp vụ quan trọng — cái gì đã chọn, tại sao, phương án nào đã bỏ. Giúp developer hiểu context khi đọc code hoặc khi cần thay đổi kiến trúc.
>
> **Quy ước:** Mỗi quyết định ghi rõ: bối cảnh, phương án đã chọn, phương án đã bỏ (nếu có), lý do. Sắp theo nhóm, không theo thời gian.

---

## Mục lục

1. [Quyết định chiến lược dự án](#1-quyết-định-chiến-lược-dự-án)
2. [Tech stack](#2-tech-stack)
3. [Kiến trúc database](#3-kiến-trúc-database)
4. [Engine tính toán](#4-engine-tính-toán)
5. [Phân quyền và bảo mật](#5-phân-quyền-và-bảo-mật)
6. [Giao diện và UX](#6-giao-diện-và-ux)
7. [Hạ tầng và deploy](#7-hạ-tầng-và-deploy)
8. [Nghiệp vụ — các quyết định đã xác nhận với khách](#8-nghiệp-vụ--các-quyết-định-đã-xác-nhận-với-khách)
9. [Tech debt đã ghi nhận](#9-tech-debt-đã-ghi-nhận)

---

## 1. Quyết định chiến lược dự án

### D01. Giữ nguyên giá, chấp nhận effort tăng

- **Bối cảnh:** Sau khi phân tích nghiệp vụ chi tiết (7 nhóm cấp bậc, 4 khoản trừ, bơm nước 2 khái niệm, bảng 22 cột), effort thực tế lớn hơn ước lượng ban đầu đáng kể.
- **Đã chọn:** Giữ nguyên giá đã thống nhất với khách. Chấp nhận effort tăng.
- **Lý do:** Dự án fixed-price, giá đã cam kết. Mối quan hệ lâu dài quan trọng hơn lợi nhuận ngắn hạn. Phase 2 có thể bù lại.

### D02. Ship early, iterate

- **Bối cảnh:** Nghiệp vụ phức tạp, nhiều điểm cần phản hồi thực tế (báo cáo, biểu đồ, layout bảng 24 cột).
- **Đã chọn:** Giao từng milestone để khách dùng thử, không chờ hoàn thiện 100%.
- **Đã bỏ:** Phát triển xong toàn bộ rồi mới demo.
- **Lý do:** Phản hồi sớm giúp sửa hướng đi kịp thời. Đặc biệt quan trọng với khách non-tech — thấy sản phẩm thật mới biết mình cần gì.

### D03. Không chuyển dữ liệu cũ

- **Bối cảnh:** Phần mềm cũ (WinForms) có dữ liệu lịch sử nhiều năm.
- **Đã chọn:** Không import dữ liệu từ phần mềm cũ. Phần mềm mới bắt đầu từ data mới.
- **Lý do:** Cấu trúc dữ liệu cũ khác hoàn toàn (15 đơn vị phẳng vs 2 cấp, số nhóm cấp bậc khác). Effort mapping + verify dữ liệu cũ rất lớn, không tương xứng với giá trị mang lại. Khách đồng ý.

### D04. Timeline 25/5/2026 (hard deadline)

- **Bối cảnh:** Khách mong muốn 15/5, developer đánh giá cần buffer.
- **Đã chọn:** Mục tiêu 15/5, buffer đến 25/5.
- **Lý do:** 1 developer duy nhất, 0 buffer nếu ốm. Nghỉ lễ 30/4–1/5 mất 2 ngày.

---

## 2. Tech stack

### D05. Rails 8 (không phải Rails 7)

- **Đã chọn:** Rails 8.
- **Đã bỏ:** Rails 7.0, 7.1.
- **Lý do:** Rails 7.0 và 7.1 đã hết hỗ trợ (EOL tháng 10/2025). Dự án mới không có lý do dùng bản cũ.

### D06. Không dùng Motor Admin / Rails Admin

- **Bối cảnh:** Ban đầu dự kiến dùng Motor Admin để tiết kiệm thời gian CRUD.
- **Đã chọn:** Viết Rails views thuần (controllers + views + partials).
- **Đã bỏ:** Motor Admin, Rails Admin.
- **Lý do:** Nghiệp vụ phức tạp (bảng 24 cột, 4 khoản trừ, bơm nước 2 khái niệm) → custom Motor Admin tốn hơn viết views thuần. AI hỗ trợ code nên effort CRUD thêm không đáng kể. UI đồng nhất — không có 2 giao diện khác nhau gây confuse.

### D07. Không dùng ancestry

- **Bối cảnh:** Cần mô hình tổ chức phân cấp.
- **Đã chọn:** Cột `parent_id` trực tiếp trên bảng `organizations`.
- **Đã bỏ:** Gem `ancestry`.
- **Lý do:** Chỉ 2 cấp phẳng (Sư đoàn → 13 đơn vị). ancestry overkill cho cấu trúc đơn giản này. `parent_id` đủ.

### D08. Devise thay vì tự viết authentication

- **Đã chọn:** Devise với modules: `database_authenticatable`, `lockable`, `timeoutable`, `trackable`.
- **Đã bỏ:** Tự viết authentication.
- **Lý do:** Devise là tiêu chuẩn ngành, battle-tested. Module Lockable (F17), Timeoutable (F18) có sẵn. Quan trọng: tài liệu bảo mật từ Devise gửi khách quân đội có trọng lượng hơn so với tự code.

### D09. CanCanCan thay vì Pundit

- **Đã chọn:** CanCanCan.
- **Đã bỏ:** Pundit.
- **Lý do:** Dự án chỉ có 4 vai trò cố định, khoảng 8 model → file Ability khoảng 40–60 dòng, quản lý được. Pundit mạnh hơn cho ứng dụng phức tạp nhưng overkill ở đây. CanCanCan hỗ trợ `accessible_by` — pattern quan trọng cho scope isolation (mỗi đơn vị chỉ thấy data mình). CanCanCan dùng hash conditions (không blocks) để hỗ trợ `accessible_by` (xem 02_GLOSSARY mục 12).

### D10. Tailwind (không cần Node)

- **Đã chọn:** Tailwind qua `tailwindcss-rails`.
- **Lý do:** Tích hợp sẵn Rails 8, không cần Node. Styling nhanh cho 1 developer.

### D11. Chartkick cho biểu đồ

- **Đã chọn:** Chartkick (dùng Chart.js bên dưới).
- **Lý do:** API đơn giản, tích hợp Rails tốt. Nếu cần custom nhiều hơn thì chuyển sang Chart.js trực tiếp.

### D12. RSpec (không Minitest)

- **Đã chọn:** RSpec + FactoryBot + Shoulda Matchers.
- **Lý do:** Developer đã có kinh nghiệm. Đặc biệt quan trọng cho engine tính toán bảng 24 cột — test từng cột với dữ liệu thật từ file Excel khách.

---

## 3. Kiến trúc database

### D13. BigDecimal cho tất cả cột tiền và kW

- **Đã chọn:** Kiểu `decimal` (BigDecimal trong Ruby) cho tất cả cột liên quan tiền và kW.
- **Đã bỏ:** `float`.
- **Lý do:** Tránh sai số làm tròn trong tính toán tài chính. Ví dụ: 0.1 + 0.2 ≠ 0.3 với float. Không làm tròn số ở bất kỳ đâu trong engine tính toán.

### D14. Hardcode 7 nhóm cấp bậc trong schema

- **Đã chọn:** Cột cố định `rank1_count` đến `rank7_count` trong bảng `personnel` và `monthly_calculations`.
- **Đã bỏ:** Thiết kế dynamic (bảng riêng cho số quân mỗi nhóm, join với `rank_quotas`).
- **Lý do:** 7 nhóm đã cố định hàng chục năm theo nghị định. Query đơn giản hơn, performance tốt hơn, code dễ hiểu hơn. Tên nhóm và định mức kW đã dynamic (đọc từ `rank_quotas`). Nếu nghị định mới thay đổi **số lượng** nhóm → cần migration (xem tech debt mục 9).

### D15. Tách bảng `unit_configs` thay vì nhúng vào `organizations`

- **Đã chọn:** Bảng `unit_configs` riêng, lưu tỷ lệ tiết kiệm, công cộng Sư đoàn, công cộng đơn vị — theo đơn vị và theo tháng.
- **Lý do:** Tỷ lệ thay đổi theo năm/tháng. Nếu nhúng vào `organizations` thì mất lịch sử. Tách ra cho phép track cấu hình theo từng kỳ.

### D16. paper_trail cho tất cả model có nhập liệu

- **Đã chọn:** Gem `paper_trail` cho audit log.
- **Lý do:** Yêu cầu nghiệp vụ (F19): ai sửa gì, lúc nào, giá trị cũ/mới. Khách quân đội cần truy vết thay đổi. `whodunnit` = user ID.

---

## 4. Engine tính toán

### D17. Tổn hao trừ khỏi tiêu chuẩn (không cộng vào sử dụng)

- **Bối cảnh:** File Excel gốc của khách cộng tổn hao vào sử dụng. Tuy nhiên, nghiệp vụ quy định tổn hao nằm trong "Số phải trừ".
- **Đã chọn:** Tổn hao trừ ở cột 16 (Số phải trừ), không cộng vào cột 20 (Sử dụng).
- **Lý do:** Tuân theo quy tắc nghiệp vụ "Số phải trừ" mà khách xác nhận. Kết quả cuối cùng (thừa/thiếu) tương đương về mặt toán học. Xem 13_BUSINESS_RULES mục 10.1 cho so sánh chi tiết.

### D18. Tách cột Chênh lệch và Thành tiền (22 → 24 cột, PR#62)

- **Bối cảnh:** Mẫu Excel gốc dùng 1 cột "Chênh lệch" (giá trị dương = thừa, âm = thiếu) và 1 cột "Thành tiền".
- **Đã chọn:** Tách thành 4 cột: Thừa (kW), Thiếu (kW), Thừa (đồng), Thiếu (đồng). Bảng 22 → 24 cột.
- **Lý do:** Tránh nhầm lẫn khi đọc số âm/dương. Dòng tổng tính riêng (tổng Thừa, tổng Thiếu) — không bù trừ. Phản hồi từ anh Hưng (21/04/2026).

### D19. Tên nhóm cấp bậc đọc từ database (không i18n, PR#63)

- **Bối cảnh:** Ban đầu tên 7 nhóm hardcode trong `config/locales/vi.yml`. Khi admin sửa tên qua F21, UI không cập nhật.
- **Đã chọn:** Tất cả trang đọc `rank_name` từ bảng `rank_quotas` trong database.
- **Đã bỏ:** i18n hardcode.
- **Lý do:** Admin cần sửa được tên nhóm khi có nghị định mới (F21). Tech debt phát hiện 24/04, fix ngay PR#63.

---

## 5. Phân quyền và bảo mật

### D20. Hash conditions (không blocks) trong CanCanCan Ability

- **Đã chọn:** Dùng hash conditions trong Ability class.
- **Đã bỏ:** Block conditions.
- **Lý do:** Hash conditions hỗ trợ `accessible_by` — pattern cốt lõi cho scope isolation (mỗi đơn vị chỉ thấy data mình). Block conditions không hỗ trợ `accessible_by`.

### D21. admin_level1 explicit `cannot :manage, :backup`

- **Bối cảnh:** admin_level1 có `can :manage, :all`. Backup/restore là tính năng hạ tầng chỉ dành cho tech.
- **Đã chọn:** Explicit `cannot :manage, :backup` cho admin_level1.
- **Lý do:** Least privilege principle. admin_level1 quản lý nghiệp vụ, không quản lý hạ tầng. Restore database có thể gây mất dữ liệu — chỉ tech mới nên làm.

### D22. Password policy: 8+ ký tự, chữ + số

- **Đã chọn:** Tối thiểu 8 ký tự, bắt buộc có cả chữ và số.
- **Lý do:** Cân bằng giữa bảo mật và dễ dùng cho khách quân đội (nhiều người lớn tuổi, ít quen công nghệ).

### D23. Lock → unlock: KHÔNG bắt đổi mật khẩu

- **Bối cảnh:** Khi tài khoản bị khoá (5 lần sai), admin mở khoá.
- **Đã chọn:** Sau khi mở khoá, user đăng nhập lại bằng mật khẩu cũ. Không bắt đổi mật khẩu.
- **Lý do:** Nếu bắt đổi mật khẩu, admin phải tạo mật khẩu tạm → gửi cho user → user đổi → phức tạp quy trình. Khoá chỉ vì nhập sai, không phải vì bị xâm nhập.

### D24. Timeout 2 giờ (không phải 30 phút)

- **Bối cảnh:** Scope v3.0 ban đầu ghi 30 phút.
- **Đã chọn:** 2 giờ.
- **Lý do:** 30 phút quá ngắn cho workflow nhập liệu thực tế (admin_unit có thể nhập công tơ cho 40+ đầu mối). Thay đổi trong quá trình triển khai, cập nhật scope v3.0.1.

---

## 6. Giao diện và UX

### D25. Giao diện tiếng Việt, code tiếng Anh

- **Đã chọn:** UI (view, flash message, label) bằng tiếng Việt qua i18n (`config/locales/vi.yml`). Code (model, biến, comment, commit message) bằng tiếng Anh.
- **Lý do:** Khách quân đội Việt Nam dùng tiếng Việt. Developer cần code tiếng Anh để dễ maintain.

### D26. Không viết tắt trong UI

- **Đã chọn:** Viết đầy đủ tên nhóm cấp bậc, đơn vị, thuật ngữ trên giao diện.
- **Đã bỏ:** Viết tắt ("BC", "TC", "CL", "MK", "QS").
- **Lý do:** Bài học rút ra — viết tắt trong demo khiến khách quân đội đọc không hiểu, trông thiếu chuyên nghiệp. Ngoại lệ: "SQ" (Sĩ quan) là viết tắt khách dùng — giữ nguyên.

### D27. Bảng 24 cột: Thừa = xanh, Thiếu = đỏ

- **Đã chọn:** Màu xanh cho cột Thừa, đỏ cho cột Thiếu.
- **Lý do:** Trực quan, quen thuộc. Thừa = tốt (xanh), thiếu = cần trả tiền (đỏ).

---

## 7. Hạ tầng và deploy

### D28. Docker cho cả dev và production

- **Đã chọn:** Docker Compose cho cả 2 môi trường. `docker-compose.yml` (dev), `docker-compose.production.yml` (production: Rails + PostgreSQL + Nginx).
- **Lý do:** Đảm bảo consistency giữa môi trường. Đội kỹ thuật khách (non-developer) có thể triển khai bằng `docker compose up`.

### D29. Railway cho staging (tạm thời)

- **Bối cảnh:** Cần staging nhanh để demo cho khách.
- **Đã chọn:** Railway — auto-deploy on push to main.
- **Lưu ý:** Railway là giải pháp tạm. Production sẽ chạy trên Mini PC tại đơn vị (mạng nội bộ, không internet).

### D30. Production trên Mini PC (on-premise)

- **Đã chọn:** Deploy trên Mini PC Optori P54M, Ubuntu 24.04, Docker, 2 SSD với autorestic backup, fixed IP, local HTTPS certs, Netdata + Uptime Kuma monitoring.
- **Đã bỏ:** Cloud hosting.
- **Lý do:** Đơn vị quân đội yêu cầu mạng nội bộ, không kết nối internet. Data nhạy cảm phải ở on-premise.

### D31. Nginx reverse proxy trong production

- **Đã chọn:** Nginx trong Docker Compose production: reverse proxy, gzip, security headers, /assets/ long-cache (expires 1 year).
- **Lý do:** Rails Puma không nên expose trực tiếp. Nginx xử lý static assets, SSL termination, security headers.

### D32. Backup bằng pg_dump, không backup application-level

- **Đã chọn:** `pg_dump` toàn bộ database.
- **Đã bỏ:** Export data theo model (CSV/JSON).
- **Lý do:** pg_dump đảm bảo consistency toàn bộ database. Restore = trạng thái chính xác tại thời điểm backup. Application-level export phức tạp hơn, dễ thiếu data.

---

## 8. Nghiệp vụ — các quyết định đã xác nhận với khách

Chi tiết đầy đủ xem 13_BUSINESS_RULES. Ở đây chỉ ghi quyết định ở dạng tóm tắt.

### D33. Cấu trúc 2 cấp (Sư đoàn → 13 đơn vị)

- **Thay đổi từ:** Ban đầu hiểu là "Lữ đoàn 164" với 15 đơn vị phẳng.
- **Xác nhận:** Sư đoàn (cấp 1) → 13 đơn vị cấp 2. Không có cấp trung gian.

### D34. 7 nhóm cấp bậc theo bảng mẫu mới (không theo nghị định gốc)

- **Thay đổi từ:** Tên dài theo nghị định gốc ("sĩ quan có cấp bậc quân hàm cao nhất là...").
- **Xác nhận:** Tên rút gọn theo bảng mẫu khách gửi. Ví dụ: "Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá".

### D35. Bơm nước = điện bơm (không dùng mét khối)

- **Thay đổi từ:** Scope v2 tính nước bằng mét khối riêng.
- **Xác nhận:** Nước = điện bơm nước (kW), nằm trong luồng tính toán điện. Không có đồng hồ nước.

### D36. Gộp bảng sử dụng vào bảng 24 cột

- **Thay đổi từ:** File Excel gốc có 2 sheet riêng ("Sheet1 (2)" cho tiêu chuẩn, "SD điện" cho sử dụng).
- **Xác nhận:** Phần mềm gộp thành 1 bảng. Khách: "để theo dõi có thể trên phần mềm để gộp như e đang làm tiện theo dõi cũng được".

### D37. Vị trí không tổn hao (meter_type: `no_loss`)

- **Phát sinh từ:** Data thật tháng 02 — Tiểu đoàn 18 có công tơ tại trạm biến áp.
- **Xác nhận:** Thêm tuỳ chọn "Vị trí không tổn hao". Phần mềm bỏ qua khi tính tổn hao phân bổ.

### D38. Cột "Khác" cho phép giá trị âm

- **Phát sinh từ:** Data thật tháng 02 — đầu mối "Bảo đảm" có Khác = −296.
- **Xác nhận:** Cho phép âm. Âm = cộng ngược vào tiêu chuẩn.

---

## 9. Tech debt đã ghi nhận

| # | Mô tả | Ảnh hưởng | Khả năng xảy ra | Ghi chú |
|---|---|---|---|---|
| 1 | Hardcode 7 nhóm cấp bậc trong schema (`rank1_count`–`rank7_count`) | Nếu nghị định thay đổi **số lượng** nhóm → migration thêm/bớt cột cả 2 bảng (`personnel`, `monthly_calculations`) + sửa CalculationEngine + views + specs | Rất thấp — 7 nhóm cố định hàng chục năm | Tên và định mức đã dynamic. Chỉ số lượng nhóm là hardcode. |
| 2 | Auto-save F06 (Stimulus + localStorage) | Nếu admin_unit đang nhập chỉ số công tơ cho 40+ đầu mối và mất kết nối/timeout → mất data chưa save | Trung bình | Đóng giai đoạn 1, có thể thêm ở phase 2 |
| 3 | Cleanup Vietnamese commit messages M1–M3 | Commit messages cũ bằng tiếng Việt, không đúng convention | Không ảnh hưởng chức năng | Cleanup planned cuối dự án |
