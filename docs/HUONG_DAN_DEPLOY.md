# Hướng dẫn deploy — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.3.0
> **Ngày:** 10/06/2026
> **Đối tượng:** Người thực hiện deploy (kỹ thuật viên, cố vấn IT, hoặc developer).
> **Server:** Ubuntu 24.04, Docker, LAN nội bộ, không có internet.
> **Thời gian ước tính:** 1-2 giờ (lần đầu).
> **Tham khảo:** Để hiểu chi tiết Docker và cách hệ thống hoạt động, xem `docs/KIEN_THUC_DOCKER.md`.

---

## Tổng quan

Hệ thống gồm 3 thành phần chạy trong Docker:

```
Trình duyệt (LAN) → nginx (port 80) → Rails app → PostgreSQL
```

- **nginx** — nhận request từ trình duyệt, chuyển cho Rails
- **app** — xử lý nghiệp vụ (tính tiền điện, quản lý đầu mối, xuất báo cáo)
- **postgres** — lưu trữ toàn bộ dữ liệu

Server không cần internet. Toàn bộ phần mềm được chuẩn bị trước trên máy có internet rồi copy sang server qua USB.

---

## Yêu cầu phần cứng

| Thành phần | Yêu cầu tối thiểu | Khuyến nghị |
|---|---|---|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8-16 GB |
| Ổ cứng chính | 50 GB SSD | 512 GB SSD |
| Ổ cứng phụ | 512 GB SSD (sao lưu) | — |
| Mạng | LAN, IP cố định | — |
| Hệ điều hành | Ubuntu 24.04 | — |

Ổ cứng phụ dùng để sao lưu tự động (mục Sao lưu tự động). Bắt buộc — nếu ổ chính hỏng, dữ liệu vẫn còn trên ổ phụ.

---

## Phần A — Chuẩn bị trên máy có internet

> Thực hiện trên máy tính bất kỳ có internet và Docker. Có thể là máy developer hoặc máy khác.

### A1. Cài Docker

Tải và cài Docker Desktop (Mac/Windows) hoặc Docker Engine (Linux): https://docs.docker.com/get-docker/

Xác nhận đã cài:

```bash
docker --version
docker compose version
```

### A2. Tạo bản delivery

```bash
git clone <repo-url> electric-water-management
cd electric-water-management
bin/prepare-delivery
cd ../electric-water-management-delivery
```

Từ bước này trở đi, tất cả thao tác đều trong thư mục `electric-water-management-delivery`.

### A3. Build Docker images cho server

Build image app và pull images postgres + nginx:

```bash
docker build -t ewm-app .
docker pull postgres:16-alpine
docker pull nginx:alpine
```

Nếu máy chuẩn bị là Mac Apple Silicon (ARM) mà server là Intel/AMD (x86_64), thêm `--platform linux/amd64`:

```bash
docker build --platform linux/amd64 -t ewm-app .
docker pull --platform linux/amd64 postgres:16-alpine
docker pull --platform linux/amd64 nginx:alpine
```

### A4. Lưu images ra file

```bash
docker save ewm-app postgres:16-alpine nginx:alpine | gzip > ewm-images.tar.gz
```

File này khoảng 500 MB - 1 GB.

### A5. Tạo SECRET_KEY_BASE

```bash
docker run --rm ewm-app bin/rails secret
```

Lưu chuỗi 128 ký tự hex này lại — cần ở bước B4.

### A6. Copy sang USB

Copy 3 thứ vào USB:

```
USB/
├── electric-water-management-delivery/    # Thư mục source code đã dọn sạch
└── ewm-images.tar.gz                      # Docker images đã build
```

---

## Phần B — Cài đặt trên server

> Thực hiện trên server Ubuntu. Server cần có Docker đã cài sẵn (xem Phụ lục 1 nếu chưa cài).

### B1. Copy file từ USB

```bash
# Cắm USB, mount (Ubuntu thường tự mount vào /media/<user>/<tên USB>)
cp -r /media/$USER/<tên-USB>/electric-water-management-delivery /opt/ewm
cp /media/$USER/<tên-USB>/ewm-images.tar.gz /opt/ewm/
cd /opt/ewm
```

### B2. Load Docker images

```bash
docker load < ewm-images.tar.gz
```

Mất 1-2 phút. Xác nhận:

```bash
docker images
```

