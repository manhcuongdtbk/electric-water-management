# Lộ trình triển khai (nội bộ) — v3.1

> File này chỉ dành cho mình. Scope nghiệp vụ, danh sách chức năng, thanh toán, bảo hành → xem **SCOPE_DOCUMENT_v3_0_2.html**

---

## Tổng quan

| | |
|---|---|
| **Timeline** | 14/4 – 15/5/2026 (mục tiêu khách), hard deadline 25/5 |
| **Nghỉ lễ** | 30/4 – 1/5 (Giải phóng + Quốc tế Lao động) |
| **Tech stack** | Rails 8 + PostgreSQL + Tailwind + Hotwire + Devise + CanCanCan + paper_trail + Chartkick + pagy + ransack + RSpec + Docker |
| **Scope** | 21 chức năng (F01–F21) + sao lưu/phục hồi (không có F#), xem chi tiết trong SCOPE_DOCUMENT_v3_0_2.html |
| **Cách làm** | Ship early, iterate. Cái gì rõ làm trước, cái gì chưa rõ để khách dùng thử rồi feedback |

### Ghi chú tech stack

- **Rails 8** — Rails 7.0 và 7.1 đã hết hỗ trợ (EOL tháng 10/2025). Dự án mới không có lý do dùng bản cũ.
- **Tailwind** — tích hợp sẵn Rails 8 qua `tailwindcss-rails`, không cần Node. Styling nhanh cho 1 developer.
- **Hotwire (Turbo + Stimulus)** — đi kèm Rails 8 mặc định. Turbo xử lý form submit không reload trang, Stimulus xử lý behavior động (thêm/bớt công tơ, flash messages).
- **Devise** — xác thực tiêu chuẩn ngành, battle-tested. Module Lockable (F17 — khóa sau 5 lần sai), Timeoutable (F18 — tự đăng xuất 2 giờ), Trackable có sẵn. Quan trọng: tài liệu bảo mật gửi khách quân đội có trọng lượng hơn so với tự code authentication.
- **CanCanCan** — phân quyền. Dự án chỉ có 4 vai trò cố định, ~8 model → file Ability ~40–60 dòng, quản lý được. Pundit mạnh hơn cho ứng dụng phức tạp nhưng overkill ở đây.
- **Chartkick** — biểu đồ so sánh tiêu chuẩn vs sử dụng (F12). Dùng Chart.js bên dưới. Nếu cần custom nhiều hơn thì chuyển sang Chart.js trực tiếp.
- **pagy** — pagination nhẹ nhất, nhanh nhất.
- **ransack** — search/filter/sort trên bảng. Tiết kiệm thời gian so với viết scope thủ công cho 5–6 bảng.
- **RSpec** — test framework. Developer đã có kinh nghiệm với RSpec. Đặc biệt quan trọng cho engine tính toán bảng 22 cột (milestone rủi ro cao nhất).
- **Không dùng Motor Admin / Rails Admin** — nghiệp vụ phức tạp (bảng 22 cột, 4 khoản trừ, bơm nước), custom Motor Admin tốn hơn viết Rails views thuần. AI hỗ trợ code nên effort CRUD thêm không đáng kể. UI đồng nhất, không có 2 giao diện khác nhau.
- **Không dùng ancestry** — chỉ 2 cấp phẳng (Sư đoàn → 13 đơn vị), dùng cột `parent_id` là đủ.

### Nghiệp vụ đã xác nhận hoàn tất (21/04/2026)

Toàn bộ nghiệp vụ tính toán đã được anh Thảo xác nhận. 3 câu hỏi bổ sung (vị trí không tổn hao, cột "Khác" âm, gộp bảng sử dụng) đã xác nhận ngày 21/04. Không còn mục nào chờ confirm về mặt nghiệp vụ. Chi tiết xem XAC_NHAN_NGHIEP_VU_v5_2_0.html hoặc SCOPE_DOCUMENT_v3_0_2.html.

### Quyết định chiến lược (12/04/2026)

- **Giá:** Giữ nguyên giá đã thống nhất, chấp nhận effort tăng
- **Ship early:** Không chờ xác nhận 100% mới code. Giao từng phần để khách phản hồi sớm
- **Scope v3:** Không blocking — code song song. Scope có thể iterate (v3, v4...)
- **Báo cáo:** Hoàn thiện dần dựa trên phản hồi thực tế, không chờ xác nhận trước
- **Xuất file:** CSV trước. Excel đúng mẫu Cục Doanh trại khi có file mẫu
- **Chuyển dữ liệu cũ:** KHÔNG LÀM

---

## Gantt

```
Tuần     14/4    21/4    28/4    5/5     12/5  15/5  25/5
         ├───────┼───────┼───────┼───────┼─────┼─────┤
M1       ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  Nền tảng ✅ DONE
M2       ░░░░░░░░████████████████████░░░░░░░░░░░░░░░░  Nghiệp vụ ✅ DONE
M3       ░░░░░░░░░░░░░░░░░░░░████████████░░░░░░░░░░░  Phân quyền ✅ DONE
M4       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░░░░░░  Báo cáo
M5       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░░  Vận hành
M6       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████  Bàn giao
         └───────┴───────┴───────┴───────┴─────┴─────┘
                                 30/4-1/5 nghỉ lễ  ▲15/5  ▲25/5
                                                   mục tiêu  buffer

Các milestone chồng lấn nhau — bắt đầu milestone tiếp khi milestone trước đủ ổn, không chờ xong hẳn.
```

---

## M1: Nền tảng — 14/4 → 23/4

Database + CRUD khai báo + Docker dev. Đây là phần rõ nhất, code ngay được.

### Database

- [ ] Schema chính:
  - `organizations` — Sư đoàn (cấp 1), 13 đơn vị cấp 2. Chỉ 2 cấp phẳng, dùng cột `parent_id`
  - `users` — Devise + role (quản trị viên cấp 1 / quản trị viên đơn vị / chỉ huy đơn vị / kỹ thuật)
  - `contact_points` (đầu mối) — thuộc đơn vị, ví dụ: Ban Tác huấn, Tổ xe... (Sư đoàn bộ có 46 đầu mối)
  - `meters` (công tơ) — thuộc đầu mối, có flag: thường / công cộng / trạm bơm nước / vị trí không tổn hao
  - `personnel` (quân số) — theo đầu mối, 7 nhóm cấp bậc
  - `rank_quotas` (bảng định mức cấp bậc) — 7 dòng, mặc định 570/440/305/130/210/110/24 kW, quản trị viên cấp 1 sửa khi có nghị định mới (F21)
  - `monthly_periods` — kỳ tính theo tháng, lưu đơn giá (F20), trạng thái khóa
  - `meter_readings` — chỉ số đầu/cuối công tơ theo tháng
  - `monthly_calculations` — kết quả tính toán bảng 22 cột theo đầu mối theo tháng
  - `unit_configs` — tỷ lệ tiết kiệm (cấp 1), tỷ lệ công cộng Sư đoàn (cấp 1), tỷ lệ công cộng đơn vị (đơn vị tự cấu hình), cột "Khác" (F04)
  - `pump_stations` — trạm bơm nước, liên kết với meter + nhóm đối tượng phục vụ
- [ ] Seed data: 13 đơn vị cấp 2, 46 đầu mối Sư đoàn bộ (từ v5 section 8)
- [ ] paper_trail cho tất cả model có nhập liệu

### Khai báo ban đầu (F01–F04)

- [ ] F01: Khai báo đầu mối trong đơn vị — CRUD, thuộc đơn vị. Thêm bớt linh động
- [ ] F02: Khai báo công tơ trong mỗi đầu mối — CRUD, thuộc đầu mối. Flag: thường / công cộng / trạm bơm nước / vị trí không tổn hao. Công tơ công cộng không xuất hiện trong bản thu tiền. Công tơ "vị trí không tổn hao" (ví dụ: đặt tại trạm biến áp) bỏ qua khi tính tổn hao phân bổ
- [ ] F03: Khai báo quân số theo 7 nhóm cấp bậc — theo đầu mối. Phần mềm tự tính tiêu chuẩn
- [ ] F04: Cấu hình tỷ lệ và cột "Khác" — tiết kiệm 5–10% (cấp 1), công cộng Sư đoàn 5–10% (cấp 1), công cộng đơn vị 10–20% (đơn vị tự cấu hình), cột "Khác" (nhập số hoặc hệ số × số người; cho phép giá trị âm — âm = cộng ngược vào tiêu chuẩn, lấy từ đầu mối khác). Tổn hao: phần mềm tự tính, không cần khai báo
- [ ] i18n tiếng Việt

### Docker dev

- [ ] docker-compose: Rails + PostgreSQL
- [ ] Dockerfile cơ bản, polish thành production ở M5

### Test

- [ ] RSpec setup (rspec-rails, factory_bot_rails, shoulda-matchers)
- [ ] Test model validations + associations cơ bản

**Demo:** Vào web, thấy danh sách đơn vị, thêm/sửa đầu mối, công tơ, quân số, cấu hình tỷ lệ.

---

## M2: Nghiệp vụ tính toán — 21/4 → 5/5

Đây là milestone phức tạp nhất — nhập liệu hàng tháng, engine tính toán bảng 22 cột, bơm nước, kế thừa tháng.

### Nhập liệu hàng tháng (F05–F07)

- [ ] F05: Nhập số điện lực (đồng hồ tổng) — số liệu điện lực cung cấp cho đơn vị trong tháng. Quản trị viên đơn vị tự nhập
- [ ] F06: Nhập chỉ số công tơ đầu kỳ, cuối kỳ — cho từng công tơ. Phần mềm tự tính sử dụng = cuối kỳ − đầu kỳ
- [ ] F07: Soát lại quân số — tháng sau tự kế thừa tháng trước (đầu mối, công tơ, quân số). Chỉ sửa chỗ có thay đổi. Dữ liệu tháng cũ bị khóa, chỉ quản trị viên cấp 1 mở khóa

### Tính toán (F08–F10)

- [ ] F08: Tính toán tiêu chuẩn theo nghị định 02 — tiêu chuẩn = tổng(số người × định mức kW) + (tổng quân số × 9,45 kW bơm nước). Trừ 4 khoản: tiết kiệm (%), tổn hao (phân bổ theo tỷ lệ kW), công cộng (2 cấp: Sư đoàn + đơn vị), khác (cho phép âm — âm = cộng ngược vào tiêu chuẩn). Tổn hao nằm trong "Số phải trừ" (trừ khỏi tiêu chuẩn). Kết quả: "tiêu chuẩn còn lại"
- [ ] F09: Tính toán sử dụng và so sánh — tổng sử dụng = sử dụng công tơ (không cộng tổn hao) + bơm nước thực tế. So sánh với tiêu chuẩn còn lại, tính thâm điện, nhân đơn giá ra thành tiền. Đơn giá thay đổi hàng tháng
- [ ] F10: Phân bổ điện bơm nước thực tế — trạm bơm có đồng hồ điện riêng, quản lý như công tơ. Tổng điện bơm chia cho các đơn vị theo quân số. Quản trị viên có thể chỉ định trạm bơm phục vụ nhóm đối tượng cụ thể

### Bảng 22 cột (F11)

- [ ] F11: Bảng tổng hợp theo tháng (bảng 22 cột) — hiển thị bảng tính chi tiết từng đầu mối: quân số, tiêu chuẩn, các khoản trừ, còn được hưởng, thành tiền. Đúng cấu trúc bảng mẫu đơn vị đang dùng

**Demo:** Nhập chỉ số công tơ tháng + đồng hồ tổng → hệ thống tự tính bảng 22 cột → xem kết quả, đối chiếu với file Excel khách.

### ⚠ Đây là milestone rủi ro cao nhất

- Bảng 22 cột có nhiều cột phụ thuộc lẫn nhau — cần test kỹ từng cột
- Bơm nước 2 khái niệm (tiêu chuẩn 9,45 kW cố định vs sử dụng thực tế phân bổ) dễ nhầm
- 4 khoản trừ với logic khác nhau (%, phân bổ theo tỷ lệ kW, 2 cấp)
- Tổn hao trừ khỏi tiêu chuẩn (không cộng vào sử dụng) — khác trực giác
- Nếu tính sai ở đây → báo cáo M4 sai theo
- **Cách kiểm tra:** So sánh kết quả với dữ liệu thật từ file `bang tính điện thảo tháng 02 làm lại THU CƠ QUAN.xlsx`
- **RSpec:** Test engine tính toán là ưu tiên cao nhất — test từng cột bảng 22 cột với dữ liệu thật, đảm bảo kết quả khớp file Excel khách

---

## M3: Phân quyền — 2/5 → 9/5

### Đăng nhập + Bảo mật (F15–F18)

- [ ] Devise setup: modules `database_authenticatable`, `recoverable`, `lockable`, `timeoutable`, `trackable`
- [ ] F15: Quản lý tài khoản người dùng — tạo, khóa, mở khóa. Gán vai trò + đơn vị. Quản trị viên cấp 1 quản lý toàn bộ. Không có đăng ký tự do (quản trị viên tạo tài khoản)
- [ ] F16: Đăng nhập bằng tài khoản, mật khẩu — bắt buộc đổi mật khẩu lần đầu (custom flag `force_password_change`)
- [ ] F17: Khóa tài khoản khi nhập sai mật khẩu — Devise Lockable, sau 5 lần sai liên tiếp. Cần quản trị viên mở lại
- [ ] F18: Tự động đăng xuất khi không thao tác — Devise Timeoutable, sau 2 giờ

### Phân quyền 3 vai trò + kỹ thuật

- [ ] CanCanCan ability:
  - Quản trị viên cấp 1: quản lý toàn bộ, cấu hình Sư đoàn (tỷ lệ tiết kiệm, công cộng Sư đoàn, định mức, đơn giá), mở khóa tháng cũ, tạo tài khoản
  - Quản trị viên đơn vị: chỉ thao tác trong đơn vị mình (khai báo F01–F03, cấu hình đơn vị trong F04, nhập liệu F05–F07, đẩy số liệu)
  - Chỉ huy đơn vị: chỉ xem và kiểm tra số liệu, không thao tác được gì
  - Kỹ thuật: quản lý tài khoản (F15), xem nhật ký (F19), sao lưu
- [ ] Scope dữ liệu: mỗi đơn vị chỉ thấy dữ liệu mình
- [ ] Test: tạo tài khoản các vai trò, thử truy cập chéo → bị chặn

**Demo:** Đăng nhập 3–4 tài khoản khác vai trò, chứng minh phân quyền đúng.

---

## M4: Báo cáo + Tra cứu — 7/5 → 16/5

### Báo cáo tổng hợp (F12)

- [ ] F12: Báo cáo tổng hợp — theo tháng, quý, năm. Biểu đồ so sánh tiêu chuẩn và sử dụng (Chartkick). Nhận biết đơn vị / đầu mối vượt tiêu chuẩn. Chi tiết báo cáo hoàn thiện dần dựa trên phản hồi thực tế
- [ ] Dashboard tổng quan (không có F# riêng, là trang chủ tích hợp từ F11 + F12): metric cards tổng tiêu chuẩn / tiêu thụ / chênh lệch, đếm đầu mối vượt tiêu chuẩn, chọn tháng/năm

### Tra cứu lịch sử (F13)

- [ ] F13: Tra cứu lịch sử và so sánh cùng kỳ — tra cứu dữ liệu tháng bất kỳ năm trước. So sánh cùng kỳ theo từng đầu mối (tổng sử dụng tất cả công tơ trong đầu mối, so với cùng tháng năm trước)

### Xuất file (F14)

- [ ] F14: Xuất báo cáo ra file — CSV để mở bằng Excel, in hoặc lưu trữ. Excel đúng mẫu Cục Doanh trại: chỉ làm khi có file mẫu từ khách

**Demo:** Xem dashboard → mở bảng 22 cột → báo cáo tổng hợp với biểu đồ → tra cứu lịch sử → so sánh cùng kỳ → xuất CSV.

### Ghi chú

- Báo cáo chi tiết hoàn thiện dần dựa trên phản hồi thực tế khi khách dùng thử các phần trước
- Không cố hoàn thiện 100% báo cáo trước khi khách dùng phần nhập liệu

---

## M5: Vận hành — 14/5 → 19/5

### Cấu hình hệ thống (F19–F21)

- [ ] F19: Nhật ký thay đổi dữ liệu — paper_trail, ai sửa gì lúc nào, giá trị cũ/mới. Tìm theo người / thời gian / dữ liệu. Đội kỹ thuật và quản trị viên cấp 1 xem được
- [ ] F20: Cấu hình đơn giá điện — quản trị viên cấp 1 nhập theo tháng. Giá thay đổi hàng tháng theo quy định
- [ ] F21: Cấu hình bảng định mức cấp bậc — quản trị viên cấp 1 chỉnh sửa bảng 7 nhóm + định mức kW khi có nghị định mới

### Quản lý đơn vị

- [ ] Quản trị viên cấp 1 thêm/bớt đơn vị cấp 2 (nằm trong scope phân quyền cấp 1, không có F# riêng)

### Sao lưu và phục hồi (không có F#, nằm trong scope "Trong phạm vi")

- [ ] Script pg_dump / pg_restore
- [ ] Giao diện đơn giản cho đội kỹ thuật

### Docker production

- [ ] Multi-stage build, asset precompile
- [ ] docker-compose production: Rails + PostgreSQL + Nginx
- [ ] Harden: RAILS_ENV=production, secure headers
- [ ] README deploy cho đội kỹ thuật

### Tài liệu

- [ ] Tài liệu hướng dẫn sử dụng
- [ ] Tài liệu hướng dẫn vận hành cho đội kỹ thuật

**Deliverable:** Docker image + README + tài liệu.

---

## M6: Bàn giao — 17/5 → 25/5

- [ ] Khách test trên staging
- [ ] Fix bug, adjust UI theo phản hồi
- [ ] Đào tạo sử dụng cơ bản (~1–2 tiếng)
- [ ] Đào tạo vận hành cho đội kỹ thuật (~1–2 tiếng)
- [ ] Bàn giao: source code, Docker image, tài liệu sử dụng, tài liệu vận hành
- [ ] Ký biên bản nghiệm thu

---

## Rủi ro

| Rủi ro | Khả năng | Impact | Giải pháp |
|--------|----------|--------|-----------|
| Bảng 22 cột tính sai | **Cao** | **Cao** | RSpec test từng cột với dữ liệu thật từ file Excel khách. So sánh kết quả |
| Scope creep từ phản hồi "dùng thử" | **Cao** | TB | Scope v3 = ranh giới. Phản hồi hợp lý → iterate. Tính năng mới → giai đoạn 2 |
| Báo cáo chưa đúng ý khách | TB | TB | Ship early — giao sớm, sửa theo feedback thực tế. Không cố đoán trước |
| Devise custom phức tạp (đổi mật khẩu lần đầu, không cho đăng ký tự do) | Thấp | TB | Logic đơn giản, Devise documentation đầy đủ. AI hỗ trợ code |
| Ốm (1 người, 0 buffer) | Thấp | **Cao** | Timeline có buffer (~1 tuần). Chấp nhận rủi ro |
| Khách chậm test M6 | TB | Cao | Set kỳ vọng: cần người test từ 17/5. Giao từng phần để test dần |

---

## Giao tiếp

- Phản hồi khách trong 24h qua Zalo
- Gom câu hỏi, không nhắn lẻ tẻ
- Demo theo milestone — giao sớm để khách dùng thử
- Phản hồi hợp lý → iterate ngay. Tính năng mới → ghi nhận cho giai đoạn 2

---

## Thông tin chờ khách

| # | Nội dung | Trạng thái |
|---|----------|------------|
| 1 | File mẫu Excel Cục Doanh trại (để xuất báo cáo đúng mẫu — F14) | ⏳ Chưa có — xuất CSV trước |
| 2 | Mẫu xuất báo cáo 2 bảng (anh Thảo hẹn gửi 22/04/2026) | ⏳ Chờ nhận — input cho F12/F14 |

Tất cả các mục khác từ v2 (cách nhập tiêu chuẩn, cách nhập tiêu thụ, cây đơn vị, phân quyền, cách tính nước, migrate dữ liệu) đã được giải quyết trong quá trình xác nhận nghiệp vụ v5.

---

## Mapping chức năng → milestone

| F# | Tên (đúng SCOPE_DOCUMENT_v3_0_2) | Milestone | Ghi chú |
|----|------|-----------|---------|
| F01 | Khai báo đầu mối trong đơn vị | M1 | Khai báo ban đầu |
| F02 | Khai báo công tơ trong mỗi đầu mối | M1 | Khai báo ban đầu |
| F03 | Khai báo quân số theo 7 nhóm cấp bậc | M1 | Khai báo ban đầu |
| F04 | Cấu hình tỷ lệ và cột "Khác" | M1 | Khai báo ban đầu |
| F05 | Nhập số điện lực (đồng hồ tổng) | M2 | Nhập liệu hàng tháng |
| F06 | Nhập chỉ số công tơ đầu kỳ, cuối kỳ | M2 | Nhập liệu hàng tháng |
| F07 | Soát lại quân số | M2 | Nhập liệu hàng tháng (kế thừa + khóa) |
| F08 | Tính toán tiêu chuẩn theo nghị định 02 | M2 | Tính toán — engine |
| F09 | Tính toán sử dụng và so sánh | M2 | Tính toán — engine |
| F10 | Phân bổ điện bơm nước thực tế | M2 | Tính toán — engine |
| F11 | Bảng tổng hợp theo tháng (bảng 22 cột) | M2 | Tính toán — hiển thị |
| F12 | Báo cáo tổng hợp | M4 | Biểu đồ + bảng theo tháng/quý/năm |
| F13 | Tra cứu lịch sử và so sánh cùng kỳ | M4 | Theo từng đầu mối |
| F14 | Xuất báo cáo ra file | M4 | CSV trước, Excel khi có mẫu |
| F15 | Quản lý tài khoản người dùng | M3 | Tạo, khóa, mở, gán vai trò |
| F16 | Đăng nhập bằng tài khoản, mật khẩu | M3 | Đổi mật khẩu lần đầu |
| F17 | Khóa tài khoản khi nhập sai mật khẩu | M3 | Sau 5 lần sai |
| F18 | Tự động đăng xuất khi không thao tác | M3 | Sau 2 giờ |
| F19 | Nhật ký thay đổi dữ liệu | M5 | paper_trail |
| F20 | Cấu hình đơn giá điện | M5 | Theo tháng, cấp 1 nhập |
| F21 | Cấu hình bảng định mức cấp bậc | M5 | 7 nhóm, sửa khi có NĐ mới |
| — | Sao lưu và phục hồi | M5 | Không có F#, nằm trong scope |
| — | Quản lý đơn vị cấp 2 (thêm/bớt) | M5 | Không có F#, quyền cấp 1 |

---

## Log

**1/4** — Kickoff. Nhận Slide.ppt. Rút ra: 15 đơn vị (phẳng), giá 2092.20đ, NĐ 76/2016 + TT 36/2017.

**1/4 – 6/4** — Nhiều vòng trao đổi nghiệp vụ qua Zalo. Phân tích file Excel khách (bảng tính tháng 02, mẫu theo dõi F bộ). Phát hiện: Sư đoàn (không phải Lữ đoàn), 13 đơn vị, bảng 22 cột, 7 nhóm cấp bậc, bơm nước 2 khái niệm, 4 khoản trừ, 46 đầu mối Sư đoàn bộ. Xác nhận nghiệp vụ qua 5 phiên bản (v1→v5).

**6/4** — Anh Thảo xác nhận "Ok" cho toàn bộ nghiệp vụ v5. Đề xuất thêm tra cứu lịch sử + so sánh cùng kỳ. Đề cập giai đoạn 2 (báo cáo lên trên, tiếp nhận từ trên xuống).

**6/4 – 12/4** — Cập nhật SCOPE_DOCUMENT v2 → v3 dựa trên nghiệp vụ v5. Quyết định chiến lược: giữ giá, ship early, timeline 25/5, không chuyển dữ liệu cũ.

**12/4** — Scope v3 xong, sẵn sàng gửi khách. PROJECT_ROADMAP v2 → v3. Tech stack chốt: Rails 8 + PostgreSQL + Tailwind + Hotwire + Devise + CanCanCan + paper_trail + Chartkick + pagy + ransack + RSpec + Docker. Bỏ Motor Admin / Rails Admin / ancestry.

**14/4 – 20/4** — M1–M3 hoàn tất (688 specs). Pre-M4 hoàn tất. Railway staging live với data thật tháng 02. Screenshot specs, HUONG_DAN_SU_DUNG v1.2.0, XAC_NHAN_NGHIEP_VU v5.1.0, SCOPE_DOCUMENT v3.0.1 hoàn thành. Gửi 3 file PDF lên Zalo group.

**21/4** — Anh Thảo xác nhận 3 câu hỏi mở trong v5.1.0 (vị trí không tổn hao, cột "Khác" âm, gộp bảng sử dụng). Duyệt scope v3.0.1. Hẹn gửi mẫu xuất báo cáo 2 bảng ngày 22/04. Deadline mong muốn: 15/5. Cập nhật XAC_NHAN_NGHIEP_VU v5.2.0, SCOPE_DOCUMENT v3.0.2, PROJECT_ROADMAP v3.1.
