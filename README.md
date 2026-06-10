# Hệ thống quản lý điện nội bộ Sư đoàn

Hệ thống web quản lý sử dụng điện, tính toán tiêu chuẩn, tổn hao, phân bổ bơm nước, và tạo bảng tính tiền cho các đơn vị trong Sư đoàn.

## Stack

Rails 8, PostgreSQL 16, Tailwind CSS, Hotwire (Turbo + Stimulus).

## Environments

| Loại | Hạ tầng | Nguồn deploy | Nhãn (`APPLICATION_ENVIRONMENT_LABEL`) | URL |
|---|---|---|---|---|
| Phát triển (local) | Docker Desktop (`Dockerfile.dev`, `compose.dev.yml`) | máy bạn — `develop`/`feature/*` | — | http://localhost |
| Railway `development` | Railway (`Dockerfile`, `railway.json`, sleep) | nhánh `develop` (tự deploy) | `Development` | https://electric-water-management-development.up.railway.app |
| Railway `acceptance` | Railway (`Dockerfile`, `railway.json`, sleep) | nhánh `main` (tự deploy) | `Acceptance` | https://electric-water-management-acceptance.up.railway.app |
| Railway `mirror` | Railway (`Dockerfile`, `railway.json`, sleep) | nhánh `production` (ghim tag đang giao) | `Mirror` | https://electric-water-management-mirror.up.railway.app |
| **Production (thật)** | Ubuntu Mini PC LAN offline (`Dockerfile`, `compose.yml` + `.env`) | tag `main` đã giao | `Production` (đặt tại Mini PC) | http://\<IP server\> |

> Ba env Railway và Mini PC đều chạy `RAILS_ENV=production`; chỉ `APPLICATION_ENVIRONMENT_LABEL` khác nhau để phân biệt (xem "environment terminology" trong `AGENTS.md`). **Production thật là Mini PC offline tại chỗ khách**, không phải Railway. `mirror` là bản sinh đôi *online* của Production để khách đối chiếu với `acceptance` (bản ứng viên). Hiện `mirror` chạy `v1.0.0` — bản này **ra đời trước** tính năng tự báo cáo phiên bản nên chưa có nhãn/endpoint `/version`; `acceptance`/`development` (1.1.0+) thì có. Khi Production lên 1.1.0+, `mirror` sẽ hiện nhãn.

## Development

