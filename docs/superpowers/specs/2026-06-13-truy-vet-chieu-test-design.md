---
title: CI gate truy vết chiều test ↔ test (anchor CHIEU-<slug>, đối chiếu bảng spec với test)
version: 0.1.2
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# CI gate truy vết chiều test ↔ test

Biến luật **"test mọi output + cả 6 vai trò + theo chiều test của spec"** (AGENTS) từ **kỷ luật/trí nhớ** thành **luật máy ép được**, đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép; đừng viết prose rồi mong người nhớ"). Đây là **kích hoạt đường nâng cấp đã được [ADR-015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) tiên liệu** ("Điều kiện xem lại: cần CI chặn yêu cầu thiếu test → khi đó mới gắn tag vào test + viết script đối chiếu anchor trong tài liệu với tag"), áp cho **chiều test** thay vì yêu cầu nghiệp vụ. Tái dùng nguyên pattern guardrail bash native fail-loud của [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (job `doc-governance`). Truy vết: GitHub Issue [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329).

## Bối cảnh

Retro TN1 (#327) và phiên TN3 (#331/#333) lộ một **failure mode lặp lại** mà tự kỷ luật không chặn được:

- **Hạ một chiều test của spec xuống "optional"** vì cho là "phủ gián tiếp" (ví dụ khu-vực-trống trên billing) — gap bị **im lặng hoãn** thay vì hỏi gate.
- **Phủ thiếu vai trò** dù luật "6 vai trò" (billing A/B/C ban đầu chỉ 3 vai trò).
- **Test gọi service trực tiếp** thay vì đi qua action người dùng bấm (POST `recalculate`).
- **Doc current-state lỗi thời** sau merge (`V2_CHIEU_TEST.md` ghi "chưa triển khai" khi đã merge).

Điểm chung: **người làm phải tự nhớ áp luật** — đúng cái ADR-002 dạy phải tránh. Có **một dạng drift đo được bằng máy, không nhập nhằng**: một chiều test **được spec tuyên bố** mà **không có test** nào hiện thực, và lại **không được hoãn tường minh** (không trỏ Issue). Đây là phần khả thi để máy ép.

> **Cái KHÔNG kiểm được bằng máy (để "Giới hạn"):** (1) một chiều test **đáng-lẽ-phải-có nhưng chưa ai khai vào bảng** — máy không suy ra được "spec này lẽ ra cần chiều X"; (2) test "đi qua action thật, không gọi service trực tiếp"; (3) prose current-state ("chưa triển khai") còn đúng với hiện trạng không. (2) và (3) là các lớp phụ của #329, **ngoài phạm vi** ADR này (xem "Giới hạn").

ADR-014 cố ý **không** nhúng mã `NV-...` vào test ("0 churn test") khi chỉ cần truy vết. Nhưng để **chặn-bằng-CI**, ADR-015 đã chốt sẵn đánh đổi: khi muốn ép thì **chấp nhận** gắn mã vào test + script đối chiếu. ADR này thực thi đúng đánh đổi đó cho chiều test.

## ADR-030: CI gate truy vết chiều test ↔ test bằng anchor `CHIEU-<slug>` (mở rộng ADR-002/015/024)

- **Trạng thái:** Accepted · 2026-06-13 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md), [ADR-015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md).
- **Bối cảnh:** xem trên.
- **Quyết định:**

  **(1) Anchor `CHIEU-<slug>` — song song `NV-<slug>`.** Mỗi chiều test có một mã định danh `CHIEU-<slug>` ("CHIEU" = chiều test). Slug **không dấu, theo chủ đề** (ví dụ `CHIEU-ton-hao-chua-tinh`), **globally unique**, định nghĩa trong `docs/THUAT_NGU.md` cạnh hàng Anchor (`NV-...`). Đặt cạnh `NV-` để dùng chung trực giác, không thêm convention lạ.

  **(2) Bảng truy vết trong spec** (in-scope = **opt-in bằng việc có bảng**). Spec tính năng kết phần chiều test bằng **một bảng** thay cho danh sách gạch đầu dòng, dưới heading chuẩn `## Truy vết chiều test`:

  ```
  ## Truy vết chiều test
  | Mã | Chiều test (mô tả) | Trạng thái |
  |---|---|---|
  | `CHIEU-ton-hao-chua-tinh` | Chưa bấm tính → hai cột trống | có test |
  | `CHIEU-ton-hao-sau-tinh`  | Sau tính → cột đúng `meter_losses` | có test |
  | `CHIEU-phan-bo-tram-regression` | Kỳ cũ gộp khu vực không đổi | DEFERRED #319 |
  ```

  Trạng thái một hàng chỉ có **hai loại** theo máy: **DEFERRED** (cell khớp `DEFERRED` kèm `#<số>`) hoặc **mặc định "phải có test"** (mọi cell khác; chữ "có test" chỉ để người đọc).

  **(3) Test mang anchor ở chuỗi mô tả** `it`/`describe`: `it "CHIEU-ton-hao-chua-tinh: hai cột trống khi chưa tính"`. Một test phủ nhiều chiều → nhiều anchor trong mô tả. Greppable trần, lộ ngay trong output CI (giúp người thấy độ phủ), khớp đề xuất gốc của #329.

  **(4) Script `check-test-dimensions.sh`** — **script thứ tư** của job `doc-governance` (fail-loud, hard-fail, chạy trên MỌI pull request). Đối chiếu mọi bảng spec với `grep` cây `spec/`:
  - hàng **không-DEFERRED** mà **không** test nào nhắc anchor → **đỏ** ("thiếu test").
  - hàng **DEFERRED** mà cell trạng thái **không** có `#<số>` → **đỏ** ("hoãn không trỏ Issue").
  - anchor `CHIEU-` xuất hiện trong `spec/` mà **không** có trong bảng spec nào → **đỏ** (typo/orphan).
  - cùng một anchor `CHIEU-` ở **hai** bảng spec khác nhau → **đỏ** (đụng tên, phá tính unique).

  Chạy trên **mọi** pull request (không gate qua job `changes`) là **bản chất**: job `tests` bị skip khi pull request docs-only, nên một spec **âm thầm bỏ một chiều test** (chỉ sửa `.md`) vẫn bị bắt. Không cần Postgres/boot app.

  **Trục quyết định kèm theo:**
  - **Hard-fail (đỏ)** cho mọi vi phạm — nhất quán với 3 script `doc-governance` sẵn có; đỏ là *tín hiệu* (repo private, ADR-007), kỷ luật một-người-merge tôn trọng. (Đã chọn blocking thay vì warning: cả tiền đề #329 là "tự kỷ luật không đủ — cần máy ÉP"; warning bỏ qua được = cùng failure mode.)
  - **Fail-loud:** lỗi nội bộ script → exit khác 0; mỗi vi phạm in `spec + anchor + lý do`.
  - **Portable bash:** `set -uo pipefail`, `while IFS= read` (không `mapfile` — macOS bash 3.2), khớp các `check-*.sh` hiện có.

- **Lý do:**
  - Dạng drift "chiều đã tuyên bố mà thiếu test, không hoãn tường minh" **đo được chắc chắn** → ép bằng máy đúng ADR-002, mạnh hơn "mong nhớ".
  - `CHIEU-<slug>` song song `NV-<slug>`: 0 convention mới, slug bền khi đánh số lại spec, unique theo chủ đề → giải luôn hai câu hỏi mở của #329 ("chuẩn hoá mã cho nhiều spec" + "tự sinh hay viết tay": **bảng viết tay** khai *ý định*, test mang anchor, script đối chiếu — đúng path ADR-015).
  - **Bảng phải viết tay, không tự sinh từ tên test:** muốn bắt chiều **bị bỏ âm thầm** thì tập chiều-bắt-buộc phải khai **độc lập với test**. Nếu test là nguồn duy nhất, bỏ một chiều = bỏ luôn cả test lẫn khai báo → không gì bắt được. Bảng tay **chính là** cơ chế, không phải gánh nặng cần tự-động-hoá đi.
  - Job chạy luôn vì guardrail cần nhất đúng lúc pull request **chỉ sửa spec** (docs-only).
- **Tradeoff:**
  - (+) Đảm bảo cơ học: chiều đã khai có test hoặc hoãn-có-Issue; chống "âm thầm hạ optional"; nhanh (bash thuần); không false-positive (chỉ đối chiếu token tường minh).
  - (−) **Không** tự bắt chiều *đáng-lẽ-phải-có nhưng chưa ai khai* (cổng "phải có bảng" vẫn là review người + template) — nêu rõ ở "Giới hạn".
  - (−) Churn test: gắn anchor vào mô tả test (retrofit milestone 1.2.0) — chấp nhận đúng đánh đổi ADR-015 (ép thì phải gắn mã).
  - (−) Thêm 1 script + 1 gloss `CHIEU-` trong `THUAT_NGU.md` để bảo trì; nhỏ.
- **Phương án đã loại:**
  - *Tự sinh bảng từ tên test* — loại: phá mục tiêu (không bắt được chiều bị bỏ âm thầm; xem "Lý do").
  - *RSpec metadata tag (`ct: "..."`) thay vì mô tả* — loại (v1): mã ẩn khỏi output test, lợi ích formatter chưa cần (YAGNI); mô tả-trần đủ greppable và minh bạch hơn. Để "Điều kiện xem lại".
  - *Chỉ cảnh báo, không đỏ* — loại: yếu "đảm bảo", trái tiền đề #329.
  - *Mã số ngắn (`D5`, `TN3-D5`)* — loại: đụng luật no-abbrev (AGENTS), cần registry, đọc khó; slug chủ đề bền + tự diễn giải.
  - *Bảng tập trung ở `V2_CHIEU_TEST.md`* — loại: spec là nơi chiều test ra đời; `V2_CHIEU_TEST.md` giữ vai trò catalog 12 chiều khái niệm + trỏ tới bảng `CHIEU-` của từng spec (một fact một nơi).
- **Điều kiện xem lại:** cần formatter/coverage-report theo chiều → chuyển/bổ sung sang RSpec tag. Số anchor `CHIEU-` lớn tới mức khó quản → cân nhắc mục "Danh mục mã chiều test" tự sinh (song song gợi ý ADR-015 cho `NV-`).

## Thiết kế triển khai

Một pull request, nhánh `feature/ci-gate-truy-vet-chieu-test` ← `develop`. **Đụng code** (`.github/**`) → CI chạy **full** → guardrail mới tự kiểm chính nó trên pull request giới thiệu nó.

### Tệp tạo mới (code/data — KHÔNG versioned theo ADR-002)
- `.github/scripts/check-test-dimensions.sh` — bash native, `set -uo pipefail`, `while read` (không `mapfile`), comment tiếng Việt + ref ADR-030, in vi phạm rõ ràng, exit khác 0 khi vi phạm hoặc lỗi nội bộ.

### Tệp sửa
- `.github/workflows/ci.yml` — thêm `check-test-dimensions.sh` vào step của job `doc-governance` (gom vào `rc`, không dừng ở lỗi đầu); đổi nhãn `name:` của job cho gồm "test dimensions".
- `docs/THUAT_NGU.md` — thêm hàng gloss "Anchor chiều test" (`CHIEU-<slug>`) cạnh hàng Anchor (`NV-...`). **Bump version + changelog.** (Không đăng ký term mới vào `.github/dictionaries/glossary-terms.txt` — song song với `NV-` vốn không phải term đăng ký; khái niệm "anchor" đã được guardrail bảo vệ.)
- `docs/V2_CHIEU_TEST.md` — một dòng: chiều test per-tính-năng sống ở bảng `## Truy vết chiều test` (anchor `CHIEU-`) của spec; doc này giữ 12 chiều khái niệm + trỏ tới spec. **Bump version + changelog.**
- `CONTRIBUTING.md` mục 8 (tự động hoá) + mục 9 (truy vết): mô tả convention `CHIEU-` + yêu cầu plan/PR (không version — file meta).
- `.github/pull_request_template.md` — một dòng checklist: "mỗi chiều test của spec → một hàng `CHIEU-` (có test hoặc DEFERRED #issue)".
- **Retrofit milestone 1.2.0 (chứng minh end-to-end trên data thật):**
  - TN1 ([`2026-06-11-cot-khac-he-so-don-vi-design.md`](2026-06-11-cot-khac-he-so-don-vi-design.md)) + TN3 ([`2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`](2026-06-11-hien-thi-chi-tiet-ton-hao-design.md)): đổi danh sách chiều test → bảng `CHIEU-`; gắn anchor vào **mô tả các test sẵn có** tương ứng (CI xanh trên data thật). Bump version + changelog mỗi spec.
  - TN2 ([`2026-06-11-phan-bo-bom-theo-tram-design.md`](2026-06-11-phan-bo-bom-theo-tram-design.md), **chưa triển khai**): bảng `CHIEU-` với mọi hàng **`DEFERRED #319`** — ví dụ worked-example cho nhánh hoãn. Bump version + changelog.

### Kiểm thử (bash CI script — parity với script hiện có, repo không có framework test bash)
Theo đúng pattern ADR-024: chạy script trên cây repo sau retrofit = **pass**. Rồi tạo vi phạm cố ý tạm thời, xác nhận **fail đúng + thông báo đúng**, hoàn nguyên: (a) xóa anchor khỏi một test của hàng không-DEFERRED → "thiếu test"; (b) đổi một hàng DEFERRED bỏ `#<số>` → "hoãn không trỏ Issue"; (c) thêm `CHIEU-khong-co-trong-bang` vào một test → "orphan"; (d) lặp một anchor sang bảng spec thứ hai → "đụng tên". Plan ghi từng bước fixture.

## Giới hạn (không phóng đại "đảm bảo")

ADR này chỉ ép phần **cơ học, không nhập nhằng**: chiều **đã khai trong bảng** có test hoặc hoãn-có-Issue; anchor không orphan, không đụng tên. **KHÔNG** đảm bảo:
1. **Chiều đáng-lẽ-phải-có nhưng chưa ai khai vào bảng** — máy không suy ra được. Cổng "spec phải có bảng + bảng phải đủ chiều" vẫn là **review người** (checklist plan/PR + 2 luật AGENTS mọi-output/6-vai-trò). Backstop một phần: hễ test dùng anchor `CHIEU-` thì luật orphan ép bảng phải tồn tại; template plan (writing-plans) ép map mỗi chiều spec → một hàng.
2. **Test "đi qua action thật, không gọi service trực tiếp"** — lớp phụ #329 (review-convention), **ngoài phạm vi**, follow-up.
3. **Prose current-state ("chưa triển khai") còn đúng không** — lớp phụ #329, khó, dễ false-positive (như quét-prose ở ADR-024 đã loại), **ngoài phạm vi**, follow-up.

Mạnh nhất vẫn là construct **tự-không-lỗi-thời**: trạng thái đích của một chiều sống trong bảng `CHIEU-` (máy canh), không nằm rải rác ở prose current-state.

## Truy vết

- **Issue:** [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329) (`enhancement`) — **`Refs #329`** ở pull request, **không** `Closes`: #329 có 3 mục, ADR này chỉ làm mục "truy vết chiều test ↔ test"; hai mục còn lại (guardrail i18n; dimension review tuân AGENTS) là follow-up riêng.
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-015](2026-06-08-truy-vet-quan-ly-thay-doi-design.md) (đường nâng cấp "CI chặn thiếu test + gắn mã vào test" mà ADR này kích hoạt), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern job `doc-governance` bash native fail-loud).
- **Test:** `check-test-dimensions.sh` tự-kiểm trên chính pull request giới thiệu nó (đụng `.github/**` → CI full) trên các bảng `CHIEU-` retrofit milestone 1.2.0; kèm fixture vi phạm cố ý trong plan.

