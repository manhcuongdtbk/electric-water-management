---
title: Quản trị tài liệu (từ điển thuật ngữ + bản đồ tài liệu + quy tắc chống lỗi thời)
version: 0.1.0
status: draft (chờ duyệt)
date: 2026-06-10
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Quản trị tài liệu

Mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md) (chiến lược tài liệu/tri thức) bằng một bộ quản trị tài liệu **nhẹ**, hợp đội 2–3 người và mô hình *ít nghi thức* của [ADR-001](2026-06-07-sdlc-overview-design.md). Mục tiêu: chặn tài liệu **rời rạc → lỗi thời → mâu thuẫn**. Truy vết: GitHub Issue [`#310`](https://github.com/manhcuongdtbk/electric-water-management/issues/310).

## Bối cảnh

ADR-002 đặt nền: nguồn sự thật nằm trong repo, `AGENTS.md` canonical, mỗi fact một nơi. Nhưng thực tế sau loạt chuẩn hoá SDLC, tài liệu **phân mảnh** và xuất hiện trùng lặp:

- Gloss **"canonical"** giải thích ở **ba nơi**: `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`.
- **Từ viết tắt** (CI, ADR, CRUD, UI, SDLC, SemVer): bảng định nghĩa ở `AGENTS.md`, lại một phần ở `docs/HUONG_DAN_SDLC.md` §1 và §8.
- **Thuật ngữ quy trình** (nhánh, commit, squash, pull request, milestone, "chủ dự án"…): chỉ ở `docs/HUONG_DAN_SDLC.md` §1, không có nơi canonical chung.

Khi cập nhật, người và công cụ AI có xu hướng **"append mù"** — dán thêm nội dung mà chưa đọc/đối chiếu toàn file — thay vì tích hợp. Hệ quả đã thấy thật: mô hình `-rc.N` còn sót lại rải rác sau khi đã bỏ (rà soát trong session Issue #307). ADR-002 nói *"mỗi fact một nơi canonical"* nhưng chưa nói **làm sao biết nơi đó ở đâu** và **quy trình cập nhật** để giữ kỷ luật ấy.

## ADR-023: Quản trị tài liệu (mở rộng ADR-002)

- **Trạng thái:** Proposed · 2026-06-10 · mở rộng (không thay) [ADR-002](2026-06-07-sdlc-overview-design.md).
- **Bối cảnh:** xem trên.
- **Quyết định:** thêm ba khí cụ nhẹ và một bước rà soát, tất cả nằm trong repo:

  1. **Một từ điển thuật ngữ canonical — `docs/THUAT_NGU.md`.** Nguồn **duy nhất** cho định nghĩa từ, gồm: (a) bảng **từ viết tắt được phép** (kèm cột nguồn chính thống); (b) **thuật ngữ quy trình**; (c) các **gloss** rải rác ("canonical", "chủ dự án"…). Nơi khác **trỏ về**, không chép. Hai khối **ở lại `AGENTS.md`** (chỉ thêm một dòng trỏ sang): bảng đặt tên nghiệp vụ (`zones → Zone`…) và mục "Thuật ngữ environment" — vì là nội dung code/thiết kế gắn `SystemInfo` và spec app-version-reporting, không phải định nghĩa từ thuần.

  2. **Một bản đồ tài liệu canonical — `docs/BAN_DO_TAI_LIEU.md`.** Liệt kê **mỗi tài liệu → mục đích → đối tượng → loại**, phân ba loại:
     - **canonical** — nguồn sự thật cho một fact; **sửa ở đây** (`docs/V2_*` nghiệp vụ/thiết kế/hành vi/kiểm thử, `AGENTS.md`, `THUAT_NGU.md`, `BAN_DO_TAI_LIEU.md`).
     - **current-state** — mô tả hiện trạng hoặc dữ liệu suy ra từ canonical; **phải rà cho khớp** (`README.md`, `CONTRIBUTING.md`, `HUONG_DAN_SDLC.md`, `HUONG_DAN_DEPLOY.md`, `KIEN_THUC_DOCKER.md`, `hdsd/V2_HUONG_DAN_SU_DUNG.md`, `V2_KICH_BAN_TEST.md` — kịch bản suy ra từ bốn tài liệu nguồn, tái sinh khi nguồn đổi).
     - **lịch sử** — bản ghi quyết định/thời điểm; **KHÔNG viết lại** (`docs/superpowers/specs/*` ADR, `docs/superpowers/plans/*`, `CHANGELOG.md`).

  3. **Quy tắc "sửa đừng thêm" trong `AGENTS.md`** (file mọi công cụ AI đều đọc): trước khi cập nhật tài liệu → **đọc lại toàn file và đối chiếu** xem fact đã có chỗ chưa. **Thêm hay sửa là tùy kết quả đánh giá** — đã có thì sửa/tích hợp tại chỗ; thực sự mới thì thêm vào đúng nơi canonical (tra `BAN_DO_TAI_LIEU.md`). Cái cần tránh là **"append mù"** tạo trùng lặp/mâu thuẫn. Mỗi fact một nơi canonical; nơi khác trỏ về. Thuật ngữ tra/cập nhật ở `THUAT_NGU.md` — gặp thuật ngữ mới hoặc thấy giải thích cũ chưa đủ rõ thì cập nhật ở đó.

  4. **Rà soát định kỳ nhẹ — một dòng trong checklist phát hành** (`2026-06-07-quy-trinh-release-design.md`): *"Rà tài liệu current-state khớp ADR mới nhất (xem `BAN_DO_TAI_LIEU.md`)."* Không thêm nhịp họp/nghi thức; rà gắn vào thời điểm đã có sẵn (cắt release).

- **Lý do:**
  - Một nguồn thuật ngữ chặn drift tại gốc: sửa một chỗ, mọi nơi trỏ về nên không lệch.
  - Bản đồ tài liệu biến *"mỗi fact một nơi canonical"* (ADR-002, trừu tượng) thành tra cứu được: biết **chỗ để sửa** thay vì **thêm chỗ mới**.
  - Quy tắc "sửa đừng thêm" đặt ở `AGENTS.md` vì đây là điều máy **không** ép được (khác CI/branch-guard) — phải là chỉ dẫn mệnh lệnh cho cả người và AI (đúng tinh thần ADR-002: cái gì máy ép được thì để máy, còn lại để prose ngắn + kỷ luật).
  - Gắn rà soát vào checklist phát hành tránh đẻ thêm nghi thức (ADR-001 *ít nghi thức*).
- **Tradeoff:**
  - (+) Một nguồn thuật ngữ; tra được fact ở đâu; quy trình cập nhật rõ; vẫn nhẹ.
  - (−) Danh sách từ viết tắt rời khỏi `AGENTS.md` (file mọi AI đọc) sang `THUAT_NGU.md` → AI phải theo một link để biết từ nào được phép. Bù lại bằng câu luật mệnh lệnh trong `AGENTS.md` trỏ thẳng `THUAT_NGU.md` ("không viết tắt trừ các từ liệt kê ở đó; cần từ mới → thêm vào đó trước").
  - (−) Thêm hai tài liệu canonical phải bảo trì; nhưng chúng thay thế nội dung đang trùng lặp nên tổng khối lượng không tăng.
- **Phương án đã loại:**
  - *Gộp cả mục "environment" + bảng đặt tên nghiệp vụ vào `THUAT_NGU.md`* — loại: làm file phình to và đứt mạch nội dung thiết kế (environment gắn `SystemInfo`/spec, đặt tên gắn quy ước code), vốn đã có nơi canonical.
  - *Để bảng "Từ vựng" nguyên ở `HUONG_DAN_SDLC.md`, chỉ gom viết tắt* — loại: vẫn còn hai nơi định nghĩa từ, chưa dứt động lực của Issue #310.
  - *Đặt bản đồ tài liệu thành một mục trong `THUAT_NGU.md`* — loại (chủ dự án chốt): trộn "từ điển" với "chỉ mục tài liệu" làm mờ vai trò; tách `BAN_DO_TAI_LIEU.md` riêng cho rạch ròi.
  - *Nhịp rà soát định kỳ theo lịch* — loại: thừa nghi thức cho đội nhỏ; gắn vào checklist phát hành là đủ.
- **Điều kiện xem lại:** số thuật ngữ/tài liệu tăng tới mức `THUAT_NGU.md`/`BAN_DO_TAI_LIEU.md` khó đọc một lượt → cân nhắc tách theo nhóm; hoặc khi thêm công cụ AI mới có cơ chế riêng cho thuật ngữ → rà lại pointer.

## Thiết kế triển khai

Một pull request, nhánh `feature/document-governance` ← `develop`, docs-only (CI bỏ qua job test theo ADR-021).

### Tài liệu mới (canonical, có version + changelog theo ADR-002)

- **`docs/THUAT_NGU.md`** (`1.0.0`) — ba phần: (1) Từ viết tắt được phép (chuyển nguyên bảng từ `AGENTS.md`, giữ cột nguồn); (2) Thuật ngữ quy trình (chuyển bảng "Từ vựng" từ `HUONG_DAN_SDLC.md` §1); (3) Gloss ("canonical", "chủ dự án"…). Đầu file ghi rõ: đây là nguồn duy nhất, nơi khác trỏ về.
- **`docs/BAN_DO_TAI_LIEU.md`** (`1.0.0`) — bảng phân loại canonical / current-state / lịch sử như Quyết định mục 2, kèm một đoạn ngắn giải thích ba loại và ý nghĩa với quy tắc "sửa đừng thêm".

### Tài liệu meta sửa (KHÔNG version — theo ADR-002)

- **`AGENTS.md`**: "Nguyên tắc viết" bỏ bảng viết tắt, giữ luật + trỏ `THUAT_NGU.md`; thêm section ngắn **"Quản trị tài liệu"** (quy tắc "sửa đừng thêm" + trỏ `BAN_DO_TAI_LIEU.md`, `THUAT_NGU.md`, ADR-023); "Tài liệu liên quan" thêm hai dòng cho hai file mới.
- **`CONTRIBUTING.md`**: thay gloss "canonical" inline (đầu file) bằng pointer `THUAT_NGU.md`.

### Tài liệu versioned sửa (bump version + changelog cùng commit)

- **`docs/HUONG_DAN_SDLC.md`** (`1.0.0` → `1.1.0`): §1 thay bảng "Từ vựng" bằng dòng trỏ `THUAT_NGU.md`; §8 sửa pointer viết tắt từ `AGENTS.md` → `THUAT_NGU.md`; §5 thêm dòng bản đồ tài liệu.
- **`docs/superpowers/specs/2026-06-07-quy-trinh-release-design.md`** (`0.13.0` → `0.14.0`): thêm một dòng checklist phát hành (Quyết định mục 4).
- **`docs/superpowers/specs/2026-06-07-sdlc-overview-design.md`** (`0.2.0` → `0.3.0`): ADR-002 thêm một dòng "mở rộng bởi ADR-023".

## Truy vết

- **Issue:** [`#310`](https://github.com/manhcuongdtbk/electric-water-management/issues/310) (`change-request`, `documentation`) — `Closes #310` ở pull request (giải quyết trọn bốn tiêu chí chấp nhận).
- **Lên:** [`2026-06-07-sdlc-overview-design.md`](2026-06-07-sdlc-overview-design.md) ADR-002 (chiến lược tài liệu/tri thức) — ADR-023 mở rộng; ADR-001 (mô hình ít nghi thức). Phụ thuộc: làm **sau** Issue #307 (onboarding) đã merge để tránh xung đột file.
- **Test:** không — *docs-only*; CI path filter (ADR-021) bỏ qua job test.

## Changelog

- **0.1.0 (2026-06-10):** Bản thảo đầu — ADR-023 (quản trị tài liệu: `THUAT_NGU.md` + `BAN_DO_TAI_LIEU.md` + quy tắc "sửa đừng thêm" + dòng rà soát trong checklist phát hành), mở rộng ADR-002. Chờ duyệt.