Yêu cầu: [Docker Desktop](https://www.docker.com/products/docker-desktop/).

```bash
git clone <repo>
cd electric-water-management
bin/docker up
# Mở http://localhost khi thấy "Listening on 0.0.0.0:3000"
```

Tài khoản mặc định: `quanTri` / `Abc@1234` (quản trị viên hệ thống), `kyThuat` / `Abc@1234` (kỹ thuật viên).

### Cách làm việc khuyến nghị: Docker + git worktree

**Quy tắc: luôn làm việc qua Docker, trong một git worktree riêng** — cho cả người (bất kỳ ai) lẫn AI (Claude Code, Cursor, Codex, Copilot, ...). Lý do: mỗi phiên / mỗi người / mỗi AI session cô lập hoàn toàn (code + database + container riêng), nhiều worktree chạy Docker song song không đụng nhau, và tái lập y hệt trên mọi máy.

**Claude Code** tự tạo worktree cho mỗi session (trong `.claude/worktrees/`) — bạn đã ở sẵn trong worktree, chỉ cần `bin/docker up`, KHÔNG tự chạy `git worktree add`.

**Người làm tay, hoặc AI khác không tự tạo worktree** (Cursor, Codex, Copilot, ...): tạo worktree trước rồi mới chạy:

```bash
git worktree add ../ewm-<việc> -b feature/<việc> develop   # cắt nhánh feature mới từ develop (Git Flow; thư mục anh em cạnh repo)
cd ../ewm-<việc>
bin/docker up                                # tự in cổng đã gán cho worktree này
# → App (nginx): http://localhost:<cổng>
# → PostgreSQL: localhost:<cổng>
```

`bin/docker` tự gán cổng host riêng và ổn định cho mỗi worktree (postgres + nginx) nên không đụng checkout gốc hay worktree khác. Checkout gốc (không phải worktree) giữ mặc định `5433` / `80`.

- **Preview riêng mỗi session** (Claude Desktop app): `preview_start docker-dev` tự trỏ đúng app của worktree đó (qua autoPort); nhiều session preview song song không đụng nhau.
- **Dọn dẹp khi xong worktree:** chạy `bin/docker nuke` (xóa container + network + volume gems + image của worktree) **trước** `git worktree remove <đường-dẫn>` — làm ngược lại sẽ để rác orphan. `nuke` KHÔNG xóa dữ liệu DB (nằm trong thư mục worktree). Tạm nghỉ rồi quay lại thì chỉ cần `bin/docker stop`.
- **Chia sẻ dữ liệu dev giữa các worktree** (khi cần): snapshot — `bin/docker dump-dev [tên]` lưu, worktree khác `bin/docker load-dev [tên]` nạp; hoặc DB sống chung — `bin/docker up --shared-db=<cổng postgres nguồn>`. Chỉ dùng giữa các worktree cùng schema — xem `docs/KIEN_THUC_DOCKER.md`.
- **Trùng cổng** (hiếm): nếu `bin/docker up` báo `port already allocated`, đặt `POSTGRES_HOST_PORT` / `NGINX_HOST_PORT` thủ công trước khi chạy.
- **Máy hỗ trợ:** macOS Apple Silicon (M1/M2/M3...) — đã kiểm chứng đầy đủ (cả Docker lẫn host). macOS Intel và Linux: nên chạy được nhưng chưa kiểm chứng kỹ. Windows: dùng qua WSL2, chưa kiểm chứng. Gặp vấn đề trên máy khác → ưu tiên dùng Apple Silicon.

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
bin/docker nuke               # Dọn sạch Docker của worktree (chạy trước git worktree remove)
bin/docker dump-dev [tên]     # Lưu DB dev thành snapshot dùng chung (mặc định "dev")
bin/docker load-dev [tên]     # Nạp snapshot dùng chung vào DB dev worktree này
bin/docker up --shared-db=<cổng>  # Dùng chung DB sống với worktree khác (Cách B)
```

### Workflow hàng ngày

```bash
bin/docker start              # Sáng: chạy lại containers đã dừng
# Code bình thường, Rails tự reload khi sửa file
bin/docker stop               # Chiều: dừng containers
```

Ngoại lệ: dùng `bin/docker up` thay `start` khi lần đầu hoặc sau khi sửa compose.dev.yml / Dockerfile.dev.

### Chạy không dùng Docker (phương án dự phòng)

Chỉ dùng khi Docker trục trặc và cần debug nhanh trên host — không phải cách làm chính. Yêu cầu: Ruby 3.4.3, PostgreSQL 16, và Google Chrome nếu chạy system test.

```bash
bin/setup
bin/dev
# Mở http://localhost:3000
```

Chạy test trên host (kể cả xem trình duyệt thật khi debug): `HEADLESS=false bundle exec rspec spec/system/...` — chi tiết trong `docs/KIEN_THUC_DOCKER.md` (mục 11, Test).

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
| `docs/KIEN_THUC_DOCKER.md` | Kiến thức Docker, các môi trường, deploy |
| `docs/HUONG_DAN_DEPLOY.md` | Hướng dẫn deploy production (cho kỹ thuật viên) |
| `AGENTS.md` | Quy ước code và quy trình — nguồn canonical (Claude Code đọc qua `CLAUDE.md` `@import`) |
| `CONTRIBUTING.md` | Quy trình đóng góp cho người (Git Flow, Conventional Commits, pair local) |

**Cập nhật ảnh hướng dẫn sử dụng** khi giao diện thay đổi:

```bash
docs/hdsd/capture-screenshots
```

Script tự reset database, tạo dữ liệu mẫu, chụp lại toàn bộ ảnh. Thêm/sửa trang chụp: sửa mảng `PAGES` trong `docs/hdsd/capture.mjs`.

## Railway (development / acceptance / mirror)

Ba environment trên Railway (đều bật sleep) tự deploy theo nhánh: `develop`→`development`, `main`→`acceptance`, nhánh con trỏ `production`→`mirror`. Mỗi env có nhãn `APPLICATION_ENVIRONMENT_LABEL` riêng (Development/Acceptance/Mirror). Chi tiết và lý do: ADR-005 (ghi chú "Triển khai & điều chỉnh (P4)") trong `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.

## Production

3 containers (PostgreSQL + Rails + nginx). Deploy trên máy Ubuntu LAN nội bộ (offline).

> **Phiên bản:** repo này là **hệ thống v2**, nhưng version phần mềm theo **SemVer từ `1.0.0`** (số MAJOR = tương thích/breaking, không phải "đời sản phẩm"; hệ thống v1 ở project Railway riêng). Production hiện chạy `v1.0.0`.

**Hướng dẫn chi tiết:** `docs/HUONG_DAN_DEPLOY.md`

**Quan trọng:** Phải chạy `bin/prepare-delivery` để tạo bản sạch trước khi ship cho khách. Không ship source code trực tiếp từ repo này.
