# 14. Hướng dẫn triển khai — Deployment Guide

> **Version:** v1.0.0 | **Date:** 2026-05-05
>
> **Audience:** Developer / vai trò kỹ thuật (`tech`) triển khai hệ thống
>
> **Cross-references:** `03_QUICKSTART_v1_0_0`, `08_INFRASTRUCTURE_v1_0_0`
>
> **Source of truth cho hạ tầng (Docker, nginx, backup cơ chế):** `08_INFRASTRUCTURE_v1_0_0.md`. File này focus vào **runbook thực hành** — lệnh CLI từng bước, paths thực tế, troubleshooting.

---

## Mục lục

1. [Tổng quan kiến trúc triển khai](#1-tổng-quan-kiến-trúc-triển-khai)
2. [Yêu cầu hệ thống](#2-yêu-cầu-hệ-thống)
3. [Development environment](#3-development-environment)
4. [Production — Triển khai lần đầu](#4-production--triển-khai-lần-đầu)
5. [Production — Cập nhật phiên bản mới](#5-production--cập-nhật-phiên-bản-mới)
6. [Staging — Railway](#6-staging--railway)
7. [Backup và phục hồi](#7-backup-và-phục-hồi)
8. [CI/CD](#8-cicd)
9. [Troubleshooting](#9-troubleshooting)
10. [TODO / Quyết định chờ](#10-todo--quyết-định-chờ)
11. [Changelog](#changelog)

---

## 1. Tổng quan kiến trúc triển khai

### 1.1 Sơ đồ production stack

```
[Trình duyệt người dùng]
        │ HTTP/HTTPS
        ▼
  [Nginx :80]          ← config/nginx/production.conf
  nginx:alpine         ← docker-compose.production.yml, service nginx
        │ HTTP proxy_pass
        ▼
  [Rails/Puma :3000]   ← build từ Dockerfile (Ruby 3.4.3, jemalloc)
  service web          ← docker-compose.production.yml, service web
        │ PostgreSQL protocol
        ▼
  [PostgreSQL :5432]   ← postgres:16-alpine
  service db           ← docker-compose.production.yml, service db
        │ bind mount
        ▼
  ./db/backups/        ← pg_dump backup files (host path)
```

### 1.2 Ba môi trường

| Aspect | Development | Staging (Railway) | Production (Mini PC) |
|---|---|---|---|
| Compose / Build | `docker-compose.yml` | NIXPACKS (Railway managed) | `docker-compose.production.yml` |
| Web server | Puma trực tiếp (bind mount code) | Puma (Railway managed) | Puma + Nginx reverse proxy |
| Database | named volume `postgres_data` | Railway PostgreSQL addon | named volume `postgres_data` (→ bind mount `./pgdata/` trên Mini PC) |
| Port host | 3000 (web), 5433 (db) | Railway managed | 80 (nginx), db không expose |
| HTTPS | Không (HTTP localhost) | ✅ Railway edge (auto) | Local certs IT khách (cần cấu hình) |
| Backup cron | Không | Không | 2:00 AM hàng ngày |
| Deploy trigger | Thủ công (`docker compose up`) | Auto (push lên `main`) | Thủ công (`git pull` + build) |
| Source code | Bind mount (live reload) | COPY trong NIXPACKS build | COPY trong Dockerfile build |

---

## 2. Yêu cầu hệ thống

### 2.1 Phần cứng (production Mini PC)

| Thành phần | Yêu cầu | Ghi chú |
|---|---|---|
| Máy chủ | Mini PC Optori P54M | Đặt tại đơn vị, mạng LAN nội bộ |
| OS | Ubuntu 24.04 LTS | LTS đến 2029 |
| RAM | ≥ 2 GB (khuyến nghị 8–16 GB) | 2 GB tối thiểu để chạy 3 container |
| Storage | 2 SSDs | SSD1: server chính; SSD2: backup mirror |
| Network | IP cố định trong LAN | Không expose Internet |

### 2.2 Phần mềm

| Công cụ | Phiên bản tối thiểu | Ghi chú |
|---|---|---|
| Docker Engine | ≥ 24.0 | Cài qua `get.docker.com` |
| Docker Compose Plugin | v2.x | Cú pháp `docker compose` (dấu cách) |
| Git | bất kỳ | Clone repo |

**Không cần cài** Ruby, PostgreSQL, hoặc Node.js trên host — toàn bộ chạy trong container.

### 2.3 Network

- Port **80** mở trong LAN (nginx)
- Port **443** nếu cấu hình HTTPS trực tiếp trên nginx
- Truy cập từ máy nội bộ đơn vị — không expose Internet

---

## 3. Development environment

> **Chi tiết đầy đủ:** xem `03_QUICKSTART_v1_0_0.md` mục 1. Phần này chỉ tóm tắt flow.

### 3.1 Khởi động

```bash
git clone <repo-url> electric-water-management
cd electric-water-management
docker compose up -d --build
```

`docker-compose.yml` định nghĩa 2 service: `db` (postgres:16-alpine, port `5433:5432`) và `web` (Rails, port `3000:3000`, bind mount source code).

`bin/docker-entrypoint` tự gọi `db:prepare` (create + migrate, idempotent) khi container `web` khởi động.

### 3.2 Khởi tạo database

```bash
# db:prepare đã chạy tự động — chỉ cần seed
docker compose exec web bin/rails db:seed

# (Tùy chọn) Import data demo tháng 02/2026 + chạy CalculationEngine cho tất cả đơn vị
docker compose exec web bin/rails data:seed_demo
```

### 3.3 Verify

Mở **http://localhost:3000** — đăng nhập `admin@example.com` / `admin123`.

Health check: `curl http://localhost:3000/up` → `200 OK`

---

## 4. Production — Triển khai lần đầu

### 4.1 Chuẩn bị server (Ubuntu 24.04)

```bash
# Cài Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker    # hoặc logout và login lại
docker --version
docker compose version
```

### 4.2 Cấu trúc thư mục trên server

Cấu trúc đề xuất tại SSD1 (từ `08_INFRASTRUCTURE_v1_0_0.md` mục 3.2):

```
/opt/electric-water-management/
├── source-code/                    # git clone của repo
│   ├── docker-compose.production.yml
│   ├── config/nginx/production.conf
│   ├── Dockerfile
│   ├── .env.production             # Secrets — KHÔNG commit git
│   └── db/backups/                 # Bind mount backup files (tạo thủ công)
├── pgdata/                         # PostgreSQL data (bind mount — xem TODO mục 10)
├── certs/                          # SSL certs nếu nginx terminate SSL trực tiếp
└── cron-script.sh                  # Script cron backup (tùy chọn)
```

> **Lưu ý:** `docker-compose.production.yml` mặc định dùng **named volume** `postgres_data`. Trên Mini PC anh Phương sẽ chuyển sang bind mount `./pgdata/` để tiện snapshot SSD2. <!-- TODO: verify on production -->

### 4.3 Clone repo

```bash
git clone <repo-url> /opt/electric-water-management/source-code
cd /opt/electric-water-management/source-code
```

### 4.4 Cấu hình environment variables

```bash
cp .env.production.example .env.production
```

Mở `.env.production` và điền giá trị thực (từ `08_INFRASTRUCTURE_v1_0_0.md` mục 2.3):

```
DB_USERNAME=postgres
DB_PASSWORD=<mật_khẩu_mạnh_≥16_ký_tự>
DB_NAME=electric_water_management_production
RAILS_MASTER_KEY=<nội_dung_file_config/master.key>
BACKUP_DIR=/rails/db/backups
```

| Biến | Mô tả | Cách lấy |
|---|---|---|
| `DB_USERNAME` | User PostgreSQL | Tự đặt, ví dụ `postgres` |
| `DB_PASSWORD` | Mật khẩu PostgreSQL | Sinh ngẫu nhiên ≥ 16 ký tự — **không dùng default** |
| `DB_NAME` | Tên database | `electric_water_management_production` |
| `RAILS_MASTER_KEY` | Khóa giải mã `config/credentials.yml.enc` | Nội dung file `config/master.key` — không commit git, liên hệ developer |
| `BACKUP_DIR` | Thư mục backup trong container | Giữ nguyên `/rails/db/backups` |

> **Lỗi sai `RAILS_MASTER_KEY`:** Container `web` sẽ restart loop với lỗi `Missing encryption key to decrypt file with...` — xem mục 9.1.

### 4.5 Chuẩn bị thư mục backup

```bash
mkdir -p db/backups
sudo chown -R 1000:1000 db/backups/
sudo chmod 750 db/backups/
```

Container `web` chạy với UID/GID `1000:1000` (`Dockerfile` dòng 65–67). Host phải `chown` để container ghi được file backup. Nếu thiếu → lỗi "Permission denied" khi backup.

### 4.6 Build và khởi động

```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

Lần đầu build mất 5–10 phút (bundle install + asset precompile). Lần sau vài phút (layer cache).

Kiểm tra trạng thái:

```bash
docker compose -f docker-compose.production.yml ps
```

Output mong đợi — tất cả `Up`:

```
NAME                     SERVICE   STATUS    PORTS
source-code-db-1         db        running
source-code-web-1        web       running
source-code-nginx-1      nginx     running   0.0.0.0:80->80/tcp
```

### 4.7 Database setup

`bin/docker-entrypoint` tự gọi `bin/rails db:prepare` (create + migrate) khi container khởi động. Sau đó chạy seed thủ công:

```bash
# Seed cơ bản: 14 tổ chức, 7 nhóm cấp bậc, 16 tài khoản demo
docker compose -f docker-compose.production.yml exec web bin/rails db:seed

# (Tùy chọn) Import data demo tháng 02/2026 + CalculationEngine
docker compose -f docker-compose.production.yml exec web bin/rails data:seed_demo
```

> Trong production thật: sau `db:seed`, `tech` user tạo tài khoản thật qua F15 — seed users là tài khoản demo, nên xóa hoặc đổi mật khẩu sau bàn giao. <!-- TODO: verify on production -->

### 4.8 Cấu hình Nginx + HTTPS

`config/nginx/production.conf` hiện tại **chỉ lắng nghe port 80** (HTTP). Rails đã cấu hình `assume_ssl = true` và `force_ssl = true` (`config/environments/production.rb`) — sẵn sàng cho HTTPS khi cần.

**Hai phương án SSL** (chưa quyết định — xem mục 10):

**Phương án A — Nginx terminate SSL trực tiếp:**

1. Nhận cert từ IT khách (cert nội bộ LAN, không cần Let's Encrypt)
2. Đặt cert vào `../certs/` (ngoài `source-code/`)
3. Sửa `config/nginx/production.conf` thêm block `listen 443 ssl`
4. Thêm port 443 và bind mount `./certs/` vào `docker-compose.production.yml`
5. Rebuild nginx: `docker compose -f docker-compose.production.yml restart nginx`

**Phương án B — Reverse proxy ngoài (Caddy/Traefik):**

1. Cài Caddy hoặc Traefik trên host
2. Cấu hình forward tới nginx container port 80
3. Nginx + Rails giữ nguyên cấu hình

### 4.9 Verify hệ thống

```bash
# Health check (HTTP)
curl http://<server-ip>/up            # → 200 OK

# Hoặc nếu đã có HTTPS
curl https://<server-ip>/up           # → 200 OK

# Log container web (realtime)
docker compose -f docker-compose.production.yml logs -f web

# Log nginx
docker compose -f docker-compose.production.yml logs -f nginx
```

Mở trình duyệt `http://<server-ip>` — đăng nhập với tài khoản demo hoặc tài khoản thật sau khi tạo qua F15.

---

## 5. Production — Cập nhật phiên bản mới

```bash
cd /opt/electric-water-management/source-code

# Pull code mới từ repo
git pull

# Build lại image và khởi động lại service (zero-downtime với compose)
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

`bin/docker-entrypoint` tự gọi `db:prepare` (idempotent) khi container `web` restart — migration mới chạy tự động.

**Verify sau update:**

```bash
curl http://<server-ip>/up
docker compose -f docker-compose.production.yml logs --tail=50 web
```

**Rollback (nếu lỗi):**

```bash
git checkout <previous-commit>
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
# Nếu migration mới đã chạy và không tương thích → restore từ backup trước update
```

---

## 6. Staging — Railway

### 6.1 Cấu hình

File `railway.json` ở root repo:

```json
{
  "build": { "builder": "NIXPACKS" },
  "deploy": {
    "preDeployCommand": "bin/rails db:prepare",
    "startCommand": "bin/rails server -b ::"
  }
}
```

- **NIXPACKS**: Railway tự detect Rails app, build container không cần Dockerfile riêng
- **preDeployCommand**: migrate DB tự động trước khi start
- **startCommand**: `bin/rails server -b ::` — bind IPv6 wildcard (Railway yêu cầu)

### 6.2 Auto-deploy

Railway watch branch `main`. Mọi push lên `main` (kể cả merge PR) → trigger build + deploy mới tự động.

### 6.3 Env vars cần set thủ công trên Railway dashboard

| Biến | Railway | Ghi chú |
|---|---|---|
| `RAILS_MASTER_KEY` | Set thủ công | Lấy từ developer |
| `RAILS_SERVE_STATIC_FILES` | `true` | Không có nginx — Rails tự serve assets |
| `DATABASE_URL` | Auto-inject từ PostgreSQL addon | Thay thế `DB_HOST/PORT/USERNAME/PASSWORD/NAME` |

### 6.4 Khác biệt Railway vs production Mini PC

| Aspect | Railway | Mini PC |
|---|---|---|
| HTTPS | ✅ Tự động (Railway edge proxy) | Cần cấu hình thủ công |
| Backup | ❌ Không có cron, không có bind mount | ✅ Cron 2:00 AM + 2 SSD |
| DB access | Chỉ qua Railway CLI/dashboard | Direct (psql qua container exec) |
| File system | Ephemeral (mất khi redeploy) | Persistent (SSD) |
| Nginx | ❌ Không có | ✅ nginx:alpine |

### 6.5 Tại sao Railway là tạm

Railway là PaaS — không control infrastructure. Phần mềm deploy on-premise tại đơn vị quân đội — Railway không phải target environment cuối. Kế hoạch migrate sang VPS Docker trước M6 nghiệm thu (xem `08_INFRASTRUCTURE_v1_0_0.md` mục 5.6).

---

## 7. Backup và phục hồi

> **Code chi tiết `BackupService`:** xem `05_BUSINESS_LOGIC_v1_0_1.md` mục 5. Phần này focus vào lệnh CLI và vận hành.

### 7.1 Cơ chế

- `pg_dump -Fc` (custom format binary, có nén) → file `.dump`
- `pg_restore --clean --no-owner --no-acl -1` để phục hồi
- **Filename:** `backup_YYYYMMDD_HHMMSS.dump`
- **Container path:** `/rails/db/backups/` (env `BACKUP_DIR`)
- **Host path:** `./db/backups/` (bind mount vào container)

### 7.2 Ba cách trigger backup

**Cách 1 — Qua giao diện web** (vai trò `tech`):

Đăng nhập → menu **Sao lưu dữ liệu** → **Sao lưu ngay**

**Cách 2 — Qua terminal** (rake task `db:backup` trong `lib/tasks/db_backup.rake`):

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup
```

**Cách 3 — Cron tự động 2:00 AM hàng ngày** — thêm vào `crontab -e`:

```
0 2 * * * cd /opt/electric-water-management/source-code && docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup >> /var/log/ewm-backup.log 2>&1
```

> **Flag `-T` bắt buộc** khi chạy từ cron: cron không có TTY, thiếu `-T` sẽ exit ngay với lỗi "the input device is not a TTY".

Xem danh sách backup:

```bash
ls -lah db/backups/
```

### 7.3 Phục hồi từ backup

**Qua giao diện web** (vai trò `tech`): Sao lưu dữ liệu → nhấn **Phục hồi** cạnh file → xác nhận → đăng nhập lại.

**Qua terminal:**

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_20260423_020000.dump]'
```

> **Cảnh báo:** `pg_restore --clean` xóa **toàn bộ** dữ liệu hiện tại. Dữ liệu nhập sau backup mốc đó sẽ mất. **Bắt buộc backup ngay trước khi restore.**

Sau restore, `BackupsController#restore` sign out user đang gọi (vai trò `tech`). Các user khác đang đăng nhập vẫn còn cookie — khi họ refresh có thể gặp bất ngờ nếu data restore không khớp. **Quy ước vận hành tạm:** thông báo qua Zalo để mọi người đăng xuất trước khi restore.

### 7.4 Disaster recovery — 2 SSD

- **SSD1** (server): chạy production, backup cron 2:00 AM mỗi ngày → `db/backups/`
- **SSD2** (backup): mirror SSD1 qua `autorestic` — cấu hình do IT khách (ngoài scope repo)

**Kịch bản SSD1 chết:**

```bash
# Trên SSD mới (hoặc SSD2):
# 1. Cài Docker + clone repo
# 2. Restore backup file từ SSD2
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_YYYYMMDD_HHMMSS.dump]'
```

---

## 8. CI/CD

### 8.1 CI Pipeline (`.github/workflows/ci.yml`)

3 jobs chạy **song song** trên mỗi PR và push lên `main`:

| Job | Lệnh | Mục đích |
|---|---|---|
| `scan_ruby` | `bin/brakeman --no-pager` + `bin/bundler-audit` | Security: Rails static analysis + gem vulnerabilities |
| `scan_js` | `bin/importmap audit` | Security: JS import map dependencies |
| `lint` | `bin/rubocop -f github` | Code style |

Wall time ≈ thời gian job chậm nhất (~30s với RuboCop cache, ~2 phút khi cache miss).

**Không có RSpec trong CI** — developer chạy local trước khi push.

**Không có auto-deploy** — deploy thủ công theo mục 4 và 5.

### 8.2 Local CI runner

```bash
bin/ci                              # Trên host (cần Ruby + bundle)
docker compose exec web bin/ci      # Trong container dev
```

`bin/ci` gọi `config/ci.rb`: setup → rubocop → bundler-audit → importmap audit → brakeman. Có thêm step `Setup` (`bin/setup --skip-server`) so với CI workflow.

### 8.3 Trước khi commit / push

```bash
bin/rubocop -f github   # Luôn chạy không giới hạn path
bin/brakeman --no-pager
bin/bundler-audit
bundle exec rspec       # Chạy test suite local
```

---

## 9. Troubleshooting

### 9.1 Container `web` restart loop — lỗi `RAILS_MASTER_KEY`

```
Missing encryption key to decrypt file with...
```

`RAILS_MASTER_KEY` trong `.env.production` sai hoặc thiếu. Kiểm tra:

```bash
cat .env.production | grep RAILS_MASTER_KEY
docker compose -f docker-compose.production.yml logs web | tail -20
```

Lấy giá trị đúng từ file `config/master.key` của developer (không commit git).

### 9.2 Nginx trả về `502 Bad Gateway`

Container `nginx` up trước `web` sẵn sàng — tạm thời, tự hết sau vài giây. Nếu kéo dài:

```bash
docker compose -f docker-compose.production.yml logs web
docker compose -f docker-compose.production.yml ps
```

Nếu `web` đang restart liên tục → thường do `RAILS_MASTER_KEY` sai (mục 9.1) hoặc DB chưa migrate.

### 9.3 Permission denied khi backup

```bash
sudo chown -R 1000:1000 db/backups/
sudo chmod 750 db/backups/
```

Container chạy UID 1000 (`Dockerfile` dòng 65–67) — host phải cho phép ghi.

### 9.4 Migrations pending sau pull code mới

```bash
docker compose -f docker-compose.production.yml exec web bin/rails db:migrate
```

Hoặc đơn giản restart container — `docker-entrypoint` tự gọi `db:prepare` khi restart.

### 9.5 Database không kết nối được

```bash
docker compose -f docker-compose.production.yml logs db
```

Kiểm tra `DB_USERNAME` và `DB_PASSWORD` trong `.env.production` khớp với `POSTGRES_USER`/`POSTGRES_PASSWORD` mà container `db` dùng khi khởi tạo. Nếu đổi sau khi volume đã tạo → cần xóa volume và tạo lại (mất data — restore từ backup).

### 9.6 CSS / assets không load

Assets được precompile trong Dockerfile build stage (`SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile`). Nếu assets cũ:

```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

### 9.7 Rake tasks tham chiếu nhanh

```bash
# Reset mật khẩu admin bị khóa (escape hatch — lib/tasks/admin.rake)
docker compose -f docker-compose.production.yml exec web bin/rails 'admin:reset_password[email@example.com]'

# Backup thủ công (lib/tasks/db_backup.rake)
docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup

# Restore từ file (lib/tasks/db_backup.rake)
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_YYYYMMDD_HHMMSS.dump]'

# Import data demo + CalculationEngine (lib/tasks/data.rake)
docker compose -f docker-compose.production.yml exec web bin/rails data:seed_demo

# Rails console
docker compose -f docker-compose.production.yml exec web bin/rails console

# Xem log realtime
docker compose -f docker-compose.production.yml logs -f web nginx

# Dừng hệ thống (giữ data)
docker compose -f docker-compose.production.yml down

# Kiểm tra health
curl http://<server-ip>/up
```

---

## 10. TODO / Quyết định chờ

Từ `08_INFRASTRUCTURE_v1_0_0.md` mục TODO và quá trình triển khai:

1. **Bind mount `./pgdata/` trên Mini PC:** `docker-compose.production.yml` hiện dùng named volume `postgres_data`. Cần override compose để dùng bind mount `./pgdata/` trên Mini PC (tiện snapshot SSD2). Chưa có file override trong repo — thêm khi triển khai.

2. **SSL: chốt phương án trước khi deploy thật.** `config/nginx/production.conf` hiện chỉ `listen 80`. Hai phương án (mục 4.8) — cần chọn cùng IT khách và test trên staging VPS trước. <!-- TODO: verify on production -->

3. **Monitoring (Netdata + Uptime Kuma):** document only, chưa cài. Quyết định trong M6 nghiệm thu — nếu khách yêu cầu, cập nhật file này với lệnh cài cụ thể.

4. **`DEPLOY.md` (root repo):** runbook ngắn hiện tại còn tồn tại. Sau khi `14_DEPLOY` đầy đủ, cân nhắc deprecate `DEPLOY.md` hoặc giữ như quick reference một trang.

5. **Stale sessions sau restore:** `BackupsController#restore` chỉ sign out user gọi restore. Sessions user khác còn hợp lệ — workaround vận hành: thông báo trước khi restore. Fix code (rotate `secret_key_base`) — xem TODO #6 trong `05_BUSINESS_LOGIC_v1_0_1.md`.

6. **Tài khoản demo sau bàn giao:** `db/seeds.rb` tạo 16 tài khoản với mật khẩu `admin123` và `Test1234!`. Trong production thật, cần xóa hoặc đổi mật khẩu các tài khoản demo trước khi bàn giao. <!-- TODO: verify on production -->

---

## Changelog

| Version | Ngày | Thay đổi |
|---|---|---|
| v1.0.0 | 2026-05-05 | Khởi tạo. |
