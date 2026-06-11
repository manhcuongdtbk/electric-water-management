---
title: SDLC Overview — Mô hình phát triển & chiến lược tài liệu
version: 0.4.0
status: draft (chờ duyệt)
date: 2026-06-07
---

# SDLC Overview (umbrella)

Tài liệu **đứng đầu** loạt spec chuẩn hoá SDLC. Mỗi mảnh (release process, CI, vận hành…) là một spec riêng, **tuân theo hai ADR dưới đây**.

> **Cách đọc tài liệu này:** mỗi quyết định viết theo **ADR** (Architecture Decision Record): Bối cảnh → Quyết định → Lý do → Tradeoff → Phương án đã loại → Điều kiện xem lại → Trạng thái. ADR mới **thay** (supersede) ADR cũ, giữ lịch sử.

---

## ADR-001: Mô hình phát triển & cách quản lý dự án

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Hệ thống nội bộ (điện sư đoàn), domain cần đúng & truy vết. Tài liệu thiết kế dày, làm trước (`docs/V2_*`). Phát hành theo phiên bản rời rạc, có khách nghiệm thu (UAT), giao bản chạy offline. Team 2–3 người, một người (chủ dự án) duyệt & phát hành.
- **Quyết định:** Đặt tên tường minh mô hình đang theo:
  - **Quản lý dự án:** *Hybrid* (predictive + adaptive) — theo nghĩa PMI.
  - **Kỹ thuật (SDLC):** *Iterative/Incremental, design-first*.
  - **Dòng việc:** *Kanban* (luồng liên tục, ít nghi thức).
- **Lý do:** Phản ánh đúng cách làm thực tế; cả ba đều là tên/chuẩn có sẵn (không tự chế); phù hợp domain cần thiết kế trước + giao tăng dần có nghiệm thu.
- **Tradeoff:**
  - (+) Truyền đạt/onboarding rõ; tra cứu được chuẩn; ít nghi thức cho team nhỏ.
  - (−) Hybrid không "thuần" một trường phái → cần kỷ luật tự giữ ranh giới predictive/adaptive.
- **Phương án đã loại:**
  - *Scrum thuần* — loại: team quá nhỏ, không cần sprint/ceremony.
  - *Waterfall thuần* — loại: cần lặp & giao tăng dần.
  - *Áp đầy đủ ISO/IEC/IEEE 12207 / PMBOK* — loại: quá nặng cho quy mô; chỉ mượn khái niệm.
- **Điều kiện xem lại:** team >5 người, hoặc nhiều khách/nhiều sản phẩm song song → cân nhắc thêm cấu trúc (Scrum/SAFe-lite).

---

## ADR-002: Chiến lược tài liệu & tri thức (bền + chia sẻ + tự động + tool-agnostic)