Phải thấy 3 images: `ewm-app`, `postgres`, `nginx`.

### B3. Tạo file cấu hình

```bash
cp .env.example .env
```

Mở file `.env`, điền giá trị:

```
POSTGRES_PASSWORD=<đặt mật khẩu mạnh, ví dụ: MatKhau$Manh2026>
SECRET_KEY_BASE=<chuỗi 128 ký tự từ bước A5>
```

Hai dòng còn lại (`POSTGRES_USER`, `POSTGRES_DB`) giữ nguyên mặc định.

### B4. Khởi động

```bash
docker compose up -d
```

Chờ 30-60 giây. Kiểm tra:

```bash
# Xem trạng thái 3 containers
docker compose ps

# Phải thấy cả 3 ở trạng thái "Up":
# postgres  Up (healthy)
# app       Up
# nginx     Up
```

Nếu container nào không Up, xem lỗi:

```bash
docker compose logs <tên-container>
# Ví dụ: docker compose logs app
```

### B5. Kiểm tra hoạt động

Từ trình duyệt trên máy tính khác trong LAN, truy cập:

```
http://<IP-server>
```

Phải thấy trang đăng nhập tiếng Việt "Hệ thống quản lý điện nội bộ Sư đoàn".

### B6. Đăng nhập lần đầu

Đăng nhập bằng tài khoản kỹ thuật viên mặc định:

- Tên đăng nhập: `kyThuat`
- Mật khẩu: `Abc@1234`

Hệ thống bắt buộc đổi mật khẩu lần đầu. Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số, và ký tự đặc biệt.

Sau đó đăng nhập tài khoản quản trị viên hệ thống:

- Tên đăng nhập: `quanTri`
- Mật khẩu: `Abc@1234`

Cũng phải đổi mật khẩu.

### B7. Xác nhận hoàn tất

Checklist sau khi deploy:

- [ ] Truy cập `http://<IP-server>` từ máy khác trong LAN — thấy trang đăng nhập
- [ ] Đăng nhập `kyThuat` thành công, đổi mật khẩu
- [ ] Đăng nhập `quanTri` thành công, đổi mật khẩu
- [ ] Trang Tổng quan hiện "Không có kỳ đang mở"
- [ ] Sidebar hiện đủ các mục menu
- [ ] Tạo thử 1 bản sao lưu trên trang Sao lưu dữ liệu — thành công
- [ ] Thiết lập sao lưu tự động sang ổ cứng phụ (mục Sao lưu tự động)

---

## Vận hành hàng ngày

### Khởi động lại server (sau khi tắt/mất điện)

Docker tự khởi động lại containers khi server bật (nhờ `restart: unless-stopped`). Không cần làm gì.

Nếu cần khởi động thủ công:

```bash
cd /opt/ewm
docker compose start
```

### Xem logs khi có lỗi

```bash
cd /opt/ewm
docker compose logs app          # Logs ứng dụng
docker compose logs postgres     # Logs database
docker compose logs nginx        # Logs web server
docker compose logs              # Tất cả
```

### Dừng hệ thống

```bash
cd /opt/ewm
docker compose stop
```

### Trạng thái

```bash
cd /opt/ewm
docker compose ps
```

---

## Sao lưu dữ liệu

### Lớp 1 — Sao lưu qua giao diện web (snapshot tạm trước thao tác nguy hiểm)

Dùng khi cần tạo bản sao lưu trước thao tác quan trọng (ví dụ: trước khi cập nhật phiên bản, trước khi khôi phục dữ liệu cũ).

1. Đăng nhập tài khoản kỹ thuật viên
2. Vào trang **Sao lưu dữ liệu** trên sidebar
3. Bấm **Tạo bản sao lưu mới**
4. Hệ thống tạo file backup, lưu trong container

Tối đa 3 bản. Đây là snapshot **tạm thời** trước thao tác nguy hiểm — **không** phải nguồn sao lưu chính (nguồn chính là Lớp 3, tự động sang ổ phụ, bên dưới). Muốn tạo bản mới khi đã đủ 3 — xóa bản cũ nhất trước.

### Khôi phục từ bản sao lưu

> **Quan trọng — tạo bản sao lưu TRƯỚC khi khôi phục:** restore ghi đè toàn bộ dữ liệu hiện tại. Trước khi chạy, hãy tạo một bản sao lưu Lớp 1 qua giao diện web (mục trên) để còn đường lùi nếu khôi phục hỏng. (Quy ước: `CONTRIBUTING.md` mục 10, ADR-017.)

