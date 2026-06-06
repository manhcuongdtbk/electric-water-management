---
title: SDLC Overview — Mô hình phát triển & chiến lược tài liệu
version: 0.1.0
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

- **Trạng thái:** Proposed · 2026-06-07
- **Bối cảnh:** Cần giữ kiến thức/quyết định không bị quên qua các session; cả team (người + nhiều loại AI: Claude Code, Cursor, …, có thể cả Windows) thừa hưởng và cải tiến được.
- **Quyết định:** Kiến trúc **4 lớp**, nguồn sự thật nằm trong **repo** (version-control), không nằm ở trí nhớ:
  1. **Guardrails tự động** — luật nào máy kiểm được thì để máy ép: CI, release-please, commitlint, branch-guard, AI review PR. *(Không viết prose rồi mong người nhớ.)*
  2. **`AGENTS.md` (canonical)** — quy ước ngắn gọn, mệnh lệnh, trỏ tới chi tiết. Là chuẩn cross-tool (Linux Foundation; 20+ công cụ đọc: Cursor, Copilot, Codex, Gemini, VS Code…).
     - Claude Code **không** đọc `AGENTS.md` → `CLAUDE.md` chỉ chứa một dòng **`@AGENTS.md`** (cú pháp import của Claude Code). **Không dùng symlink** (hỏng trên Windows). Hai file đều là file thường → an toàn Windows, nội dung vẫn một chỗ.
  3. **`docs/` (spec + ADR)** — chi tiết & *vì sao*; có version + changelog; cải tiến qua PR + supersede.
  4. **`CONTRIBUTING.md`** — onboarding/quy trình cho người; trỏ về AGENTS.md + docs.
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

## Changelog

- **0.1.0 (2026-06-07):** Bản thảo đầu; ADR-001 (mô hình) + ADR-002 (tài liệu/tri thức). Chờ duyệt.
