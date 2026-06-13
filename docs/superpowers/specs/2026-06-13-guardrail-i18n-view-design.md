---
title: Guardrail i18n cho view (baseline grandfather — chặn hard-code tiếng Việt mới ngoài t())
version: 0.1.0
status: draft (chờ duyệt)
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Guardrail i18n cho view

Biến luật AGENTS "chữ người-dùng-cuối phải qua `t(...)` + `config/locales/vi.yml`, không hard-code tiếng Việt trong view" thành **máy ép**: một script CI quét `app/views/**/*.erb`, phát hiện literal tiếng Việt nằm **ngoài** `t(...)`, và làm CI **đỏ** khi có vi phạm **mới**. Phần hard-code **đã có** được **grandfather** qua một file baseline (ảnh chụp hiện trạng) — không ép một đợt migration lớn. Đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép; đừng viết prose rồi mong người nhớ"). Truy vết: GitHub Issue [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329), **mục A**.

## Bối cảnh

`#329` (process hardening) chia làm ba mục, mục A là mục cuối:

- **Truy vết chiều test ↔ test** — xong ở [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (#335): CI gate `check-test-dimensions.sh`.
- **Chiều review "tuân AGENTS" (mục B)** — xong ở [ADR-031](2026-06-13-dimension-review-tuan-agents-design.md) (#336): RuboCop cop BigDecimal + hook/checklist. B cố ý **để tạm** phần i18n cho "mắt người + hook `/code-review`" cho tới khi A máy-ép (xem ADR-031 "Điều kiện xem lại": *mục A lên kế hoạch → rà lại dòng i18n trong checklist §8, chuyển "người" → "máy ép"*).
- **Guardrail i18n cho view (mục A)** — **tài liệu này.**

**Failure mode #329 cụ thể cho i18n:** review chỉ soi đúng/sai chức năng của diff, không soi tuân quy ước → implementer **bê nguyên pattern hard-code có sẵn** (chữ tiếng Việt không qua `t(...)`). Đây là lỗi **thêm-mới qua sao-chép**, nên guardrail chỉ cần **chặn cái mới**, không nhất thiết phải dọn sạch cái cũ trước.

Triage (chủ dự án) đã chốt: A **không** `priority-high` (CI/process tooling, không gác cắt release); chưa gán milestone (reslot ở lần planning release kế); cần brainstorm hướng scale trước khi build.

### Khảo sát code thật (2026-06-13)

| Chỉ số | Giá trị |
|---|---|
| File `.erb` trong `app/views` | 81 |
| File `.erb` chứa diacritic tiếng Việt | 65 |
| Dòng `.erb` chứa diacritic tiếng Việt | ~476 |
| File `.erb` đã dùng `t(...)` | 35 (i18n nửa vời, không greenfield) |
| Dòng `config/locales/vi.yml` | 516 (catalog thật, đang dùng) |

**Độ sạch của tín hiệu "diacritic tiếng Việt ngoài comment":**
- Trong 476 dòng diacritic, chỉ **1** dòng đồng thời có `t(...)` (key của `t` là ASCII nên dòng đã-i18n hầu như không dính diacritic).
- Chỉ **14** dòng là comment ERB (`<%# … %>`) — loại trừ dễ.
- Mẫu kiểm bằng mắt: tất cả là chữ người-dùng-thấy thật — nhãn, `page_title`, caption nút, placeholder, heading.

→ Quy tắc **"dòng `.erb` (sau khi bỏ comment span) còn chứa ký tự diacritic tiếng Việt = literal người-dùng-thấy hard-code"** có **false-positive rất thấp** trên codebase này. Đây là điểm khó nhất mà chủ dự án lo (phân biệt chữ-người-dùng vs chữ-kỹ-thuật), và hoá ra **xử lý được** vì discriminator là *ngôn ngữ* (diacritic) chứ không phải vị trí cú pháp.

### Ngã rẽ thiết kế (đã chốt với chủ dự án)

| Phương án | Mô tả | Quyết |
|---|---|---|
| **XL — full migration + repo-wide** | Migrate hết ~476 dòng/65 file sang `t()` + `vi.yml` rồi ép repo-wide (không baseline) | **Loại** |
| **M — baseline grandfather** | Grep diacritic ngoài comment trên toàn cây → so với baseline; chỉ vi phạm **mới** (không có trong baseline) → đỏ. Grandfather phần cũ; baseline co dần khi migrate dần | **Chọn** |

**Vì sao M, không XL:** app **single-locale (vi)**, không có ngôn ngữ thứ hai trong kế hoạch → giá trị **cốt lõi** của i18n (dịch đa ngôn ngữ) **không bao giờ dùng tới**. Migrate 476 dòng/65 file chỉ để đạt "đồng nhất" là speculative theo **YAGNI**, lại mang **regression risk cao** trên hệ đang chạy production (mỗi dòng đổi có thể lệch chữ hiển thị). M **trúng đúng failure mode** (chặn hard-code *mới*), effort vừa, **0 big-bang risk**, và baseline còn là **sổ nợ kỹ thuật co dần** mời migrate tăng dần mà không ép.

### Khảo sát công cụ có sẵn (không tự viết nếu off-the-shelf giải quyết được)

Đã rà hệ sinh thái Ruby/Rails. **Không công cụ nào khớp ca này:**

| Công cụ | Vì sao không khớp |
|---|---|
| **rubocop-i18n** (`RailsI18n/DecorateString`) | Chỉ bắt literal **dạng câu tiếng Anh** (`SENTENCE_REGEXP` = chữ hoa + có space + dấu kết câu). UI ta là nhãn tiếng Việt ngắn ("Lưu", "Hủy", "Đơn vị", "Thêm khối") — **không dấu kết câu, thường không space → bỏ sót gần hết**. Lại chạy trên **AST Ruby**, nên **text node thuần** trong ERB (`<h1>Đăng nhập</h1>`) và nhiều string-arg helper **vô hình** với nó. Cần thêm gem `erb_lint` để trích Ruby, vẫn sót phần lớn. |
| **erb_lint** | Không có linter "hard-code i18n" sẵn; chỉ làm host chạy rubocop-i18n trên Ruby trích ra → thừa kế mọi vấn đề trên, vẫn mù text node thuần. |
| **i18n-tasks** | Giải **bài khác**: key thiếu/thừa (quét lời gọi `t()` đối chiếu `vi.yml`). **Không** phát hiện literal **chưa từng** bọc `t()`. (Có thể là công cụ *tương lai, riêng* cho key-hygiene — không phải mục A.) |

Hai lý do gốc khiến không gì khớp đồng thời **làm cách của ta đơn giản hơn:** (1) discriminator của ta là **diacritic tiếng Việt** — đặc-ngôn-ngữ, không công cụ tổng quát nào có (chúng dùng heuristic câu-tiếng-Anh, sót nhãn VN ngắn); (2) phần lớn hard-code nằm ở **text node / string-arg ERB thuần**, chỉ **quét text/dòng** bắt được, không phải cop AST. Điều này củng cố tiền lệ [ADR-031](2026-06-13-dimension-review-tuan-agents-design.md): *AST semantics → cop; text/markdown → bash*. i18n-trên-ERB là kiểm **text-level** → bash, như [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md)/[ADR-030](2026-06-13-truy-vet-chieu-test-design.md).

## ADR-032: Guardrail i18n cho view — baseline grandfather bằng script CI bash native (mở rộng ADR-002/024/030)

- **Trạng thái:** Proposed · 2026-06-13 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail CI bash fail-loud), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (guardrail bash chạy cả cây + companion `.test.sh`).
- **Bối cảnh:** xem trên.
- **Quyết định:**

  **(1) Hướng M — baseline grandfather** (không full migration; lý do YAGNI single-locale ở trên).

  **(2) Cơ chế — bash native fail-loud**, kế thừa [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md)/[ADR-030](2026-06-13-truy-vet-chieu-test-design.md). Script `.github/scripts/check-view-i18n.sh`; companion `.github/scripts/check-view-i18n.test.sh` (người-chạy, không wire CI). Portable bash, `set -uo pipefail`, FAIL-LOUD (vi phạm → exit 1).

  **(3) Phát hiện literal tiếng Việt người-dùng-thấy.** Quét `app/views/**/*.erb`. Với mỗi dòng:
  1. **Bỏ comment span**: cắt đoạn comment ERB `<%# … %>` và comment HTML `<!-- … -->` khỏi dòng (diacritic trong comment **không** tính — comment tiếng Việt hợp lệ). Cắt theo *span trong dòng* nên dòng **lẫn** (vừa code vừa comment) vẫn xét đúng phần code còn lại.
  2. **Bắt diacritic**: nếu phần còn lại chứa ký tự **diacritic tiếng Việt** (lớp ký tự precomposed tường minh, `grep -E` — chạy được cả GNU grep ở CI/Docker lẫn BSD grep khi developer chạy companion trên macOS) → dòng là **ứng viên vi phạm**.
  3. Phát ra một bản ghi `relpath<TAB>normalized-text` (text **chuẩn-hoá khoảng-trắng**, **không** số dòng).

  Không cố parse "string này có nằm trong `t()` không": khảo sát cho thấy dòng-diacritic-ngoài-comment đã 99% chính xác (1/476 trùng `t()`), nên bắt cả-dòng + grandfather là đủ và đơn giản hơn nhiều việc phân tích cú pháp ERB.

  **(4) So baseline content-based.** Baseline `.github/i18n-view-baseline.txt` — mỗi dòng một bản ghi `relpath<TAB>normalized-text`, **sort, unique, không số dòng**. Script tính tập ứng viên hiện tại rồi so:
  - Ứng viên **không có trong baseline** → **vi phạm MỚI → exit 1 (đỏ)**, in file + text + gợi ý ("bọc `t(...)` + thêm key vào `config/locales/vi.yml`").
  - Bản ghi baseline **không còn xuất hiện** (dòng đã được sửa/migrate nhưng còn trong baseline) → **note thông tin, KHÔNG chặn**; dọn bằng regenerate.

  **Vì sao content-based (không số-dòng, không file-level):** ổn định trước dịch-chuyển dòng (không churn baseline khi sửa chỗ khác trong file), **nhưng vẫn bắt** literal **mới** thêm vào file đã-grandfather (file-level sẽ bỏ sót). Sửa chính chữ tiếng Việt trên một dòng đã-baseline → text đổi → bị bắt lại — đúng thời điểm nên i18n nó.

  **(5) Regenerate / escape hatch.** `UPDATE_BASELINE=1 bash .github/scripts/check-view-i18n.sh` ghi lại baseline. Grandfather một literal thực-sự-hợp-lệ-nhưng-bị-bắt (hiếm), hoặc ghi nhận một đợt migrate, là một **diff baseline thấy được trong PR** → người gác merge duyệt (đúng tinh thần `rubocop:disable`-kèm-lý-do và inline-disable của [ADR-031](2026-06-13-dimension-review-tuan-agents-design.md); người-giữ-gate theo [ADR-007](2026-06-07-quy-trinh-release-design.md)).

  **(6) Vị trí chạy — job CI riêng `i18n-view-guardrail`, always-on.** Grep rất rẻ; chạy **luôn** trên mọi pull request (kể cả docs-only) theo đúng triết lý "guardrail bash native always-on" của job `doc-governance` (ADR-024). Để **tách concern** (job `doc-governance` thuần tài liệu), đặt job **riêng** thay vì nhồi vào đó.

  **Trục quyết định kèm theo:**
  - **Hard-fail (đỏ) cho vi phạm mới**: nhất quán với guardrail ADR-024/030; tín hiệu sạch (diacritic-ngoài-comment) → false-positive thấp; escape bằng baseline-regenerate-duyệt-ở-PR.
  - **Stale baseline non-blocking**: không chặn PR vô tình sửa một dòng mà chưa prune baseline; giữ ergonomics. Dọn chủ động bằng regenerate. (Đánh đổi: một bản ghi stale chỉ "che" việc tái-thêm **đúng text đó ở đúng file đó** — khe rất hẹp; chấp nhận.)
  - **Always-on**: vi phạm i18n cần bắt đúng lúc PR đụng `.erb`; chạy luôn cũng phủ trường hợp đổi tên/di chuyển file.

- **Lý do:**
  - **Đẩy luật máy-kiểm-được sang máy** (ADR-002): "UI phải i18n" có một lát cắt **đo được chắc chắn** trên app này (diacritic ngoài comment) → script hoá, không "mong người nhớ" / không phụ thuộc mắt review (chính là failure mode #329).
  - **Bash thay cop/gem** cho kiểm text-level: nhất quán ADR-024/030; không công cụ off-the-shelf nào khớp (khảo sát ở trên); cop AST mù text node ERB thuần.
  - **Baseline thay full migration**: YAGNI (single-locale), 0 big-bang risk, sổ-nợ co dần.
  - **Bề mặt repo-local, team-shared, version-controlled**: `.github/scripts/` + `.github/workflows/ci.yml` + baseline trong repo — không phụ thuộc plugin toàn cục (xem ADR-031 Bối cảnh).
- **Tradeoff:**
  - (+) Hard-code tiếng Việt **mới** ngoài `t()` → CI đỏ tự động, không phụ thuộc trí nhớ người review.
  - (+) Không ép migration; baseline co dần mời migrate tăng dần.
  - (−) **Không** bắt được chữ người-dùng-thấy **không có diacritic** (ví dụ chuỗi toàn ASCII, hoặc số/ký hiệu) — hiếm trong UI tiếng Việt; còn người/AI (checklist §8 + hook ADR-031).
  - (−) **Không** phân biệt được literal kỹ-thuật-hợp-lệ hiếm-hoi có diacritic (ví dụ một chuỗi dữ liệu) — xử lý bằng baseline-escape.
  - (−) Baseline có thể tích cruft nếu không prune (non-blocking) — regenerate dọn.
  - (−) Thêm 1 script + 1 companion test + 1 job CI + 1 file baseline để bảo trì; nhỏ.
- **Phương án đã loại:**
  - *XL full migration + ép repo-wide* — loại: YAGNI single-locale; regression risk; effort lớn (xem ngã rẽ).
  - *rubocop-i18n (+erb_lint)* — loại: heuristic câu-tiếng-Anh sót nhãn VN ngắn; AST mù text node ERB thuần (xem khảo sát công cụ).
  - *i18n-tasks* — loại cho mục A: giải bài key thiếu/thừa, không bắt literal chưa-bọc-`t()`. (Ghi nhận khả năng dùng tương lai cho key-hygiene — ngoài scope #329.)
  - *Baseline theo số dòng* — loại: churn mỗi lần dịch chuyển dòng; diff nhiễu.
  - *Baseline file-level* (cả file được "miễn") — loại: bỏ sót literal **mới** thêm vào file đã-grandfather.
  - *Soi diff git so base SHA* (chỉ quét dòng thêm) — loại: cần plumbing base SHA, hành vi khác nhau local vs CI, bỏ sót vi phạm khi sửa dòng kế cận; baseline content-based đơn giản và deterministic hơn (chạy trên cây, không cần lịch sử).
  - *Nhồi vào job `doc-governance`* — loại: job đó thuần tài liệu; tách concern rõ hơn với job riêng.
- **Điều kiện xem lại:**
  - Khi baseline co về **rỗng** (đã migrate hết) → cân nhắc bỏ cơ chế baseline, ép repo-wide vô điều kiện (script vẫn nguyên, chỉ là baseline rỗng).
  - Nếu xuất hiện nhiều false-negative "chữ người-dùng ASCII không diacritic" → cân nhắc bổ sung heuristic (ví dụ allowlist key chữ Anh dành cho UI, hoặc kiểm text node thuần).
  - Nếu xuất hiện false-positive diacritic kỹ-thuật lặp lại → xét thêm quy tắc loại trừ (ngoài baseline-escape).
  - Nếu đội thêm công cụ i18n (ví dụ i18n-tasks cho key-hygiene) → rà lại quan hệ với guardrail này.

## Thiết kế triển khai

Một pull request, nhánh `feature/i18n-view-guardrail` ← `develop`. PR đụng `.github/` + thêm baseline; **không** đụng `app/` (không migrate) nên không đổi hành vi app.

### Tệp tạo mới (code/tooling — KHÔNG versioned theo ADR-002)
- `.github/scripts/check-view-i18n.sh` — script guardrail (phát hiện + so baseline + regenerate qua `UPDATE_BASELINE=1`). Comment tiếng Việt giải thích; mọi output/echo **tiếng Anh** (output kỹ thuật cho CI/developer).
- `.github/scripts/check-view-i18n.test.sh` — companion người-chạy (fixture tạm, kiểm exit code + thông báo). Không wire CI.
- `.github/i18n-view-baseline.txt` — ảnh chụp hiện trạng (`relpath<TAB>normalized-text`, sort/unique). Sinh bằng `UPDATE_BASELINE=1` trên cây hiện tại. Có dòng header `#` giải thích cách regenerate.

### Tệp sửa
- `.github/workflows/ci.yml` — thêm job `i18n-view-guardrail` (always-on, chạy `bash .github/scripts/check-view-i18n.sh`).
- `CONTRIBUTING.md` §8 — tiểu mục mới "Guardrail i18n cho view": cơ chế, cách regenerate baseline, và **đổi dòng i18n ở bảng "Chiều review tuân AGENTS"** từ "người/AI (mục A tương lai)" → "máy ép ([ADR-032](2026-06-13-guardrail-i18n-view-design.md))" (đúng "Điều kiện xem lại" của ADR-031). **File meta, KHÔNG versioned** (ADR-002).
- `docs/THUAT_NGU.md` — thêm gloss **"baseline (guardrail)"** vào §3 (jargon dùng xuyên ADR-024/030/032, chưa có định nghĩa canonical). Bump version + changelog cùng commit (ADR-002). **Không** đăng ký term mới vào `.github/dictionaries/glossary-terms.txt` (giữ baseline guardrail ADR-024).

### Không đụng (cố ý)
- **Không** sửa file `.erb` (không migrate — đó là XL đã loại).
- **Không** thêm checkbox PR template mới: ADR-031 đã có checkbox "tuân AGENTS (§8)" phủ i18n; nay §8 trỏ guardrail máy-ép.

## Kiểm thử

Theo kiểu ADR-024/030:
- **Companion `.test.sh`** (người chạy): fixture các ca — (a) dòng diacritic mới không trong baseline → đỏ + đúng message; (b) mọi dòng đều trong baseline → xanh; (c) diacritic chỉ trong comment ERB/HTML → xanh (bỏ qua); (d) dòng lẫn code+comment, code có diacritic → đỏ; (e) dòng dịch chuyển (cùng text, khác số dòng) → xanh (content-based); (f) `UPDATE_BASELINE=1` sinh baseline rồi chạy lại → xanh.
- **Kiểm chứng trên cây thật**: sau khi commit baseline → script **xanh** trên repo; chèn một literal hard-code mới vào một `.erb` → **đỏ** ("new violation"); hoàn nguyên → xanh. Ghi lại trong plan.
- `bin/docker rspec` chạy bình thường (không đụng app code).

## Giới hạn (không phóng đại "đảm bảo")

Guardrail này **chỉ** đảm bảo: literal **mới** chứa **diacritic tiếng Việt**, ngoài comment, ngoài `t(...)`, trong `app/views/**/*.erb`, **không có trong baseline** → CI đỏ. **KHÔNG** đảm bảo:
1. **Chữ người-dùng-thấy không-diacritic** (toàn ASCII) — không bắt; còn người/AI (§8 + hook ADR-031).
2. **Hard-code ngoài view** (helper, mailer, model, file xuất Excel `*.axlsx`) — ngoài scope v1 (chỉ `.erb`).
3. **Phần đã grandfather** trong baseline — chủ ý không ép dọn (M, không XL); chỉ mời migrate.
4. **Người tự thêm vào baseline để qua CI** — diff baseline thấy ở PR, dựa người gác merge (ADR-007).
5. **i18n-tasks-style key hygiene** (key thiếu/thừa trong `vi.yml`) — bài khác, ngoài scope.

Mạnh nhất là phần lưới chống regression: pattern hard-code tiếng Việt **mới** (đúng failure mode #329 — bê pattern có sẵn) sẽ làm CI đỏ tự động.

## Truy vết

- **Issue:** [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329) (`enhancement`, `needs-design`), **mục A**. Với #335 (truy-vết) và #336 (mục B) đã merge, **A là mục mở cuối cùng** → pull request dùng **`Closes #329`** (rà lại checklist các mục con của #329 lúc mở PR; nếu còn mục khác mở thì `Refs`). Không `priority-high`; chưa milestone (reslot ở planning release kế).
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail CI bash fail-loud), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (guardrail bash + companion `.test.sh`), [ADR-031](2026-06-13-dimension-review-tuan-agents-design.md) (mục B; B để tạm i18n cho người/AI tới khi A máy-ép — ADR này thực hiện "Điều kiện xem lại" đó).
- **Test:** companion `check-view-i18n.test.sh` (người chạy) + kiểm chứng đỏ/xanh trên cây thật (ghi trong plan).

## Lịch sử thay đổi

- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-032 (guardrail i18n cho view, hướng M baseline grandfather). Script bash native `check-view-i18n.sh` + companion `.test.sh` + baseline content-based `.github/i18n-view-baseline.txt` + job CI `i18n-view-guardrail` always-on. Phát hiện: diacritic tiếng Việt ngoài comment span = literal người-dùng-thấy (false-positive thấp, khảo sát 1/476 trùng `t()`). Loại: XL full migration (YAGNI single-locale), rubocop-i18n/erb_lint (heuristic câu-tiếng-Anh + mù text node ERB), i18n-tasks (giải bài key, không bắt literal chưa-bọc), baseline số-dòng/file-level, soi-diff-git, nhồi job doc-governance. Chờ duyệt.