Khôi phục thực hiện qua dòng lệnh (không có nút trên giao diện vì đây là thao tác nguy hiểm — ghi đè toàn bộ dữ liệu hiện tại):

```bash
cd /opt/ewm

# Xem danh sách bản sao lưu
docker compose exec app bundle exec rails runner "Backup.all.each { |b| puts \"#{b.filename} — #{b.created_at}\" }"

# Khôi phục (thay <tên-file> bằng tên file thực)
docker compose exec app bundle exec rails "backups:restore[<tên-file>]"
```

Hệ thống hỏi xác nhận trước khi khôi phục. Gõ `YES` (chữ hoa) để xác nhận.

### Lớp 3 — Sao lưu tự động sang ổ cứng phụ (bắt buộc, nguồn cậy chính)

Đây là **nguồn sao lưu chính** (nằm ngoài máy chạy app): nếu ổ chính hoặc cả máy hỏng, dữ liệu vẫn còn trên ổ phụ. Lớp 1 (giao diện) chỉ là snapshot tạm. Giữ 7 bản gần nhất để có khoảng lùi an toàn.

1. Mount ổ cứng phụ (ví dụ `/mnt/backup`):

```bash
# Xem tên ổ
lsblk

# Mount (thay sdb1 bằng tên thực)
sudo mkdir -p /mnt/backup
sudo mount /dev/sdb1 /mnt/backup

# Tự mount khi khởi động lại
echo "/dev/sdb1 /mnt/backup ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

2. Chạy script thiết lập có sẵn:

```bash
cd /opt/ewm
sudo ./script/setup-auto-backup /mnt/backup
```

Script tự động:
- Sao lưu database (pg_dump) + file sao lưu trong app mỗi ngày lúc 2:00 sáng
- Giữ tối đa 7 bản, xóa bản cũ nhất tự động
- Ghi log tại `/mnt/backup/ewm-backup/backup.log`

---

## Cập nhật phiên bản

> **Trước khi cập nhật:** trên server, tạo một bản sao lưu Lớp 1 qua giao diện web để có đường lùi nếu bản mới gặp sự cố.

Khi có phiên bản mới từ nhà phát triển:

1. Trên máy có internet: lặp lại Phần A (tạo bản delivery mới + build images mới)
2. Copy sang USB
3. Trên server:

```bash
cd /opt/ewm

# Backup file cấu hình cũ
cp .env /tmp/ewm-env-backup

# Thay code mới
docker compose down
cd /opt
rm -rf /opt/ewm
cp -r /media/$USER/<tên-USB>/electric-water-management-delivery /opt/ewm
cp /media/$USER/<tên-USB>/ewm-images.tar.gz /opt/ewm/
cd /opt/ewm

# Khôi phục cấu hình + load images mới
cp /tmp/ewm-env-backup .env
docker load < ewm-images.tar.gz
docker compose up -d
```

---

## Xử lý sự cố

### Container không khởi động

```bash
docker compose logs <tên-container>
```

| Lỗi | Nguyên nhân | Cách xử lý |
|---|---|---|
| `POSTGRES_PASSWORD not set` | Thiếu file .env hoặc chưa điền password | Kiểm tra file .env |
| `port is already allocated` | Port 80 bị phần mềm khác chiếm | Dừng phần mềm đó hoặc đổi port trong compose.yml |
| `no space left on device` | Ổ cứng đầy | Xóa file cũ, dọn Docker: `docker system prune` |
| `fe_sendauth: no password supplied` | Database password sai | Kiểm tra POSTGRES_PASSWORD trong .env |

### Quên mật khẩu tài khoản

Kỹ thuật viên hoặc quản trị viên hệ thống reset mật khẩu cho người khác qua giao diện web (trang Tài khoản).

Nếu quên mật khẩu cả 2 tài khoản mặc định, reset qua dòng lệnh:

```bash
cd /opt/ewm
docker compose exec app bundle exec rails runner "
  user = User.find_by(username: 'kyThuat')
  user.update!(password: 'Abc@1234', password_confirmation: 'Abc@1234', force_password_change: true)
  puts 'Đã reset mật khẩu kyThuat về Abc@1234'
