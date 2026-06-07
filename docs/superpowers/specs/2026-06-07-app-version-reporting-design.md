---
title: Tự báo cáo phiên bản (application self-version reporting)
version: 0.4.0
status: draft (chờ duyệt)
date: 2026-06-07
---

# Tự báo cáo phiên bản

Cho phép ứng dụng đang chạy **tự báo cáo phiên bản của chính nó**, để:

- Người nghiệm thu / khách hàng biết đang xem **bản phát hành nào** — đặc biệt để phân biệt hai môi trường Railway gần như giống hệt nhau (**Nghiệm thu** và **Mốc**).
- Script tự động deploy và bộ phận hỗ trợ **xác minh** bản nào đang chạy (kể cả Mini PC offline).
- Lỗi báo về từ Mini PC offline **truy vết được** về đúng một bản phát hành.

> **Phụ thuộc:** cần `version.txt` ở gốc repo (do release-please quản lý, công việc P3). Đã có trên `develop` (giá trị hiện tại `1.0.1`). Nhánh này tạo từ `develop`.

---

## Nguồn sự thật duy nhất

Mọi nơi hiển thị/trả về phiên bản đều đọc từ **một** nguồn, không lặp lại logic.

### 1. Hằng số phiên bản — `config/initializers/version.rb`

```ruby
module ElectricWaterManagement
  VERSION = (File.exist?(Rails.root.join("version.txt")) ?
    File.read(Rails.root.join("version.txt")).strip.presence : nil) || "unknown"
  VERSION.freeze
end
```

- Đọc `version.txt` **một lần lúc khởi động** vào hằng số.
- Thiếu file hoặc file rỗng → trả `"unknown"`, ứng dụng vẫn khởi động bình thường (không raise).
- Initializer cũng ghi **một dòng log khởi động** (xem ADR-004).

### 2. Module `SystemInfo` — `lib/system_info.rb`

Một **module** không trạng thái, gom phiên bản + nhãn môi trường; là nơi duy nhất view / endpoint / Excel / log gọi tới. Đặt ở `lib/` (đã bật `autoload_lib`) — đây là mối quan tâm **hạ tầng** (đọc `version.txt` + ENV), không phải service domain; để `app/services/` thuần class domain, không trộn module với class.

```ruby
module SystemInfo
  module_function

  def version           = ElectricWaterManagement::VERSION
  def environment_label = ENV["APP_ENVIRONMENT_LABEL"].presence || Rails.env.to_s.capitalize
  def to_h              = { version:, environment: environment_label, rails_env: Rails.env }
end
```

- **Nhãn môi trường là tiếng Anh** (xem ADR-003). Vận hành (ops) đặt `APP_ENVIRONMENT_LABEL` cho từng môi trường: Railway ví dụ `Acceptance` / `Mirror`, Mini PC `Production`.
- Khi biến môi trường trống → dự phòng `Rails.env.capitalize` (`Development` / `Test` / `Production`) — vẫn tiếng Anh, không cần i18n cho tên môi trường.
- `SystemInfo` là PORO (không phải ActiveRecord) → dễ test, không chạm database.

---

## Ba bề mặt hiển thị + endpoint + log

| # | Bề mặt | Vị trí | Nội dung |
|---|--------|--------|----------|
| 1a | **Đáy sidebar** | `app/views/layouts/_sidebar.html.erb` (đổi `<aside>` thành `flex flex-col`, `<nav>` `flex-1`, khối phiên bản ghim đáy) | **một dòng**, chữ nhỏ/mờ: `v1.0.1 · Production` (`whitespace-nowrap`) — vừa sidebar, súc tích; mọi trang sau đăng nhập, mọi vai trò |
| 1b | **Màn hình đăng nhập** | `app/views/devise/sessions/new.html.erb` | cùng dòng đó, dưới phụ đề — nhìn thấy **trước khi** đăng nhập (quan trọng cho người nghiệm thu) |
| 2 | **Endpoint `/version` (JSON)** | route `get "version" => "version#show"`, `VersionController` bỏ qua `authenticate_user!` → công khai | `{"version":"1.0.1","environment":"Acceptance","rails_env":"production"}` |
| 3 | **Log** | dòng khởi động trong initializer + `config.log_tags` (production) thêm lambda gộp version + môi trường | mọi dòng log request + báo cáo lỗi mang `[v1.0.1 Production]`; một dòng khởi động `Booting ... version=... environment=...` |
| 4 | **Excel** | `app/views/billing/show.xlsx.axlsx` — thêm dòng trống + dòng lấy từ i18n `system_info.excel_footer` (`Phiên bản hệ thống: v1.0.1 · Môi trường: Production`) **dưới** dòng `TỔNG` (kiểu chữ nhỏ/xám, không merge → không phá bảng) |

