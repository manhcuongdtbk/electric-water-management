# 03 — Quickstart: Chạy project từ zero

> **Phiên bản:** v1.0.0 — 29/04/2026
>
> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì.
>
> **Mục đích file này:** Hướng dẫn chạy project từ zero — cả development và production.
>
> **Đối tượng đọc:** Developer mới vào project, hoặc developer quay lại sau thời gian dài.
>
> Thuật ngữ sử dụng tuân theo `02_GLOSSARY_v1_2_0.md`. Cấu trúc 24 cột bảng tổng hợp xem `13_BUSINESS_RULES_v1_1_0.md` mục 4.

---

## Mục lục

1. [Phần 1 — Development setup](#1-development-setup)
2. [Phần 2 — Production setup](#2-production-setup)
3. [Phần 3 — Các thao tác thường dùng](#3-các-thao-tác-thường-dùng)
4. [Phần 4 — Troubleshooting](#4-troubleshooting)
5. [TODO — Cần verify](#todo--cần-verify)
6. [Changelog](#changelog)

---

## 1. Development setup

### 1.1 Prerequisites

| Công cụ | Phiên bản tối thiểu | Ghi chú |
|---|---|---|
| Docker Engine | ≥ 20.10 | Chạy container Rails + PostgreSQL |
| Docker Compose Plugin | v2.x | Cú pháp `docker compose` (dấu cách, không phải `docker-compose`) |
| Git | bất kỳ | Để clone repo |

**Không cần cài** Ruby, PostgreSQL hoặc Node.js trên máy host — toàn bộ chạy trong container. File `.tool-versions` ghi nhận `ruby 3.4.3` và `nodejs 24.14.1` chỉ để Docker build tham chiếu (Node có sẵn trong base image, dự án không cần Node runtime — Tailwind dùng `tailwindcss-rails` không qua npm; xem `01_OVERVIEW` mục 6).

> **Tham chiếu:** Phiên bản chính xác đang dùng — xem `.ruby-version` (3.4.3), `.tool-versions`, `Dockerfile` (dòng 11–12), `Gemfile` (`gem "rails", "~> 8.1.3"`).

### 1.2 Clone repo

```bash
git clone <repo-url> electric-water-management
cd electric-water-management
```

### 1.3 Tạo file môi trường (tùy chọn)

```bash
cp .env.example .env
```

Nội dung `.env.example`:

```
DB_HOST=127.0.0.1
DB_PORT=5433
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

> **Lưu ý:** File `.env` này chỉ cần khi **chạy Rails trực tiếp trên host** (ví dụ chạy `bin/rails server` ngoài Docker, dùng PostgreSQL container như backend). Khi chạy đầy đủ qua `docker compose up` (workflow chính), biến môi trường được khai báo trong `docker-compose.yml` và **không cần** file `.env`.

### 1.4 Khởi động Docker Compose

`docker-compose.yml` định nghĩa 2 service:

| Service | Image | Port host:container | Mục đích |
|---|---|---|---|
| `db` | `postgres:16-alpine` | `5433:5432` | PostgreSQL — DB tên `electric_water_management_development` (user `postgres`, password `postgres`) |
| `web` | build từ `Dockerfile` | `3000:3000` | Rails 8 — chạy `bundle exec rails server -b 0.0.0.0` |

Container `web` mount thư mục project vào `/rails` (live reload code) và cache bundle ở volume `bundle_cache`. Healthcheck `db` dùng `pg_isready` — `web` đợi `db` healthy mới start.

Khởi động lần đầu:

```bash
docker compose up -d --build
```

Build container có thể mất 5–10 phút lần đầu (cài gem). Lần sau chỉ vài giây.

Kiểm tra container đang chạy:

```bash
docker compose ps
```

### 1.5 Khởi tạo database

Container `web` đã có sẵn biến môi trường: `DB_HOST=db`, `DB_PORT=5432`, `DB_USERNAME=postgres`, `DB_PASSWORD=postgres`, `RAILS_ENV=development` (xem `docker-compose.yml` dòng 26–31). Chạy:

```bash
docker compose exec web bin/rails db:create db:migrate db:seed
```

Hoặc dùng `db:prepare` (gộp `create + migrate`, idempotent — không lỗi nếu DB đã tồn tại):

```bash
docker compose exec web bin/rails db:prepare
docker compose exec web bin/rails db:seed
```

> **Tự động chạy `db:prepare`:** File `bin/docker-entrypoint` tự gọi `bin/rails db:prepare` trước khi start Rails server, nên `db:create + db:migrate` chạy tự động khi container up. Tuy nhiên `db:seed` **phải chạy thủ công** (entrypoint không chạy seed).

### 1.6 Seed tạo gì

`db/seeds.rb` chạy idempotent (`find_or_create_by`/`find_or_initialize_by`) — chạy lại nhiều lần không tạo bản ghi trùng. Sau khi seed, database có:

#### 14 tổ chức (`Organization`)

| Code | Tên | Level | Position |
|---|---|---|---|
| `SD` | Sư đoàn | division | 0 |
| `SDB` | Sư đoàn bộ | unit | 1 |
| `TR101` | Trung đoàn 101 | unit | 2 |
| `TR18` | Trung đoàn 18 | unit | 3 |
| `TR95` | Trung đoàn 95 | unit | 4 |
| `TD14` | Tiểu đoàn 14 | unit | 5 |
| `TD15` | Tiểu đoàn 15 | unit | 6 |
| `TD16` | Tiểu đoàn 16 | unit | 7 |
| `TD17` | Tiểu đoàn 17 | unit | 8 |
| `TD18` | Tiểu đoàn 18 | unit | 9 |
| `TD24` | Tiểu đoàn 24 | unit | 10 |
| `TD25` | Tiểu đoàn 25 | unit | 11 |
| `DH26` | Đại đội 26 | unit | 12 |
| `DH29` | Đại đội 29 | unit | 13 |

Xem `02_GLOSSARY` mục 11 cho chi tiết 14 đơn vị.

#### 7 nhóm cấp bậc (`RankQuota`)

Tất cả với `effective_from = 2024-01-01`, định mức đọc từ hằng số `RankQuota::STANDARD_QUOTAS`. Tên nhóm trong seed dùng nguyên văn nghị định gốc (dài hơn) — khác với tên rút gọn trong `02_GLOSSARY` mục 9 (xem mục TODO cuối file).

#### 16 tài khoản người dùng

**8 tài khoản demo — mật khẩu `admin123`:**

| Email | Vai trò | Đơn vị |
|---|---|---|
| `admin@example.com` | `admin_level1` | Sư đoàn |
| `test_admin1@example.com` | `admin_level1` | Sư đoàn |
| `admin_unit@example.com` | `admin_unit` | Sư đoàn bộ (SDB) |
| `admin_unit_a@example.com` | `admin_unit` | Trung đoàn 101 (TR101) |
| `commander@example.com` | `commander` | Sư đoàn bộ (SDB) |
| `commander_a@example.com` | `commander` | Trung đoàn 101 (TR101) |
| `tech@example.com` | `tech` | Sư đoàn |
| `test_adminunit@example.com` | `admin_unit` | Trung đoàn 101 (TR101) |

**8 tài khoản test — mật khẩu `Test1234!`:**

| Email | Vai trò | Đơn vị |
|---|---|---|
| `cuong_admin1@test.local` | `admin_level1` | Sư đoàn |
| `cuong_unit@test.local` | `admin_unit` | Sư đoàn bộ |
| `cuong_commander@test.local` | `commander` | Sư đoàn bộ |
| `cuong_tech@test.local` | `tech` | Sư đoàn |
| `thy_admin1@test.local` | `admin_level1` | Sư đoàn |
| `thy_unit@test.local` | `admin_unit` | Trung đoàn 101 |
| `thy_commander@test.local` | `commander` | Trung đoàn 101 |
| `thy_tech@test.local` | `tech` | Sư đoàn |

Tất cả tài khoản trong seed đều có `force_password_change = false` nên **không yêu cầu đổi mật khẩu** khi đăng nhập (tiện cho dev). Trong production, người dùng mới do `tech` tạo qua F15 sẽ **bắt buộc đổi mật khẩu lần đầu** (xem `02_GLOSSARY` mục 8.5, F18).

Xem `02_GLOSSARY` mục 7 cho chi tiết 4 vai trò.

> **Lưu ý:** Ở môi trường `RAILS_ENV=test`, seed **chỉ tạo Organization và RankQuota** (không tạo User) — xem dòng `unless Rails.env.test?` trong `db/seeds.rb`.

#### Import data tháng 02/2026 (tùy chọn)

`ImportFeb2026Service` đọc file `test/fixtures/files/bang_tinh_thang_02.xlsx` và tạo dữ liệu mẫu cho **Sư đoàn bộ (SDB)**: đầu mối, công tơ, quân số, chỉ số đầu/cuối kỳ, trạm bơm, khoản trừ "Khác". Chạy qua rake task:

```bash
docker compose exec web bin/rails data:import_feb_2026
```

Service idempotent (`find_or_initialize_by`) — chạy lại sẽ cập nhật, không nhân đôi. Bắt buộc đã `db:seed` trước (cần `Organization.code = "SDB"` tồn tại). Sau khi import, có 79 đầu mối Sư đoàn bộ — xem `02_GLOSSARY` mục 1 và `13_BUSINESS_RULES` mục 1.

### 1.7 Đăng nhập và verify

Mở trình duyệt: **http://localhost:3000**

1. Auto redirect về `/users/sign_in` (Devise).
2. Đăng nhập với `admin@example.com` / `admin123`.
3. Sau khi login, chuyển về root (`dashboard#show`) — Dashboard hiển thị biểu đồ tổng hợp tháng/quý/năm (chức năng F12, xem `02_GLOSSARY` mục 8.4).
4. Menu (tùy vai trò) có các mục: **Tổng hợp tháng** (F11), **Tra cứu lịch sử** (F13), **Đơn giá** (F20), **Định mức cấp bậc** (F21), **Nhật ký** (F19), **Quản lý tài khoản** (F15), **Sao lưu dữ liệu** (chỉ vai trò `tech`).

**Verify hệ thống hoạt động đúng:**

- **Health check:** `curl http://localhost:3000/up` → trả về `200 OK` (route `/up` ánh xạ tới `rails/health#show`).
- **Phân quyền 4 vai trò:** Đăng nhập lần lượt `admin@example.com`, `admin_unit@example.com`, `commander@example.com`, `tech@example.com` — mỗi vai trò thấy menu và dữ liệu khác nhau theo `app/models/ability.rb` (xem `02_GLOSSARY` mục 7).
- **Bảng 24 cột:** Mở **Tổng hợp tháng** (F11) — nếu đã import data tháng 02, sẽ thấy 79 đầu mối Sư đoàn bộ; nếu chưa import, bảng trống. Cấu trúc cột xem `13_BUSINESS_RULES` mục 4.

### 1.8 Chạy test suite

Chạy toàn bộ:

```bash
docker compose exec web bundle exec rspec
```

Hoặc một file:

```bash
docker compose exec web bundle exec rspec spec/services/calculation_engine_spec.rb
```

**Kỳ vọng:** > 800 specs pass (theo CLAUDE.md, M5 PR3 đã đạt 836 specs; đầu M6 tiếp tục tăng). `CalculationEngine` (bảng 24 cột) là test ưu tiên cao nhất, dùng dữ liệu thật từ `test/fixtures/files/bang_tinh_thang_02.xlsx`.

> **Tham chiếu:** Service test ở `spec/services/`: `calculation_engine_spec.rb`, `import_feb_2026_service_spec.rb`, `period_inheritance_service_spec.rb`, `backup_service_spec.rb`. Tổng 18 migration trong `db/migrate/`.

---

## 2. Production setup

Chi tiết hạ tầng triển khai khách (Mini PC Ubuntu 24.04 — anh Phương phụ trách) xem `08_INFRASTRUCTURE_v1_0_0.md` (khi có) và `14_DEPLOY_v1_0_0.md` (khi có). Phần dưới đây tóm tắt các bước thiết yếu, dựa trên `docker-compose.production.yml` và `DEPLOY.md` thực tế trong repo.

### 2.1 Yêu cầu hạ tầng

- Docker Engine ≥ 24.0
- Docker Compose Plugin ≥ 2.0
- Linux server (Ubuntu 20.04+ hoặc CentOS 8+)
- Tối thiểu 2 GB RAM, 10 GB ổ trống

### 2.2 Sao chép source và tạo file môi trường

```bash
git clone <repo-url> /opt/electric-water-management
cd /opt/electric-water-management
cp .env.production.example .env.production
```

Nội dung `.env.production.example` (5 biến bắt buộc):

```
DB_USERNAME=postgres
DB_PASSWORD=changeme_secure_password
DB_NAME=electric_water_management_production
RAILS_MASTER_KEY=<value from config/master.key>
BACKUP_DIR=/rails/db/backups
```

| Biến | Mô tả | Cách lấy |
|---|---|---|
| `DB_USERNAME` | User PostgreSQL | Tự đặt — ví dụ `postgres` |
| `DB_PASSWORD` | Mật khẩu PostgreSQL | Mật khẩu mạnh ≥ 16 ký tự |
| `DB_NAME` | Tên database | `electric_water_management_production` |
| `RAILS_MASTER_KEY` | Khóa giải mã `config/credentials.yml.enc` | Lấy từ file `config/master.key` (không commit git) — liên hệ developer |
| `BACKUP_DIR` | Thư mục backup trong container | Mặc định `/rails/db/backups` |

### 2.3 Tạo thư mục backup

```bash
mkdir -p db/backups
```

Thư mục này được bind mount vào container `web` tại `/rails/db/backups` (xem `docker-compose.production.yml` dòng 31–32). Container chạy với UID `1000:1000` (xem `Dockerfile` dòng 65) — host phải cho UID 1000 ghi vào thư mục này.

### 2.4 Build và khởi động

`docker-compose.production.yml` định nghĩa 3 service:

| Service | Image | Port | Mục đích |
|---|---|---|---|
| `db` | `postgres:16-alpine` | (không expose ra host) | PostgreSQL persistent |
| `web` | build từ `Dockerfile` | expose 3000 (chỉ trong network compose) | Rails 8 production |
| `nginx` | `nginx:alpine` | `80:80` | Reverse proxy, gzip, security headers |

Khởi động:

```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

Lần đầu build mất 5–10 phút.

### 2.5 Khởi tạo database

```bash
docker compose -f docker-compose.production.yml exec web bin/rails db:prepare
```

Sau đó tạo các tài khoản admin/tech ban đầu — phương án cụ thể (qua seed, qua console, hoặc qua giao diện) chưa cố định. Xem `08_INFRASTRUCTURE_v1_0_0.md` (khi có) hoặc liên hệ developer.

### 2.6 Verify

```bash
# Health check
curl http://localhost/up           # → 200 OK

# Trạng thái container
docker compose -f docker-compose.production.yml ps

# Log
docker compose -f docker-compose.production.yml logs -f web
docker compose -f docker-compose.production.yml logs -f nginx
```

### 2.7 SSL/HTTPS

`config/nginx/production.conf` hiện tại **chỉ cấu hình HTTP** trên port 80, không có SSL termination. Trên Mini PC khách, tùy chọn cài đặt:

- Sửa `config/nginx/production.conf` thêm block `listen 443 ssl`, mount certificate vào container nginx.
- Hoặc đặt reverse proxy phía trước (Caddy, Traefik) handle SSL termination.

Quyết định cuối cùng và certificate lấy ở đâu — xem `08_INFRASTRUCTURE_v1_0_0.md` (khi có).

### 2.8 Backup tự động

Backup dùng `pg_dump`/`pg_restore` qua `BackupService` (xem `02_GLOSSARY` mục 12). 3 cách:

**1. Qua giao diện web** (chỉ vai trò `tech`):

Đăng nhập → menu **Sao lưu dữ liệu** → **Sao lưu ngay**.

**2. Qua terminal** (rake task `db:backup` định nghĩa trong `lib/tasks/db_backup.rake`):

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup
```

**3. Cron tự động** mỗi ngày 2:00 sáng — thêm vào `crontab -e`:

```
0 2 * * * cd /opt/electric-water-management && docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup >> /var/log/ewm-backup.log 2>&1
```

File backup lưu tại `db/backups/` (host) ↔ `/rails/db/backups` (container), tên dạng `backup_YYYYMMDD_HHMMSS.dump`.

**Phục hồi:**

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_20260423_020000.dump]'
```

> **Cảnh báo:** Phục hồi ghi đè **toàn bộ** dữ liệu hiện tại. Bắt buộc sao lưu trước khi phục hồi. Sau phục hồi, tất cả phiên đăng nhập bị reset (`BackupService.restore!` sign out toàn bộ user).

Chi tiết quy trình backup/restore xem `08_INFRASTRUCTURE_v1_0_0.md` (khi có) và `DEPLOY.md` mục 5.

---

## 3. Các thao tác thường dùng

Tất cả lệnh dưới đây giả định đang ở thư mục root của project (development). Production thay `docker compose ...` thành `docker compose -f docker-compose.production.yml ...`.

### 3.1 Reset database (xóa toàn bộ dữ liệu)

```bash
docker compose exec web bin/rails db:reset
# Tương đương: db:drop db:create db:migrate db:seed
```

Hoặc bạo lực hơn (xóa cả PostgreSQL volume):

```bash
docker compose down -v
docker compose up -d
docker compose exec web bin/rails db:setup
```

> **Cảnh báo:** Cả 2 lệnh trên xóa sạch dữ liệu — chỉ làm ở dev. Production dùng `db:restore` từ backup.

### 3.2 Xem log

```bash
# Realtime, tất cả service
docker compose logs -f

# Realtime, riêng web hoặc db
docker compose logs -f web
docker compose logs -f db

# Log Rails (development)
docker compose exec web tail -f log/development.log

# Log Rails (production) — mặc định stdout do RAILS_LOG_TO_STDOUT=true
docker compose -f docker-compose.production.yml logs -f web
```

### 3.3 Vào Rails console

```bash
docker compose exec web bin/rails console
```

Một số lệnh hữu ích:

```ruby
User.count
Organization.find_by(code: "SDB").contact_points.count
MonthlyPeriod.last
RankQuota.order(:rank_group).pluck(:rank_group, :rank_name, :quota_kw)
```

### 3.4 Chạy rubocop, brakeman, security audit

CI (`.github/workflows/ci.yml`) chạy 4 job: rubocop, brakeman, bundler-audit, importmap audit. Trước khi commit, chạy local:

```bash
# Style — luôn chạy không giới hạn path
bin/rubocop -f github

# Security: Rails code analysis
bin/brakeman --no-pager

# Security: gem vulnerabilities
bin/bundler-audit

# Security: JavaScript dependencies
bin/importmap audit

# Tất cả CI step trong 1 lệnh
bin/ci
```

`bin/ci` thực thi pipeline khai báo trong `config/ci.rb`: setup → rubocop → bundler-audit → importmap audit → brakeman.

Chạy trong container Docker:

```bash
docker compose exec web bin/rubocop -f github
docker compose exec web bin/ci
```

> **Quan trọng:** Theo CLAUDE.md, **luôn chạy `bin/rubocop -f github` không giới hạn path** trước khi commit (memory rule).

### 3.5 Migration mới

```bash
# Tạo migration
docker compose exec web bin/rails generate migration AddXxxToYyy field:type

# Chạy
docker compose exec web bin/rails db:migrate

# Rollback 1 step
docker compose exec web bin/rails db:rollback

# Status
docker compose exec web bin/rails db:migrate:status
```

### 3.6 Reset password / unlock tài khoản (escape hatch)

Khi quản trị viên cấp 1 bị khóa (5 lần sai mật khẩu — F17) hoặc quên mật khẩu, không có ai khác mở khóa được. Dùng rake task `admin:reset_password` (xem `lib/tasks/admin.rake`):

```bash
docker compose exec web bin/rails 'admin:reset_password[admin@example.com]'
```

Lệnh này:
- Sinh mật khẩu ngẫu nhiên 12 ký tự, in ra màn hình.
- Set `locked_at = nil`, `failed_attempts = 0` (mở khóa).
- Set `force_password_change = true` (bắt buộc đổi khi đăng nhập lần đầu — F18).

> **Cú pháp:** Bắt buộc đặt tham số trong dấu nháy đơn `'admin:reset_password[email]'` để shell không expand `[]`.

### 3.7 Import lại data tháng 02

```bash
docker compose exec web bin/rails data:import_feb_2026
```

Service idempotent — chạy lại sẽ update, không nhân đôi (xem `lib/tasks/data.rake`).

### 3.8 Dừng / khởi động lại

```bash
# Dừng giữ data
docker compose stop

# Khởi động lại
docker compose start

# Dừng và xóa container (giữ volume)
docker compose down

# Dừng và xóa cả volume (mất data)
docker compose down -v
```

---

## 4. Troubleshooting

### 4.1 Lỗi port 5433 đã được sử dụng

```
Error: bind: address already in use
```

Một process khác (thường là PostgreSQL local) đang dùng port 5433. Cách xử lý:

```bash
# Tìm process đang chiếm port
lsof -i :5433

# Hoặc đổi port trong docker-compose.yml — sửa "5433:5432" thành "5434:5432"
```

Nếu đổi port, cập nhật `DB_PORT` trong `.env` cho phù hợp (chỉ ảnh hưởng workflow chạy Rails ngoài Docker).

### 4.2 Lỗi port 3000 đã được sử dụng

Tương tự — Rails server local hoặc app khác đang chiếm. Tìm bằng `lsof -i :3000` rồi kill, hoặc đổi port trong `docker-compose.yml`.

### 4.3 Container `web` không khởi động được

```bash
docker compose logs web
```

Nguyên nhân thường gặp:

- **Database chưa healthy:** `web` depend trên `db: condition: service_healthy`. Xem `docker compose logs db`. Nếu PostgreSQL khởi động chậm, đợi và `docker compose restart web`.
- **Bundle cache hỏng:** Xóa volume và build lại:

  ```bash
  docker compose down -v
  docker compose up -d --build
  ```

- **Migration pending:** Log có `Migrations are pending`. Chạy thủ công:

  ```bash
  docker compose exec web bin/rails db:migrate
  ```

### 4.4 Production: `web` báo thiếu `RAILS_MASTER_KEY`

Lỗi:

```
Missing encryption key to decrypt file with...
```

Kiểm tra `.env.production` đã điền `RAILS_MASTER_KEY` đúng giá trị nội dung file `config/master.key` của developer. File `master.key` không commit vào git — liên hệ developer để lấy.

### 4.5 Production: nginx trả về 502 Bad Gateway

Container `web` chưa sẵn sàng nhưng nginx đã chạy. Kiểm tra:

```bash
docker compose -f docker-compose.production.yml logs web
docker compose -f docker-compose.production.yml ps
```

Nếu `web` đang restart liên tục — thường do `RAILS_MASTER_KEY` sai, database chưa migrate, hoặc lỗi seed.

### 4.6 Permission denied khi truy cập file backup

Container `web` chạy với UID `1000:1000` (xem `Dockerfile` dòng 65). Thư mục `db/backups/` trên host phải cho UID 1000 ghi:

```bash
sudo chown -R 1000:1000 db/backups/
```

### 4.7 "Migrations are pending" sau pull code mới

```bash
# Development
docker compose exec web bin/rails db:migrate

# Production
docker compose -f docker-compose.production.yml exec web bin/rails db:migrate
```

### 4.8 Test fail vì thiếu DB test

```bash
docker compose exec web bin/rails db:test:prepare
```

Hoặc:

```bash
docker compose exec web env RAILS_ENV=test bin/rails db:create db:migrate
```

### 4.9 `bin/dev` (chạy ngoài Docker) báo lỗi `foreman: command not found`

`bin/dev` dùng `foreman` để start `bin/rails server` + `bin/rails tailwindcss:watch` song song (xem `Procfile.dev`). Cài foreman:

```bash
gem install foreman
```

`bin/dev` chỉ dùng khi chạy Rails trực tiếp trên host (không qua Docker). Workflow chính của dự án là Docker — `bin/dev` chỉ là tùy chọn.

### 4.10 Devise lock account sau 5 lần sai mật khẩu

Theo F17 (xem `02_GLOSSARY` mục 8.5), Devise tự khóa account sau 5 lần sai. Mở khóa qua:

- Tài khoản khác có vai trò `tech` → giao diện F15.
- Hoặc rake task — xem mục 3.6 trên.

---

## TODO — Cần verify

Các sai lệch phát hiện giữa code thực tế và `02_GLOSSARY` / `13_BUSINESS_RULES`. Cần cập nhật glossary hoặc code:

1. **Tên 7 nhóm cấp bậc trong `db/seeds.rb` không khớp `02_GLOSSARY` mục 9 / `13_BUSINESS_RULES` mục 3.**
   - Seed dùng tên đầy đủ theo nghị định gốc, ví dụ nhóm 1 = `"Chỉ huy sư đoàn và tương đương; quân hàm cao nhất là Đại tá"`.
   - Glossary và Business Rules dùng tên rút gọn theo bảng mẫu khách gửi (Zalo 21/04/2026), ví dụ nhóm 1 = `"Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá"`.
   - Cần xác định bản nào là chuẩn — nếu glossary đúng thì sửa `db/seeds.rb`, nếu seed đúng thì sửa glossary và business rules.

2. **Schema `MonthlyCalculation` không có cột `surplus_kw` / `deficit_kw` / `surplus_amount` / `deficit_amount`.**
   - `02_GLOSSARY` mục 3.2 và `13_BUSINESS_RULES` mục 4 mô tả 24 cột với 4 cột riêng cho Thừa/Thiếu (kW + đồng).
   - Schema thực tế (`db/schema.rb`, table `monthly_calculations`) chỉ có `over_under_kw` và `total_amount` — tức structure 22 cột gốc.
   - Khả năng cao 24 cột là cấu trúc UI/calculation tách từ `over_under_kw` ở view layer hoặc trong `CalculationEngine`, không phải cột DB. Cần verify trong `app/services/calculation_engine.rb` và view `app/views/monthly_summaries/`.
   - Index Anh → Việt trong `02_GLOSSARY` mục 14 cũng list các cột này như tên column code — cần điều chỉnh.

3. **TODO #1 trong `02_GLOSSARY` ("Số điện lực" lưu ở đâu?) đã có lời giải.**
   - Code thực tế: lưu trong `UnitConfig.electricity_supply_kw` (decimal precision 12, scale 2). Xem `app/models/unit_config.rb` dòng 24 và migration `20260412010012_add_electricity_supply_to_unit_configs.rb`.
   - Có thể đóng TODO này trong glossary.

4. **TODO #2 trong `02_GLOSSARY` (F12 Dashboard — admin_unit có xem được không?) đã có lời giải.**
   - Code thực tế: dashboard là `root` trong `config/routes.rb` dòng 55 (`root "dashboard#show"`). `app/models/ability.rb` không có quy tắc hạn chế nào cho dashboard.
   - Tất cả 4 vai trò đăng nhập đều truy cập được dashboard (admin_level1, admin_unit, commander, tech).
   - Có thể đóng TODO này trong glossary.

5. **TODO #3 trong `02_GLOSSARY` (`effective_from` trên `RankQuota`) đã được verify.**
   - Cột `effective_from` (`date`, `null: false`) tồn tại trong `db/schema.rb` table `rank_quotas`. Seed gán giá trị `Date.new(2024, 1, 1)`.
   - Có thể đóng TODO này.

6. **CLAUDE.md mô tả route `monthly_summaries#show` (số nhiều) nhưng `config/routes.rb` dùng `resource :monthly_summary` (số ít).**
   - Rails convention: singular `resource` map đến controller plural (`MonthlySummariesController`) — không sai, chỉ dễ nhầm. Không cần sửa.

7. **Số spec thực tế khi sample đếm `it`-block ≈ 820, CLAUDE.md ghi M5 PR3 đạt 836.**
   - Sai lệch nhỏ có thể do `shared_examples` được expand khi chạy. Chạy `docker compose exec web bundle exec rspec --dry-run` để có con số chính xác hiện tại.

---

## Changelog

| Version | Ngày | Thay đổi |
|---------|------|---------|
| v1.0.0 | 29/04/2026 | Khởi tạo. |
