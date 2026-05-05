# 08. Infrastructure — v1.0.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì.
>
> **Mục đích file này:** Tài liệu hạ tầng — Docker, production setup, backup, CI, environments.
>
> **Đối tượng đọc:** Developer cần setup môi trường, hoặc đội kỹ thuật cần triển khai/vận hành production.
>
> **Quick start:** Xem 03_QUICKSTART để chạy project từ zero.
>
> **Backup chi tiết:** Xem 05_BUSINESS_LOGIC mục 5 cho `BackupService` code.

> Thuật ngữ sử dụng tuân theo `02_GLOSSARY_v1_4_0.md`.

---

## Mục lục

1. [Docker — Development](#1-docker--development)
2. [Docker — Production](#2-docker--production)
3. [Production setup — Mini PC](#3-production-setup--mini-pc)
4. [Backup và Restore](#4-backup-và-restore)
5. [Railway — Staging tạm](#5-railway--staging-tạm)
6. [CI Pipeline](#6-ci-pipeline)
7. [So sánh 3 environments](#7-so-sánh-3-environments)
8. [TODO — sai lệch giữa code và docs](#todo--sai-lệch-giữa-code-và-docs)
9. [Changelog](#changelog)

---

## 1. Docker — Development

### 1.1 Tổng quan

Workflow chính của developer là chạy toàn bộ stack qua `docker compose up` — không cài Ruby, PostgreSQL hay Node trên host. File `docker-compose.yml` ở root repo định nghĩa 2 service: `db` (PostgreSQL 16) và `web` (Rails 8). Lệnh khởi động đầy đủ và verify xem `03_QUICKSTART` mục 1.

### 1.2 Services trong `docker-compose.yml`

| Service | Image | Port host:container | Volumes | depends_on |
|---|---|---|---|---|
| `db` | `postgres:16-alpine` | `5433:5432` | `postgres_data:/var/lib/postgresql/data` (named volume) | — |
| `web` | build từ `Dockerfile` | `3000:3000` | `.:/rails` (bind mount source) + `bundle_cache:/usr/local/bundle` (named volume) | `db: condition: service_healthy` |

**Đặc điểm `db`:**

- `POSTGRES_USER=postgres`, `POSTGRES_PASSWORD=postgres`, `POSTGRES_DB=electric_water_management_development`. Mật khẩu default cho dev — không được đem qua production.
- Healthcheck: `pg_isready -U postgres` mỗi 5 giây, retry 5 lần. `web` chỉ khởi động sau khi healthy.
- Port 5433 ở host (không phải 5432 default) để tránh xung đột với PostgreSQL local nếu developer cài sẵn.

**Đặc điểm `web`:**

- Command override: `bash -c "rm -f tmp/pids/server.pid && bundle exec rails server -b 0.0.0.0"` — xóa PID file cũ trước khi start (tránh "A server is already running" khi container restart).
- Bind mount `.:/rails` cho phép edit code trên host và Rails auto-reload (development mode). Khác production — production COPY code vào image.
- Named volume `bundle_cache:/usr/local/bundle` giữ gem cache giữa các lần `docker compose down` — không phải reinstall gem mỗi lần.
- Env vars khác production (xem mục 1.5): `RAILS_ENV=development`, `DB_HOST=db`, `DB_PORT=5432` (port nội bộ network compose, không phải 5433).

### 1.3 `Dockerfile` — multi-stage

File `Dockerfile` ở root, dùng cho **cả development lẫn production** (cùng image, khác cách chạy). 3 stage:

| Stage | Mục đích | Kết quả |
|---|---|---|
| `base` | Cài runtime packages: `curl`, `libjemalloc2`, `libvips`, `postgresql-client`. Set ENV `RAILS_ENV=production`, `BUNDLE_DEPLOYMENT=1`, `BUNDLE_PATH=/usr/local/bundle`, `BUNDLE_WITHOUT=development`, `LD_PRELOAD=libjemalloc.so`. | Image cơ sở Ruby 3.4.3-slim. |
| `build` | Cài build packages (`build-essential`, `git`, `libpq-dev`, `libyaml-dev`, `pkg-config`). Chạy `bundle install`, `bundle exec bootsnap precompile -j 1 --gemfile`, `bootsnap precompile -j 1 app/ lib/`, và `assets:precompile` (với `SECRET_KEY_BASE_DUMMY=1`). | Bundle gems + bootsnap cache + precompiled assets. |
| (final) | COPY artifacts từ `build` stage. Tạo non-root user `rails` UID/GID `1000:1000`. ENTRYPOINT = `/rails/bin/docker-entrypoint`. CMD = `./bin/thrust ./bin/rails server`. EXPOSE 80. | Image production gọn (~250 MB). |

> **Tham chiếu:** `Dockerfile` 79 dòng, dòng 11 (Ruby version), dòng 65–67 (non-root user — xem 06_AUTH_SECURITY mục 6.5), dòng 78 (default CMD via Thruster).

**Khác biệt khi chạy dev:** `docker-compose.yml` override `command:` thành `bundle exec rails server -b 0.0.0.0` (không qua Thruster) và mount source code vào `/rails`. Tức image vẫn là production-ready, chỉ runtime config khác.

> **Lưu ý jemalloc:** `LD_PRELOAD` trỏ tới `libjemalloc.so` ngay từ `base` stage — Ruby process dùng jemalloc thay malloc default, giảm memory fragmentation cho Rails app dài hạn. Áp dụng cả dev lẫn production.

### 1.4 `bin/docker-entrypoint` — auto db:prepare

```bash
#!/bin/bash -e

if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails db:prepare
fi

exec "${@}"
```

- Chạy `bin/rails db:prepare` (`db:create + db:migrate`, idempotent) khi command kết thúc bằng `./bin/rails server`.
- Không chạy `db:seed` — seed phải tự gọi (`docker compose exec web bin/rails db:seed`).
- Match điều kiện chỉ với 2 token cuối — nếu CMD khác (ví dụ `bin/rails console`), entrypoint không chạy db:prepare.

### 1.5 Env vars — `.env.example`

```
DB_HOST=127.0.0.1
DB_PORT=5433
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

| Biến | Mục đích | Khi cần |
|---|---|---|
| `DB_HOST` | Host PostgreSQL | Chỉ khi chạy Rails **trực tiếp trên host** (không qua Docker), kết nối tới PostgreSQL container qua port 5433 mapped. |
| `DB_PORT` | Port PostgreSQL | Như trên — phải khớp port mapped trong `docker-compose.yml`. |
| `DB_USERNAME` / `DB_PASSWORD` | Credentials | Khớp với `POSTGRES_USER`/`POSTGRES_PASSWORD` của container `db`. |

Khi chạy đầy đủ qua `docker compose up`, **không cần** file `.env` — biến môi trường khai báo trực tiếp trong block `environment:` của service `web` (`docker-compose.yml` dòng 26–31). File `.env.example` chỉ dành cho workflow chạy Rails ngoài Docker (ví dụ `bin/rails server` trên host, dùng PostgreSQL container như backend) — xem mục 1.7 bên dưới.

> **Tham chiếu:** Logic ưu tiên ENV trong `config/database.yml` dòng 4–7 dùng `ENV.fetch(...)` với default fallback (host `localhost`, port `5433`, user/pass `postgres`).

### 1.6 Khác biệt: chạy ngoài Docker (`bin/dev`)

Workflow phụ — developer chạy Rails trực tiếp trên host, dùng PostgreSQL container làm backend:

```bash
docker compose up -d db    # Chỉ start PostgreSQL container
bin/dev                    # Start Rails + Tailwind watcher trên host
```

`bin/dev` (script Ruby) trước tiên build Tailwind 1 lần (`bin/rails tailwindcss:build`) để đảm bảo `tailwind.css` tồn tại, rồi `exec foreman start -f Procfile.dev`. `Procfile.dev` định nghĩa 2 process:

```
web: bin/rails server -p 3000
css: bin/rails tailwindcss:watch[always]
```

`foreman` chạy 2 process song song — tailwindcss:watch theo dõi thay đổi `app/assets/stylesheets/application.tailwind.css` và rebuild liên tục. Mode `[always]` (option của `tailwindcss-rails`) buộc rebuild kể cả khi không có file thay đổi (poll mode) — hữu ích khi watcher mismatch trên một số filesystem.

**Khi nào dùng `bin/dev`:** Khi muốn debug bằng `byebug`/`debug` gem trực tiếp trên host (terminal IO không qua Docker layer), hoặc khi performance Docker quá chậm. Đa số trường hợp dùng `docker compose exec web` đủ.

> **Yêu cầu:** Cần Ruby 3.4.3 (xem `.ruby-version`), bundler, và gem `foreman` cài global (`gem install foreman`). Xem `03_QUICKSTART` mục 4.9 troubleshooting.

### 1.7 `bin/setup` — script idempotent

`bin/setup` chạy `bundle install`, `bin/rails db:prepare`, `log:clear tmp:clear`, rồi `exec bin/dev`. Hỗ trợ flag `--reset` (drop + recreate DB) và `--skip-server` (không start server cuối cùng). `bin/ci` gọi `bin/setup --skip-server` trước khi chạy lint/audit (xem mục 6.4).

### 1.8 Tóm tắt khác biệt dev vs production

| Aspect | Development | Production |
|---|---|---|
| Compose file | `docker-compose.yml` | `docker-compose.production.yml` |
| Source code | Bind mount `.:/rails` (live reload) | COPY vào image lúc build |
| Port host | 3000 (web), 5433 (db) | 80 (nginx), 3000 (web chỉ expose nội bộ network), db không expose |
| Web server | Puma trực tiếp `bundle exec rails server -b 0.0.0.0` | Puma sau Nginx reverse proxy. CMD default Dockerfile dùng Thruster (`./bin/thrust`) — production compose override thành `bin/rails server -b 0.0.0.0 -p 3000`. |
| RAILS_ENV | `development` | `production` |
| Asset pipeline | Tailwind watcher (rebuild khi sửa) | Precompiled trong build stage Dockerfile |
| Log | Rails `log/development.log` | Stdout (RAILS_LOG_TO_STDOUT=true) → Docker logs |
| DB password | Hardcode `postgres` | Từ `.env.production` |
| HTTPS | Không | Reverse proxy phía trước (xem mục 2.6) |

---

## 2. Docker — Production

### 2.1 Tổng quan

Production stack gồm 3 service trong `docker-compose.production.yml`: `db` (PostgreSQL 16), `web` (Rails 8), `nginx` (reverse proxy). Build cùng `Dockerfile` với dev — khác biệt chỉ ở compose file và env vars. File `.env.production` chứa secrets, không commit git.

Bước triển khai chi tiết và lệnh CLI: xem `03_QUICKSTART` mục 2 và `DEPLOY.md` (file ở root repo, dành cho đội kỹ thuật khách).

### 2.2 Services trong `docker-compose.production.yml`

| Service | Image | Port | Volumes | Restart policy |
|---|---|---|---|---|
| `db` | `postgres:16-alpine` | Không expose ra host (chỉ truy cập trong network compose) | `postgres_data:/var/lib/postgresql/data` (named volume) | `unless-stopped` |
| `web` | build từ `Dockerfile` | `expose: 3000` (chỉ trong network compose, không bind ra host) | `./db/backups:/rails/db/backups` (bind mount) | `unless-stopped` |
| `nginx` | `nginx:alpine` | `80:80` (host:container) | `./config/nginx/production.conf:/etc/nginx/conf.d/default.conf:ro` (read-only mount) | `unless-stopped` |

**Đặc điểm `db`:**

- Credentials lấy từ env: `POSTGRES_USER=${DB_USERNAME}`, `POSTGRES_PASSWORD=${DB_PASSWORD}`, `POSTGRES_DB=${DB_NAME}`.
- Healthcheck: `pg_isready -U ${DB_USERNAME}` mỗi 10s, retry 5. `web` đợi healthy.
- **Không expose port ra host** — chỉ `web` và `nginx` (qua network compose) tới được DB. Defense-in-depth chống unauthorized access từ host network.
- Dữ liệu nằm trong **named volume** `postgres_data`. Trên Mini PC sẽ chuyển sang **bind mount** `./pgdata/` để tiện snapshot SSD (xem mục 3).

**Đặc điểm `web`:**

- ENV: `RAILS_ENV=production`, `RAILS_MASTER_KEY` (decrypt credentials), `RAILS_LOG_TO_STDOUT=true` (Docker logs thay file), `BACKUP_DIR=/rails/db/backups`.
- Bind mount `./db/backups:/rails/db/backups` — backup dump file ghi từ container, đọc được trên host. Container chạy UID 1000 — host phải `chown 1000:1000` thư mục này (xem 06_AUTH_SECURITY mục 6.5).
- `expose: 3000` chỉ public port trong network compose, không bind ra host — chỉ nginx tới được.
- Command: `bin/rails server -b 0.0.0.0 -p 3000` (không dùng Thruster — Thruster chỉ là default CMD của Dockerfile).

**Đặc điểm `nginx`:**

- Port 80 host → 80 container. **Không có 443** — SSL termination bên ngoài (xem mục 2.6).
- Mount config read-only — không thể sửa từ container, sửa trên host rồi `docker compose restart nginx`.
- Phụ thuộc `web` (start sau) nhưng không có healthcheck cho `web` — nginx có thể up sớm hơn web sẵn sàng → 502 Bad Gateway tạm thời (xem `03_QUICKSTART` mục 4.5).

### 2.3 Env vars — `.env.production.example`

```
DB_USERNAME=postgres
DB_PASSWORD=changeme_secure_password
DB_NAME=electric_water_management_production
RAILS_MASTER_KEY=<value from config/master.key>
BACKUP_DIR=/rails/db/backups
```

| Biến | Mô tả | Cách lấy giá trị |
|---|---|---|
| `DB_USERNAME` | User PostgreSQL | Tự đặt — ví dụ `postgres`. |
| `DB_PASSWORD` | Mật khẩu PostgreSQL | **Mật khẩu mạnh ≥ 16 ký tự**, sinh ngẫu nhiên. Không dùng default. |
| `DB_NAME` | Tên database | `electric_water_management_production` (mặc định). |
| `RAILS_MASTER_KEY` | Khóa giải mã `config/credentials.yml.enc` | Giá trị nội dung file `config/master.key` của developer (không commit git — liên hệ developer). |
| `BACKUP_DIR` | Thư mục backup trong container | Giữ nguyên `/rails/db/backups` (bind mount đã wire sẵn). |

`config/credentials.yml.enc` chứa `secret_key_base` Rails dùng để encrypt session cookie. Sai `RAILS_MASTER_KEY` → web container restart loop với lỗi "Missing encryption key" (xem `03_QUICKSTART` mục 4.4).

### 2.4 `config/nginx/production.conf` — chi tiết

```nginx
upstream rails_app {
    server web:3000;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    gzip on;
    gzip_types text/html text/css application/javascript application/json;
    gzip_min_length 1024;

    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location /assets/ {
        proxy_pass http://rails_app;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        proxy_pass http://rails_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
    }
}
```

| Directive | Tác dụng | Lý do chọn giá trị |
|---|---|---|
| `upstream rails_app { server web:3000; }` | Pool 1 backend | DNS `web` resolve theo Docker network, port nội bộ 3000. |
| `listen 80` | HTTP only | SSL termination bên ngoài (mục 2.6). |
| `server_name _` | Catch-all | Mini PC có IP cố định, không có domain — accept mọi Host header. |
| `client_max_body_size 10M` | Giới hạn upload | Phần mềm không có upload file lớn — F14 export CSV chỉ vài MB. 10M dư cho future-proof. |
| `gzip on` + `gzip_min_length 1024` | Nén response | Bảng 24 cột HTML có thể vài chục KB — gzip giảm ~70%. |
| `gzip_types ...` | Loại MIME được nén | HTML, CSS, JS, JSON. Không nén ảnh (đã nén). |
| `X-Frame-Options SAMEORIGIN` | Chống clickjacking | Phần mềm nội bộ, không cần embed iframe ngoài. |
| `X-Content-Type-Options nosniff` | Chặn MIME sniffing | Defense-in-depth. |
| `X-XSS-Protection "1; mode=block"` | XSS filter browser cũ | Deprecated trên Chrome modern, nhưng vô hại. |
| `location /assets/` + `expires 1y` + `Cache-Control immutable` | Cache asset 1 năm | Asset có fingerprint hash (Rails default) — cache aggressive. |
| `proxy_set_header X-Forwarded-Proto $scheme` | Forward scheme tới Rails | Khi reverse proxy ngoài terminate SSL, header này = `https` → Rails với `assume_ssl = true` tin và set cookie `secure`. |
| `proxy_read_timeout 300s` | Timeout đợi response từ Rails | 5 phút — đủ rộng cho rake task hoặc query lâu. Default nginx 60s có thể fail backup/restore qua UI. |

> **Cross-reference:** Security header trùng với Rails-level (`config/environments/production.rb:72–76` trong 06_AUTH_SECURITY mục 6.2). Header được set 2 lần (Rails + nginx) — không xung đột, browser dùng giá trị cuối nhận được. Đây là defense-in-depth.

### 2.5 Bind mounts — UID 1000 và backup directory

- `./db/backups:/rails/db/backups` — backup dump files. Container ghi với UID 1000, host cần `chown 1000:1000 db/backups/`. Lý do: container chạy non-root (xem 06_AUTH_SECURITY mục 6.5).
- `./config/nginx/production.conf:/etc/nginx/conf.d/default.conf:ro` — config nginx. Read-only (`:ro`) — container không sửa được.

Trên Mini PC, ngoài 2 mount trên còn có thể có `./pgdata/` cho PostgreSQL (thay named volume) và `./certs/` cho SSL nếu nginx terminate SSL — xem mục 3.

### 2.6 SSL — hiện trạng và kế hoạch

**Hiện tại:** `config/nginx/production.conf` chỉ `listen 80`. Không có SSL block.

**Intent (xem 06_AUTH_SECURITY mục 6.1):** Mini PC chạy Rails sau **HTTPS reverse proxy** (Cloudflare hoặc nginx ngoài cùng do IT khách quản lý). Rails app nhận HTTP từ proxy.

- `production.rb:29` → `config.assume_ssl = true` — Rails tin header `X-Forwarded-Proto: https` từ proxy, không tự reject HTTP request nội bộ.
- `production.rb:32` → `config.force_ssl = true` — Rails redirect HTTP → HTTPS từ phía client (cookie `secure`, HSTS header).
- `nginx/production.conf` forward `proxy_set_header X-Forwarded-Proto $scheme` để chain hoạt động.

**Trên Railway staging:** HTTPS managed bởi Railway edge proxy — khớp với `assume_ssl + force_ssl` config.

**Trên Mini PC:** 2 phương án, quyết định cuối khi triển khai khách (xem TODO mục 8 file này):

1. Sửa `config/nginx/production.conf` thêm `listen 443 ssl`, mount certificate vào nginx container, cập nhật `docker-compose.production.yml` thêm port 443 và bind mount `./certs/`.
2. Đặt reverse proxy phía trước (Caddy auto-renew Let's Encrypt, hoặc Traefik). Nginx container giữ nguyên port 80.

Cert local từ IT khách cung cấp (nội bộ LAN, không cần Let's Encrypt).

---

## 3. Production setup — Mini PC

> **Cross-reference:** Bối cảnh chiến lược (anh Phương phụ trách, 2 SSDs, IP cố định) xem `01_OVERVIEW` mục 7.

### 3.1 Hardware

| Thành phần | Cấu hình | Ghi chú |
|---|---|---|
| Máy chủ | Mini PC Optori P54M | Đặt tại đơn vị khách, mạng LAN nội bộ. |
| OS | Ubuntu 24.04 LTS | LTS đến 2029. |
| RAM | ≥ 8 GB (khuyến nghị 16 GB) | Dự án nhỏ, 2 GB tối thiểu (xem `DEPLOY.md`). 16 GB cho buffer monitoring/backup. |
| Storage | 2 SSDs (1 server + 1 backup) | SSD1: source + DB + filesystem chính. SSD2: backup mirror qua autorestic cron. |
| Network | IP cố định trong LAN | Không expose Internet — chỉ truy cập từ máy nội bộ đơn vị. |

### 3.2 Directory structure trên SSD1

Cấu trúc dự kiến tại root deploy (ví dụ `/opt/electric-water-management/`):

```
/opt/electric-water-management/
├── source-code/            # Git clone của repo
│   ├── docker-compose.production.yml
│   ├── config/nginx/production.conf
│   ├── Dockerfile
│   ├── .env.production     # Secrets, không commit git
│   └── ...
├── pgdata/                 # PostgreSQL data (bind mount thay named volume)
├── upload/                 # File user upload (nếu phát sinh — hiện tại không dùng)
├── certs/                  # SSL certs (nếu nginx terminate SSL trực tiếp)
├── db/backups/             # pg_dump output, mount vào /rails/db/backups
├── Dockerfile.xxx          # Override Dockerfile cho Mini PC nếu cần
├── compose.yml             # Override docker-compose.production.yml nếu cần
└── cron-script.sh          # Script gọi db:backup và autorestic
```

> **Lưu ý:** Cấu trúc này khác `docker-compose.production.yml` mặc định (dùng named volume `postgres_data`). Trên Mini PC, anh Phương sẽ chuyển sang bind mount `./pgdata/` để tiện snapshot SSD và restore từ SSD2. Cụ thể compose override hoặc Dockerfile override (`Dockerfile.xxx`, `compose.yml`) chưa có trong repo — sẽ thêm khi triển khai. Xem TODO mục 8.

### 3.3 Network

- **IP cố định** trong LAN đơn vị (ví dụ `10.x.x.x` hoặc `192.168.x.x`).
- Không expose Internet — phần mềm chỉ truy cập từ máy nội bộ đơn vị.
- HTTPS qua **local certs do IT khách cung cấp** — cài lên nginx container hoặc reverse proxy phía trước. Xem mục 2.6.

### 3.4 Monitoring — chưa cài

| Tool | Mục đích | Trạng thái |
|---|---|---|
| Netdata | System metrics realtime (CPU, RAM, disk, network), agent local trên Mini PC. Web UI nhẹ. | **Chưa cài.** Dự án chỉ document cách integrate, không cài sẵn. |
| Uptime Kuma | Monitor uptime endpoint `/up` (Rails health check). Self-hosted, alert qua email/webhook. | **Chưa cài.** Document only. |

Lý do "document only": dự án giai đoạn 1 không bao gồm monitoring stack. Quyết định cài hay không thuộc về IT khách sau bàn giao. Tài liệu monitoring chi tiết (cài đặt, dashboard mẫu) — xem `14_DEPLOY` (khi có).

### 3.5 Bảo mật và verify

- **IT khách tự verify security** sau setup — quét port, kiểm tra firewall, SSL config. Dự án giao codebase + Docker compose + tài liệu, không chịu trách nhiệm hardening hệ điều hành Mini PC.
- Defense-in-depth từ phía app: `Rack::Attack` (06_AUTH_SECURITY mục 6.3), security headers (06_AUTH_SECURITY mục 6.2), Devise Lockable (06_AUTH_SECURITY mục 2.3), CanCanCan scope isolation (06_AUTH_SECURITY mục 3).
- Phía hạ tầng: container non-root UID 1000 (06_AUTH_SECURITY mục 6.5), DB không expose ra host, robots.txt + meta noindex (06_AUTH_SECURITY mục 6.4).

---

## 4. Backup và Restore

> **Code chi tiết của `BackupService`:** xem `05_BUSINESS_LOGIC` mục 5. File này focus vào hạ tầng (binding, cron, ownership, disaster recovery).

### 4.1 Cơ chế

- `pg_dump -Fc` (custom format binary, có nén) tạo file `.dump`.
- `pg_restore --clean --no-owner --no-acl -1` để phục hồi (xóa table cũ, restore trong 1 transaction).
- Mật khẩu DB truyền qua env var `PGPASSWORD` (không qua arg → không lộ trong `ps`).
- Service gọi qua `Open3.capture3(env, *cmd_array)` — không qua shell → tránh injection.

### 4.2 Path và filename convention

- **Container path:** `/rails/db/backups/` (env `BACKUP_DIR`).
- **Host path:** `./db/backups/` (relative tới project root) — bind mount vào container.
- **Filename:** `backup_YYYYMMDD_HHMMSS.dump` (giây-precision, không trùng).
- File extension `.dump` — `BackupService.list` glob `*.dump` (xem 05_BUSINESS_LOGIC mục 5.3).

### 4.3 Permission — UID 1000 ownership

Container Docker chạy với UID/GID `1000:1000` (`Dockerfile:65–67`). Khi `pg_dump` ghi file vào `/rails/db/backups/`, file thuộc UID 1000. Trên host, thư mục `db/backups/` phải:

```bash
sudo chown -R 1000:1000 db/backups/
sudo chmod 750 db/backups/   # rwx cho UID 1000, r-x cho group, none cho other
```

Nếu host UID 1000 không tồn tại hoặc khác user, file vẫn ghi được (UID là số, không cần resolve username) — nhưng admin host sẽ thấy file thuộc "1000" thay vì username quen. Đây là expected behavior, không phải lỗi.

> **Troubleshooting:** Lỗi "Permission denied" khi backup → xem `03_QUICKSTART` mục 4.6.

### 4.4 3 cách trigger backup

| Cách | Ai chạy | Khi nào | Lệnh |
|---|---|---|---|
| **UI web** | `tech` (chỉ vai trò này — xem `02_GLOSSARY` mục 7) | Adhoc — trước nâng cấp, trước restore | Đăng nhập → menu **Sao lưu dữ liệu** → **Sao lưu ngay** |
| **Rake task** | Bất kỳ ai có shell access | Manual debug, hoặc gọi từ cron | `docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup` |
| **Cron tự động** | Hệ thống (root hoặc deploy user) | Mỗi ngày 2:00 sáng | Crontab: `0 2 * * * cd /opt/electric-water-management && docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup >> /var/log/ewm-backup.log 2>&1` |

> **Tham chiếu:** `lib/tasks/db_backup.rake` định nghĩa `db:backup` và `db:restore`. UI controller: `BackupsController#create`. Quy tắc CanCanCan chỉ `tech` có quyền — `admin_level1` được explicit `cannot :manage, :backup` (05_BUSINESS_LOGIC mục 5.6).

> **Flag `-T`:** `docker compose exec -T` tắt TTY allocation — bắt buộc khi chạy từ cron (cron không có TTY). Nếu thiếu `-T`, exec sẽ exit ngay với lỗi "the input device is not a TTY".

### 4.5 Restore flow

```bash
# Qua rake task
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_20260423_020000.dump]'
```

Hoặc qua UI: tech user → Sao lưu dữ liệu → "Phục hồi" cạnh file → xác nhận.

**Dòng chảy** (xem 05_BUSINESS_LOGIC mục 5.2):

1. `safe_filepath!(filename)` validate filename (chặn `/`, `..` → path traversal). 
2. `pg_restore --clean` drop tất cả table hiện tại.
3. `pg_restore -1` restore trong 1 transaction. Lỗi → rollback, DB giữ nguyên.
4. `BackupsController#restore` gọi `sign_out current_user`, redirect tới `new_user_session_path`.

**Caveat về session — stale sessions của user khác:**

`sign_out current_user` chỉ sign out **user đang gọi restore** (thường là `tech`). Sessions của user khác (admin_level1, admin_unit, commander đang đăng nhập) **vẫn còn cookie hợp lệ** trên browser của họ. Khi họ refresh, cookie giải mã ra `User#id` cũ — nếu data restore không khớp (user đó đã bị xóa hoặc đổi role), Devise có thể behave bất ngờ.

Đây là **TODO #6 trong 05_BUSINESS_LOGIC** (chưa fix). Tương lai cần `User.update_all(remember_token: nil)` hoặc rotate `secret_key_base` sau restore để invalidate toàn bộ session. Tạm thời quy ước vận hành: restore chỉ làm khi tất cả user đã đăng xuất, hoặc thông báo trước qua kênh khác (Zalo) để mọi người login lại.

### 4.6 Cảnh báo

- Restore **ghi đè toàn bộ** dữ liệu hiện tại (`pg_restore --clean` drop table). Dữ liệu nhập sau backup → mất.
- **Bắt buộc backup trước khi restore** — tạo snapshot of "now" trước khi quay về snapshot cũ.
- Không có recycle bin — `BackupService.delete!(filename)` xóa thật, không revert được.

### 4.7 Disaster recovery — 2 SSDs

Trên Mini PC:

- **SSD1** (server): chạy production, ghi backup vào `db/backups/` mỗi ngày 2:00 AM qua cron.
- **SSD2** (backup): chạy `autorestic` (wrapper restic) cron mirror SSD1 sang SSD2 — tần suất do IT khách cấu hình.

**Kịch bản disaster recovery:**

1. **SSD1 chết:** Lấy SSD2, mount vào hệ thống, restore source code và `db/backups/` từ SSD2 lên SSD mới. Khởi động lại stack Docker, chạy `db:restore[latest_backup.dump]`.
2. **DB corrupt:** `db:restore` từ backup gần nhất trên SSD1. Nếu file SSD1 cũng hỏng, lấy từ SSD2.
3. **App lỗi sau update:** `git checkout <previous-commit>` source code, rebuild image, restore DB nếu cần.

Cấu hình `autorestic` cụ thể (config file, schedule, retention) thuộc trách nhiệm IT khách — không trong scope dự án. Repo chỉ cung cấp file backup chuẩn, IT khách quyết định mirror như thế nào.

> **Cross-reference:** Disaster recovery RTO/RPO mục tiêu chưa cố định trong scope dự án. Xem `12_SCOPE` (khi cập nhật) hoặc thảo luận với khách trong giai đoạn nghiệm thu (M6).

---

## 5. Railway — Staging tạm

### 5.1 Cấu hình hiện tại

File `railway.json` ở root repo:

```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "preDeployCommand": "bin/rails db:prepare",
    "startCommand": "bin/rails server -b ::"
  }
}
```

| Field | Giá trị | Tác dụng |
|---|---|---|
| `build.builder` | `NIXPACKS` | Railway tự detect Rails app, build container không cần Dockerfile riêng. Khác production Mini PC dùng Dockerfile thủ công. |
| `deploy.preDeployCommand` | `bin/rails db:prepare` | Migrate DB tự động trước khi start app — idempotent. |
| `deploy.startCommand` | `bin/rails server -b ::` | Bind IPv6 + IPv4 (`::` là IPv6 wildcard, Linux mặc định cho phép IPv4 mapped). Railway proxy yêu cầu listen IPv6. |

### 5.2 Auto-deploy

- Railway watch branch `main` của repo GitHub.
- Mỗi push lên `main` (kể cả merge PR) → trigger build + deploy mới.
- Build NIXPACKS detect `Gemfile`, `package.json` (không có), `.ruby-version` → tự cài Ruby 3.4.3 và bundle install.
- Sau build, chạy `preDeployCommand` rồi `startCommand`.

### 5.3 PostgreSQL addon

- Railway cung cấp PostgreSQL managed (không phải self-host) qua addon riêng trong cùng project.
- Kết nối qua env var `DATABASE_URL` Railway tự inject (Rails 8 đọc env này thay `config/database.yml` khi present).
- Không có quyền truy cập host PostgreSQL — chỉ qua Railway dashboard và CLI.

### 5.4 Env vars Railway-specific

Khác production Mini PC:

| Biến | Railway | Mini PC |
|---|---|---|
| `DATABASE_URL` | ✅ Auto-inject từ PostgreSQL addon | ❌ Dùng `DB_HOST/PORT/USERNAME/PASSWORD/NAME` riêng lẻ |
| `RAILS_MASTER_KEY` | Manual set qua Railway dashboard | Trong `.env.production` |
| `RAILS_ENV` | `production` (mặc định khi build NIXPACKS) | `production` (set explicit trong compose) |
| `PORT` | Railway tự inject port động | Hardcode 3000 trong compose |
| `RAILS_LOG_TO_STDOUT` | Mặc định true (Railway capture stdout) | Set explicit `true` |
| `RAILS_SERVE_STATIC_FILES` | Cần set `true` (không có nginx serve assets) | Không cần — nginx mount serve `/assets/` |
| `BACKUP_DIR` | Không dùng (không có backup cron) | `/rails/db/backups` |

> **Lưu ý:** Danh sách env vars Railway-specific thực tế phụ thuộc cấu hình hiện tại trên dashboard — file `railway.json` chỉ chứa build/deploy command, không chứa env vars. Xem TODO mục 8.

### 5.5 URL staging

URL Railway dạng `<app>.up.railway.app` (Singapore region) — dùng để demo cho khách và test trước khi deploy production. URL cụ thể chưa lock vào tài liệu (có thể đổi khi rotate environment hoặc redeploy) — xem TODO mục 8.

### 5.6 Tại sao Railway là tạm

Theo `01_OVERVIEW` mục 7: kế hoạch chuyển sang **VPS Docker** trước khi deploy production thực sự lên Mini PC. Lý do:

- Railway là PaaS — không control infrastructure (network, storage, region).
- Phần mềm cuối cùng deploy on-premise tại đơn vị quân đội — Railway không phải target environment.
- Tier free Railway có quota nhỏ (chỉ đủ demo, không đủ load thực tế).
- Compliance: data quân đội không nên store trên cloud nước ngoài (Railway US, addon Singapore).

VPS Docker (giai đoạn trung gian) cho phép test deploy bằng `docker-compose.production.yml` thật trước khi mang lên Mini PC.

### 5.7 Limitations so với production

| Aspect | Railway | Production Mini PC |
|---|---|---|
| Reverse proxy | Railway edge (managed) | Nginx tự config (mục 2.4) |
| HTTPS | ✅ Tự động (Railway cert) | Manual (cert IT khách) |
| Backup | ❌ Không có cron, không có bind mount | ✅ Cron 2:00 AM + 2 SSD autorestic (mục 4.4, 4.7) |
| File system | Ephemeral (mất khi redeploy) | Persistent (SSD bind mount) |
| Monitoring | Railway dashboard cơ bản | Netdata + Uptime Kuma (planned, mục 3.4) |
| Custom Dockerfile | ❌ NIXPACKS only | ✅ Full control |
| DB access | Chỉ qua Railway CLI/dashboard | Direct (psql qua container exec) |
| Cost | Pay-per-usage | One-time hardware (Mini PC) |

---

## 6. CI Pipeline

### 6.1 Trigger

`.github/workflows/ci.yml`:

```yaml
on:
  pull_request:
  push:
    branches: [ main ]
```

- Chạy trên **mọi PR** (mọi branch tạo PR đều trigger).
- Chạy trên **push trực tiếp lên `main`** (theo memory `feedback_no_direct_push_to_main.md`, không push thẳng lên `main` — trigger này tồn tại như fallback).

### 6.2 3 jobs song song

| Job | Steps | Mục đích |
|---|---|---|
| `scan_ruby` | 1. Checkout. 2. Setup Ruby (`bundler-cache: true`). 3. `bin/brakeman --no-pager`. 4. `bin/bundler-audit`. | Static analysis Rails security + audit gem vulnerabilities. |
| `scan_js` | 1. Checkout. 2. Setup Ruby. 3. `bin/importmap audit`. | Audit JavaScript import map dependencies (gem `importmap-rails`). |
| `lint` | 1. Checkout. 2. Setup Ruby. 3. Cache RuboCop (`tmp/rubocop`). 4. `bin/rubocop -f github`. | Style check. Cache theo hash `(.ruby-version + .rubocop.yml + Gemfile.lock)` — tăng tốc CI run sau lần đầu. |

3 jobs chạy **song song** trên 3 runner ubuntu-latest riêng → tổng wall time ≈ thời gian job chậm nhất (thường `lint` ~30s với cache, ~2 phút khi cache miss).

### 6.3 Không có RSpec trong CI

CI workflow **không chạy `bundle exec rspec`**. Lý do (theo memory + project policy):

- Chạy RSpec trong CI cần PostgreSQL service container (setup database test) — mỗi job thêm ~30s.
- Solo developer, RSpec chạy local trước khi push (xem `03_QUICKSTART` mục 1.8).
- Khi merge PR, dev chịu trách nhiệm spec pass — CI chỉ guard về style + security.

> **Note CLAUDE.md:** CLAUDE.md ghi "5 bước CI: rubocop, bundler-audit, importmap audit, brakeman, rspec (nếu có)". Thực tế repo chỉ 4 step (không có rspec). Xem TODO mục 8.

### 6.4 `bin/ci` — local runner

Khác CI workflow, `bin/ci` là script Ruby chạy local pipeline đầy đủ. File `config/ci.rb` định nghĩa các step:

```ruby
CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"
  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
```

5 step (Setup + 4 check). Chạy với:

```bash
bin/ci                    # Trên host
docker compose exec web bin/ci   # Trong container
```

Khác biệt với CI workflow:

- Có step `Setup` (gọi `bin/setup --skip-server` — bundle install, db:prepare, log:clear).
- `bin/rubocop` không có flag `-f github` (output dạng default thay vì format GitHub Actions).
- `bin/brakeman` thêm `--quiet --no-pager --exit-on-warn --exit-on-error` — strict hơn CI workflow.

### 6.5 Quy tắc cho Claude Code

> **Memory rule** (`feedback_rubocop_full_project.md`): Luôn chạy `bin/rubocop -f github` không giới hạn path trước khi commit.

Khác với memory: **Claude Code chỉ cần chạy `rspec` cho thay đổi logic** (theo CLAUDE.md). Không phải chạy `rubocop` mỗi turn (tốn thời gian) — developer chạy local trước khi commit. CI chặn merge PR nếu rubocop fail.

### 6.6 Setup Ruby trong CI

Tất cả 3 jobs dùng `ruby/setup-ruby@v1` với `bundler-cache: true`. Cấu hình:

- Đọc `.ruby-version` (3.4.3) → cài Ruby version đó.
- Đọc `Gemfile.lock` → cài gem cùng version pin.
- Cache `vendor/bundle` theo hash `Gemfile.lock` — tái sử dụng giữa các CI run.

Khi nào cache invalidate: thay đổi `Gemfile.lock` (thêm/sửa gem). CI run đầu sau update sẽ mất 2–3 phút bundle install lần đầu, các run sau ~10 giây.

---

## 7. So sánh 3 environments

| Aspect | Development | Staging (Railway) | Production (Mini PC) |
|---|---|---|---|
| Compose / Build | `docker-compose.yml` | Railway managed (NIXPACKS) | `docker-compose.production.yml` |
| Database | `postgres:16-alpine` (named volume `postgres_data`) | Railway PostgreSQL addon (managed) | `postgres:16-alpine` (bind mount `./pgdata/` trên Mini PC) |
| Web server | Puma trực tiếp (`bin/rails server`) | Puma (Railway start command) | Puma + Nginx reverse proxy |
| Tailwind | Watcher live (`tailwindcss:watch[always]`) hoặc precompiled trong image | Precompiled trong build NIXPACKS | Precompiled trong build Dockerfile |
| HTTPS | Không (chỉ HTTP localhost:3000) | ✅ Railway edge SSL | Local certs do IT khách cung cấp (kế hoạch — xem mục 2.6) |
| Backup | Manual (rake task hoặc UI), không cron | ❌ Không có | ✅ Cron 2:00 AM + autorestic mirror sang SSD2 |
| Monitoring | N/A | Railway dashboard cơ bản | Netdata + Uptime Kuma (planned, chưa cài — mục 3.4) |
| Source code | Bind mount (live reload) | COPY trong build NIXPACKS | COPY trong build Dockerfile |
| Container user | UID 1000 (cùng image) | Railway managed | UID 1000 |
| Log destination | File `log/development.log` + Docker stdout | Railway log capture | Docker stdout (`RAILS_LOG_TO_STDOUT=true`) |
| Rack::Attack | Active (06_AUTH_SECURITY mục 6.3) | Active | Active |
| Devise Lockable | Active | Active | Active |
| Force SSL | Không (`production.rb` chỉ apply khi `RAILS_ENV=production`) | ✅ Active (assume_ssl + force_ssl) | ✅ Active (cùng config) |
| Trigger deploy | `docker compose up -d` thủ công | Auto on push to `main` | `git pull && docker compose up -d --build` thủ công |

---

## TODO — sai lệch giữa code và docs

1. **CLAUDE.md ghi CI có 5 steps bao gồm rspec, thực tế chỉ 4.** CLAUDE.md mục "Test" có gợi ý "Chạy `bundle exec rspec` sau mỗi thay đổi logic" và task description đề cập "5 bước CI: rubocop, bundler-audit, importmap audit, brakeman, rspec (nếu có)". File `.github/workflows/ci.yml` thực tế chỉ có 3 jobs (scan_ruby, scan_js, lint) với 4 check (rubocop + brakeman + bundler-audit + importmap audit) — **không có rspec job**. `bin/ci` local cũng không gọi rspec. Cần đồng bộ: hoặc thêm rspec job vào CI (thêm PostgreSQL service, ~30s/run), hoặc cập nhật doc rằng rspec chỉ chạy local.

2. **Cấu trúc Mini PC (`source-code/`, `pgdata/`, `upload/`, `certs/`, `Dockerfile.xxx`, `compose.yml`) chưa có trong repo.** `docker-compose.production.yml` hiện dùng named volume `postgres_data` (không phải bind mount `./pgdata/`), không có `./certs/` mount, không có override file. Cấu trúc thư mục này dự định setup khi triển khai khách (anh Phương phụ trách) — sẽ có override compose hoặc `Dockerfile.xxx` riêng. Cần verify trước khi deploy thật và cập nhật docs sau setup.

3. **SSL config trên Mini PC chưa quyết định.** `config/nginx/production.conf` chỉ `listen 80`. 2 phương án (mục 2.6): nginx terminate SSL trực tiếp, hoặc reverse proxy ngoài (Caddy/Traefik). Cần chốt với IT khách trước khi deploy.

4. **URL staging Railway và env vars cụ thể chưa lock vào docs.** `railway.json` chỉ có build/deploy command, không có env vars list. URL Railway có thể thay đổi khi rotate environment. Cần snapshot trạng thái Railway hiện tại (URL, env vars) vào doc — hoặc ghi rõ "Railway là tạm, sẽ deprecate trước M6 nghiệm thu".

5. **DEPLOY.md (file ở root) trùng nội dung với mục 2 file này.** `DEPLOY.md` viết bằng tiếng Việt, dành cho IT khách — gồm bước cài Docker, build, restore. File 08_INFRASTRUCTURE focus structure + lý do, DEPLOY.md focus runbook lệnh. Cần quyết định: keep cả 2 (chấp nhận overlap — DEPLOY.md ngắn hơn, dễ theo step-by-step) hoặc deprecate DEPLOY.md, link sang 08 + 14_DEPLOY (khi có).

6. **Disaster recovery RTO/RPO không có target cụ thể.** Mục 4.7 mô tả kịch bản restore từ SSD2 nhưng không định nghĩa Recovery Time Objective (mất bao lâu phục hồi) và Recovery Point Objective (chấp nhận mất bao nhiêu data). Backup cron 2:00 AM nghĩa là RPO ≤ 24h, nhưng cần xác nhận với khách trong giai đoạn nghiệm thu.

7. **Stale session sau restore — chưa fix (TODO #6 trong 05_BUSINESS_LOGIC).** Restore chỉ sign out user gọi restore, sessions của user khác vẫn còn cookie hợp lệ — có thể stale nếu DB restore khác state hiện tại. Workaround vận hành tạm thời, fix code (rotate `secret_key_base` hoặc `User.update_all(remember_token: nil)`) chưa làm.

8. **Monitoring (Netdata + Uptime Kuma) chỉ document, chưa cài.** Mục 3.4 ghi rõ "document only". Cần quyết định cài hay không trong M6 nghiệm thu — nếu khách yêu cầu, cập nhật `14_DEPLOY` với hướng dẫn cài cụ thể.

9. **`bin/ci` không khớp 100% với CI workflow.** `bin/ci` (local) gọi `bin/rubocop` không có `-f github` flag, có thêm step `Setup` (`bin/setup --skip-server`), và `bin/brakeman` strict hơn (`--exit-on-warn --exit-on-error`). CI workflow (`.github/workflows/ci.yml`) gọi `bin/rubocop -f github` để output GitHub Actions format. Đây là lựa chọn ý muốn (local dùng default format, CI dùng GitHub format) — không phải bug, nhưng đáng ghi rõ để tránh bất ngờ khi local pass mà CI fail (hoặc ngược lại).

---

## Changelog

| Version | Ngày | Thay đổi |
|---------|------|---------|
| v1.0.0 | 01/05/2026 | Khởi tạo. |