> Nhãn tiếng Việt bao quanh chỉ xuất hiện ở Excel ("Phiên bản hệ thống", "Môi trường") và lấy từ i18n; sidebar/đăng nhập chỉ hiển thị `vX.Y.Z · <môi trường>` (không có chữ tiếng Việt). Chỉ **giá trị môi trường** là tiếng Anh.

---

## Quyết định (ADR)

### ADR-001: Vị trí hiển thị phiên bản trên giao diện

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Mục tiêu cao nhất là để người nghiệm thu phân biệt được hai môi trường Railway gần giống hệt. Mọi trang sau đăng nhập đều có sidebar; chưa có footer.
- **Quyết định:** Hiển thị ở **(a) đáy sidebar** (mọi trang, mọi vai trò) và **(b) màn hình đăng nhập** (trước khi đăng nhập). **Không** làm trang admin "Thông tin hệ thống" riêng.
- **Lý do:** Sidebar có mặt ở mọi trang nên không cần footer mới; màn hình đăng nhập cho người nghiệm thu thấy ngay khi mở app. Một trang admin riêng là **thừa** khi phiên bản đã hiện khắp nơi và đã có endpoint `/version` cho thông tin máy đọc — thêm route/controller/view/mục sidebar/guard + test 6 vai trò mà giá trị tăng thêm rất ít (YAGNI).
- **Tradeoff:** (+) Phủ trước-và-sau đăng nhập, không thêm thành phần layout mới, không đụng `SettingsAccessGuard`. (−) Phải sửa cấu trúc flex của sidebar.
- **Phương án đã loại:**
  - *Footer toàn cục* — loại: thêm thành phần layout mới trong khi sidebar đã có mặt khắp nơi.
  - *Trang admin "Thông tin hệ thống" riêng* — loại: thừa so với sidebar + login + `/version`.

### ADR-002: Dạng endpoint trả phiên bản

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Script deploy và hỗ trợ cần xác minh bản đang chạy bằng cách gọi HTTP (kể cả Mini PC offline trong mạng nội bộ). Đã có sẵn health check `/up` của Rails (đã bị tắt log).
- **Quyết định:** Thêm endpoint riêng `GET /version` trả **JSON** `{version, environment, rails_env}`, **công khai (không cần đăng nhập)**.
- **Lý do:** JSON cho máy đọc dễ; tách khỏi `/up` để không trộn ngữ nghĩa health-check với version; công khai để script/hỗ trợ gọi không cần phiên đăng nhập.
- **Tradeoff:** (+) Máy đọc dễ, ổn định. (−) Lộ số phiên bản + tên môi trường công khai — chấp nhận được với hệ nội bộ; không phải bí mật.
- **Phương án đã loại:** *plain text* (kém cấu trúc khi cần thêm trường); *gộp vào `/up`* (trộn ngữ nghĩa, `/up` đã bị tắt log).

### ADR-003: Nhãn môi trường — tiếng Anh, từ biến môi trường

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Hai môi trường Railway (Nghiệm thu, Mốc) có thể **tạm thời chạy cùng một phiên bản**; khi đó chỉ số phiên bản không đủ để phân biệt. Quy ước dự án: UI tiếng Việt 100%, nhưng tên môi trường là **định danh triển khai/kỹ thuật**.
- **Quyết định:** Hiển thị/trả thêm **nhãn môi trường bằng tiếng Anh**, lấy từ biến `APP_ENVIRONMENT_LABEL`; dự phòng `Rails.env.capitalize` khi biến trống.
- **Lý do:** Giải quyết trực tiếp mục tiêu phân biệt hai môi trường; tên môi trường là định danh triển khai (đồng bộ với `Rails.env`, tài liệu deploy, biến môi trường) nên để tiếng Anh — chủ dự án xác nhận ngoại lệ với quy ước UI-tiếng-Việt. Cấu hình đơn giản (một biến mỗi nơi triển khai), không cần i18n cho tên môi trường.
- **Tradeoff:** (+) Phân biệt chắc chắn ngay cả khi trùng phiên bản; nhất quán với định danh triển khai. (−) Phụ thuộc ops đặt đúng biến; nếu quên → rơi về `Rails.env.capitalize` (vẫn an toàn, không lỗi).

