---
title: Auto-prepend Vietnamese release notes template
version: 0.2.0
date: 2026-06-25
governed_by: 2026-06-07-quy-trinh-release-design.md
---

# Auto-prepend Vietnamese release notes template

> **Ghi chú:** CONTRIBUTING.md §6 yêu cầu ghi chú tiếng Việt cho mọi GitHub Release. Hiện tại honor-system — dễ quên. Spec này tự động inject template vào release body.

## Bối cảnh

release-please tạo GitHub Release body từ CHANGELOG (tiếng Anh). CONTRIBUTING.md §6 yêu cầu prepend ghi chú tiếng Việt (2 phần: "Tóm tắt cho người dùng" + "Chi tiết cho chủ dự án"). Hiện tại do người soạn thủ công (hoặc nhờ Claude Code) rồi `gh release edit` — không có gì ngăn quên.

**Ràng buộc:**
- release-please tạo release tự động, không có hook chen giữa merge → release creation.
- ~1 release/tháng.
- Không muốn phụ thuộc API key hoặc chi phí bên ngoài.

---

## Quyết định (ADR)

### ADR-066: Auto-prepend Vietnamese release notes template on release:published
- **Trạng thái:** Accepted · 25/06/2026
- **Bối cảnh:** Honor-system cho bước "thêm ghi chú tiếng Việt" sau release-please tạo release. Dễ quên, không có guard.
- **Quyết định:** Workflow `release-notes-vi.yml` trigger `release: published`. Tự prepend template tiếng Việt (heading + 2 phần "(chưa soạn)") vào đầu release body qua `gh release edit`, giữ nguyên CHANGELOG tiếng Anh bên dưới. Idempotent: skip nếu body đã chứa "Phiên bản" (đã có tiếng Việt). Không cần API key, không chi phí.

  Người (hoặc Claude Code trong session) điền nội dung 2 phần, duyệt trước khi công bố (gate — ADR-029). Template hiện ngay trên release body nên ai mở ra cũng thấy placeholder "(chưa soạn)" → nhắc nhở tự nhiên.

- **Lý do:** Zero-cost, zero-dependency. Template đúng format ngay tại chỗ — người chỉ cần điền, không cần nhớ format. Placeholder "(chưa soạn)" là lời nhắc tự nhiên (nhìn release thấy ngay chưa xong).
- **Tradeoff:** (+) Không phụ thuộc API key/uptime/chi phí; template inject tức thì khi release tạo. (−) Vẫn cần người/AI điền nội dung — template chỉ nhắc, không tự soạn. Nếu người quên điền → release có placeholder xấu.
- **Phương án đã loại:** (a) Claude API auto-generate — chất lượng cao nhưng cần API key + chi phí + phụ thuộc uptime. Có thể nâng cấp lên sau nếu cần. (b) Scheduled check — chậm (chờ cron), phát hiện muộn. (c) Check trên Release PR — release body do release-please tạo sau merge, không chen vào được.
- **Điều kiện xem lại:** Khi thấy placeholder "(chưa soạn)" thường xuyên không được điền → cân nhắc nâng lên Claude API auto-generate (cần API key).

---

## Truy vết

- Issue: #446
- CONTRIBUTING.md §6 (quy trình ghi chú tiếng Việt)
- ADR-029 (vận hành AI-assisted: AI draft, người gate)
- ADR-008 (release-please)

---

## Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung |
|---|---|---|
| 0.2.0 | 25/06/2026 | Chuyển từ Claude API sang template trống (không cần API key, không chi phí). Đổi tiêu đề ADR-066. |
| 0.1.0 | 25/06/2026 | Tạo spec: ADR-066 (auto-generate Vietnamese release notes via Claude API). Issue #446. |
