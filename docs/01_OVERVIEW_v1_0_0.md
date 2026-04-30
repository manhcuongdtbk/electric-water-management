# 01 — Tổng quan dự án

> **Phiên bản:** v1.0.0 — 24/04/2026
>
> File này cung cấp bối cảnh tổng thể: dự án giải quyết vấn đề gì, cho ai, bằng công nghệ nào, trong thời gian bao lâu, và cách đọc bộ tài liệu. Đọc file này trước khi đọc bất kỳ file nào khác trong thư mục `docs/`.
>
> Thuật ngữ sử dụng trong file này tuân theo `02_GLOSSARY_v1_2_0.md`.

---

## 1. Bài toán

Một Sư đoàn thuộc Quân đội Nhân dân Việt Nam đang quản lý tiêu chuẩn và tiêu thụ điện năng hàng tháng cho 13 đơn vị trực thuộc bằng phần mềm WinForms cũ kết hợp bảng tính Excel. Quy trình hiện tại có nhiều hạn chế:

- Phần mềm WinForms chạy trên một máy tính duy nhất, không truy cập được từ xa, không chia sẻ dữ liệu giữa các đơn vị.
- Mỗi tháng, kế toán đơn vị phải gửi số liệu về Sư đoàn qua file Excel, Ban Doanh trại (bộ phận thuộc Sư đoàn chịu trách nhiệm quản lý điện nước — xem `02_GLOSSARY` mục 1) tổng hợp thủ công.
- Bảng tính toán (gốc 22 cột, nay 24 cột — xem `02_GLOSSARY` mục 3) chứa công thức phức tạp: 7 nhóm cấp bậc với định mức khác nhau theo Nghị định 02 của Bộ Quốc phòng (xem `02_GLOSSARY` mục 6), điện bơm nước, 4 khoản trừ — dễ sai khi thao tác thủ công.
- Không có phân quyền, không có nhật ký thay đổi, không có cơ chế sao lưu và phục hồi.

Dự án này xây dựng ứng dụng web thay thế toàn bộ quy trình trên. Bên đặt hàng là Ban Doanh trại Sư đoàn.

---

## 2. Phạm vi sản phẩm

Ứng dụng web gồm 21 chức năng (đánh số F01–F21) cùng tính năng sao lưu và phục hồi (không có F-number riêng — đây là tính năng hạ tầng, không phải chức năng nghiệp vụ). Các chức năng chia thành 5 nhóm:

- **Khai báo ban đầu (F01–F04):** Quản lý đầu mối, công tơ (4 loại: thường, công cộng, trạm bơm, vị trí không tổn hao), quân số theo 7 nhóm cấp bậc, cấu hình tỷ lệ và khoản trừ "Khác" (khoản trừ đặc thù từng đầu mối, cho phép giá trị âm — xem `02_GLOSSARY` mục 4). Xem `02_GLOSSARY` mục 8.1.
- **Nhập liệu hàng tháng (F05–F07):** Nhập số điện lực (đồng hồ tổng), chỉ số công tơ (đầu kỳ kế thừa tự động từ cuối kỳ tháng trước), soát lại quân số. Xem `02_GLOSSARY` mục 8.2.
- **Tính toán tự động (F08–F10):** Engine tính bảng 24 cột — tiêu chuẩn theo Nghị định 02, sử dụng thực tế, 4 khoản trừ (tiết kiệm, tổn hao, công cộng, khác), phân bổ bơm nước, so sánh thừa/thiếu, thành tiền. Xem `02_GLOSSARY` mục 8.3 và chi tiết tại `13_BUSINESS_RULES_v1_1_0.md` (khi có).
- **Báo cáo và tra cứu (F11–F14):** Bảng tổng hợp 24 cột, dashboard so sánh tiêu chuẩn và sử dụng (tháng, quý, năm), tra cứu lịch sử và so sánh cùng kỳ, xuất CSV. Xem `02_GLOSSARY` mục 8.4.
- **Quản trị hệ thống (F15–F21):** Quản lý tài khoản, đăng nhập, khoá tài khoản sau 5 lần sai, bắt buộc đổi mật khẩu lần đầu, nhật ký hoạt động, quản lý đơn giá, quản lý định mức cấp bậc. Xem `02_GLOSSARY` mục 8.5.

