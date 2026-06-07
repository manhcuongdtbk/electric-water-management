# Hướng dẫn đóng góp (CONTRIBUTING)

Tài liệu quy trình làm việc **cho người**. Quy ước code và quy ước chung là `AGENTS.md` (nguồn canonical). Quyết định kèm lý do nằm trong `docs/superpowers/specs/`.

> Mọi quy ước viết (tuyệt đối không viết tắt), ngôn ngữ (tài liệu/giao diện tiếng Việt; code/commit tiếng Anh) theo `AGENTS.md`.

## 1. Trước khi bắt đầu

- Đọc `AGENTS.md` (quy ước) và tài liệu nguồn trong `docs/` (nghiệp vụ, thiết kế, hành vi, kiểm thử).
- Cài đặt và chạy: xem `README.md` (Docker + git worktree). **Luôn làm việc trong một git worktree riêng + Docker** — cho cả người lẫn AI.

## 2. Mô hình nhánh — Git Flow

Theo ADR-003 (xem `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` để biết lý do và sơ đồ đầy đủ).

- `main` — chỉ chứa bản đã phát hành; mỗi commit trên `main` đều có tag version tương ứng.
- `develop` — nhánh tích hợp công việc đang làm.
- `feature/*` — cắt từ `develop`, làm xong merge ngược về `develop`.
- `release/*` — cắt từ `develop` khi đủ nội dung; deploy môi trường Nghiệm thu; gắn tag release candidate `X.Y.Z-rc.N`.
- `hotfix/*` — cắt từ `main` khi production lỗi gấp.
- **Merge-back bắt buộc:** sau khi `release/*` hoặc `hotfix/*` hoàn tất, phải merge ngược về `develop` để bản vá không bị mất.
- **Cổng nhánh:** pull request đích `main` chỉ được đến từ `release/*` hoặc `hotfix/*` (branch-source guard sẽ ép ở CI — xem ADR-011).

## 3. Conventional Commits (commit message tiếng Anh)

- Định dạng: `type(scope): subject` — ví dụ `feat(billing): ...`.
- `type` thường dùng: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`.
- Liên hệ SemVer (ADR-004): `feat` → tăng MINOR; `fix` → tăng PATCH; có `BREAKING CHANGE:` trong body hoặc `type!` → tăng MAJOR.
- release-please dựa vào commit message để tự bump version + sinh changelog (ADR-008) → viết commit nghiêm túc, đúng `type`.
- Ví dụ:

```text
feat(billing): add cross-period comparison column
fix(meter): guard against stale lock_version on concurrent update
docs(sdlc): add CONTRIBUTING and canonical AGENTS files
```

- Nếu làm cùng AI, kết commit bằng dòng đồng tác giả theo quy ước repo:

```text
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## 4. Luồng làm một thay đổi

1. Tạo worktree + nhánh `feature/<việc>` từ `develop` (xem `README.md` để biết lệnh worktree + cổng Docker).
2. Code và test: `bin/docker rspec` (test phải cover mọi output của trang — xem `AGENTS.md`).
3. Chạy review AI local **trước khi push**: `/code-review` (ADR-009; dùng Claude sẵn có, không tốn thêm).
4. Mở pull request đích `develop` (với `feature/*`). CI xanh + chủ dự án duyệt → merge.
5. Pull request đích `main` chỉ đến từ `release/*` hoặc `hotfix/*`.

## 5. Pair lập trình / cùng test app đang chạy local — VS Code Dev Tunnels

Theo ADR-010.

- Trong VS Code hoặc Cursor: chạy app local (`bin/docker up`), mở tab **Ports**, chọn **Forward a Port** cho cổng nginx mà `bin/docker` gán cho worktree.
- Đặt visibility **Private** (mặc định) → người trong team đăng nhập GitHub để truy cập. **Không** để Public khi có dữ liệu thật.
- Dự phòng (cần URL ngoài editor hoặc không muốn bắt đăng nhập GitHub): **Cloudflare Tunnel**.
- Người không phải dev (ví dụ khách nghiệm thu): dùng **môi trường Nghiệm thu trên Railway** thay vì tunnel.

## 6. Phát hành

Quy trình đầy đủ và checklist: `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`.

Tóm tắt: đủ nội dung → `release/*` → deploy Nghiệm thu (`-rc.N`) → khách nghiệm thu → release-please tạo Release pull request → merge `main` + tag `X.Y.Z` → giao bản xuống production Mini PC + cập nhật môi trường Mốc → **merge-back về `develop`**.

## 7. Giao bản cho khách

- Dùng `bin/prepare-delivery` để tạo bản sạch trước khi ship: script xóa các file dev nội bộ (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `.claude/`) và dọn git history. **KHÔNG** ship source code trực tiếp từ repo này.
- Chi tiết deploy production: `docs/HUONG_DAN_DEPLOY.md` và `docs/KIEN_THUC_DOCKER.md`.

## 8. Trạng thái tự động hoá

Một số guardrail (CI: `rspec`/`rubocop`/`brakeman`/`commitlint`/branch-guard; release-please; môi trường Railway Nghiệm thu + Mốc) sẽ được triển khai ở các giai đoạn sau của chuẩn hoá quy trình phát triển (P2–P4). Hiện tại các quy ước ở mục 2–3 được giữ bằng kỷ luật + review thủ công; xem mục Backlog trong release spec.

## Tài liệu liên quan

- `AGENTS.md` — quy ước canonical (code + quy trình).
- `docs/superpowers/specs/2026-06-07-sdlc-overview-design.md` — ADR-001 (mô hình phát triển), ADR-002 (chiến lược tài liệu/tri thức).
- `docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md` — ADR-003..011 (quy trình phát hành).
- `README.md` — cài đặt, lệnh thường dùng, môi trường.