"
```

### Hệ thống chậm

```bash
# Kiểm tra tài nguyên
docker stats
```

Nếu RAM hoặc CPU cao liên tục, cân nhắc tăng phần cứng.

### Muốn xóa toàn bộ và cài lại từ đầu

```bash
cd /opt/ewm
docker compose down -v    # -v xóa cả database
docker compose up -d      # Tạo lại từ đầu (database trống, seed 2 tài khoản)
```

**Cảnh báo: mất toàn bộ dữ liệu.** Chỉ làm khi thực sự cần thiết.

---

## Phụ lục 1 — Cài Docker trên Ubuntu 24.04

> Thực hiện 1 lần khi server chưa có Docker. Cần internet tạm thời hoặc cài offline từ file .deb.

### Có internet tạm thời

```bash
# Cập nhật hệ thống
sudo apt update && sudo apt upgrade -y

# Cài Docker
curl -fsSL https://get.docker.com | sudo sh

# Cho user hiện tại dùng Docker không cần sudo
sudo usermod -aG docker $USER

# Đăng xuất rồi đăng nhập lại, sau đó xác nhận
docker --version
docker compose version
```

### Hoàn toàn offline

Tải Docker Engine .deb packages trên máy có internet:

1. Vào https://download.docker.com/linux/ubuntu/dists/noble/pool/stable/amd64/
2. Tải 3 file: `containerd.io_*.deb`, `docker-ce_*.deb`, `docker-ce-cli_*.deb`
3. Tải thêm docker-compose-plugin: `docker-compose-plugin_*.deb`
4. Copy 4 file sang server qua USB

Trên server:

```bash
sudo dpkg -i containerd.io_*.deb docker-ce-cli_*.deb docker-ce_*.deb docker-compose-plugin_*.deb
sudo usermod -aG docker $USER
# Đăng xuất rồi đăng nhập lại
docker --version
```

---

## Phụ lục 2 — Thông tin kỹ thuật

| Thành phần | Chi tiết |
|---|---|
| Ngôn ngữ | Ruby 3.4.3, Rails 8 |
| Database | PostgreSQL 16 |
| Web server | nginx (reverse proxy) + Thrust (HTTP/2) |
| Timezone | Asia/Ho_Chi_Minh (UTC+7) |
| Port | 80 (HTTP) |
| Dữ liệu | Docker volumes: pg_data, storage_data, backups_data |
| Backup | pg_dump (custom format), tối đa 3 bản qua giao diện |
| Tài khoản mặc định | kyThuat / Abc@1234, quanTri / Abc@1234 |
| Health check | http://\<IP\>/up (trả 200 nếu app chạy) |

---

## Lịch sử thay đổi

### v1.3.0 (10/06/2026)

- Làm rõ chính sách sao lưu theo ADR-016/017: đặt tên **Lớp 1** (snapshot giao diện, tạm) vs **Lớp 3** (tự động sang ổ phụ, nguồn cậy chính, 7 bản); thêm cảnh báo **tạo bản sao lưu Lớp 1 trước khi khôi phục** và **trước khi cập nhật phiên bản**. (Issue #307)

### v1.2.0 (24/05/2026)

- compose.yml thêm `image: ewm-app` cùng `build: .` — Docker Compose tự dùng image có sẵn, không cần sửa tay file.
- Xóa bước B3 (sửa compose.yml thủ công). Đánh lại số B4-B7.

### v1.1.0 (24/05/2026)

- A2: bỏ `pip3 install git-filter-repo` (script tự cài).
- A3: sửa dùng `docker build -t ewm-app` thay `docker compose build` (tên image khớp docker save).
- Yêu cầu phần cứng: ổ cứng phụ chuyển từ khuyến nghị sang bắt buộc.
- Cập nhật phiên bản: thêm bước backup `.env` trước khi xóa code cũ.

### v1.0.0 (24/05/2026)

- Tài liệu ban đầu. Cover: chuẩn bị offline (build images, save file, copy USB), cài đặt trên server (load images, cấu hình, khởi động), vận hành hàng ngày, 3 lớp sao lưu (giao diện, terminal restore, cron tự động sang ổ phụ), cập nhật phiên bản, xử lý sự cố, cài Docker offline.
- Bắt buộc chạy `bin/prepare-delivery` trước khi ship (bước A2).
- Script `setup-auto-backup` thiết lập cron tự động.
