---
title: Tự báo cáo phiên bản (application self-version reporting)
version: 0.1.0
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

### 2. PORO `SystemInfo` — `app/models/system_info.rb`

Một module gom phiên bản + nhãn môi trường; là nơi duy nhất view / endpoint / Excel / log gọi tới.

```ruby
module SystemInfo
  module_function

  def version           = ElectricWaterManagement::VERSION
  def environment_label = ENV["APP_ENVIRONMENT_LABEL"].presence ||
                          I18n.t("system_info.environments.#{Rails.env}", default: Rails.env)
  def to_h              = { version:, environment: environment_label, rails_env: Rails.env }
end
```

- Vận hành (ops) đặt `APP_ENVIRONMENT_LABEL` cho từng môi trường: Railway `Nghiệm thu` / `Mốc`, Mini PC `Sản xuất`.
- Khi biến môi trường trống → dùng nhãn dự phòng theo `Rails.env` từ i18n (Development/Test).
- `SystemInfo` là PORO (không phải ActiveRecord) → dễ test, không chạm database.

---

## Bốn bề mặt hiển thị/trả về

| # | Bề mặt | Vị trí | Nội dung |
|---|--------|--------|----------|
| 1a | **Đáy sidebar** | `app/views/layouts/_sidebar.html.erb` (đổi `<aside>` thành `flex flex-col`, `<nav>` `flex-1`, khối phiên bản ghim đáy) | dòng chữ xám nhỏ `v1.0.1 · Nghiệm thu` — mọi trang sau đăng nhập, mọi vai trò |
| 1b | **Màn hình đăng nhập** | `app/views/devise/sessions/new.html.erb` | cùng dòng đó, dưới phụ đề — nhìn thấy **trước khi** đăng nhập (quan trọng cho người nghiệm thu) |
| 1c | **Trang "Thông tin hệ thống"** | route `resource :system_info, only: [:show]` → `SystemInfoController#show`; liên kết sidebar trong nhóm `:system` | đầy đủ: phiên bản, môi trường, Rails env. Guard cấp trang: **chỉ TECH + SA** (khớp nhóm `:system`) |
| 2 | **Endpoint `/version` (JSON)** | route `get "version" => "version#show"`, `VersionController` bỏ qua `authenticate_user!` → công khai | `{"version":"1.0.1","environment":"Nghiệm thu","rails_env":"production"}` |
| 3 | **Log** | dòng khởi động trong initializer + `config.log_tags` (production) thêm lambda `->(req){ "v#{ElectricWaterManagement::VERSION}" }` | mọi dòng log request + báo cáo lỗi mang `[v1.0.1]`; một dòng khởi động `Booting ... version=... environment=...` |
| 4 | **Excel** | `app/views/billing/show.xlsx.axlsx` — thêm dòng trống + dòng `Phiên bản hệ thống: v1.0.1 · Môi trường: Nghiệm thu` **dưới** dòng `TỔNG` (kiểu chữ nhỏ/xám, không merge → không phá bảng) |

---

## Quyết định (ADR)

### ADR-001: Vị trí hiển thị phiên bản trên giao diện

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Mục tiêu cao nhất là để người nghiệm thu phân biệt được hai môi trường Railway gần giống hệt. Mọi trang sau đăng nhập đều có sidebar; chưa có footer.
- **Quyết định:** Hiển thị ở **(a) đáy sidebar** (mọi trang, mọi vai trò), **(b) màn hình đăng nhập** (trước khi đăng nhập), và **(c) trang "Thông tin hệ thống"** dành cho quản trị (TECH + SA).
- **Lý do:** Tận dụng sidebar có sẵn ở mọi trang thay vì thêm footer mới; màn hình đăng nhập cho người nghiệm thu thấy ngay khi mở app; trang admin cho thông tin đầy đủ + chỗ mở rộng sau này.
- **Tradeoff:** (+) Phủ trước-và-sau đăng nhập, không thêm thành phần layout mới. (−) Phải sửa cấu trúc flex của sidebar.
- **Phương án đã loại:** *Footer toàn cục* — loại: thêm thành phần layout mới trong khi sidebar đã có mặt khắp nơi.

### ADR-002: Dạng endpoint trả phiên bản

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Script deploy và hỗ trợ cần xác minh bản đang chạy bằng cách gọi HTTP (kể cả Mini PC offline trong mạng nội bộ). Đã có sẵn health check `/up` của Rails (đã bị tắt log).
- **Quyết định:** Thêm endpoint riêng `GET /version` trả **JSON** `{version, environment, rails_env}`, **công khai (không cần đăng nhập)**.
- **Lý do:** JSON cho máy đọc dễ; tách khỏi `/up` để không trộn ngữ nghĩa health-check với version; công khai để script/hỗ trợ gọi không cần phiên đăng nhập.
- **Tradeoff:** (+) Máy đọc dễ, ổn định. (−) Lộ số phiên bản công khai — chấp nhận được với hệ nội bộ; số phiên bản không phải bí mật.
- **Phương án đã loại:** *plain text* (kém cấu trúc khi cần thêm trường); *gộp vào `/up`* (trộn ngữ nghĩa, `/up` đã bị tắt log).