## Lịch sử thay đổi

- **0.1.2 (2026-06-13):** Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.
- **0.1.1 (2026-06-13):** Đổi tiền tố anchor `CT-` → `CHIEU-` (viết đủ chữ "chiều") sau khi triển khai phát hiện `CT-` đã được dùng làm **tên công tơ** trong fixture test (`CT` = công tơ) → tránh trùng nghĩa. Guardrail nhận anchor theo dạng `CHIEU-<slug>:` (có dấu hai chấm) ở mô tả test. Glossary: thêm gloss "Anchor chiều test" trong `THUAT_NGU.md` thay vì đăng ký term `CT` vào `glossary-terms.txt` (song song cách xử lý `NV-`).
- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-030 (CI gate truy vết chiều test ↔ test): anchor `CHIEU-<slug>` song song `NV-<slug>`; bảng `## Truy vết chiều test` trong spec (opt-in); test mang anchor ở mô tả `it`; script thứ tư `check-test-dimensions.sh` của job `doc-governance` (hard-fail, fail-loud) đối chiếu bảng ↔ `grep spec/` với 4 luật (thiếu-test / hoãn-không-Issue / orphan / đụng-tên). Retrofit milestone 1.2.0 (TN1+TN3 có test thật, TN2 toàn DEFERRED #319). Loại tự-sinh-bảng, RSpec-tag (v1), chỉ-cảnh-báo, mã-số-ngắn. Kích hoạt ADR-015; mở rộng ADR-002/024. Lớp phụ #329 (i18n guardrail; dimension review) ngoài phạm vi. Chờ duyệt.