- **Trạng thái:** Proposed · 2026-06-07 · **mở rộng bởi [ADR-023](2026-06-10-quan-tri-tai-lieu-design.md)** (quản trị tài liệu: từ điển thuật ngữ + bản đồ tài liệu + quy tắc "sửa đừng thêm").
- **Bối cảnh:** Cần giữ kiến thức/quyết định không bị quên qua các session; cả team (người + nhiều loại AI: Claude Code, Cursor, …, có thể cả Windows) thừa hưởng và cải tiến được.
- **Quyết định:** Kiến trúc **4 lớp**, nguồn sự thật nằm trong **repo** (version-control), không nằm ở trí nhớ:
  1. **Guardrails tự động** — luật nào máy kiểm được thì để máy ép: CI, release-please, commitlint, branch-guard, AI review PR. *(Không viết prose rồi mong người nhớ.)*
  2. **`AGENTS.md` (canonical)** — quy ước ngắn gọn, mệnh lệnh, trỏ tới chi tiết. Là chuẩn cross-tool (Linux Foundation; 20+ công cụ đọc: Cursor, Copilot, Codex, Gemini, VS Code…).
     - Claude Code **không** đọc `AGENTS.md` → `CLAUDE.md` chỉ chứa một dòng **`@AGENTS.md`** (cú pháp import của Claude Code). **Không dùng symlink** (hỏng trên Windows). Hai file đều là file thường → an toàn Windows, nội dung vẫn một chỗ.
  3. **`docs/` (spec + ADR)** — chi tiết & *vì sao*; có version + changelog; cải tiến qua PR + supersede.
  4. **`CONTRIBUTING.md`** — onboarding/quy trình cho người; trỏ về AGENTS.md + docs.

  **Quy ước version & changelog cho tài liệu (hệ quả của 4 lớp trên):**
  - **File meta ở gốc repo** (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`): **KHÔNG** có version/changelog riêng — theo dõi qua git history; lịch sử cấp dự án do `CHANGELOG.md` sinh tự động từ Conventional Commits (release-please, xem ADR-008).
  - **Tài liệu trong `docs/`** (thiết kế, nghiệp vụ, hành vi, kiểm thử, `KIEN_THUC_*`, `HUONG_DAN_*`, `hdsd/*`, `superpowers/specs/*`): **CÓ** version + lịch sử thay đổi riêng (`> **Phiên bản:**` + `## Lịch sử thay đổi`, hoặc frontmatter `version:` + `## Changelog`). Sửa file loại này → **bump version + thêm entry trong cùng commit**.
  - **Vì sao tách vậy:** khớp quy ước ngành (file meta ở gốc không versioned; versioning diễn ra ở cấp dự án/bản phát hành), còn tài liệu thiết kế/tri thức cần version riêng vì ghi nhận quyết định tiến hoá theo thời gian (kiểu ADR/RFC).
- **Lý do:** Repo = thứ duy nhất vừa bền, vừa chia sẻ được cả team, vừa cải tiến qua PR. AGENTS.md là chuẩn sẵn cho "tương thích mọi AI". `@import` thay symlink để an toàn Windows mà vẫn DRY.
- **Tradeoff:**
  - (+) Một nguồn sự thật; mọi AI + người đọc; tự động hoá tối đa; an toàn đa nền tảng.
  - (−) Phải kỷ luật giữ `AGENTS.md` ngắn (đừng nhồi hết vào).
- **Phương án đã loại:**
  - *Symlink `CLAUDE.md`→`AGENTS.md`* — loại: hỏng khi checkout trên Windows không bật core.symlinks.
  - *Mỗi tool một file riêng (CLAUDE.md, .cursor, copilot-instructions… nội dung riêng)* — loại: lệch nhau theo thời gian.
  - *Dựa vào bộ nhớ AI* — loại: bộ nhớ là cục bộ/cá nhân, **không tới được đồng đội**; chỉ dùng làm *pointer* trỏ về repo.
- **Điều kiện xem lại:** khi số quyết định nhiều → tách ADR ra `docs/adr/` riêng; khi có tool AI mới không đọc AGENTS.md → thêm pointer tương ứng.

> **Để team thực sự thừa hưởng:** các tài liệu này phải được **merge vào `main` qua PR** (không để treo ở nhánh worktree).

---

## ADR-029: Vận hành vòng đời với trợ lý AI — "AI lo cơ học, người giữ gate quyết định"

- **Trạng thái:** Proposed · 2026-06-11 · **mở rộng [ADR-001](#adr-001-mô-hình-phát-triển--cách-quản-lý-dự-án)** (ADR-001 đặt tên *mô hình vận hành*; ADR-029 đặt tên *cách vận hành hằng ngày* mô hình đó cùng một trợ lý AI). Tổng quát hoá [ADR-028](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) (cổng xác nhận khách trước build — một áp dụng cụ thể của nguyên tắc này).
- **Bối cảnh:** Tài liệu SDLC (`HUONG_DAN_SDLC.md`, `CONTRIBUTING.md`) mô tả thao tác kiểu **thủ công cho người**. Thực tế đội (2–3 người, một chủ dự án duyệt & phát hành) vận hành **xuyên suốt vòng đời bằng một trợ lý AI** (hiện là Claude Code): trợ lý soạn Issue, draft spec/ADR, fold canonical, tạo nhánh/PR, theo dõi CI, soạn release notes. Cần đặt tên tường minh **nguyên tắc vận hành** này — vừa để onboarding hiểu đúng cách làm, vừa để giữ kỷ luật *ai quyết cái gì*. Đây là **mô hình vận hành** + tài liệu SDLC, **không đụng nghiệp vụ app**.
- **Quyết định:** Mỗi bước vòng đời chạy theo mô hình **"trợ lý AI lo phần cơ học — người giữ các gate quyết định"** (định nghĩa **gate**, **human-in-the-loop**, **dogfood**, **vận hành AI-assisted**: `docs/THUAT_NGU.md`). Ranh giới đi theo **6 bước vòng đời** đã dùng ở `HUONG_DAN_SDLC.md` mục 4 (intake → triage → design → implement → release → close) để canonical + onboarding + `CONTRIBUTING.md` cùng mô tả **một** khung 6 bước:

  | Bước | Phần cơ học → trợ lý AI | Gate quyết định → người |
  |---|---|---|
  | **Intake** | soạn Issue từ trao đổi/khách báo, điền template | chốt yêu cầu, duyệt nội dung Issue |
  | **Triage** | đề xuất loại thay đổi / mức SemVer / milestone | **gán milestone + `priority-high`** (chủ dự án quyết) |
  | **Design** | draft spec/ADR, fold vào canonical + anchor `NV-…`, bump version/changelog | **duyệt thiết kế** (HARD-GATE brainstorming) |
  | **Implement** | tạo nhánh, viết code + test, mở PR `Refs #N`, theo dõi CI | **duyệt + merge** |
  | **Release** | soạn release notes, chạy release-please; sinh/đánh version bản gửi khách, ghi vết | **quyết cắt release**, duyệt nội dung gửi khách + chuyển lời khách, giao Mini PC |
  | **Close** | ghi vết (`Closes #N`), cập nhật truy vết | xác nhận đóng |

  **Ba gate cứng — luôn human-in-the-loop, trợ lý AI KHÔNG tự quyết:** **triage** (milestone/priority), **merge** (vào `develop`/`main`), **cắt release** (kể cả giao Mini PC + nội dung gửi khách). Trợ lý đề xuất; người chốt.

  **Trung lập công cụ ở lớp canonical:** `AGENTS.md` và ADR này chỉ nói "**trợ lý AI**", **không** hard-wire Claude Code. Chi tiết riêng của Claude Code (hook tự theo dõi CI, nhắc bump version, chặn push nhánh cũ; lệnh `/code-review`) nằm ở **`CONTRIBUTING.md` mục 8** — ánh xạ cụ thể, thay được khi đổi/thêm tool. Khớp kiến trúc 4 lớp + tool-agnostic của [ADR-002](#adr-002-chiến-lược-tài-liệu--tri-thức-bền--chia-sẻ--tự-động--tool-agnostic).

- **Lý do:** Phản ánh đúng cách làm thực tế (tài liệu cũ tả thao tác tay đã lệch hiện trạng). Tách *cơ học* khỏi *quyết định* giúp tăng tốc mà **không mất quyền kiểm soát** ở các điểm rủi ro (triage/merge/release). Viết trung lập công cụ ở canonical để tài liệu sống lâu hơn một công cụ cụ thể. ADR này cũng **dogfood chính nó**: chính nó được soạn theo mô hình "AI draft, người duyệt gate".
- **Tradeoff:**
  - (+) Onboarding hiểu ngay "vận hành cùng trợ lý AI, người duyệt ở đâu"; nhanh hơn thao tác tay; giữ kiểm soát ở gate; canonical không khoá vào một tool.
  - (−) Phụ thuộc năng lực công cụ AI (chất lượng draft phụ thuộc tool); giữ human-in-the-loop ở mọi gate là *chi phí* (không tự động hoá tới cùng) — đổi lấy an toàn; lớp trung lập tạo **một** chỗ chỉ-dẫn gián tiếp (canonical → `CONTRIBUTING.md` §8) phải giữ đồng bộ.
- **Phương án đã loại:**
  - *Hard-wire Claude Code vào canonical (`AGENTS.md`/ADR)* — loại: khoá tài liệu vào một công cụ; đổi/thêm tool (Codex, Antigravity…) phải sửa canonical. Giữ chi tiết tool ở `CONTRIBUTING.md` §8.
  - *Trợ lý AI tự quyết trọn vòng đời (gồm merge + cắt release)* — loại: bỏ human-in-the-loop ở điểm rủi ro cao; domain nội bộ cần đúng + truy vết + một người chịu trách nhiệm phát hành (ADR-001).
  - *Để tài liệu mô tả thao tác tay, không ghi nhận vai trò AI* — loại: lệch hiện trạng; người mới hiểu sai cách đội thực sự làm.
  - *Mở rộng thẳng ADR-001 thay vì ADR mới* — loại: ADR-001 là *mô hình* (Hybrid/Iterative/Kanban) ổn định; cách-vận-hành-với-AI tiến hoá theo công cụ nên tách ADR riêng để supersede độc lập. (ADR-028 + `CONTRIBUTING.md` đã forward-reference "ADR-029".)
- **Điều kiện xem lại:** thêm/đổi công cụ AI (Codex, Antigravity, coding agent khác) → rà lại ánh xạ `CONTRIBUTING.md` §8; team >5 người hoặc nhiều khách song song → cân nhắc dời gate (ADR-001); năng lực AI thay đổi đáng kể (đáng tin hơn / kém hơn) → xét lại ranh giới cơ học/gate.

---

## Changelog

- **0.4.0 (2026-06-11):** Thêm **ADR-029** (vận hành vòng đời với trợ lý AI — "AI lo cơ học, người giữ gate quyết định"; ranh giới theo 6 bước; ba gate cứng triage/merge/release luôn human-in-the-loop; trung lập công cụ ở canonical, chi tiết Claude Code ở `CONTRIBUTING.md` §8). Mở rộng ADR-001, tổng quát hoá ADR-028. Issue #322.
- **0.3.0 (2026-06-10):** ADR-002 ghi chú được **mở rộng bởi ADR-023** (quản trị tài liệu — spec `2026-06-10-quan-tri-tai-lieu-design.md`; Issue #310).
- **0.2.0 (2026-06-07):** ADR-002: thêm quy ước version & changelog cho tài liệu — file meta ở gốc repo (`README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`) không versioned; tài liệu trong `docs/` có version + lịch sử thay đổi, bump khi sửa.
- **0.1.0 (2026-06-07):** Bản thảo đầu; ADR-001 (mô hình) + ADR-002 (tài liệu/tri thức). Chờ duyệt.
