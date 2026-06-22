---
title: Vòng đời trạng thái ADR (một nguồn inline per-ADR, merge = Accepted) + guardrail máy-ép
version: 0.1.1
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Vòng đời trạng thái ADR

Chốt **một** quy ước trạng thái ADR và **máy-ép** nó, để trạng thái không còn lệch thực tế. Phát hiện khi đóng [`#339`](https://github.com/manhcuongdtbk/electric-water-management/issues/339): **15/17 spec đã merge & shipped vẫn để `status: draft (chờ duyệt)`** ở frontmatter và `**Trạng thái:** Proposed` inline — vì chuyển trạng thái cần một commit follow-up mà không ai nhớ làm. Đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép"). Bản thân tài liệu này là spec **đầu tiên** theo quy ước mới (dogfood): không có `status:` ở frontmatter, ADR-033 dưới đây ghi `**Trạng thái:** Accepted` ngay.

## Bối cảnh

Khảo sát `docs/superpowers/specs/*.md` (2026-06-13, 17 file):

- **Hai chỉ báo trạng thái song song**, không cái nào được duy trì sau merge:
  - **Inline `**Trạng thái:**`** trong khối ADR — `docs/superpowers/ADR-TEMPLATE.md` (dòng 8) định nghĩa lifecycle `Proposed → Accepted → (Superseded by ADR-XXX)`. Thực tế: **36 dòng** `**Trạng thái:** Proposed` còn nguyên, kể cả ADR đã chạy thật (ADR-024 doc-governance, ADR-012 CI spec).
  - **Frontmatter `status:`** — **KHÔNG có trong ADR-TEMPLATE** (quy ước copy ngầm spec-này-sang-spec-kia, không tài liệu nào định nghĩa). 15 file `draft (chờ duyệt)`, 1 file `approved` (TN3 — chỉ vì plan của nó script tường minh bước bump), 1 file không có field.
- Một spec có thể chứa **nhiều ADR** (release spec: ADR-003..011) ở các stage khác nhau → một `status:` doc-level **không** biểu diễn nổi; inline per-ADR mới đúng granularity.
- Nguyên nhân gốc: chuyển `Proposed → Accepted` là **commit follow-up thủ công** sau merge → không ai làm → kẹt draft.

Đây là vấn đề **toàn repo**; ADR-030/031/032 chỉ là ba trường hợp mới nhất. Triage (chủ dự án) đã chốt làm ngay (session-này), không `priority-high` lúc tạo #339; quy ước chốt qua brainstorm.

## Quyết định (ADR)

### ADR-033: Một nguồn sự thật inline per-ADR + "merge = Accepted" + guardrail máy-ép (mở rộng ADR-002)

- **Trạng thái:** Accepted · 2026-06-13 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail CI bash fail-loud), [ADR-007](2026-06-07-quy-trinh-release-design.md) (single-merger: merge là tín hiệu duyệt).
- **Bối cảnh:** xem trên — hai field song song không bảo trì được, kẹt 15/17 ở draft.
- **Quyết định:**
  1. **Một nguồn sự thật = inline per-ADR `**Trạng thái:**`** (`Proposed → Accepted → Superseded`, đúng ADR-TEMPLATE). **Bỏ** field `status:` ở frontmatter mọi spec. Lý do chọn inline: granular per-ADR (xử đúng spec nhiều ADR), được template bảo trợ; frontmatter `status:` vốn là quy ước ngầm không tài liệu hoá.
  2. **Merge = Accepted.** Tác giả ghi `**Trạng thái:** Accepted · <ngày>` **ngay trong PR** giới thiệu ADR — vì merge chính là hành động chấp nhận (single-merger, [ADR-007](2026-06-07-quy-trinh-release-design.md)). Không cần commit follow-up → hết stale.
  3. **`Proposed` chỉ cho quyết định CỐ Ý HOÃN**, ghi kèm marker Issue: `**Trạng thái:** Proposed (chờ quyết #<issue>)`. (Đường escape, song song pattern `DEFERRED #<số>` của [ADR-030](2026-06-13-truy-vet-chieu-test-design.md).)
  4. **Guardrail máy-ép** — script thứ 5 của job `doc-governance` (`check-adr-status.sh`, bash fail-loud) quét `docs/superpowers/specs/*.md`, hai luật:
     - **R1:** trong **khối frontmatter YAML** (giữa cặp `---` đầu file) **không** được có key `status:` (ép một-nguồn). Chỉ soi frontmatter — nhắc tới `status:` trong prose (thân bài) không tính.
     - **R2:** sau khi **bỏ code fence + span inline-code** (`` `...` ``) khỏi mỗi dòng (giống `check-doc-links.sh`), dòng còn lại khớp `**Trạng thái:**` theo sau là `Proposed` thì **phải** kèm deferred-marker `chờ quyết` + `#<số>` (đúng cụm `Proposed (chờ quyết #<issue>)`) — nếu không → đỏ. **Cố ý chặt:** một trích **provenance** kiểu `(Issue #N)` trên dòng `Proposed` **không** tính là hoãn (ADR đã merge dù dẫn Issue gốc vẫn phải `Accepted`) — nếu chỉ kiểm "có `#<số>`" thì một ADR đã merge mang `(Issue #N)` sẽ lọt. Việc bỏ inline-code khiến **ví dụ trong prose** (bắt buộc bọc backtick, ví dụ tài liệu này) **không** báo nhầm; chỉ dòng trạng thái ADR thật (`- **Trạng thái:** ...`, không bọc backtick) mới bị soi. Khớp đúng nhãn `**Trạng thái:**` (KHÔNG đụng `**Trạng thái khách:**` — trạng thái nghiệm thu khách, field khác).
     Chạy whole-tree mọi pull request (không cần baseline vì backfill làm xanh ngay trong PR này). **Quy ước kèm theo:** khi viết *về* trạng thái trong prose, bọc trong backtick (để R2 bỏ qua).
  5. **Backfill cùng PR:** mọi spec — bỏ `status:` frontmatter; lật mỗi inline `**Trạng thái:** Proposed` → `Accepted` (giữ ngày + ghi chú "mở rộng/supersede"); **rà từng dòng** — ADR nào thực sự còn hoãn thì để `Proposed (chờ quyết #<issue>)` thay vì Accepted. Mỗi spec sửa: bump version (PATCH) + 1 dòng changelog trỏ ADR-033 ([ADR-002](2026-06-07-sdlc-overview-design.md)).
