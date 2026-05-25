# Hệ thống quản lý điện nội bộ Sư đoàn

Hệ thống web quản lý sử dụng điện, tính toán tiêu chuẩn, tổn hao, phân bổ bơm nước, và tạo bảng tính tiền cho các đơn vị trong Sư đoàn.

## Stack

Rails 8, PostgreSQL 16, Tailwind CSS, Hotwire (Turbo + Stimulus).

## Environments

| | Development | Staging | Production |
|---|---|---|---|
| Hạ tầng | Docker Desktop (Mac) | Railway | Ubuntu Mini PC (LAN offline) |
| Dockerfile | Dockerfile.dev | Dockerfile | Dockerfile |
| Web server | nginx container | Railway edge proxy | nginx container |
| Database | PostgreSQL container | Railway PostgreSQL | PostgreSQL container |
| Config | compose.dev.yml | railway.json | compose.yml + .env |
| URL | http://localhost | https://electric-water-management.up.railway.app | http://\<IP server\> |

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
bin/docker logs               # Xem logs container app
bin/docker logs postgres      # Xem logs container postgres
bin/docker ps                 # Trạng thái containers
bin/docker stop               # Dừng
bin/docker start              # Chạy lại
```

### Workflow hàng ngày

```bash
bin/docker start              # Sáng: chạy lại containers đã dừng
# Code bình thường, Rails tự reload khi sửa file
bin/docker stop               # Chiều: dừng containers
```

Ngoại lệ: dùng `bin/docker up` thay `start` khi lần đầu hoặc sau khi sửa compose.dev.yml / Dockerfile.dev.

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
bin/docker prspec                       # Song song (auto-detect số processes)
bin/docker prspec -n 2                  # Song song với 2 processes
bin/docker prspec:setup                 # Tạo databases cho test song song (chạy 1 lần)
```

## Tài liệu

| File | Nội dung |
|---|---|
| `docs/hdsd/V2_HUONG_DAN_SU_DUNG.md` | Hướng dẫn sử dụng (cho tất cả người dùng, có ảnh chụp màn hình) |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ (nguồn sự thật duy nhất) |
| `docs/V2_THIET_KE_HE_THONG.md` | Thiết kế hệ thống |
| `docs/V2_HANH_VI_HE_THONG.md` | Hành vi runtime, 6 vai trò, 3 trạng thái kỳ |
| `docs/V2_CHIEU_TEST.md` | 12 chiều kiểm thử |
| `docs/KIEN_THUC_DOCKER.md` | Kiến thức Docker, 4 môi trường, deploy |
| `docs/HUONG_DAN_DEPLOY.md` | Hướng dẫn deploy production (cho kỹ thuật viên) |
| `CLAUDE.md` | Quy tắc code, convention |

**Cập nhật ảnh hướng dẫn sử dụng** khi giao diện thay đổi:

```bash
docs/hdsd/capture-screenshots
```

Script tự reset database, tạo dữ liệu mẫu, chụp lại toàn bộ ảnh. Thêm/sửa trang chụp: sửa mảng `PAGES` trong `docs/hdsd/capture.mjs`.

## Staging

Railway auto-deploy khi push branch main. Cấu hình trong `railway.json`.

## Production

3 containers (PostgreSQL + Rails + nginx). Deploy trên máy Ubuntu LAN nội bộ (offline).

**Hướng dẫn chi tiết:** `docs/HUONG_DAN_DEPLOY.md`

**Quan trọng:** Phải chạy `bin/prepare-delivery` để tạo bản sạch trước khi ship cho khách. Không ship source code trực tiếp từ repo này.