Chi tiết phạm vi dự án (trong scope, ngoài scope, thanh toán, bảo hành) xem `12_SCOPE_v1_0_0.md` (khi có).

---

## 3. Cấu trúc tổ chức

Hệ thống phục vụ cấu trúc 2 cấp phẳng (dùng `parent_id`, không dùng thư viện ancestry — chỉ có 2 cấp nên không cần cây đa tầng):

- **Cấp 1 — Sư đoàn (`Organization`, level: `division`):** 1 tổ chức duy nhất. Quản lý bởi Ban Doanh trại.
- **Cấp 2 — 13 đơn vị trực thuộc (`Organization`, level: `unit`):** Liên kết với Sư đoàn qua `parent_id`.

Danh sách đầy đủ 14 tổ chức (1 Sư đoàn + 13 đơn vị) xem `02_GLOSSARY` mục 11.

Bên dưới đơn vị cấp 2 là các **đầu mối** (`ContactPoint`) — đơn vị nhỏ nhất có công tơ điện riêng. Ví dụ: Ban Tác huấn, Tổ xe, Nhà ăn. Sư đoàn bộ có 79 đầu mối (data tháng 02/2026). Mỗi đầu mối có ít nhất một công tơ (`Meter`) và một bản ghi quân số (`Personnel`) theo 7 nhóm cấp bậc. Tóm lại hierarchy dữ liệu là: Sư đoàn → Đơn vị → Đầu mối → (Công tơ + Quân số).

### 4 vai trò người dùng

| Vai trò | Code | Thuộc | Mô tả | Phạm vi dữ liệu |
|---------|------|-------|-------|-----------------|
| Quản trị viên cấp 1 | `admin_level1` | Sư đoàn | Ban Doanh trại. Cấu hình toàn hệ thống: đơn giá, tiết kiệm, công cộng Sư đoàn, định mức cấp bậc. Mở khoá kỳ cũ. | Xem và thao tác tất cả đơn vị |
| Quản trị viên đơn vị | `admin_unit` | 1 đơn vị cấp 2 | Kế toán đơn vị. CRUD đầu mối, công tơ, quân số. Nhập liệu hàng tháng. Cấu hình công cộng đơn vị. | Chỉ đơn vị mình |
| Chỉ huy đơn vị | `commander` | 1 đơn vị cấp 2 | Kiểm tra số liệu. Chỉ xem, không thao tác. | Chỉ đơn vị mình |
| Kỹ thuật | `tech` | Sư đoàn | Quản lý tài khoản (F15), nhật ký hoạt động (F19), sao lưu và phục hồi. Không truy cập dữ liệu nghiệp vụ. | Tất cả đơn vị (chỉ đọc data hệ thống) |

Chi tiết quyền từng vai trò xem `02_GLOSSARY` mục 7.

---

## 4. Người liên quan

