# Hệ thống quản lý điện nội bộ Sư đoàn

Hệ thống web quản lý sử dụng điện, tính toán tiêu chuẩn, tổn hao, phân bổ bơm nước, và tạo bảng tính tiền cho các đơn vị trong Sư đoàn.

## Stack

Rails 8, PostgreSQL 16, Tailwind CSS, Hotwire (Turbo + Stimulus).

## Development

Yêu cầu: [Docker Desktop](https://www.docker.com/products/docker-desktop/).

```bash
git clone <repo>
cd electric-water-management
bin/docker up
# Mở http://localhost khi thấy "Listening on 0.0.0.0:3000"
```

Tài khoản mặc định: `quanTri` / `Abc@1234` (quản trị viên hệ thống), `kyThuat` / `Abc@1234` (kỹ thuật viên).

### Lệnh thường dùng

```bash
bin/docker rspec              # Chạy test
bin/docker rspec spec/models  # Chạy test 1 thư mục
bin/docker console            # Rails console
bin/docker bash               # Shell trong container app
bin/docker bash postgres      # Shell trong container postgres
bin/docker logs               # Xem logs
bin/docker ps                 # Trạng thái containers
bin/docker stop               # Dừng
bin/docker start              # Chạy lại
```

### Chạy không dùng Docker

Yêu cầu: Ruby 3.4.3, PostgreSQL 16.

```bash
bin/setup
bin/dev
# Mở http://localhost:3000
```

## Test

```bash
bin/docker rspec                        # Toàn bộ
bin/docker rspec spec/models            # Model specs
bin/docker rspec spec/requests          # Request specs
bin/docker rspec spec/system            # System specs (headless Chrome)
bundle exec parallel_rspec spec/        # Song song (chạy local)
```

## Tài liệu

| File | Nội dung |
|---|---|
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ (nguồn sự thật duy nhất) |
| `docs/V2_THIET_KE_HE_THONG.md` | Thiết kế hệ thống |
| `docs/V2_HANH_VI_HE_THONG.md` | Hành vi runtime, 6 vai trò, 3 trạng thái kỳ |
| `docs/V2_CHIEU_TEST.md` | 12 chiều kiểm thử |
| `CLAUDE.md` | Quy tắc code, convention |

## Production

3 containers: PostgreSQL + Rails + nginx. Deploy trên máy Ubuntu LAN nội bộ (offline).

```bash
cp .env.example .env
# Điền POSTGRES_PASSWORD, SECRET_KEY_BASE, RAILS_MASTER_KEY
docker compose up -d
```
