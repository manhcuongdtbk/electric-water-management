---
title: Chốt demo spec ở Definition-of-Done cho tính năng hướng-khách
version: 0.2.1
date: 2026-06-14
---

# Chốt demo spec ở Definition-of-Done cho tính năng hướng-khách

Thiết kế cho [#357](https://github.com/manhcuongdtbk/electric-water-management/issues/357) — siết quy trình để **không tính năng hướng-khách nào tới PR mà thiếu demo spec**. Phát sinh từ [#355](https://github.com/manhcuongdtbk/electric-water-management/issues/355) (TN1 ship trước engine demo → phải backfill).

> **Mở rộng cho [#379](https://github.com/manhcuongdtbk/electric-water-management/issues/379) (ADR-059):** ba lớp ADR-052 chỉ ép demo **TỒN TẠI**, không ép demo **TỐT**. Mục [Chuẩn "demo tốt" (chất lượng)](#chuẩn-demo-tốt-chất-lượng--adr-059) thêm trục chất lượng — không thay, không trùng ba lớp tồn tại ở trên.

Hạ tầng demo đã có: DSL `DemoRecorder`, `spec/demo/`, seed demo, CI ghi hình ([#343](https://github.com/manhcuongdtbk/electric-water-management/issues/343), ADR-036..041); scaffold `rails g demo:spec` ([#352](https://github.com/manhcuongdtbk/electric-water-management/issues/352), ADR-050/051); gom bộ demo theo delta release ([#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351), ADR-047/048). Spec này KHÔNG thêm năng lực demo mới — chỉ **dịch điểm ép sớm hơn** trong vòng đời.

Liên quan: guardrail bắt-buộc-tồn-tại (ADR-040 trong [tự động hoá demo](2026-06-13-tu-dong-hoa-demo-design.md)); "AI lo cơ học — người giữ gate" (ADR-029 trong [tổng quan SDLC](2026-06-07-sdlc-overview-design.md)); họ guardrail truy vết chiều test (ADR-030 trong [truy vết & quản lý thay đổi](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)); triết lý guardrail tài liệu chạy-luôn (ADR-024 trong [CI spec](2026-06-07-ci-spec-design.md)).

## Vấn đề

Guardrail hiện tại (ADR-040, `check-demo-spec.sh`) ép demo spec **chỉ ở PR-time** và **chỉ khi PR đã gắn nhãn `customer-facing`**. Hai lỗ rơi:

1. **Quên nhãn.** Người quên gắn `customer-facing` ở triage/PR → guardrail im lặng (PR không nhãn = miễn) → tính năng khách-thấy-được tới merge mà không demo.
2. **Thiết kế không nhắc demo.** Spec/plan của tính năng không coi demo là deliverable → demo thành "việc-làm-sau", nhồi sát giờ gửi khách hoặc backfill (đúng ca #355).

Cả hai đều là **ép quá muộn**: tới PR mới phát hiện thiếu, trong khi quyết định "đây là tính năng hướng-khách" đã có từ **khâu thiết kế**. Cần dịch điểm ép về sớm hơn và thêm lưới an toàn không phụ thuộc nhãn người.

## Quyết định tổng quát

Phòng-thủ-theo-lớp: ba lớp bổ trợ, mỗi lớp bắt một lỗ rơi khác nhau. Không lớp nào đứng một mình đủ; cùng nhau khép kín đường từ thiết kế tới PR. Chi tiết quyết định + lý do ở ADR-052.

### Lớp A — Demo spec là DoD trong template & quy trình (quy ước)

Đưa "demo spec" thành **deliverable hiển ngôn của khâu thiết kế** cho tính năng hướng-khách, cùng họ với việc liệt kê test theo chiều:

- **`CONTRIBUTING.md` §9 bước 2 (Phân loại/triage):** thêm một dòng — tính năng **khách-thấy-được → gắn `customer-facing` NGAY khi triage** (không đợi PR); nhãn này kéo theo demo spec là DoD của thiết kế lẫn hiện thực.
- **`CONTRIBUTING.md` §9 mục "Demo spec cho tính năng hướng-khách":** ghi rõ với tính năng `customer-facing`, demo spec là **deliverable của thiết kế** — spec PHẢI khai nó (frontmatter `customer_facing: true` + mục `## Truy vết demo`), giống `## Truy vết chiều test`.
- **`.github/ISSUE_TEMPLATE/change-request.md`:** thêm trường *"Khách có thấy thay đổi này không?"* → nếu có, gắn `customer-facing` ngay khi triage.
- **`.github/pull_request_template.md`:** siết dòng demo sẵn có để trỏ ADR-052 + luật "spec đã khai demo".

Lớp A **không** thêm script — là quy ước + chỗ-ghi. Giá trị: đóng lỗ rơi #2 (thiết kế không nhắc demo) và đẩy nhãn về sớm.

### Lớp B — Guardrail demo-deliverable ở mức spec (chốt từ khâu thiết kế)

Một spec tính năng hướng-khách **tự khai** mình là hướng-khách và **chỉ tên** demo của nó:

- Frontmatter spec thêm `customer_facing: true`.
- Spec kết bằng mục **`## Truy vết demo`** chứa **một** trong hai: tham chiếu tới một file `spec/demo/<x>_demo_spec.rb` (đường dẫn), hoặc `DEFERRED #<issue>` (hoãn có gate, không bỏ im — cùng luật DEFERRED của chiều test).

Script mới **`.github/scripts/check-demo-deliverable.sh`** (+ `check-demo-deliverable.test.sh`), nối vào job `doc-governance` sẵn có và vào vòng chạy cục bộ trước push:

1. Quét mọi spec trong `docs/superpowers/specs/*.md`; lọc spec có frontmatter `customer_facing: true`.
2. Mỗi spec như vậy phải có mục `## Truy vết demo` với khai báo hợp lệ:
   - Nếu chỉ tên `spec/demo/<x>_demo_spec.rb` → file đó **phải tồn tại** (bắt drift đường dẫn/đổi tên).
   - Nếu `DEFERRED` → phải kèm `#<số issue>`.
   - Thiếu mục / mục rỗng / file không tồn tại / DEFERRED thiếu issue → **FAIL-LOUD** (exit 1).
3. **Opt-in:** spec không có `customer_facing: true` thì không bị ràng buộc (như test-dimensions section).

Bash portable (macOS 3.2: while-read, không mapfile/assoc-array), mẫu y hệt `check-test-dimensions.sh`. Đây là điểm ép **sớm nhất** chạy được bằng máy: ngay khi spec hướng-khách vào PR, máy đòi nó trỏ demo.

> Lỗ rơi còn lại của Lớp B: tác giả quên đặt `customer_facing: true` ở frontmatter (giống quên nhãn). Lớp C là lưới hứng ca này ở PR-time.

### Lớp C — Suy luận hướng-khách từ path (lưới an toàn, advisory)

Mở rộng `check-demo-spec.sh` (job `demo-guardrail`): khi PR **không** gắn `customer-facing`, **không** đụng `spec/demo/**`, nhưng **có** đụng path khách-thấy-được → in **cảnh báo to** rồi **exit 0** (không chặn).

- **Tập path khách-thấy-được:** `app/views/**` (UI render) và `app/javascript/controllers/**` (hành vi Stimulus: validate realtime, cascade filter…). Cao-tín-hiệu, ít-nhiễu; cố ý **không** gồm helper/mailer để tránh cảnh báo nổ trên mọi PR.
- **Vì sao advisory, không chặn:** path-inference dễ false-positive (sửa view nội bộ, trang cấu hình admin không cần demo). Chặn cứng sẽ buộc người gắn nhãn-rác để dập CI đỏ → phản tác dụng. Cảnh báo to vẫn nổi đúng ca "quên nhãn" mà không tạo ma sát sai.
- Nhãn `customer-facing` có mặt → hành vi chặn cũ (ADR-040) giữ nguyên, không đổi.

> "Điều kiện xem lại" của ADR-040 chính là gợi ý này; ADR-052 hiện thực nó ở mức advisory và để ngỏ nâng lên chặn nếu dữ liệu cho thấy nhãn hay bị quên.

## Chuẩn "demo tốt" (chất lượng) — ADR-059

Ba lớp trên đóng đường "demo **thiếu**". Chúng **không** chạm tới việc demo **dở**: #363 cho thấy một demo qua hết guardrail + CI mà vẫn lười — nói-trong-caption-mà-không-chỉ-trên-màn-hình, kể sai chuyện khách, diễn nửa-vời thứ medium không kham (trỏ nút "Xuất Excel" — video không dựng được `.xlsx`), và **xanh nhờ may** (recorder flake).

**Sự thật cốt lõi (giữ nguyên, không giấu):** CI bảo đảm demo **chạy**, không bảo đảm demo **hay**. "Hay" là phán đoán con người — **không lint được**. Nên giải pháp KHÔNG phải một check thần kỳ, mà là **đưa chuẩn ra ngoài đầu người + một bước review người thật**, kèm hai lưới đỡ để "tốt" thành đường-dễ-đi-nhất. Ba tầng, chắc dần code → mẫu → quy trình:

### Tầng 1 — Bộ công cụ (code), neo kỹ thuật vào `DemoRecorder` (chắc nhất, tự tái dùng)

Các kỹ thuật làm demo TN1 hay đã thành **primitive tái dùng** của `DemoRecorder` (`spec/support/demo_recorder.rb`) + một quy ước **DOM hook** trên view. Demo sau thừa kế miễn phí — không phải phát minh lại:

- `visit(path, caption:)` — mở thẳng một path (kèm query) để vào đúng màn cần, không phải lái qua filter.
- `click(locator, caption:, confirm:)` — `confirm: true` chấp nhận hộp xác nhận Turbo (`data-turbo-confirm`); driver Playwright mặc định **dismiss** dialog nên thiếu cờ này form không submit (vd "Tính toán lại"). Bài học #363.
- `fill(field, with:, caption:)`, `select(option, from:, caption:)` — nhập/chọn có trỏ + nhịp đọc được.
- `highlight(selector, caption:)` — cuộn một ô/kết quả vào khung + vẽ viền, để thứ caption khẳng định **thấy được trên màn hình** (vd ô −44 sâu trong bảng tính tiền rộng).
- `narrate(caption)` — caption không thao tác, để kể bối cảnh/nhân-quả giữa các bước.
- `unpoint` (riêng tư) — gỡ viền best-effort, `rescue` nuốt lỗi vì click/fill có thể đã điều hướng (chống flake "xanh nhờ may").
- **Quy ước DOM hook `data-*-cp-id`** trên view (vd `data-other-deduction-cp-id`, `data-contact-point-name-id`, `data-total-personnel-cp-id`) — để `highlight` nhắm **đúng ô của đúng đầu mối** thay vì dò text mong manh.

> **Quy ước neo:** cần một kỹ thuật demo mới → **thêm vào `DemoRecorder`/hook DOM**, đừng tự chế tại chỗ trong một spec. Demo sau thừa kế; sửa một chỗ là cả họ được. Danh sách primitive này cũng nằm ở `CONTRIBUTING.md` §9 để tra nhanh.

### Tầng 2 — Demo mẫu (golden example) + scaffold sinh đúng-hình (cụ thể thắng trừu tượng)

`spec/demo/cot_khac_he_so_don_vi_demo_spec.rb` (TN1, đã refine ở #363 qua PR #375/#382) là **DEMO MẪU** của dự án. Checklist Tầng 3 trỏ tới nó cho từng tiêu chí (nhân-quả cùng khung, two-beat reveal cause→effect, narration bám-chuyện-khách, trung thực về medium với ghi chú "Excel để test lo").

Scaffold `rails g demo:spec` (ADR-051, #352) sinh khung **kèm sẵn pattern tốt + pointer TN1**: chỗ trống `highlight` để cho-thấy-kết-quả, narration bám-chuyện, và ghi chú "đừng diễn thứ browser không dựng được (vd Excel)". Demo mới ra đời đã đúng hình. Anti-drift của khung sống ở `spec/generators/demo/spec_generator_spec.rb` (đối chiếu nội dung sinh ra), không phải một bash guardrail riêng.

### Tầng 3 — Checklist 6 tiêu chí + tự-soi-như-khách + gate người (bắt phần phán đoán)

Checklist "demo tốt" (ở `CONTRIBUTING.md` §9 + mục demo của PR template + header `rails g demo:spec` sinh ra — để chuẩn ở repo, không ở đầu người):

1. **Cho thấy, đừng nói** — mọi điều caption khẳng định phải *thấy được* trên màn hình (dùng `highlight`).
2. **Kể đúng chuyện khách** — khớp ví dụ/thế giới thật của khách, không chỉ số đúng.
3. **Diễn kết quả + cái đau được xoá**, không diễn thao tác.
4. **Trung thực với medium** — không diễn thứ browser không dựng (vd `.xlsx`); cái đó để test/file thật lo.
5. **Đủ cung đường khách quan tâm**, không nhồi mọi ngóc ngách/chiều test.
6. **Ổn định** — không "xanh nhờ may" (dùng primitive `confirm:`/`unpoint`-rescue; không đua điều hướng).

**Bước bắt buộc trước gate:** người làm **xem lại bản quay như một khách chưa biết gì**, đối chiếu 6 tiêu chí + so với TN1, và **báo đã soi gì** ở PR. Mắt xích cuối "mãi về sau" là **gate người** soi theo chuẩn — anti-drift CI (ADR-036) chỉ giữ demo *chạy*, không giữ nó *hay*.

## Hiện thực

- `docs/superpowers/specs/2026-06-14-demo-dod-design.md` — spec này (ADR-052).
- `.github/scripts/check-demo-deliverable.sh` + `.test.sh` — Lớp B.
- `.github/scripts/check-demo-spec.sh` — thêm nhánh advisory Lớp C (giữ nguyên đường chặn khi có nhãn). `BASE_SHA`/`HEAD_SHA` đã có sẵn trong env job. Test: `.github/scripts/check-demo-spec.test.sh` (repo git tạm, phủ block + advisory + exempt).
- `.github/workflows/ci.yml` — thêm `check-demo-deliverable.sh` vào danh sách job `doc-governance`.
- `CONTRIBUTING.md` — §9 bước 2 + mục Demo spec (Lớp A).
- `.github/ISSUE_TEMPLATE/change-request.md`, `.github/pull_request_template.md` — Lớp A.
- Vòng chạy cục bộ trước push (CONTRIBUTING/AGENTS đề cập) thêm `check-demo-deliverable`.

Không đụng code ứng dụng end-user → không có chiều test (`CHIEU-...`) mới, không anchor `NV-...` mới. Test của thay đổi này là `check-demo-deliverable.test.sh` (đối chiếu ca pass/fail của script) — chạy ở job `tests`/cục bộ như các `*.test.sh` guardrail khác.

**Chuẩn "demo tốt" (#379, ADR-059) — chủ ý KHÔNG thêm bash guardrail** (chất lượng không lint được):

- `docs/superpowers/specs/2026-06-14-demo-dod-design.md` — mục [Chuẩn "demo tốt"](#chuẩn-demo-tốt-chất-lượng--adr-059) + ADR-059 (spec này).
- `CONTRIBUTING.md` §9 — mục "Chuẩn demo tốt": danh sách primitive `DemoRecorder` + quy ước neo (Tầng 1), pointer TN1 golden example (Tầng 2), checklist 6 tiêu chí + bước tự-soi-như-khách bắt buộc (Tầng 3).
- `.github/pull_request_template.md` — thêm dòng demo: tự-soi-như-khách theo 6 tiêu chí + đối chiếu TN1, báo đã soi gì (Tầng 3).
- `lib/generators/demo/spec/templates/demo_spec.rb.tt` — khung sinh kèm pattern tốt: chỗ trống `highlight`, narration bám-chuyện, ghi chú "đừng diễn thứ browser không dựng (vd Excel)", pointer TN1 + checklist (Tầng 2).
- `spec/generators/demo/spec_generator_spec.rb` — anti-drift: đối chiếu khung sinh ra mang đủ pattern + pointer (thay cho một guardrail bash riêng).

## Quyết định (ADR)

### ADR-052: Chốt demo spec ở Definition-of-Done bằng ba lớp phòng-thủ
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Guardrail ADR-040 ép demo spec chỉ ở PR-time và chỉ khi PR đã gắn nhãn `customer-facing`. Quên nhãn, hoặc thiết kế không coi demo là deliverable, đều dẫn tới tính năng khách-thấy-được tới merge mà thiếu demo (backfill #355). Quyết định "đây là việc hướng-khách" đã có từ khâu thiết kế nhưng chưa được ép ở đó.
- **Quyết định:** Khép kín bằng **ba lớp bổ trợ**: (A) demo spec là **DoD hiển ngôn** trong template Issue/PR + `CONTRIBUTING.md` §9, và nhắc gắn `customer-facing` ngay ở triage; (B) **guardrail mức spec** `check-demo-deliverable.sh` — spec có frontmatter `customer_facing: true` phải khai `## Truy vết demo` trỏ một `spec/demo/*_demo_spec.rb` tồn tại (hoặc `DEFERRED #issue`); (C) **suy luận hướng-khách từ path** (`app/views/**`, `app/javascript/controllers/**`) ở `check-demo-spec.sh` dưới dạng **cảnh báo advisory** (exit 0) cho PR không nhãn. Đường chặn cứng khi-có-nhãn của ADR-040 giữ nguyên.
- **Lý do:** Mỗi lớp bắt một lỗ rơi khác nhau (A: thiết kế quên demo; B: ép sớm nhất chạy được bằng máy, cùng họ check-test-dimensions; C: lưới hứng "quên nhãn/quên flag" mà không false-positive chặn). Tái dùng văn hoá guardrail của dự án (opt-in, FAIL-LOUD, portable bash) thay vì dựng quy trình nặng. Khớp "AI lo cơ học — người giữ gate" (ADR-029): máy đòi *sự khai báo*; người vẫn duyệt *nội dung* demo.
- **Tradeoff:** (+) Đóng cả hai lỗ rơi (quên nhãn, thiết kế quên demo); ép sớm hơn PR-time; lưới C không tạo ma sát sai. (−) Thêm một guardrail + một flag frontmatter phải nuôi; Lớp B vẫn phụ thuộc tác giả đặt flag (giảm nhẹ nhờ Lớp C + nhãn ở triage). Path-inference advisory không *chặn* được ca cố tình bỏ qua (chấp nhận: gate người là chốt cuối).
- **Phương án đã loại:** *Chỉ Lớp A (docs)* — không có ép máy, rơi như hiện tại. *Lớp C chặn cứng* — false-positive trên view nội bộ/trang admin, đẻ nhãn-rác dập CI. *Suy luận hướng-khách hoàn toàn tự động bỏ nhãn người* — mất gate quyết định ở triage (ADR-040 cố ý để người quyết); path là tín hiệu, không phải sự thật. *Gộp ràng buộc demo vào check-test-dimensions* — trộn hai trục (chiều test vs deliverable demo), khó đọc lỗi.
- **Điều kiện xem lại:** Nếu dữ liệu cho thấy `customer-facing`/`customer_facing` vẫn hay bị quên dù đã có ba lớp → cân nhắc nâng Lớp C từ advisory lên **chặn** (có cơ chế opt-out tường minh cho PR nội bộ đụng view), hoặc suy luận flag spec từ path khi tạo spec.

### ADR-059: Chuẩn "demo tốt" — chất lượng demo bằng toolkit + golden example + gate người, không bằng lint
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Ba lớp ADR-052 ép demo **tồn tại** (spec khai, demo trỏ tới, video quay). Chúng không ép demo **tốt**: #363 cho thấy một demo qua hết guardrail + CI mà vẫn lười — nói-trong-caption-không-chỉ-trên-màn, kể sai chuyện khách, diễn thứ medium không kham (trỏ "Xuất Excel" — video không dựng `.xlsx`), xanh-nhờ-may do recorder flake. "Hay" là phán đoán con người, không lint được.
- **Quyết định:** Thêm trục **chất lượng** bằng **ba tầng**, chắc dần code → mẫu → quy trình: **(1) Toolkit** — neo kỹ thuật demo vào primitive `DemoRecorder` + quy ước DOM hook `data-*-cp-id`, ghi danh sách + quy ước "kỹ thuật mới → thêm vào recorder, đừng tự chế" vào `CONTRIBUTING.md` §9; **(2) Golden example** — `spec/demo/cot_khac_he_so_don_vi_demo_spec.rb` (TN1) là demo mẫu, checklist trỏ tới nó, scaffold `rails g demo:spec` sinh khung kèm pattern tốt + pointer TN1 + ghi chú "đừng diễn thứ browser không dựng (vd Excel)"; **(3) Checklist 6 tiêu chí + tự-soi-như-khách + gate người** ở `CONTRIBUTING.md` §9 + PR template + header generator. **Chủ ý KHÔNG thêm bash guardrail cho chất lượng** — quality không lint được; anti-drift duy nhất là generator rspec (khung sinh ra mang đủ pattern).
- **Lý do:** Một demo tốt chỉ "mãi về sau" nếu "tốt" thành đường-dễ-đi-nhất. Code (Tầng 1) làm pattern tốt thành mặc-định tái dùng; mẫu (Tầng 2) làm chuẩn cụ thể-thắng-trừu-tượng; quy trình (Tầng 3) bắt phần phán đoán mà máy không bắt được. Khớp "AI lo cơ học — người giữ gate" (ADR-029) và phân-lớp-theo-mức-chặn-được của ADR-052: tồn tại (máy) · ổn định (cơ giới-một-phần qua primitive) · chất lượng (người).
- **Tradeoff:** (+) Nâng chất demo mà không dựng một check giả-định-lint-được-cái-không-lint-được; tái dùng hạ tầng sẵn (recorder, generator, golden example). (−) Mắt xích cuối vẫn là gate người — kỷ luật, không cưỡng chế được bằng CI; chấp nhận vì đó là **bản chất** của "hay" (nói dối nếu giả vờ lint được).
- **Phương án đã loại:** *Một guardrail chấm điểm "demo tốt"* — không lint được phán đoán; chấm giả tạo cảm giác an toàn sai. *Spec mới riêng* — tách khỏi ADR-052 cùng chủ đề DoD demo, đọc rời rạc; gộp cùng spec, ADR riêng là đủ. *Bỏ Tầng 1/2, chỉ checklist* — checklist suông không tự-thực-thi; thiếu code/mẫu thì "tốt" vẫn là đường-khó-đi (đúng ca #363).
- **Điều kiện xem lại:** Nếu phần *ổn định* (flake "xanh nhờ may") tái diễn dù đã có primitive → cân nhắc lưới cơ giới riêng cho **độ ổn định** (vd chạy lặp demo N lần, hoặc lint recorder) — phần này *cơ giới hoá được*, tách khỏi phần "hay" không lint được.

## Truy vết

- Issue: [#357](https://github.com/manhcuongdtbk/electric-water-management/issues/357) (intake change-request, milestone 1.2.0, không `priority-high`). Phát sinh từ [#355](https://github.com/manhcuongdtbk/electric-water-management/issues/355). Trục chất lượng (ADR-059): [#379](https://github.com/manhcuongdtbk/electric-water-management/issues/379) (change-request, milestone 1.2.0, không `priority-high`), phát sinh từ retro [#363](https://github.com/manhcuongdtbk/electric-water-management/issues/363).
- Liên quan: [#343](https://github.com/manhcuongdtbk/electric-water-management/issues/343) (engine), [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351) (bundle), [#352](https://github.com/manhcuongdtbk/electric-water-management/issues/352) (scaffold); demo TN1 refine [#375](https://github.com/manhcuongdtbk/electric-water-management/pull/375)/[#382](https://github.com/manhcuongdtbk/electric-water-management/pull/382) (recorder primitives + golden example); mở rộng ADR-040.
- Không đụng nghiệp vụ end-user (không anchor `NV-...` mới): đây là tooling/quy trình dev.
- Không có chiều test (`CHIEU-...`): spec quy trình, không phải tính năng nghiệp vụ có ma trận chiều. Test guardrail: `.github/scripts/check-demo-deliverable.test.sh` (đối chiếu pass/fail script). Trục chất lượng (ADR-059) chủ ý không có guardrail bash (không lint được); anti-drift khung demo ở `spec/generators/demo/spec_generator_spec.rb`.

## Lịch sử thay đổi

| Phiên bản | Ngày | Thay đổi |
|---|---|---|
| 0.1.0 | 2026-06-14 | Bản đầu (#357): chốt demo spec ở DoD bằng ba lớp (DoD template/quy trình, guardrail mức spec, suy luận path advisory). Thêm ADR-052. |
| 0.2.0 | 2026-06-14 | Thêm trục chất lượng (#379): mục "Chuẩn demo tốt" ba tầng (toolkit `DemoRecorder` + quy ước neo, TN1 golden example + scaffold sinh đúng-hình, checklist 6 tiêu chí + tự-soi-như-khách + gate người). Thêm ADR-059; chủ ý không thêm guardrail bash (chất lượng không lint được). |
| 0.2.1 | 2026-06-14 | Sửa truy vết: milestone của #357 là 1.2.0 (không phải 1.3.0) — khớp milestone thực tế của issue. |
