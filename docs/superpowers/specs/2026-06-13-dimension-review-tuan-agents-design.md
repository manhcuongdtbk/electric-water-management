---
title: Chiều review "tuân AGENTS" (custom RuboCop cop cho BigDecimal + hook/checklist cho phần phán đoán)
version: 0.1.2
date: 2026-06-13
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Chiều review "tuân AGENTS"

> **Ghi chú (25/06/2026):** Spec viết khi hệ thống có 6 vai trò thực tế. Nay 7 vai trò (thêm Chỉ huy Sư đoàn `division_commander` — xem [ADR-061](2026-06-25-division-commander-role-design.md), Issue #419).
Làm cho review code — cả người review lẫn Claude khi chạy `/code-review` — **kiểm tuân thủ quy ước AGENTS**, không chỉ soi diff đúng/sai về chức năng. Bốn chiều AGENTS cần phủ: **i18n** (chữ người-dùng qua `t(...)` + `vi.yml`), **không viết tắt** (chỉ dùng viết tắt có trong `docs/THUAT_NGU.md`), **BigDecimal cho tiền/điện** (không float; làm tròn `ROUND_HALF_UP` chỉ khi hiển thị), **phủ đủ 6 vai trò** trong test. Đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) ("luật nào máy kiểm được thì để máy ép; đừng viết prose rồi mong người nhớ"): đẩy phần **máy ép được tối đa** thành CI đỏ, chỉ để lại phần **không nhập nhằng-bất-khả-thi** cho người/AI — và phần đó cũng được bơm tự động vào Claude lúc review để "người skim cũng không rớt". Truy vết: GitHub Issue [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329), mục B.

## Bối cảnh