- **Lý do:**
  - **Một nguồn inline**: bỏ field trùng dễ lệch; granular đúng spec nhiều ADR; theo template.
  - **Merge = Accepted (ghi sẵn trong PR)**: triệt **nguyên nhân gốc** (follow-up thủ công) thay vì lại dựa người nhớ; nhất quán [ADR-007](2026-06-07-quy-trinh-release-design.md) (merge = duyệt).
  - **Guardrail bash** (không cop): kiểm **văn bản markdown** → bash đúng công cụ, nhất quán [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md)/[ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (cop dành cho AST Ruby — [ADR-031](2026-06-13-dimension-review-tuan-agents-design.md)).
  - **Backfill whole-tree, không baseline**: khác guardrail i18n ([ADR-032](2026-06-13-guardrail-i18n-view-design.md)) — ở đó migration lớn nên grandfather; ở đây chỉ ~36 dòng/16 file, dọn sạch luôn rẻ hơn và đúng mong muốn (#339 muốn hết misleading).
- **Tradeoff:**
  - (+) Trạng thái ADR luôn khớp thực tế, máy chặn tái diễn; một field thay hai.
  - (+) Không commit follow-up sau merge.
  - (−) PR đang soạn-dở mà có ADR chưa quyết phải đánh `Proposed (chờ quyết #N)` nếu không sẽ đỏ — cố ý (đừng merge ADR chưa quyết âm thầm), nhưng là thay đổi nhỏ về thói quen.
  - (−) Backfill đụng ~16 file versioned (16 bump + changelog) — cơ học nhưng cần rà từng dòng (không sed mù).
  - (−) Thêm 1 script + 1 companion test bảo trì (nhỏ).
- **Phương án đã loại:**
  - *Giữ hai field, vai trò tách bạch* — loại: hai thứ phải maintain, dễ lệch ở spec nhiều ADR; frontmatter `status:` vốn không được template định nghĩa.
  - *Chỉ frontmatter `status:`* — loại: không biểu diễn được spec nhiều ADR khác stage; ngược template.
  - *Proposed → Accepted khi shipped (deploy)* — loại: deploy Mini PC thủ công/rời rạc → tái sinh follow-up friction.
  - *Hai bước thủ công (status quo)* — loại: chính nó gây kẹt 15/17.
  - *Convention-only, không guardrail* — loại: dựa kỷ luật người = đúng điểm yếu đã drift; luật này máy ép được (ADR-002).
  - *Backfill grandfather bằng baseline (kiểu ADR-032)* — loại: scope nhỏ (~36 dòng), dọn sạch rẻ hơn; #339 muốn hết misleading ngay.
- **Điều kiện xem lại:**
  - Nếu xuất hiện nhu cầu trạng thái ADR thứ ba ngoài `Proposed/Accepted/Superseded` → cập nhật template + R2.
  - Nếu R2 báo nhầm nhiều (ví dụ ADR hoãn hợp lệ bị quên marker) → rà lại định nghĩa deferred-marker.
  - Nếu thêm công cụ AI khác sinh ADR → đảm bảo chúng ghi `Accepted` theo quy ước (ánh xạ ở `CONTRIBUTING.md`).

## Thiết kế triển khai

Một pull request, nhánh `feature/adr-status-lifecycle` ← `develop`. Đụng `.github/` + `docs/**` → guardrail mới tự kiểm trên chính PR giới thiệu nó (sau backfill, whole-tree xanh).

### Tệp tạo mới
- `.github/scripts/check-adr-status.sh` — guardrail (R1 + R2). Bash thuần, `set -uo pipefail`, FAIL-LOUD. Comment tiếng Việt; output/echo **tiếng Anh** (output kỹ thuật cho CI).
- `.github/scripts/check-adr-status.test.sh` — companion người-chạy (fixture tạm), không wire CI. Ca: Accepted → xanh; Proposed không `#` → đỏ R2; `Proposed (chờ quyết #12)` → xanh; có frontmatter `status:` → đỏ R1; `**Trạng thái khách:**` không bị R2 đụng; cây sạch → xanh.

### Tệp sửa
- `.github/workflows/ci.yml` — thêm `check-adr-status.sh` vào bước "Document-governance guardrails" của job `doc-governance` (cùng `rc=1` aggregation như 4 script kia).
- `docs/superpowers/ADR-TEMPLATE.md` — sửa dòng hướng dẫn `**Trạng thái:**`: ghi `Accepted · <ngày>` khi merge (merge = duyệt); `Proposed (chờ quyết #<issue>)` chỉ khi cố ý hoãn; ghi rõ frontmatter **không** mang `status:` (một nguồn = inline). **File mẫu, không versioned.**
- `CONTRIBUTING.md` §8 — 1 đoạn "CI guardrail trạng thái ADR (ADR-033)" (kiểu các đoạn ADR-024/030/032). **File meta, không versioned.**
- **Backfill ~16 spec** — bỏ `status:` frontmatter; lật 36 dòng `Proposed → Accepted` (rà từng dòng cho hoãn-thật); mỗi spec bump version (PATCH) + 1 dòng changelog trỏ ADR-033.

### Không đụng (cố ý)
- 3 dòng `**Trạng thái khách:**` (TN1/TN2/TN3) — trạng thái nghiệm thu khách, không phải lifecycle ADR.
- Không formal-hoá toàn bộ schema frontmatter (YAGNI) — chỉ bỏ `status:`.

## Kiểm thử

Theo kiểu ADR-024/030/032:
- **Companion `.test.sh`** (người chạy): các ca R1/R2 ở trên.
- **Kiểm chứng cây thật**: sau backfill → script **xanh** whole-tree; chèn một spec-fixture có `**Trạng thái:** Proposed` không `#` → **đỏ R2**; thêm `status:` vào frontmatter một spec → **đỏ R1**; hoàn nguyên → xanh.
- 4 script doc-governance hiện có vẫn xanh. `bin/docker rspec` không liên quan (không đụng app/spec).

## Giới hạn (không phóng đại "đảm bảo")

Guardrail **chỉ** đảm bảo: trong `docs/superpowers/specs/*.md`, không có frontmatter `status:` (R1) và không có inline `**Trạng thái:** Proposed` thiếu `#<số>` (R2). **KHÔNG** đảm bảo:
1. **ADR thực sự đã được suy xét/duyệt kỹ** — R2 chỉ ép cú pháp trạng thái, không phán nội dung; duyệt là gate người (ADR-007).
2. **Mọi ADR đều có dòng `**Trạng thái:**`** — guardrail không ép sự *hiện diện* (ADR cũ thiếu dòng sẽ không bị bắt); chỉ ép dòng *đã có* đúng luật. (Backfill không thêm dòng còn thiếu — ngoài scope.)
3. **`Accepted` ghi đúng "đã merge"** — tác giả ghi tay; nếu PR bị đóng không merge, spec không vào develop nên không tồn tại để sai.
4. **Trạng thái nghiệm thu khách** (`Trạng thái khách`) — field khác, ngoài phạm vi.

## Truy vết

- **Issue:** [`#339`](https://github.com/manhcuongdtbk/electric-water-management/issues/339) (`documentation`, `needs-design`) → **`Closes #339`** (đây là toàn bộ nội dung #339). Không `priority-high`; milestone do chủ dự án gán.
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-007](2026-06-07-quy-trinh-release-design.md) (merge = duyệt), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail bash), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (deferred-marker `#<số>`), [ADR-032](2026-06-13-guardrail-i18n-view-design.md) (whole-tree vs baseline — ở đây chọn whole-tree).
- **Test:** companion `check-adr-status.test.sh` + kiểm chứng đỏ/xanh cây thật (ghi trong plan).

## Lịch sử thay đổi

- **0.1.1 (2026-06-13):** Chặt R2 (phát hiện lúc triển khai): deferred-marker hợp lệ phải là cụm `chờ quyết` + `#<số>`, KHÔNG nhận provenance `(Issue #N)`. Lý do: ADR-028 (`truy-vet-quan-ly-thay-doi`) ghi `Proposed · ... (Issue #320)` — đã merge (#323) nhưng dẫn Issue gốc; luật cũ "có `#<số>`" để nó lọt thành "hoãn". Sửa: guardrail + companion (case provenance → đỏ) + backfill lật ADR-028 sang `Accepted`.
- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-033 (vòng đời trạng thái ADR). Một nguồn = inline per-ADR `**Trạng thái:**` (bỏ frontmatter `status:`); merge = Accepted (ghi sẵn trong PR); `Proposed` chỉ khi hoãn kèm `#<issue>`; guardrail `check-adr-status.sh` (R1 không-frontmatter-status, R2 Proposed-phải-có-#) là script thứ 5 của `doc-governance`; backfill ~36 dòng/16 spec (rà từng dòng) + bump version. Dogfood: spec này theo quy ước mới ngay. Loại: hai-field-tách-vai, chỉ-frontmatter, Accepted-khi-shipped, hai-bước-thủ-công, convention-only, backfill-grandfather. Chờ duyệt.
