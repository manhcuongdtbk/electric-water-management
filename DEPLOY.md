# Hướng dẫn triển khai (Production)

Tài liệu này dành cho đội kỹ thuật triển khai phần mềm Quản lý Điện Nước lên môi trường production.

## Yêu cầu

- Docker Engine ≥ 24.0
- Docker Compose Plugin ≥ 2.0
- Máy chủ Linux (Ubuntu 20.04+/CentOS 8+)
- Ít nhất 2 GB RAM, 10 GB ổ đĩa trống

---

## 1. Chuẩn bị

### 1.1. Sao chép source code lên máy chủ

```bash
git clone <repo-url> /opt/electric-water-management
cd /opt/electric-water-management
```

### 1.2. Tạo file cấu hình môi trường

```bash
cp .env.production.example .env.production
```

Mở file `.env.production` và điền các giá trị thực:

```
DB_USERNAME=postgres
DB_PASSWORD=<mật khẩu mạnh, ít nhất 16 ký tự>
DB_NAME=electric_water_management_production
RAILS_MASTER_KEY=<nội dung file config/master.key>
BACKUP_DIR=/rails/db/backups
```

> **Lưu ý:** `RAILS_MASTER_KEY` lấy từ file `config/master.key` (không được commit vào git). Liên hệ developer để lấy giá trị này.

### 1.3. Tạo thư mục backup

```bash
mkdir -p db/backups
```

---

## 2. Build và khởi động

```bash
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

Lần đầu tiên build có thể mất 5–10 phút.

---

## 3. Khởi tạo cơ sở dữ liệu

Chỉ chạy lần đầu tiên:

```bash
docker compose -f docker-compose.production.yml exec web bin/rails db:prepare
```

---

## 4. Kiểm tra hệ thống

```bash
# Kiểm tra health check
curl http://localhost/up

# Xem trạng thái containers
docker compose -f docker-compose.production.yml ps

# Xem logs
docker compose -f docker-compose.production.yml logs -f web
```

Nếu `curl http://localhost/up` trả về `200 OK` — hệ thống đã hoạt động.

---

## 5. Quản lý Sao lưu

### 5.1. Sao lưu thủ công qua giao diện web

Đăng nhập với tài khoản **kỹ thuật** → chọn **"Sao lưu dữ liệu"** trong menu → nhấn **"Sao lưu ngay"**.

### 5.2. Sao lưu thủ công qua terminal

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup
```

### 5.3. Xem danh sách file backup trên máy chủ

```bash
ls -lah ./db/backups/
```

### 5.4. Copy file backup ra ngoài container

```bash
# Lấy tên container
docker compose -f docker-compose.production.yml ps

# Copy file ra thư mục hiện tại
docker cp <tên-container-web>:/rails/db/backups/backup_20260423_020000.dump ./
```

### 5.5. Phục hồi từ file backup

**Qua giao diện web:** Đăng nhập với tài khoản kỹ thuật → Sao lưu dữ liệu → nhấn "Phục hồi" bên cạnh file cần restore → xác nhận → đăng nhập lại.

**Qua terminal:**

```bash
docker compose -f docker-compose.production.yml exec -T web bin/rails 'db:restore[backup_20260423_020000.dump]'
```

> **Cảnh báo:** Phục hồi sẽ ghi đè **toàn bộ** dữ liệu hiện tại. Hãy sao lưu trước khi phục hồi.

### 5.6. Tự động backup hàng ngày (cron)

Thêm vào crontab của máy chủ (`crontab -e`):

```
0 2 * * * cd /opt/electric-water-management && docker compose -f docker-compose.production.yml exec -T web bin/rails db:backup >> /var/log/ewm-backup.log 2>&1
```

Lệnh trên sẽ tự động sao lưu lúc 2:00 sáng mỗi ngày.

---

## 6. Cập nhật phiên bản mới

```bash
git pull
docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

---

## 7. Dừng hệ thống

```bash
docker compose -f docker-compose.production.yml down
```

---

## 8. Xử lý sự cố thường gặp

### Web không khởi động

```bash
docker compose -f docker-compose.production.yml logs web
```

Kiểm tra:
- `RAILS_MASTER_KEY` đã điền đúng chưa
- Database đã được khởi tạo chưa (`db:prepare`)

### Database không kết nối được

```bash
docker compose -f docker-compose.production.yml logs db
```

Kiểm tra `DB_USERNAME` và `DB_PASSWORD` trong `.env.production`.

### Xem logs realtime

```bash
docker compose -f docker-compose.production.yml logs -f web nginx
```