Retro TN1 (#327) lộ một nguyên nhân gốc: review chỉ soi **đúng/sai chức năng của diff**, không soi **tuân quy ước AGENTS** → implementer bê nguyên pattern hard-code có sẵn (chữ tiếng Việt không qua i18n), loạt hành vi demo được nhưng không có test. #329 chia làm ba mục để chữa:

- **Truy vết chiều test ↔ test** — đã xong ở [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (#335): vượt mức thành CI gate (`check-test-dimensions.sh`).
- **Guardrail i18n cho view (mục A)** — follow-up riêng; cần brainstorm hướng (full migration vs guardrail chỉ soi diff). Chưa làm.
- **Dimension review "tuân AGENTS" (mục B)** — **tài liệu này.**

Triage (chủ dự án) đã chốt: thứ tự **B → A**; B **không** `priority-high` (tooling nội bộ, không gác cắt release); chưa gán milestone (gán ở lần planning release kế). Giá trị **riêng** của B nằm ở phần các guardrail khác **chưa phủ**: phần i18n chồng với mục A (CI i18n sau này sẽ máy-ép); phần phủ-6-vai-trò một phần đã được [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) máy-ép (anchor `CHIEU-<slug>`). Nên giá trị còn lại của B là phần **người-phán-đoán**: không-viết-tắt (ngữ nghĩa), BigDecimal đặt-đúng-chỗ, lập luận về độ phủ vai trò.

### Mỗi chiều máy ép được tới đâu (khảo sát code thật, 2026-06-13)

| Chiều AGENTS | Máy ép được tới đâu | Cơ chế |
|---|---|---|
| **i18n** | Grep được literal tiếng Việt ngoài `t(...)` — **nhưng đó chính là mục A** (đã tách riêng, cần quyết hướng scale trước) | Automation = **mục A** (follow-up); B để tạm cho người/AI (hook + checklist) |
| **Không viết tắt** | [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) đã kết luận **bất khả thi** với prose tiếng Việt (chỉ glossary `THUAT_NGU.md` được máy canh) | Không ép máy được → người/AI (hook + checklist) |
| **BigDecimal / làm tròn** | **Có phần ép được** — anti-pattern không nhập nhằng (`Float()`, `ROUND_HALF_EVEN`, `.round` thiếu mode, `.to_f` lẫn tầng tính toán) | **Custom RuboCop cop** (Lớp 1) — giá trị tự-động-hoá thật của B |
| **Phủ đủ 6 vai trò** | [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) đã ép liên kết *chiều test đã khai ↔ test*; phần "đã liệt kê đủ 6 vai" còn lại là phán đoán | Phần lớn đã máy (ADR-030); residue → người/AI (hook + checklist) |

**Phát hiện then chốt về BigDecimal** (grep `app/`):
- `ROUND_HALF_EVEN`: 0 chỗ. `Float(`: 0 chỗ → ban hai cái này = lưới chống regression sạch, gần 0 báo nhầm.
- `.to_f`: 15 chỗ, **tất cả ở tầng xuất Excel** (`app/views/billing/show.xlsx.axlsx`) + helper hiển thị (`app/helpers/number_helper_vi.rb`) — dùng *hợp lệ* ở ranh giới hiển thị. Tầng tính toán (`app/models`, `app/services`) hiện **0 chỗ** `.to_f`.

→ Máy **phân biệt được** "`.to_f` ở ranh giới Excel/hiển thị (OK)" với "`.to_f` lẫn vào tầng tính toán (sai)" bằng cách **giới hạn theo thư mục**. Đây đúng là quy tắc AGENTS "không làm tròn/float giữa lúc tính toán", máy ép được nó như lưới regression.

### Vì sao không sửa thẳng prompt review-agent

`/code-review` và các review subagent (`code-reviewer.md`) sống ở **plugin toàn cục** (`~/.claude/plugins/`) — **không** nằm trong repo này, không version-controlled ở đây, không chia sẻ với đồng đội, bị ghi đè khi cập nhật plugin. Nên "nhúng chiều AGENTS vào prompt review-agent" **không bền**. Các bề mặt repo-local, team-shared, được version-control là: `CONTRIBUTING.md`, `.github/`, và `.claude/` (hook + `settings.json` — vốn đã bơm `additionalContext` để lái Claude, ví dụ hook gh-pr-monitor). Thiết kế dùng chính các bề mặt này.

## ADR-031: Chiều review "tuân AGENTS" hai lớp — máy ép tối đa (RuboCop cop) + hook/checklist cho phần phán đoán (mở rộng ADR-002/024/029)

- **Trạng thái:** Accepted · 2026-06-13 · mở rộng [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail), [ADR-029](2026-06-07-sdlc-overview-design.md) (review là phần "cơ học" của vận hành AI-assisted).
- **Bối cảnh:** xem trên.
- **Quyết định:**

  **(1) Hai lớp.** Chiều "tuân AGENTS" tách thành: **Lớp 1 — máy ép** (phần chắc-chắn-kiểm-được → CI đỏ) và **Lớp 2 — hook + checklist** (phần phán đoán bất-khả-thi-máy → bơm tự động vào Claude + checklist người). Nguyên tắc: đẩy tối đa sang Lớp 1; Lớp 2 chỉ giữ phần thật sự không nhập nhằng-không-grep-được.

  **(2) Lớp 1 — custom RuboCop cop cho BigDecimal/làm tròn.** Chạy trong job `ruby-checks` sẵn có (RuboCop đã ở CI). Cop đặt ở `lib/rubocop/cop/decimal/`, nạp qua `require:` trong `.rubocop.yml`, scope theo thư mục qua `Include`/`Exclude`:
  - **`Decimal/NoFloatInCalculation`** — chặn `.to_f` và `Float(...)` ở **tầng tính toán** (`Include: app/models/**, app/services/**`). Tầng xuất/hiển thị (`*.axlsx`, `app/helpers/number_helper_vi.rb`) **không** bị bắt (qua `Exclude` hoặc giới hạn `Include`). Escape hợp lệ: `# rubocop:disable Decimal/NoFloatInCalculation` kèm lý do.
  - **`Decimal/ExplicitRoundingMode`** — scope cùng tầng tính toán (`Include: app/models/**, app/services/**`); chặn **mọi** `.round` **không** kèm đối số mode half-up tường minh (`:half_up` hoặc hằng kết thúc `ROUND_HALF_UP`). Như vậy bắt cả `.round(2)` thiếu mode, lẫn `.round(2, :half_even)`/`ROUND_HALF_EVEN`/banker's (mode bị AGENTS cấm) — chỉ `.round(2, :half_up)`/`.round(2, BigDecimal::ROUND_HALF_UP)` qua. Cùng escape `# rubocop:disable`.

  **Vì sao scope tầng tính toán cho cả hai (không "mọi nơi"):** khảo sát cho thấy tầng tính toán hiện có **0** `.round` và **0** `.to_f` (mọi làm tròn nằm ở helper hiển thị `number_helper_vi.rb`, đã dùng `ROUND_HALF_UP` tường minh, thuộc tầng hiển thị nên **Exclude**). Quy ước BigDecimal của AGENTS là về **tính toán** tiền/điện → ép đúng tầng đó cho false-positive thấp và scope mỗi cop đồng nhất (dễ hiểu/bảo trì). Banker's-rounding lọt ở tầng hiển thị là khe hở nhỏ, đã được review người + checklist §8 phủ; chấp nhận đánh đổi này thay vì cop xét đường-dẫn phức tạp.

  Hiện code đã sạch → cop chạy **xanh ngay** trên cây repo; vai trò là **lưới chống regression** về sau (bắt float/làm-tròn-sai *mới thêm*). Test cop bằng RSpec (`spec/rubocop/cop/decimal/`, dùng `RuboCop::RSpec::ExpectOffense`) — case vi phạm bị bắt đúng message, case hợp lệ (BigDecimal + `:half_up`) qua. "File ngoài scope không bị bắt" được chứng minh bằng lần chạy `rubocop` xanh trên cả repo (15 `.to_f` ở axlsx không bị bắt); inline-disable là tính năng sẵn của RuboCop, không cần unit-test riêng.

  **(3) Lớp 2 — hook `UserPromptSubmit` + checklist.**
  - **Hook** trong `.claude/settings.json`: `UserPromptSubmit` khớp prompt chứa `/code-review` → bơm `additionalContext` gồm 3 câu hỏi phán đoán (không-viết-tắt ngữ nghĩa; BigDecimal đặt-đúng-chỗ ngoài tầm cop; lập-luận phủ đủ 6 vai) + trỏ `CONTRIBUTING.md` §8. Bash thuần (`jq`, grep), **fail-open** nếu thiếu `jq` (im lặng, không lỗi) — khớp các hook hiện có. Chỉ kích hoạt khi gõ `/code-review` (không bơm ở chỗ khác → ít nhiễu); gate PR-time cho người đã có checkbox PR template riêng.
  - **Checklist canonical** ở `CONTRIBUTING.md` §8 (tiểu mục mới "Chiều review tuân AGENTS"): **nguồn duy nhất**, bảng 4 chiều, mỗi chiều ghi rõ quan hệ guardrail (i18n → mục A tương lai; không-viết-tắt → người/AI; BigDecimal → Lớp 1 cop + phán đoán; 6 vai → ADR-030 + phán đoán). Hook và PR template **trỏ về** §8, không chép (một fact một nơi).
  - **Checkbox PR template** (`.github/pull_request_template.md`): thêm 1 dòng trong "Traceability checklist" — người mở PR xác nhận đã kiểm chiều tuân AGENTS, trỏ §8.

  **Trục quyết định kèm theo:**
  - **Lớp 1 hard-fail (đỏ)**: nhất quán với RuboCop hiện có; cop conservative (chỉ bắt anti-pattern không nhập nhằng) → false-positive thấp; escape bằng inline-disable-kèm-lý-do cho ngoại lệ hợp lệ.
  - **Lớp 2 không chặn**: phần phán đoán không thể đỏ-tin-cậy (false-positive cao) → bơm context + checklist; tín hiệu, không gate.
  - **Hook fail-open**: thiếu `jq`/lỗi → cho qua, không cản người dùng.

- **Lý do:**
  - **Đẩy tối đa sang máy** đúng yêu cầu + đúng ADR-002: chiều BigDecimal có một lát cắt **đo được chắc chắn** (`Float()`, `ROUND_HALF_EVEN`, `.round` thiếu mode, `.to_f` lẫn tầng tính toán) → cop hoá, không "mong người nhớ".
  - **Custom cop thay bash grep**: hiểu AST (phân biệt `.round` có/không mode, receiver), tích hợp job `ruby-checks` sẵn có, có inline-disable-kèm-lý-do chuẩn RuboCop làm escape hatch — robust hơn grep cho ngữ nghĩa Ruby. (Khác ADR-024/030 dùng bash vì đó là kiểm *văn bản/markdown*; đây là kiểm *AST Ruby* nên cop đúng công cụ.)
  - **Phần còn lại không cố máy-hoá-ép**: ADR-024 đã chứng minh quét prose tiếng Việt tìm viết tắt là bất khả thi (false-positive ngập); "float lẩn vào tính toán qua đường vòng" và "đặt-đúng-chỗ" cần đọc luồng. Ép máy phần này = nhiễu → phản tác dụng. Thay vào đó **bơm tự động vào Claude** lúc review (Lớp 2) để không phụ thuộc trí nhớ người — đó là "tự động hoá" khả thi cho phần phán đoán.
  - **Bề mặt repo-local**: không sửa plugin toàn cục (không bền) — dùng `.claude/`, `CONTRIBUTING.md`, `.github/` (version-controlled, team-shared).
- **Tradeoff:**
  - (+) Phần BigDecimal chắc-chắn-kiểm-được thành CI đỏ tự động; lưới chống regression float/làm-tròn; Claude luôn nhận chiều AGENTS lúc `/code-review` dù người skim.
  - (−) Cop **không** bắt được "float lẩn vào tính toán qua đường vòng" (ví dụ nhận float từ biến trung gian không `.to_f` tường minh) — còn người/AI.
  - (−) Lớp 2 **không** chặn (tín hiệu, không gate) — vẫn dựa người đọc finding của Claude + checkbox.
  - (−) Thêm 2 cop + spec cop + 1 hook để bảo trì; nhỏ. Cop có thể false-positive ở ranh giới scope → có inline-disable.
  - (−) Hook chỉ tác dụng với Claude Code (công cụ đội đang dùng); người review thuần-tay dựa checklist §8 + checkbox PR.
- **Phương án đã loại:**
  - *Sửa prompt `/code-review`/review subagent* — loại: plugin toàn cục, không bền/không version-controlled/bị ghi đè (xem Bối cảnh).
  - *Bash grep cho BigDecimal* (kiểu ADR-024/030) — loại: kiểm AST Ruby (`.round` có/không mode) cần hiểu cú pháp; grep dễ false-positive, không có inline-disable chuẩn. Cop đúng công cụ hơn cho Ruby.
  - *Project subagent `.claude/agents/` review tuân-AGENTS* — loại: trùng vai `/code-review`, phải gọi tay (cùng phụ-thuộc-trí-nhớ), effort cao, dễ lệch khi AGENTS đổi.
  - *Checklist thuần (CONTRIBUTING §8) không có Lớp 1/hook* — loại: yếu trước chính failure mode #329 ("tự kỷ luật không đủ"); bỏ lỡ phần BigDecimal máy ép được.
  - *Ép i18n trong B* — loại: i18n automation là **mục A** (đã tách, cần quyết hướng scale riêng); kéo vào B = khoá sớm thiết kế A.
  - *Hook bơm ở cả PR-create / `/simplify`* — loại (v1): trùng với bước `/code-review` local + checkbox PR; `/simplify` không săn bug/tuân-quy-ước → lệch mục đích. Để "Điều kiện xem lại".
- **Điều kiện xem lại:**
  - Mục A (guardrail i18n) lên kế hoạch → rà lại dòng i18n trong checklist §8 (chuyển "người" → "máy ép").
  - Nếu xuất hiện nhiều "float lẩn đường vòng" mà cop bỏ sót → cân nhắc cop sâu hơn (theo dõi kiểu) hoặc kiểm flow.
  - Nếu đội thêm công cụ AI khác (Codex, Antigravity) → ánh xạ hook tương đương ở `CONTRIBUTING.md` §8 (giữ canonical trung lập công cụ).

## Thiết kế triển khai

Một pull request, nhánh `feature/agents-compliance-review-dimension` ← `develop`. **Đụng code** (`lib/**`, `.rubocop.yml`) → CI chạy **full** → cop mới + spec cop tự kiểm trên chính pull request giới thiệu nó.

### Tệp tạo mới (code — KHÔNG versioned theo ADR-002)
- `lib/rubocop/cop/decimal/no_float_in_calculation.rb` — cop chặn `.to_f`/`Float(...)` ở tầng tính toán. Comment tiếng Việt + ref ADR-031. `MSG` tiếng Anh (output kỹ thuật cho developer/CI).
- `lib/rubocop/cop/decimal/explicit_rounding_mode.rb` — cop chặn `ROUND_HALF_EVEN` + `.round` thiếu mode.
- `spec/rubocop/cop/decimal/no_float_in_calculation_spec.rb`, `spec/rubocop/cop/decimal/explicit_rounding_mode_spec.rb` — RSpec dùng `RuboCop::RSpec::ExpectOffense`.

### Tệp sửa
- `.rubocop.yml` — `require:` (nạp cop từ `lib/rubocop/cop/decimal/`) + cấu hình `Include`/`Exclude` per-cop (scope tầng tính toán vs hiển thị); bật cả hai cop.
- `.claude/settings.json` — thêm hook `UserPromptSubmit` (matcher khớp `/code-review`) bơm `additionalContext`.
- `CONTRIBUTING.md` §8 — tiểu mục "Chiều review tuân AGENTS" (canonical; bảng 4 chiều + quan hệ guardrail). **File meta, KHÔNG versioned** (ADR-002).
- `.github/pull_request_template.md` — thêm 1 checkbox "đã kiểm chiều tuân AGENTS (§8)".
- `docs/THUAT_NGU.md` — **kiểm**: nếu introduce term/abbrev mới cần đăng ký (dự kiến không — "RuboCop cop", "BigDecimal" là tên công cụ/chuẩn). Nếu có → bump version + changelog.

### Kiểm thử
- **Cop (máy chạy được):** `bin/docker rspec spec/rubocop/cop/decimal/` — mỗi cop có case: (a) vi phạm bị bắt đúng message; (b) code hợp lệ (BigDecimal + `:half_up`) không bị bắt. Scope theo thư mục và inline-disable do RuboCop framework lo (không unit-test riêng). Chạy `bin/docker bundle exec rubocop` trên cây repo → **xanh** (code đã sạch; 15 `.to_f` ở axlsx ngoài scope không bị bắt), chứng minh không false-positive trên data thật + scope đúng.
- **Hook (kiểm tay):** gõ `/code-review` trong Claude Code → xác nhận `additionalContext` được bơm (3 câu hỏi + trỏ §8). Không có framework test hook trong repo (như mọi hook hiện có); plan ghi bước verify.

## Giới hạn (không phóng đại "đảm bảo")

ADR này ép phần **cơ học, không nhập nhằng** của một chiều (BigDecimal), và **bơm tự động** phần phán đoán vào Claude. **KHÔNG** đảm bảo:
1. **i18n** — automation thuộc **mục A** (#329), follow-up riêng; trong B chỉ là dòng checklist + hook (người/AI).
2. **Không viết tắt** — bất khả thi máy-ép (ADR-024); chỉ checklist + hook.
3. **BigDecimal "đặt đúng chỗ" / float lẩn đường vòng** — cop bắt anti-pattern tường minh, không bắt float đến qua biến trung gian; phần này người/AI.
4. **Phủ đủ 6 vai trò** — ADR-030 ép liên kết *đã khai*; "đã liệt kê đủ 6 vai" còn người/AI.
5. **Người review thuần-tay đọc kỹ** — Lớp 2 là tín hiệu (hook + checkbox), không chặn; vẫn dựa kỷ luật người merge (ADR-007).

Mạnh nhất là phần Lớp 1: anti-pattern float/làm-tròn **mới thêm** sẽ làm CI đỏ tự động, không phụ thuộc trí nhớ.

## Truy vết

- **Issue:** [`#329`](https://github.com/manhcuongdtbk/electric-water-management/issues/329) (`enhancement`, `needs-design`) — **`Refs #329`** ở pull request, **KHÔNG** `Closes`: #329 còn mục A (guardrail i18n) đang mở. Không `priority-high`; chưa milestone (reslot ở planning release kế).
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (máy ép luật kiểm được), [ADR-024](2026-06-11-guardrail-quan-tri-tai-lieu-design.md) (pattern guardrail CI fail-loud), [ADR-029](2026-06-07-sdlc-overview-design.md) (review = phần cơ học của vận hành AI-assisted), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (đã máy-ép phần liên kết chiều test ↔ test; B bổ sung phần residue).
- **Test:** spec cop ở `spec/rubocop/cop/decimal/` (tự kiểm trên pull request giới thiệu cop); cop chạy xanh trên cây repo; verify hook bằng tay (ghi trong plan).

## Lịch sử thay đổi

- **0.1.2 (2026-06-13):** Theo ADR-033 (#339): bỏ field frontmatter `status:` (nguồn duy nhất = inline `**Trạng thái:**`); lật trạng thái các ADR đã merge sang `Accepted`.
- **0.1.1 (2026-06-13):** Tinh chỉnh hành vi `Decimal/ExplicitRoundingMode` (phát hiện lúc viết plan, khảo sát code): scope **cùng tầng tính toán** (`app/models`, `app/services`) như cop float — bỏ "ROUND_HALF_EVEN mọi nơi"; cop bắt **mọi** `.round` thiếu mode half-up tường minh (subsume cả missing-mode lẫn banker's-mode trong tầng đó). Lý do: tầng tính toán hiện 0 `.round`/0 `.to_f` (mọi làm tròn ở helper hiển thị, đã `ROUND_HALF_UP` — Exclude); scope đồng nhất mỗi cop, false-positive thấp; khe hở banker's ở tầng hiển thị do review người + §8 phủ. Bỏ unit-test "escape-comment"/"ngoài-scope" (do RuboCop framework lo; scope chứng minh qua lần chạy `rubocop` xanh toàn repo).
- **0.1.0 (2026-06-13):** Bản thảo đầu — ADR-031 (chiều review "tuân AGENTS" hai lớp). Lớp 1: custom RuboCop cop `Decimal/NoFloatInCalculation` + `Decimal/ExplicitRoundingMode` (job `ruby-checks`, scope theo thư mục, inline-disable làm escape). Lớp 2: hook `UserPromptSubmit` bơm `additionalContext` khi gõ `/code-review` + checklist canonical `CONTRIBUTING.md` §8 + checkbox PR template. Khảo sát code: `.to_f` chỉ ở tầng xuất Excel/helper (hợp lệ), tầng tính toán sạch → cop là lưới chống regression. Loại: sửa-prompt-plugin-toàn-cục, bash-grep, project-subagent, checklist-thuần, ép-i18n-trong-B, hook-bơm-PR-create/simplify. Giới hạn: i18n thuộc mục A; không-viết-tắt bất-khả-thi-máy (ADR-024); phủ-6-vai phần lớn ADR-030; Lớp 2 không chặn. Chờ duyệt.
