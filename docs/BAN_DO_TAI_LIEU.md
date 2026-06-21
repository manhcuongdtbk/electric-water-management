# Bản đồ tài liệu — Hệ thống quản lý điện nước nội bộ

> **Phiên bản:** 1.5.2
> **Ngày:** 22/06/2026
> **Tính chất:** Canonical — liệt kê mọi tài liệu của dự án kèm **mục đích, đối tượng, loại**, để người và công cụ AI biết **một fact nằm ở đâu** và **sửa ở đâu** thay vì thêm nơi mới. Hỗ trợ trực tiếp quy tắc "sửa đừng thêm" (`AGENTS.md` mục "Quản trị tài liệu"; ADR-023).

## Ba loại tài liệu

- **canonical** — nguồn sự thật cho một fact. Khi một fact sai/cũ → **sửa tại đây**. Mỗi fact chỉ một nơi canonical; nơi khác trỏ về.
- **current-state** — mô tả hiện trạng, hoặc nội dung cô đọng/suy ra từ canonical (hướng dẫn, kịch bản test). **Phải rà cho khớp** khi canonical/ADR đổi (xem checklist phát hành).
- **lịch sử** — bản ghi quyết định/thời điểm (ADR, plan, changelog). **KHÔNG viết lại**; quyết định mới *supersede* quyết định cũ, giữ nguyên bản cũ.

## Bản đồ

### canonical

| Tài liệu | Mục đích | Đối tượng |
|---|---|---|
| `AGENTS.md` | Quy ước canonical (code + quy trình), mệnh lệnh, trỏ tới chi tiết | Người + mọi công cụ AI |
| `docs/THUAT_NGU.md` | Từ điển thuật ngữ + từ viết tắt + gloss (nguồn duy nhất) | Người + AI |
| `docs/BAN_DO_TAI_LIEU.md` | Bản đồ tài liệu (file này): fact nào ở đâu, loại gì | Người + AI |
| `docs/superpowers/ADR-TEMPLATE.md` | Mẫu ADR chuẩn (7 mục, đánh số toàn cục) để viết quyết định mới trong spec | Người + AI |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Nghiệp vụ — nguồn sự thật duy nhất cho thiết kế & triển khai | Chủ dự án + đội phát triển |
| `docs/V2_THIET_KE_HE_THONG.md` | Thiết kế hệ thống — nguồn sự thật cho implementation | Đội phát triển |
| `docs/V2_HANH_VI_HE_THONG.md` | Hành vi runtime (7 vai trò, trạng thái kỳ, `.kept`/`.with_discarded`) | Đội phát triển |
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
| `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` | Bản ghi thời điểm: artifact xác nhận khách 3 tính năng milestone 1.2.0 (kỳ 4/2026, PR #264). Yêu cầu đã chốt **đã fold** vào canonical `docs/V2_XAC_NHAN_NGHIEP_VU.md` (anchor `NV-cot-khac-he-so-don-vi`, `NV-phan-bo-bom-theo-tram`, `NV-hien-thi-chi-tiet-ton-hao`) — không viết lại file này | Chủ dự án + đội phát triển |
| `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` | Bản ghi thời điểm: artifact xác nhận khách 2 mong muốn mới trên Acceptance (tên hệ thống, vai trò Chỉ huy Sư đoàn; PR #315). Yêu cầu **đã fold** vào canonical `docs/V2_XAC_NHAN_NGHIEP_VU.md` (v2.18.0, mục 1 + mục 11.5, Issue #418 + #419) — không viết lại file này | Chủ dự án + đội phát triển |
| `CHANGELOG.md` | Lịch sử phát hành sinh tự động (release-please) | Người + khách |

> `CLAUDE.md` chỉ chứa dòng `@AGENTS.md` (import shim để Claude Code đọc `AGENTS.md`) — không phải nguồn fact riêng. `version.txt` do release-please sinh, không phải tài liệu.

## Lịch sử thay đổi

- **1.5.1 (21/06/2026):** Đổi tên hệ thống trong tiêu đề: "Hệ thống quản lý điện nước nội bộ" (Issue #420, khớp tên chính thức đã chốt trong #418).
- **1.5.2 (22/06/2026):** Sửa mô tả V2_HANH_VI_HE_THONG "6 vai trò" → "7 vai trò" (division_commander, Issue #419).
- **1.5.0 (21/06/2026):** Chuyển `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` từ canonical → lịch sử: yêu cầu đợt 2 đã fold vào canonical `docs/V2_XAC_NHAN_NGHIEP_VU.md` (v2.18.0, mục 1 + mục 11.5, Issue #418 + #419), file trở thành bản ghi thời điểm không viết lại.
- **1.4.0 (21/06/2026):** Thêm `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG_2.md` (đợt 2) vào nhóm canonical. PR #315.
- **1.3.0 (11/06/2026):** Chuyển `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` từ current-state → lịch sử: yêu cầu 3 tính năng milestone 1.2.0 đã fold vào canonical `docs/V2_XAC_NHAN_NGHIEP_VU.md` (v2.15.0, Issue #319), file trở thành bản ghi thời điểm không viết lại. Spec mới (ADR-025..027) được phủ sẵn bởi glob `docs/superpowers/specs/*`.
- **1.2.0 (11/06/2026):** Thêm `docs/V2_XAC_NHAN_NGHIEP_VU_BO_SUNG.md` vào nhóm current-state (xác nhận nghiệp vụ bổ sung, đang chốt với khách). Phát hiện khi rà PR #264 chưa khớp guardrail doc-map (ADR-024).
- **1.1.0 (11/06/2026):** Thêm `docs/superpowers/ADR-TEMPLATE.md` vào nhóm canonical (mẫu ADR). Phát hiện khi dựng guardrail ADR-024 (Issue #313).
- **1.0.0 (10/06/2026):** Bản đầu — phân loại canonical / current-state / lịch sử cho toàn bộ tài liệu dự án. ADR-023, Issue #310.