| Người | Vai trò trong dự án | Ghi chú |
|-------|---------------------|---------|
| Anh Thảo | Khách hàng chính | Senior. Giao tiếp qua group Zalo. Phê duyệt mọi yêu cầu nghiệp vụ. |
| Anh Hưng | Đồng nghiệp anh Thảo | Gửi file và ảnh khi anh Thảo yêu cầu. Đề xuất tách cột Thừa/Thiếu (22→24 cột, PR#62). |
| Anh Phương | Cố vấn IT, người dẫn mối | Giới thiệu developer với anh Thảo. Review tài liệu trước khi gửi khách. Phụ trách setup Mini PC production (Ubuntu 24.04, Docker). |
| Developer (manhcuongdtbk) | Solo developer và PM | Phát triển toàn bộ hệ thống, tài liệu, triển khai. |

Cả ba (anh Thảo, anh Hưng, anh Phương) đều senior hơn developer. Giao tiếp chính qua group Zalo. Tài liệu gửi khách dùng giọng trung tính, chuyên nghiệp, không xưng hô anh/em.

---

## 5. Timeline

| Mốc | Thời gian | Nội dung | Specs | Trạng thái |
|-----|-----------|---------|-------|-----------|
| M1 — Nền tảng | 14/04 → 23/04 | Database, CRUD khai báo F01–F04, Docker dev | 247 | ✅ |
| M2 — Nghiệp vụ | 21/04 → 05/05 | Nhập liệu F05–F07, CalculationEngine F08–F10, Bảng 22 cột F11 | 388 | ✅ |
| M3 — Phân quyền | 02/05 → 09/05 | Devise F15–F18, CanCanCan Ability 4 vai trò | 546 | ✅ |
| Pre-M4 — Ổn định | 09/05 → 12/05 | Bug fix, deploy Railway, import data thật tháng 02, system specs | 688 | ✅ |
| M4 — Báo cáo | 12/05 → 15/05 | Dashboard F12 (tháng/quý/năm), tra cứu lịch sử F13, CSV F14 | 771 | ✅ |
| M5 — Vận hành | 15/05 → 20/05 | Đơn giá F20, định mức F21, nhật ký F19, sao lưu và phục hồi, Docker production | 836 | ✅ |
| M6 — Bàn giao | 20/05 → 25/05 | Staging, fix bug, tài liệu, đào tạo, nghiệm thu | 853+ | đang làm |
| Nghỉ lễ | 30/04 → 01/05 | Giải phóng miền Nam + Quốc tế Lao động | — | — |
| **Mục tiêu khách** | **15/05/2026** | Anh Thảo yêu cầu qua Zalo 21/04 | — | — |
| **Hard deadline** | **25/05/2026** | Buffer 10 ngày | — | — |

Các milestone chồng lấn nhau — bắt đầu milestone tiếp khi milestone trước đủ ổn, không chờ xong hẳn.

### Quyết định chiến lược (12/04/2026)

Đây là dự án fixed-price. Các quyết định chiến lược được chốt trước khi bắt đầu code:

- **Giá cố định:** Giữ nguyên giá đã thống nhất, chấp nhận effort tăng nếu phát sinh.
- **Ship early:** Không chờ xác nhận 100% mới code. Giao từng phần để khách phản hồi sớm.
- **Scope iterate:** Scope document có thể nâng version (v1 → v2 → v3), không blocking code.
- **Báo cáo:** Hoàn thiện dần dựa trên phản hồi thực tế, không chờ xác nhận trước.
- **Xuất file:** CSV trước. Excel đúng mẫu Cục Doanh trại khi có file mẫu.
- **Chuyển dữ liệu cũ:** Không làm.

Lý do và phương án đã bỏ xem `09_DECISIONS_LOG_v1_0_0.md` (khi có).

---

## 6. Tech stack và lý do lựa chọn

| Thành phần | Lựa chọn | Tại sao |
|-----------|----------|---------|
| Framework | Rails 8 | Rails 7.0 và 7.1 đã hết hỗ trợ (EOL tháng 10/2025). Dự án mới không có lý do dùng bản cũ. |
| Database | PostgreSQL | Tiêu chuẩn ngành. Hỗ trợ `decimal` tốt cho tính toán kW (dự án dùng BigDecimal, không float). Backup/restore qua `pg_dump`/`pg_restore`. |
| CSS | Tailwind (via `tailwindcss-rails`) | Tích hợp sẵn Rails 8, không cần Node. Styling nhanh cho 1 developer. |
| Frontend | Hotwire (Turbo + Stimulus) | Đi kèm Rails 8 mặc định. Turbo xử lý form submit không reload trang. Stimulus xử lý behavior động (thêm/bớt công tơ, tính realtime quân số trên form F03). |
| Xác thực | Devise | Battle-tested. Module Lockable (khoá sau 5 lần sai — F17), Timeoutable (tự đăng xuất sau 2 giờ — không có F-number riêng, là tính năng Devise tự động), Trackable có sẵn. Tài liệu bảo mật Devise có trọng lượng khi gửi khách quân đội, so với tự code authentication. |
| Phân quyền | CanCanCan | 4 vai trò cố định, khoảng 8 model → file Ability khoảng 40–60 dòng, quản lý được. Dùng hash conditions (không blocks) để hỗ trợ `accessible_by` — pattern quan trọng cho scope isolation giữa các đơn vị. Pundit mạnh hơn cho ứng dụng phức tạp nhưng overkill ở đây. |
| Audit log | PaperTrail | Theo dõi thay đổi trên mọi model có nhập liệu. Ghi `whodunnit` (user ID), `item_type` (model name), giá trị cũ/mới. Lưu trong bảng `versions`. Xem `02_GLOSSARY` mục 10 và 12. |
| Biểu đồ | Chartkick (Chart.js) | Biểu đồ so sánh tiêu chuẩn và tiêu thụ (F12). Đủ dùng cho dashboard đơn giản. |
| Phân trang | pagy | Nhẹ nhất, nhanh nhất. |
| Tìm kiếm và lọc | ransack | Search, filter, sort trên bảng. Tiết kiệm thời gian so với viết scope thủ công cho nhiều bảng. |
| Test | RSpec + FactoryBot + Shoulda Matchers | Developer đã có kinh nghiệm. Đặc biệt quan trọng cho CalculationEngine (bảng 24 cột — milestone rủi ro cao nhất). Test với data thật từ file Excel khách (`test/fixtures/files/bang_tinh_thang_02.xlsx`). |
| Container | Docker | Development (Docker local) và production (Docker Compose: Rails + PostgreSQL + Nginx). Staging tạm trên Railway, sẽ chuyển sang VPS. |

### Phương án đã cân nhắc và bỏ

| Phương án | Lý do bỏ |
|----------|----------|
| Motor Admin / Rails Admin | Nghiệp vụ phức tạp (bảng 24 cột, 4 khoản trừ, bơm nước), custom admin framework tốn hơn viết Rails views thuần. AI hỗ trợ code nên effort CRUD không đáng kể. UI đồng nhất, tránh 2 giao diện khác nhau gây nhầm lẫn cho khách quân đội. |
| ancestry gem | Chỉ có 2 cấp phẳng (Sư đoàn → 13 đơn vị), dùng cột `parent_id` là đủ. ancestry dành cho cây đa tầng. |
| Node.js build pipeline | Tailwind via `tailwindcss-rails` không cần Node. Giảm dependency, đơn giản hoá deployment cho production trên Mini PC. |

---

## 7. Hạ tầng triển khai

### 3 môi trường

| Môi trường | Hạ tầng | Mục đích |
|-----------|---------|---------|
| Development | Docker local trên máy developer | Phát triển và test nội bộ. |
| Staging | Railway (Singapore region), sẽ chuyển sang VPS Docker | Demo cho khách, test trước production. Tạm giữ Railway, kế hoạch chuyển VPS. |
| Production | Mini PC Optori P54M, Ubuntu 24.04, Docker (app + Nginx + PostgreSQL) | Triển khai chính thức tại đơn vị khách. IP cố định, local HTTPS certs. 2 SSD (1 server + 1 backup via autorestic cron). Anh Phương phụ trách setup. |

### Production structure

Cấu trúc thư mục trên Mini PC: `X/` (root) → `source-code/`, `pgdata/`, `upload/`, `certs/`, `Dockerfile.xxx`, `compose.yml`, cron script. Monitoring dự kiến: Netdata + Uptime Kuma (chỉ viết cách integrate, không cài sẵn). Bên IT khách tự verify bảo mật sau setup.

Chi tiết xem `08_INFRASTRUCTURE_v1_0_0.md` (khi có).

---

## 8. Nghiệp vụ đã xác nhận

Toàn bộ nghiệp vụ tính toán đã được anh Thảo xác nhận (21/04/2026). Không còn mục nào chờ xác nhận về mặt nghiệp vụ.

Tóm tắt nghiệp vụ cốt lõi (chi tiết xem `13_BUSINESS_RULES_v1_1_0.md` khi có, hoặc `02_GLOSSARY` mục 3–5):

- **Bảng 24 cột:** Bảng tính toán chính, gốc 22 cột từ mẫu Excel khách, đã tách cột Chênh lệch thành Thừa + Thiếu và cột Thành tiền thành Thừa (đồng) + Thiếu (đồng) (PR#62). Thừa và Thiếu không bù trừ nhau trong dòng tổng.
- **7 nhóm cấp bậc:** Định mức 570 / 440 / 305 / 130 / 210 / 110 / 24 kW/tháng. Tên nhóm và định mức đọc từ database (`RankQuota`), admin_level1 sửa qua F21 khi có nghị định mới. Cột `effective_from` ghi nhận ngày hiệu lực.
- **Bơm nước 2 khái niệm:** Tiêu chuẩn cố định 9,45 kW/người/tháng (theo Nghị định 02, cộng vào cột 14 "Cộng được hưởng theo NĐ 02") khác với sử dụng bơm nước thực tế (thay đổi hàng tháng, phân bổ từ trạm bơm theo quân số, cộng vào cột 20 "Sử dụng"). Xem `02_GLOSSARY` mục 5.
- **4 khoản trừ:** Tiết kiệm (%), tổn hao (phân bổ theo tỷ lệ kW — công tơ vị trí không tổn hao bị loại khỏi cả tử số lẫn mẫu số), công cộng (2 tỷ lệ: Sư đoàn + đơn vị), khác (cho phép giá trị âm — xem `02_GLOSSARY` mục 4).
- **Tổn hao:** Nằm trong "Số phải trừ" — trừ khỏi tiêu chuẩn, không cộng vào sử dụng.
- **Kế thừa tháng:** Khi mở kỳ mới, đầu mối, công tơ, quân số, cấu hình tự sao chép từ tháng trước. Chỉ số đầu kỳ = chỉ số cuối kỳ tháng trước. Xem `02_GLOSSARY` mục 6.
- **Khoá dữ liệu:** Khi khoá kỳ, admin_unit không sửa được. Chỉ admin_level1 mở khoá.
- **BigDecimal:** Toàn bộ tính toán dùng BigDecimal, không float, không làm tròn trong engine.

---

## 9. Scope giai đoạn 2 (potential)

Ngoài 21 chức năng giai đoạn 1, các yêu cầu sau đã được ghi nhận cho hợp đồng tiếp theo:

1. Thông báo lịch cắt điện (anh Hưng đề xuất)
2. Gửi báo cáo lên trên — cấp 2 → cấp 1 (anh Thảo đề xuất)
3. Tiếp nhận thông tin từ cấp trên — cấp 1 → cấp 2 (anh Thảo đề xuất)
4. Xuất báo cáo đúng mẫu Excel Cục Doanh trại (cần file mẫu từ khách)

---

## 10. Hướng dẫn đọc tài liệu

Bộ tài liệu gồm 14 file Markdown trong thư mục `docs/`, thay thế toàn bộ tài liệu HTML cũ. Mỗi file tự chứa đủ nội dung — đọc file nào cũng hiểu, không cần mở file khác. Cross-reference bằng tên file khi cần tra chi tiết.

### Thứ tự đọc theo nhu cầu

**Mới tham gia dự án:**
1. `01_OVERVIEW` (file này) — bối cảnh tổng thể
2. `02_GLOSSARY` — bảng thuật ngữ, tra cứu Việt ↔ Anh
3. `03_QUICKSTART` — chạy project từ zero

**Hiểu nghiệp vụ:**
1. `02_GLOSSARY` — nắm thuật ngữ trước
2. `13_BUSINESS_RULES` — toàn bộ nghiệp vụ đã xác nhận, công thức, ví dụ số, edge cases
3. `12_SCOPE` — phạm vi dự án, trong/ngoài scope, thanh toán, bảo hành

**Đọc/sửa code:**
1. `02_GLOSSARY` — mapping Việt ↔ Anh cho model/cột (dùng mục 14 Index)
2. `04_DATABASE_MODELS` — schema, associations, validations, tại sao
3. `05_BUSINESS_LOGIC` — CalculationEngine, services, data flow end-to-end
4. `06_AUTH_SECURITY` — Devise, CanCanCan, security patterns
5. `07_UI_CONTROLLERS` — routes, controllers, views, Stimulus, Turbo

**Triển khai / vận hành:**
1. `08_INFRASTRUCTURE` — Docker, production setup, backup, monitoring
2. `14_DEPLOY` — deploy guide hoàn chỉnh

**Sử dụng phần mềm (end user):**
1. `11_USER_GUIDE` — hướng dẫn sử dụng cho 4 vai trò

**Hiểu quyết định đã chốt:**
1. `09_DECISIONS_LOG` — quyết định kỹ thuật + nghiệp vụ, lý do, phương án đã bỏ

**Viết test:**
1. `10_TEST_SUITE` — structure, conventions, cách chạy, cách thêm test mới

### Danh sách đầy đủ 14 file

| # | File | Nội dung chính | Ai tạo |
|---|------|---------------|--------|
| 01 | `01_OVERVIEW` | Bối cảnh, stakeholders, timeline, tech stack, reading guide | Claude chat |
| 02 | `02_GLOSSARY` | Bảng thuật ngữ Việt ↔ Anh, 14 mục, index ngược | Claude chat |
| 03 | `03_QUICKSTART` | Chạy project từ zero: clone, Docker, seed, login, verify | Claude Code |
| 04 | `04_DATABASE_MODELS` | Schema chi tiết, associations, validations, migrations | Claude Code |
| 05 | `05_BUSINESS_LOGIC` | CalculationEngine, services, data flow end-to-end | Claude Code |
| 06 | `06_AUTH_SECURITY` | Devise, CanCanCan Ability, security patterns và fixes | Claude Code |
| 07 | `07_UI_CONTROLLERS` | Routes, controllers, views, Stimulus, Turbo, i18n | Claude Code |
| 08 | `08_INFRASTRUCTURE` | Docker, production setup, backup, monitoring, Railway | Claude Code + chat |
| 09 | `09_DECISIONS_LOG` | Quyết định kỹ thuật + nghiệp vụ, lý do, phương án đã bỏ | Claude chat |
| 10 | `10_TEST_SUITE` | Test structure, conventions, cách chạy, cách thêm | Claude Code |
| 11 | `11_USER_GUIDE` | Hướng dẫn sử dụng cho 4 vai trò | Claude chat |
| 12 | `12_SCOPE` | Phạm vi dự án, F01–F21, thanh toán, bảo hành, phase 2 | Claude chat |
| 13 | `13_BUSINESS_RULES` | Toàn bộ nghiệp vụ đã xác nhận, bảng 24 cột, công thức, ví dụ | Claude chat |
| 14 | `14_DEPLOY` | Deploy guide hoàn chỉnh, production + staging | Claude Code + chat |

### Quy ước chung

- **Ngôn ngữ:** Tiếng Việt. Model name, tên cột, code snippet giữ tiếng Anh.
- **Thuật ngữ:** Mọi thuật ngữ nghiệp vụ dùng đúng theo `02_GLOSSARY`. Nếu phát hiện sai lệch → ghi vào mục TODO cuối file tương ứng.
- **Versioning:** Semantic versioning (v1.0.0). Fix nhỏ → v1.0.1. Thêm nội dung → v1.1.0. Restructure lớn → v2.0.0.
- **Viết tắt:** Không viết tắt trong tài liệu, trừ "SQ" (Sĩ quan — thuật ngữ khách dùng), F-number (F01–F21), PR-number, M-number. Xem `02_GLOSSARY` mục 13.

---

## Changelog

| Version | Ngày | Thay đổi |
|---------|------|---------|
| v1.0.0 | 24/04/2026 | Khởi tạo. |
