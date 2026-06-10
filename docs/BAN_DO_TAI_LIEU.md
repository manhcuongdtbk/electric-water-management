# Bản đồ tài liệu — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.0.0
> **Ngày:** 10/06/2026
> **Tính chất:** Canonical — liệt kê mọi tài liệu của dự án kèm **mục đích, đối tượng, loại**, để người và công cụ AI biết **một fact nằm ở đâu** và **sửa ở đâu** thay vì thêm nơi mới. Hỗ trợ trực tiếp quy tắc "sửa đừng thêm" (`AGENTS.md` mục "Quản trị tài liệu"; ADR-023).

## Ba loại tài liệu

- **canonical** — nguồn sự thật cho một fact. Khi một fact sai/cũ → **sửa tại đây**. Mỗi fact chỉ một nơi canonical; nơi khác trỏ về.
- **current-state** — mô tả hiện trạng hoặc dữ liệu suy ra từ canonical (distill, hướng dẫn, kịch bản test). **Phải rà cho khớp** khi canonical/ADR đổi (xem checklist phát hành).
- **lịch sử** — bản ghi quyết định/thời điểm (ADR, plan, changelog). **KHÔNG viết lại**; quyết định mới *supersede* quyết định cũ, giữ nguyên bản cũ.

## Bản đồ

### canonical

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `AGENTS.md` | Quy ước canonical (code + quy trình), mệnh lệnh, trỏ tới chi tiết | Người + mọi công cụ AI |
| `docs/THUAT_NGU.md` | Từ điển thuật ngữ + từ viết tắt + gloss (nguồn duy nhất) | Người + AI |
| `docs/BAN_DO_TAI_LIEU.md` | Bản đồ tài liệu (file này): fact nào ở đâu, loại gì | Người + AI |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ — nguồn sự thật duy nhất cho thiết kế & triển khai | Chủ dự án + đội phát triển |
| `docs/V2_THIET_KE_HE_THONG.md` | Thiết kế hệ thống — nguồn sự thật cho implementation | Đội phát triển |
| `docs/V2_HANH_VI_HE_THONG.md` | Hành vi runtime (6 vai trò, trạng thái kỳ, `.kept`/`.with_discarded`) | Đội phát triển |
| `docs/V2_CHIEU_TEST.md` | 12 chiều kiểm thử, input/output, giao điểm nguy hiểm | Đội phát triển |

### current-state

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `README.md` | Tổng quan, cài đặt, lệnh thường dùng, môi trường | Người mới + đội |
| `CONTRIBUTING.md` | Quy trình làm việc cho người (Git Flow, commit, pair) | Thành viên đội |
| `docs/HUONG_DAN_SDLC.md` | Lối vào onboarding ~15 phút: vòng đời một thay đổi + bảng tra cứu | Thành viên mới |
| `docs/HUONG_DAN_DEPLOY.md` | Hướng dẫn deploy production (thao tác từng bước) | Người thực hiện deploy |
| `docs/KIEN_THUC_DOCKER.md` | Kiến thức + cấu hình Docker ở mọi môi trường | Developer + người vận hành |
| `docs/hdsd/V2_HUONG_DAN_SU_DUNG.md` | Hướng dẫn sử dụng cho người dùng cuối | Người dùng hệ thống |
| `docs/V2_KICH_BAN_TEST.md` | Kịch bản kiểm thử (số liệu cụ thể) — suy ra từ bốn tài liệu nguồn, tái sinh khi nguồn đổi | Đội phát triển |

### lịch sử

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `docs/superpowers/specs/*` | Spec + ADR: quyết định kèm lý do (supersede, không viết lại) | Người + AI |
| `docs/superpowers/plans/*` | Plan triển khai từng việc (bản ghi thời điểm) | Người + AI thực thi |
| `CHANGELOG.md` | Lịch sử phát hành sinh tự động (release-please) | Người + khách |

> `CLAUDE.md` chỉ chứa dòng `@AGENTS.md` (import shim để Claude Code đọc `AGENTS.md`) — không phải nguồn fact riêng. `version.txt` do release-please sinh, không phải tài liệu.

## Lịch sử thay đổi

- **1.0.0 (10/06/2026):** Bản đầu — phân loại canonical / current-state / lịch sử cho toàn bộ tài liệu dự án. ADR-023, Issue #310.
