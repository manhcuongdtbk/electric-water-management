---
title: Chống trùng số ADR giữa các nhánh/session song song — guardrail máy-ép + dọn một lần
version: 0.1.0
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Chống trùng số ADR

Chốt một guardrail **máy-ép** để hai spec không thể mang **cùng một số ADR**, và **dọn một lần** các trùng đang tồn tại. Phát hiện khi xử lý [`#342`](https://github.com/manhcuongdtbk/electric-water-management/issues/342): hai session/nhánh chạy song song cùng tạo ADR mới đều đọc "số lớn nhất trên `develop`" rồi cùng `+1` → **trùng số**, mà số của nhánh kia chưa merge nên vô hình cho tới lúc gộp. Đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép"). Bản thân tài liệu này dogfood vấn đề: số ADR của nó (046) được chọn sau khi kiểm cả `develop` lẫn nhánh/PR đang mở (xem mục "Chọn số" dưới).

## Bối cảnh

Quy ước hiện tại — `docs/superpowers/ADR-TEMPLATE.md` (dòng 3): *"ADR đánh **số toàn cục, tăng dần** (số mới nhất: xem spec gần nhất)."* Cách lấy số kế tiếp = đọc số ADR lớn nhất rồi `+1`. Khi **≥2 nhánh/session song song** cùng thao tác, cả hai chọn cùng một `+1` → trùng. Phụ thuộc người nhớ kiểm trước khi đặt số.

Đây **không** phải rủi ro giả định — khảo sát `docs/superpowers/specs/*.md` (2026-06-13):

- **Trùng đã có sẵn trong `develop` (merged) — nhiều hơn issue ghi.** Issue [`#348`](https://github.com/manhcuongdtbk/electric-water-management/issues/348) nêu `ADR-003`/`ADR-004`. Quét lại bằng regex bắt **cả hai cấp heading** (`## ADR-NNN` *và* `### ADR-NNN`) cho thấy **toàn bộ khối ADR đầu** của `2026-06-07-app-version-reporting-design.md` trùng — bốn số `ADR-001..004`:

  | Số | `app-version-reporting` (kẻ chiếm) | Nơi canonical đúng |
  |---|---|---|
  | ADR-001 | Vị trí hiển thị phiên bản (l.75, `###`) | `sdlc-overview` — Mô hình phát triển (l.15, `##`) |
  | ADR-002 | Dạng endpoint trả phiên bản (l.86, `###`) | `sdlc-overview` — Chiến lược tài liệu (l.35, `##`) |
  | ADR-003 | Nhãn môi trường (l.95, `###`) | `quy-trinh-release` — Git Flow (l.65, `###`) |
  | ADR-004 | Cách gắn version vào log (l.103, `###`) | `quy-trinh-release` — SemVer (l.74, `###`) |

  Một lần quét **chỉ `###`** (bỏ sót `##`) sẽ **không thấy** trùng ADR-001/002 — chính lỗ hổng đó đã che hai trùng này khỏi mắt thường. Đây là yêu cầu đúng-đắn cốt lõi của detector: phải bắt **cả hai cấp heading**.
- **`#343` (demo automation, PR [#347](https://github.com/manhcuongdtbk/electric-water-management/pull/347) đang draft):** session đó phải **đánh số lại ADR sang 036..041** thủ công để né trùng ADR-034 (#328) và ADR-035 (#346) — phát hiện và sửa bằng tay.

Hệ quả: bản ghi canonical mâu thuẫn (một mã ADR trỏ hai quyết định), tham chiếu chéo `[ADR-00X](...)` nhập nhằng. Thuần tooling/quy ước tài liệu (giống #339/#342), **không** đụng nghiệp vụ. Triage (chủ dự án) đã chốt **milestone 1.2.0, không `priority-high`** (session này) — cùng cụm process-hardening #339/#342; quy ước chốt qua brainstorm.

### Chọn số (dogfood — quy trình này là "ca thử" của chính nó)

"Số an toàn kế tiếp" **không** phải chỉ đọc `develop`. Trên `develop` số cao nhất = **ADR-035**, NHƯNG nhánh `feature/tu-dong-hoa-demo` (PR #347, draft) đã **giữ 036..041**. Vậy phải kiểm **cả nhánh/PR đang mở** trước khi đặt:

- `develop` max = 035; PR #347 (mở) giữ 036..041 → khoảng an toàn bắt đầu từ **042**.
- **Dọn một lần** tiêu thụ **042..045** (bốn ADR của `app-version-reporting`).
- **ADR của chính tài liệu này = 046.**

## Quyết định (ADR)

### ADR-046: Guardrail CI chống trùng số ADR (bắt cả `##`/`###`) + dọn một lần bằng renumber khối `app-version-reporting`

- **Trạng thái:** Accepted · 2026-06-13 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail CI bash fail-loud), [ADR-007](2026-06-07-quy-trinh-release-design.md) (single-merger: nhánh gộp sau renumber để né trùng).
- **Bối cảnh:** xem trên — cách "đọc max rồi +1" va chạm khi nhánh song song; bốn trùng `ADR-001..004` đã lọt vào `develop`; `##`/`###` lẫn lộn che trùng khỏi quét ngây thơ.
- **Quyết định:**
  1. **Detector máy-ép (A)** — script **mới** `.github/scripts/check-adr-numbering.sh`, script thứ **7** của job `doc-governance` (bash thuần, `set -uo pipefail`, FAIL-LOUD). Quét `docs/superpowers/specs/*.md`:
     - Nhận một dòng là **định nghĩa ADR** nếu khớp `^#{2,3} ADR-[0-9]{3}` — **cả `##` lẫn `###`** (đây là điểm mấu chốt; chỉ `###` sẽ bỏ sót). Bỏ **code fence** trước khi soi (giống `check-doc-links.sh`/`check-adr-status.sh`) để ví dụ trong fence không bị tính.
     - **Luật:** mỗi số `ADR-NNN` chỉ được xuất hiện ở **tối đa một dòng định nghĩa** trên toàn cây spec. Số nào xuất hiện ở ≥2 dòng (kể cả hai file khác nhau **hoặc** lặp trong cùng file) → liệt kê các file + exit 1.
     - **Script riêng, không nhập vào `check-adr-status.sh`:** một-script-một-mối-lo (đánh-số-duy-nhất ≠ vòng-đời-trạng-thái), khớp grain `check-test-dimensions`/`check-adr-status`/`check-changelog-header`.
  2. **Companion `check-adr-numbering.test.sh`** (người chạy, fixture tạm, không wire CI). Ca: cây sạch → xanh; **cùng số ở hai file → đỏ**; **trùng `##` ↔ `###` (chính bug ADR-001/002) vẫn bị bắt**; ví dụ trong code fence **không** bị tính; cùng số lặp trong một file → đỏ.
  3. **Dọn một lần (B)** — renumber **toàn bộ khối ADR của `2026-06-07-app-version-reporting-design.md`** (bộ rẻ nhất: tham chiếu **chỉ nội bộ**, blast radius ngoài file = 0):
     `ADR-001 → 042`, `ADR-002 → 043`, `ADR-003 → 044`, `ADR-004 → 045` (cả 4 heading + 2 tham chiếu nội bộ l.41 `(xem ADR-003)→044`, l.46 `(xem ADR-004)→045`). Bump version spec đó (PATCH) + 1 dòng changelog trỏ ADR-046 ([ADR-002](2026-06-07-sdlc-overview-design.md)).
  4. **Va chạm nhánh song song bắt tại cổng merge** — không cần cơ chế cấp-số mới. Khi nhánh sau cập-nhật-`develop`-trước-khi-push (đã có guardrail branch-behind-base) rồi mở/đồng-bộ PR, CI chạy `check-adr-numbering.sh` whole-tree thấy cả hai định nghĩa → đỏ; **single-merger** ([ADR-007](2026-06-07-quy-trinh-release-design.md)) renumber nhánh gộp sau. Detector + quy trình sẵn có đã đủ.
  5. **Nhắc tại điểm dùng** — thêm một dòng vào `docs/superpowers/ADR-TEMPLATE.md`: trùng số nay bị `check-adr-numbering` bắt, **vẫn nên** kiểm nhánh/PR đang mở (không chỉ `develop`) trước khi đặt số. **File mẫu, không versioned.**
- **Lý do:**
  - **Detector bash** (không cop): kiểm **văn bản markdown** → bash đúng công cụ, nhất quán [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md)/[ADR-030](2026-06-13-truy-vet-chieu-test-design.md); tái dùng đúng pattern dup-detect của `check-test-dimensions.sh` (đụng tên anchor ở >1 spec).
  - **Renumber `app-version-reporting`, không phải bộ release/sdlc**: bộ đó tham chiếu **chỉ nội bộ** (2 dòng), trong khi `ADR-001..004` bản release/sdlc bị trích hàng chục lần ở `AGENTS.md`/`CONTRIBUTING.md`/plan/spec → chọn bộ rẻ nhất, blast radius ngoài file = 0.
  - **Không sổ đăng ký số (loại C)**: detector + branch-behind-base + single-merger đã khoá đúng chỗ; sổ đăng ký/ID phái sinh nặng và lệch quy ước "tăng dần toàn cục".
  - **Whole-tree, không baseline**: dọn 4 ADR/1 file làm cây xanh ngay trong PR này — rẻ hơn grandfather (khác ADR-032 migration lớn).
- **Tradeoff:**
  - (+) Trùng số ADR không thể lọt im (cả trùng hiện tại lẫn va chạm song song khi nhánh sau đồng bộ `develop`); một field thay cho "người nhớ".
  - (+) Detector tự kiểm trên chính PR giới thiệu nó (sau dọn, whole-tree xanh).
  - (−) Bốn ADR `app-version-reporting` mang số (042..045) **lệch thứ tự thời gian** với ngày tạo (2026-06-07) — chấp nhận: số toàn cục theo *thứ tự cấp phát*, đây là hành động sửa lỗi, có changelog ghi rõ.
  - (−) Thêm 1 script + 1 companion test bảo trì (nhỏ).
- **Phương án đã loại:**
  - *Renumber bộ release/sdlc thay vì `app-version-reporting`* — loại: blast radius hàng chục tham chiếu chéo (AGENTS.md "ADR-003..011", CONTRIBUTING, plan…), rủi ro sót cao.
  - *Chỉ dọn (B), không guardrail* — loại: không chặn va chạm song song kế tiếp = đúng gốc vấn đề.
  - *Chỉ guardrail (A), không dọn* — loại: detector sẽ đỏ ngay trên `develop` trừ khi grandfather; vô lý khi dọn chỉ 1 file.
  - *Nhập detector vào `check-adr-status.sh` (R3)* — loại: trộn hai mối lo (trạng thái vs đánh số) trong một script/một test, ngược grain một-script-một-mối-lo.
  - *Sổ đăng ký số / ID phái sinh Issue-PR (C)* — loại: nặng, lệch quy ước tăng-dần; merge-gate đã đủ.
  - *Detector chỉ quét `###`* — loại: bỏ sót `## ADR-NNN` (đúng lỗ hổng che ADR-001/002).
- **Điều kiện xem lại:**
  - Nếu chuyển sang ADR **một-file-một-ADR** (mỗi quyết định một file) → số suy ra từ tên file, detector đổi cách quét.
  - Nếu detector báo nhầm (ví dụ thêm cú pháp heading ADR mới) → rà lại regex `^#{2,3} ADR-`.
  - Nếu va chạm song song vẫn lọt dù có guardrail (nhánh không đồng bộ `develop` trước merge) → cân nhắc siết branch-behind-base hoặc bậc-thang sổ đăng ký (C).

## Thiết kế triển khai

Một pull request, nhánh `ci/adr-numbering-collision-guardrail` ← `develop`. Đụng `.github/` + `docs/**` → guardrail mới tự kiểm trên chính PR giới thiệu nó (sau dọn, whole-tree xanh). Commit dạng `ci` (không ảnh hưởng SemVer app).

### Tệp tạo mới
- `docs/superpowers/specs/2026-06-13-adr-numbering-collision-design.md` — tài liệu này (ADR-046).
- `.github/scripts/check-adr-numbering.sh` — detector. Bash thuần, `set -uo pipefail`, FAIL-LOUD. Comment tiếng Việt; output/echo **tiếng Anh** (output kỹ thuật cho CI). Tham số 1 = thư mục spec (mặc định `docs/superpowers/specs`) để test trỏ fixture tạm.
- `.github/scripts/check-adr-numbering.test.sh` — companion người-chạy (fixture tạm), không wire CI. Các ca ở ADR-046 mục 2.

### Tệp sửa
- `.github/workflows/ci.yml` — thêm `bash .github/scripts/check-adr-numbering.sh || rc=1` vào bước "Document-governance guardrails" của job `doc-governance` (cùng `rc` aggregation như 6 script kia); thêm "ADR numbering" vào `name:` của job.
- `docs/superpowers/specs/2026-06-07-app-version-reporting-design.md` — renumber `ADR-001..004 → 042..045` (4 heading + 2 ref nội bộ l.41/l.46); bump `version: 0.8.1 → 0.8.2` + 1 dòng changelog trỏ ADR-046.
- `docs/superpowers/ADR-TEMPLATE.md` — thêm dòng nhắc (detector bắt trùng; vẫn kiểm nhánh/PR mở trước khi đặt số). **File mẫu, không versioned.**
- `CONTRIBUTING.md` §8 — 1 đoạn "CI guardrail chống trùng số ADR (ADR-046)" (kiểu các đoạn ADR-024/030/032/033). **File meta, không versioned.**

### Không đụng (cố ý)
- Bộ ADR-001..004 bản release/sdlc — đúng nơi canonical, giữ nguyên.
- Không formal-hoá schema số ADR ngoài "duy nhất + cả hai cấp heading" (YAGNI).

## Kiểm thử

Theo kiểu ADR-024/030/032/033:
- **Companion `.test.sh`** (người chạy): các ca cây-sạch→xanh; trùng-hai-file→đỏ; **trùng `##`↔`###`→đỏ**; ví-dụ-trong-fence→không tính; trùng-trong-một-file→đỏ.
- **Kiểm chứng cây thật**: sau dọn → `check-adr-numbering.sh` **xanh** whole-tree; tạm thêm một spec-fixture trùng số → **đỏ**; hoàn nguyên → xanh.
- 6 script doc-governance hiện có vẫn xanh. `bin/docker rspec` không liên quan (không đụng app/spec).

## Giới hạn (không phóng đại "đảm bảo")

Guardrail **chỉ** đảm bảo: trong `docs/superpowers/specs/*.md` (ngoài code fence), không số `ADR-NNN` nào xuất hiện ở >1 dòng định nghĩa heading `##`/`###`. **KHÔNG** đảm bảo:
1. **Va chạm song song bị bắt nếu nhánh sau không đồng bộ `develop` trước khi merge** — detector chạy whole-tree theo checkout của PR; chỉ thấy trùng khi cả hai định nghĩa cùng có mặt (tức nhánh sau đã rebase/merge `develop`). Khoá thực tế dựa branch-behind-base + single-merger ([ADR-007](2026-06-07-quy-trinh-release-design.md)).
2. **ADR được đánh số đúng "kế tiếp"** — detector chỉ ép *duy-nhất*, không ép *liên tục/không-gap* (gap hợp lệ: 036..041 do #347 giữ).
3. **Nội dung ADR đúng/đã duyệt** — duyệt là gate người (ADR-007).
4. **Tham chiếu chéo `[ADR-NNN](...)` trỏ đúng** — ngoài phạm vi detector (việc của `check-doc-links.sh`/người rà).

## Truy vết

- **Issue:** [`#348`](https://github.com/manhcuongdtbk/electric-water-management/issues/348) (`change-request`, `needs-design`) → **`Closes #348`** (đây là toàn bộ nội dung #348). Milestone **1.2.0**, **không** `priority-high` (triage chủ dự án, session này). Phát hiện thêm (ngoài 003/004 issue ghi): ADR-001/002 cũng trùng — gộp vào cùng fix.
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-007](2026-06-07-quy-trinh-release-design.md) (single-merger), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail bash), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (dup-detect anchor ở >1 spec — mẫu gần nhất), [ADR-033](2026-06-13-trang-thai-adr-lifecycle-design.md) (cùng quét heading ADR; tách concern).
- **Test:** companion `check-adr-numbering.test.sh` + kiểm chứng đỏ/xanh cây thật (ghi trong plan).

## Lịch sử thay đổi

- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-046 (chống trùng số ADR). Detector `check-adr-numbering.sh` (script thứ 7 `doc-governance`) bắt số trùng ở >1 heading `##`/`###`, bỏ code fence; dọn một lần renumber khối `app-version-reporting` `ADR-001..004 → 042..045` (bộ rẻ nhất, blast radius ngoài file = 0); va chạm song song bắt tại cổng merge (branch-behind-base + single-merger), không sổ đăng ký. Chọn số dogfood: develop max 035, PR #347 giữ 036..041 → dọn lấy 042..045, ADR này lấy 046. Phát hiện thêm ADR-001/002 trùng ngoài 003/004 issue ghi. Loại: renumber-bộ-release, chỉ-dọn, chỉ-guardrail, nhập-vào-check-adr-status, sổ-đăng-ký, detector-chỉ-`###`.