### ADR-004: Cách gắn phiên bản (và môi trường) vào log

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Cần truy vết lỗi báo về từ Mini PC offline / Railway tới đúng bản phát hành **và** đúng môi trường (khi log của nhiều môi trường bị gộp lại). Production dùng `TaggedLogging` ra STDOUT, `config.log_tags = [:request_id]`.
- **Quyết định:** (a) Một **dòng log khởi động** trong initializer ghi cả phiên bản và môi trường; (b) thêm **lambda** `->(req){ "v#{ElectricWaterManagement::VERSION} #{SystemInfo.environment_label}" }` vào đầu `config.log_tags` (production) → mọi dòng log request + báo cáo lỗi mang **một tag gộp** `[v1.0.1 Production]`. Gộp version + môi trường vào **một** tag để gọn (một cặp ngoặc thay vì hai).
- **Lý do:** Cả tính năng tồn tại để phân biệt môi trường gần giống nhau; tag chỉ có phiên bản sẽ không cho biết log đến từ Nghiệm thu hay Mốc khi log bị gộp. Hằng số định nghĩa trong initializer (chạy *sau* `production.rb`); nhưng lambda của `log_tags` được tính **theo từng request lúc runtime** nên hằng số đã có sẵn — không vướng thứ tự nạp.
- **Tradeoff:** (+) Mọi dòng log tự mô tả được phiên bản **và** môi trường. (−) Mỗi dòng dài thêm ít ký tự.

---

## i18n

`config/locales/vi.yml` — thêm khóa cho nhãn tiếng Việt của Excel footer (giá trị môi trường vẫn tiếng Anh):

- `system_info.excel_footer: "Phiên bản hệ thống: v%{version} · Môi trường: %{environment}"` — template axlsx gọi `I18n.t("system_info.excel_footer", version:, environment:)`. **Không hard-code** chuỗi tiếng Việt trong view.
- Sidebar/đăng nhập chỉ hiển thị `vX.Y.Z · <môi trường>` (không có chữ tiếng Việt) → không cần khóa i18n.
- **Không** cần khóa i18n cho tên môi trường (đã là tiếng Anh, lấy từ biến môi trường / `Rails.env`).

## Phân quyền

- Endpoint `/version`: **công khai**, `VersionController` bỏ qua `authenticate_user!` (và không vướng `enforce_password_change`).
- Không thêm trang quản trị nào → không cần đụng `SettingsAccessGuard` hay `allowed_sidebar_items`.

---

## Kiểm thử (mỗi bề mặt một spec)

- `spec/lib/system_info_spec.rb` — `environment_label` khi có `APP_ENVIRONMENT_LABEL` vs. khi rơi về `Rails.env.capitalize`; hình dạng `to_h`; `version` đọc đúng hằng số.
- `spec/requests/version_spec.rb` — `GET /version` trả JSON đúng trường, **hoạt động khi chưa đăng nhập**.
- Hiển thị ở sidebar + đăng nhập — request spec kiểm tra body chứa `v#{version}` trên một trang đã đăng nhập và trên trang đăng nhập (`new_user_session_path`).
- Excel — mở rộng `spec/requests/billing_spec.rb` dùng `parse_xlsx` để xác nhận chuỗi phiên bản có trong các dòng.
- Chạy đầy đủ `bin/docker rspec`.

---

## Phạm vi & ràng buộc

- **Không** đụng `version.txt` (release-please sở hữu).
- Hằng số chỉ đọc lúc khởi động.
- Các file meta ở gốc repo không có version/changelog riêng; spec này là file có ngày trong `docs/superpowers/specs/` — khi sửa thì bump version + thêm changelog (đã làm).
- Theo Git Flow: nhánh từ `develop`, mở pull request về `develop`. Commit theo Conventional Commits (tiếng Anh). Không push/merge khi chưa được chủ dự án duyệt.
- **Việc của ops (ghi chú cho P4):** đặt `APP_ENVIRONMENT_LABEL` cho mỗi môi trường triển khai (Railway Nghiệm thu/Mốc, Mini PC) bằng tiếng Anh.

## Lịch sử thay đổi

- 0.4.0 (2026-06-07): Sau review code của chủ dự án trước khi mở PR — sidebar hiển thị version + môi trường trên **một dòng** (`whitespace-nowrap`, vẫn vừa sidebar); nhãn Excel footer dùng **i18n** (`system_info.excel_footer`), không hard-code chuỗi tiếng Việt.
- 0.3.0 (2026-06-07): Sau review của chủ dự án — chuyển `SystemInfo` sang `lib/system_info.rb` (giữ là module, không trộn với class trong `app/services/`); sidebar hiển thị hai dòng xếp dọc súc tích cho sidebar hẹp.
- 0.2.0 (2026-06-07): Sau review của chủ dự án — chuyển `SystemInfo` sang `app/services/`; bỏ trang admin "Thông tin hệ thống" (YAGNI); nhãn môi trường dùng tiếng Anh (`Rails.env.capitalize` dự phòng); gộp môi trường vào tag log cùng phiên bản.
- 0.1.0 (2026-06-07): Bản thảo đầu tiên, chốt sau brainstorming với chủ dự án.