### ADR-003: Kèm nhãn môi trường cạnh phiên bản

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Hai môi trường Railway (Nghiệm thu, Mốc) có thể **tạm thời chạy cùng một phiên bản**; khi đó chỉ số phiên bản không đủ để phân biệt.
- **Quyết định:** Hiển thị/trả thêm **nhãn môi trường** lấy từ biến `APP_ENVIRONMENT_LABEL`, dự phòng theo `Rails.env` qua i18n.
- **Lý do:** Giải quyết trực tiếp mục tiêu phân biệt hai môi trường; cấu hình đơn giản (một biến môi trường mỗi nơi triển khai).
- **Tradeoff:** (+) Phân biệt chắc chắn ngay cả khi trùng phiên bản. (−) Phụ thuộc ops đặt đúng biến; nếu quên → rơi về nhãn dự phòng (vẫn an toàn, không lỗi).

### ADR-004: Cách gắn phiên bản vào log

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Cần truy vết lỗi báo về từ Mini PC offline tới đúng bản phát hành. Production dùng `TaggedLogging` ra STDOUT, `config.log_tags = [:request_id]`.
- **Quyết định:** (a) Một **dòng log khởi động** trong initializer ghi cả phiên bản và môi trường; (b) thêm **lambda** `->(req){ "v#{ElectricWaterManagement::VERSION}" }` vào đầu `config.log_tags` (production) → mọi dòng log request + báo cáo lỗi mang tag `[v1.0.1]`. Tag log **chỉ chứa phiên bản** (môi trường nằm ở dòng khởi động) để gọn.
- **Lý do:** Hằng số định nghĩa trong initializer (chạy *sau* `production.rb`); nhưng lambda của `log_tags` được tính **theo từng request lúc runtime** nên hằng số đã có sẵn — không vướng thứ tự nạp.
- **Tradeoff:** (+) Mọi dòng log truy vết được về phiên bản. (−) Mỗi dòng dài thêm vài ký tự.

---

## i18n

`config/locales/vi.yml` — thêm namespace `system_info:` (tiếng Việt 100%):

- Tiêu đề trang, nhãn mục sidebar.
- Nhãn các trường (phiên bản, môi trường, Rails env).
- `environments: { development:, test:, production: }` — nhãn dự phòng khi `APP_ENVIRONMENT_LABEL` trống.

## Phân quyền (khớp `SettingsAccessGuard`)

- Trang `/system_info`: guard cấp trang cho **TECH + SA** (khớp nhóm sidebar `:system`). Thêm mục `system_info` vào `allowed_sidebar_items` cho `technician` và `system_admin`.
- Endpoint `/version`: **công khai**, `VersionController` bỏ qua `authenticate_user!` (và không vướng `enforce_password_change`).

---

## Kiểm thử (mỗi bề mặt một spec)

- `spec/models/system_info_spec.rb` — `environment_label` khi có `APP_ENVIRONMENT_LABEL` vs. khi rơi về i18n; hình dạng `to_h`.
- `spec/requests/version_spec.rb` — `GET /version` trả JSON đúng trường, **hoạt động khi chưa đăng nhập**.
- `spec/requests/system_info_spec.rb` — TECH + SA nhận 200 và thấy phiên bản; **4 vai trò còn lại bị redirect** (guard cấp trang, test đủ 6 vai trò theo AGENTS.md).
- `spec/helpers/sidebar_helper_spec.rb` — mục `system_info` xuất hiện cho TECH + SA, không cho vai trò khác.
- Hiển thị ở sidebar + đăng nhập — request spec kiểm tra body chứa `v#{version}` trên một trang đã đăng nhập và trên trang đăng nhập.
- Excel — mở rộng `spec/requests/billing_spec.rb` dùng `parse_xlsx` để xác nhận chuỗi phiên bản có trong các dòng.
- Chạy đầy đủ `bin/docker rspec`.

---

## Phạm vi & ràng buộc

- **Không** đụng `version.txt` (release-please sở hữu).
- Hằng số chỉ đọc lúc khởi động.
- Các file meta ở gốc repo không có version/changelog riêng; spec này là file mới có ngày trong `docs/superpowers/specs/` nên không cần bump version tài liệu khác.
- Theo Git Flow: nhánh từ `develop`, mở pull request về `develop`. Commit theo Conventional Commits (tiếng Anh). Không push/merge khi chưa được chủ dự án duyệt.

## Lịch sử thay đổi

- 0.1.0 (2026-06-07): Bản thảo đầu tiên, chốt sau brainstorming với chủ dự án.
