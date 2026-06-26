---
title: Doc-code sync — CI guardrails + convention + periodic audit
version: 0.2.0
date: 2026-06-25
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Doc-code sync

> **Ghi chú:** Spec này sinh ra từ cross-check audit session (#456, #457, #459, #462) phát hiện 13 lệch giữa 10 file tài liệu và code. Phân tích nguyên nhân gốc: Issue #464.

## Bối cảnh

Dự án có CI guardrails cho **cấu trúc** tài liệu (link, glossary, test dimensions, ADR status, changelog header, ADR numbering) nhưng không có gì kiểm **nội dung** tài liệu khớp code. Audit thủ công (17 agent, ~85% codebase) tìm 13 lệch — 8/13 là pattern grep-được (role count, schema tables, cleanup callbacks, indexes). 5/13 cần hiểu ngữ nghĩa (spec mô tả intent khác code, AI code vượt scope).

**Ràng buộc:**
- Guardrails hiện có chạy trong job `doc-governance` (bash native, fail-loud) — pattern đã chứng minh hiệu quả (7 script, 0 false positive kể từ ADR-024).
- Tài liệu lịch sử (specs, plans) **không viết lại** (ADR-002) — chỉ thêm metadata.
- Full AI audit tốn ~1 giờ + nhiều token — không phù hợp chạy mỗi PR, nhưng phù hợp mỗi milestone.

---

## Quyết định (ADR)

### ADR-062: CI guardrail doc-code sync — 4 script bash trong job doc-governance
- **Trạng thái:** Accepted · 25/06/2026
- **Bối cảnh:** 8/13 lệch từ cross-check audit là pattern deterministic, grep-được. Hiện CI không bắt vì guardrails chỉ kiểm cấu trúc doc, không so nội dung doc với code.
- **Quyết định:** Thêm 4 script bash vào job `doc-governance` (cùng pattern fail-loud với 7 script hiện có). Mỗi script so sánh 1 nguồn sự thật trong code với tài liệu tương ứng:

  **Script 1 — `check-role-count.sh`:** Đếm enum values trong `db/schema.rb` (type `user_role`) + đếm variant runtime (grep `zone_manager` patterns) → so với số "N vai trò" trong 4 canonical docs (`V2_HANH_VI`, `V2_CHIEU_TEST`, `V2_THIET_KE`, `AGENTS.md`). Đỏ nếu lệch.

  **Script 2 — `check-schema-coverage.sh`:** List tên bảng từ `db/schema.rb` (`create_table "xxx"`) → kiểm mỗi bảng có heading `#### xxx` hoặc mention trong `V2_THIET_KE_HE_THONG.md` phần Schema. Bỏ qua Rails internal tables (`schema_migrations`, `ar_internal_metadata`, `versions`). Đỏ nếu bảng thiếu.

  **Script 3 — `check-cleanup-callbacks.sh`:** Grep `before_discard`/`after_discard` trong `app/models/*.rb` → so với bảng "Cleanup khi discard" trong `V2_THIET_KE_HE_THONG.md`. Đỏ nếu model có discard callback mà bảng không liệt kê.

  **Script 4 — `check-discarded-at-indexes.sh`:** List bảng có cột `discarded_at` trong `db/schema.rb` → kiểm mỗi bảng có dòng `(discarded_at) | Regular` trong bảng index của `V2_THIET_KE_HE_THONG.md`. Đỏ nếu thiếu.

- **Lý do:** Tái dùng pattern đã chứng minh (bash, fail-loud, job `doc-governance`). 4 script phủ 8/13 pattern drift phổ biến nhất. Chi phí CI thêm <10 giây (grep/awk). Không cần AI/LLM.
- **Tradeoff:** (+) Máy ép, 0 false positive nếu viết đúng, chạy mỗi PR. (−) Chỉ bắt drift có pattern cố định; drift ngữ nghĩa (spec intent ≠ code) vẫn cần người/AI. Thêm 4 script bảo trì khi cấu trúc doc thay đổi.
- **Phương án đã loại:** (a) Full AI audit mỗi PR — quá tốn token + chậm (1 giờ). (b) Custom linter phân tích AST — over-engineering cho 4 check đơn giản. (c) Không làm gì — audit thủ công mỗi vài tháng đủ chậm để drift tích tụ.
- **Điều kiện xem lại:** Khi thêm loại drift mới mà script hiện tại không bắt — đánh giá có nên thêm script hay chuyển sang approach khác.

### ADR-063: Spec status marker — convention ghi note khi code giản hoá spec
- **Trạng thái:** Accepted · 25/06/2026
- **Bối cảnh:** 3/13 lệch do code giản hoá spec requirement mà spec không được cập nhật (manual_usage, billing display, history range). ADR-002 cấm viết lại tài liệu lịch sử. Cần cách đánh dấu spec requirement đã bị giản hoá mà không vi phạm ADR-002.
- **Quyết định:** Khi implementation giản hoá hoặc bỏ qua một requirement trong spec, dev thêm **blockquote marker** vào spec ngay trong cùng PR:

  ```markdown
  > **Simplified (PR #NNN, ngày):** mô tả ngắn — requirement X thay bằng approach Y. Xem commit/PR để biết lý do.
  ```

  Marker là metadata, không phải viết lại nội dung → không vi phạm ADR-002. Thêm mục kiểm vào PR template checklist: "Nếu code đi hướng khác spec → ghi Simplified marker vào spec trong cùng PR."

- **Lý do:** Chi phí gần 0 (1 dòng blockquote). Bắt drift ngay tại nguồn thay vì đợi audit. Reviewer/AI thấy marker khi đọc spec → biết requirement đã thay đổi.
- **Tradeoff:** (+) Đơn giản, không cần tool/CI mới. (−) Prose — dev quên thì không ai bắt. Lưới an toàn = periodic audit (ADR-064).
- **Phương án đã loại:** (a) Đánh dấu bằng frontmatter field `simplified_requirements: [...]` — over-engineering, khó parse, ít người đọc frontmatter. (b) Tạo file riêng `spec-drift-log.md` — thêm nơi mới quản lý, vi phạm "sửa đừng thêm". (c) Máy ép: CI check spec sửa khi code sửa — không khả thi (cần hiểu ngữ nghĩa "code này implement spec nào").
- **Điều kiện xem lại:** Khi thấy drift ngữ nghĩa vẫn tích tụ dù có convention — cân nhắc tầng audit chạy thường xuyên hơn.

### ADR-064: Periodic doc-code audit — full AI cross-check trước release
- **Trạng thái:** Proposed (chờ quyết #464)
- **Bối cảnh:** 4 CI script (ADR-062) bắt drift deterministic. Convention (ADR-063) bắt drift ngữ nghĩa tại nguồn. Nhưng cả hai đều có lỗ: script không bắt được mọi pattern, convention phụ thuộc người nhớ. Cần lưới an toàn cuối cùng.
- **Quyết định:** Trước khi cắt `release/*`, chạy **doc-code cross-check audit** (tương tự session đã làm). Có thể dùng Claude Code workflow hoặc skill chạy thủ công. Scope: 10 file canonical vs code, ~17 agent, ~1 giờ. Output: danh sách lệch (nếu có) → tạo issue → fix trước khi merge release vào main.

  Chưa chốt implementation (workflow script, skill, hay chạy tay) — hoãn cho đến khi có kinh nghiệm vận hành ADR-062 + ADR-063 ít nhất 1-2 milestone. Nếu 2 tầng trên bắt đủ thì tầng 3 có thể giữ ở mức "chạy tay khi cần."

- **Lý do:** Defense in depth — 3 tầng bổ sung nhau. Tầng 3 là lưới an toàn cuối, tần suất thấp (mỗi release), chi phí chấp nhận được.
- **Tradeoff:** (+) Phủ 13/13 pattern drift. (−) Tốn token + thời gian; chỉ chạy mỗi release nên drift giữa các PR vẫn tồn tại tạm thời.
- **Phương án đã loại:** (a) Chạy mỗi PR — quá tốn. (b) Không làm — 2 tầng trên đã đủ? Có thể, nhưng giữ option mở.
- **Điều kiện xem lại:** Sau 2 milestone vận hành ADR-062 + ADR-063 — nếu 0 drift lọt qua thì tầng 3 có thể bỏ; nếu vẫn lọt thì formalize implementation.

---

## Truy vết

- Issue: #464 (nguyên nhân gốc + đề xuất)
- Audit gốc: #456, #457, #459, #462 (4 PR merged)
- Liên quan: #432 (structural duplication — ADR-062 không xử lý, #432 vẫn mở)
- Canonical docs ảnh hưởng: `V2_THIET_KE_HE_THONG.md` (bảng cleanup + schema + index), `V2_HANH_VI_HE_THONG.md`, `V2_CHIEU_TEST.md`, `AGENTS.md`
- CI job: `doc-governance` trong `.github/workflows/ci.yml`

---

## Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| 0.2.0 | 25/06/2026 | ADR-062 implemented: 4 CI scripts (`check-role-count.sh`, `check-schema-coverage.sh`, `check-cleanup-callbacks.sh`, `check-discarded-at-indexes.sh`) wired into job `doc-governance`. ADR-063 implemented: Simplified marker checklist item added to PR template. ADR-064 remains Proposed. Issue #464. |
| 0.1.0 | 25/06/2026 | Tạo spec: ADR-062 (4 CI scripts), ADR-063 (spec status marker convention), ADR-064 (periodic audit — Proposed). Issue #464. |
