# Hướng dẫn deploy — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 2.1.0
> **Ngày:** 24/05/2026
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

### A2. Build bản production

```bash
git clone <repo-url> electric-water-management
cd electric-water-management
deploy/production/build
```

Nếu server dùng CPU Intel/AMD (x86_64) mà máy chuẩn bị là Mac Apple Silicon:

```bash
deploy/production/build --platform amd64
```

Script tự động: tạo bản delivery sạch → build Docker images → save ra file → tạo SECRET_KEY_BASE. Mất 3-5 phút.

Kết quả nằm trong thư mục `../electric-water-management-delivery/`.

### A3. Copy sang USB

Copy toàn bộ thư mục `electric-water-management-delivery/` vào USB. Bên trong đã có:

```
electric-water-management-delivery/
├── (source code đã dọn sạch)
├── ewm-images.tar.gz              # Docker images (~400MB)
└── SECRET_KEY_BASE.txt             # Khóa mã hóa (cần ở bước B3)
```

---

## Phần B — Cài đặt trên server

> Thực hiện trên server Ubuntu. Server cần có Docker đã cài sẵn (xem Phụ lục 1 nếu chưa cài).

### B1. Cài đặt

Cắm USB, chạy 1 lệnh:

```bash
sudo /media/$USER/<tên-USB>/electric-water-management-delivery/deploy/production/server
```

Script tự phát hiện cài mới hay cập nhật, và thực hiện:
- Cài mới: copy source code vào `/opt/ewm` → load images → hỏi mật khẩu database → tạo .env → khởi động → hỏi thiết lập sao lưu tự động
- Cập nhật: backup .env → thay code → load images → khởi động

Mất 1-2 phút. Khi xong, script hiện IP server và tài khoản đăng nhập.

### B2. Đăng nhập lần đầu

Đăng nhập bằng tài khoản kỹ thuật viên mặc định:

- Tên đăng nhập: `kyThuat`
- Mật khẩu: `Abc@1234`

Hệ thống bắt buộc đổi mật khẩu lần đầu. Mật khẩu mới phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số, và ký tự đặc biệt.

Sau đó đăng nhập tài khoản quản trị viên hệ thống:

- Tên đăng nhập: `quanTri`
- Mật khẩu: `Abc@1234`

Cũng phải đổi mật khẩu.

### B3. Xác nhận hoàn tất

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

### Sao lưu qua giao diện web (khi cần)

Dùng khi cần tạo bản sao lưu trước thao tác quan trọng (ví dụ: trước khi cập nhật phiên bản, trước khi khôi phục dữ liệu cũ).

1. Đăng nhập tài khoản kỹ thuật viên
2. Vào trang **Sao lưu dữ liệu** trên sidebar
3. Bấm **Tạo bản sao lưu mới**
4. Hệ thống tạo file backup, lưu trong container

Tối đa 3 bản sao lưu. Muốn tạo bản mới khi đã đủ 3 — xóa bản cũ nhất trước.

### Khôi phục từ bản sao lưu

Khôi phục thực hiện qua dòng lệnh (không có nút trên giao diện vì đây là thao tác nguy hiểm — ghi đè toàn bộ dữ liệu hiện tại):

```bash
cd /opt/ewm

# Xem danh sách bản sao lưu
docker compose exec app bundle exec rails runner "Backup.all.each { |b| puts \"#{b.filename} — #{b.created_at}\" }"

# Khôi phục (thay <tên-file> bằng tên file thực)
docker compose exec app bundle exec rails "backups:restore[<tên-file>]"
```

Hệ thống hỏi xác nhận trước khi khôi phục. Gõ `YES` (chữ hoa) để xác nhận.

### Sao lưu tự động sang ổ cứng phụ (bắt buộc)

Server phải có ổ cứng phụ để sao lưu tự động. Nếu ổ chính hỏng, dữ liệu vẫn còn trên ổ phụ.

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

2. Chạy script thiết lập:

```bash
cd /opt/ewm
sudo ./deploy/production/server backup
```

Script hỏi đường dẫn ổ cứng phụ rồi thiết lập tự động.

Script tự động:
- Sao lưu database (pg_dump) + file sao lưu trong app mỗi ngày lúc 2:00 sáng
- Giữ tối đa 7 bản, xóa bản cũ nhất tự động
- Ghi log tại `/mnt/backup/ewm-backup/backup.log`

---

## Cập nhật phiên bản

Khi có phiên bản mới từ nhà phát triển:

1. Trên máy có internet: lặp lại Phần A
2. Copy sang USB
3. Trên server:

```bash
sudo /media/$USER/<tên-USB>/electric-water-management-delivery/deploy/production/server update /media/$USER/<tên-USB>/electric-water-management-delivery
```

Hoặc nếu đã copy vào máy:

```bash
cd /opt/ewm
sudo ./deploy/production/server update /đường-dẫn-thư-mục-mới
```

---

## Kiểm tra trước khi deploy

Trước khi copy sang USB hoặc sau khi deploy, chạy test tự động để đảm bảo mọi thứ hoạt động:

```bash
# Trên máy build (trước khi copy USB) — test toàn bộ flow: build → install → verify → update → login
deploy/production/test

# Test cross-platform (Mac ARM → server Intel/AMD)
deploy/production/test --platform amd64

# Trên server (sau khi deploy) — kiểm tra hệ thống đang chạy
sudo ./deploy/production/server verify
```

Test tự động mất khoảng 2 phút. Nếu TẤT CẢ PASS thì sẵn sàng deploy.

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

### v2.1.0 (24/05/2026)

- Thêm section "Kiểm tra trước khi deploy" — hướng dẫn dùng `deploy/production/test` và `server verify`.

### v2.0.0 (24/05/2026)

- Gộp 6 scripts thành 2: `deploy/production/build` (Phần A) + `deploy/production/server` (Phần B).
- `deploy/production/build` inline prepare-delivery — không còn file riêng.
- `deploy/production/server` gộp install + update + backup + status. Auto-detect cài mới/cập nhật. Chọn bước riêng hoặc chạy tất cả.
- Xóa: `bin/prepare-delivery`, `script/install.sh`, `script/setup-server`, `script/update-server`, `script/setup-auto-backup`.

### v1.5.0 (24/05/2026)

- Thêm `script/install.sh` — cài đặt 1 lệnh từ USB (copy + setup).
- Phần B giảm từ 4 bước xuống 3 (B1 chạy install, B2 đăng nhập, B3 checklist).

### v1.4.0 (24/05/2026)

- Thêm `script/setup-server` — gộp B2-B5 thành 1 lệnh (load images, hỏi mật khẩu, tạo .env, khởi động, health check).
- Thêm `script/update-server` — gộp cập nhật phiên bản thành 1 lệnh (backup .env, thay code, load images, khởi động).
- Phần B giảm từ 7 bước xuống 4 (B1 copy USB, B2 chạy script, B3 đăng nhập, B4 checklist).
- Cập nhật phiên bản giảm từ nhiều lệnh xuống 1 lệnh.

### v1.3.0 (24/05/2026)

- Thêm `deploy/production/build` — gộp A2-A5 thành 1 lệnh duy nhất.
- Phần A giảm từ 6 bước xuống 3 (A1 cài Docker, A2 build, A3 copy USB).
- SECRET_KEY_BASE tự tạo ra file `SECRET_KEY_BASE.txt` trong thư mục delivery.

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
