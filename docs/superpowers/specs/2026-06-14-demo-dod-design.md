---
title: Chốt demo spec ở Definition-of-Done cho tính năng hướng-khách
version: 0.1.0
date: 2026-06-14
---

# Chốt demo spec ở Definition-of-Done cho tính năng hướng-khách

Thiết kế cho [#357](https://github.com/manhcuongdtbk/electric-water-management/issues/357) — siết quy trình để **không tính năng hướng-khách nào tới PR mà thiếu demo spec**. Phát sinh từ [#355](https://github.com/manhcuongdtbk/electric-water-management/issues/355) (TN1 ship trước engine demo → phải backfill).

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

## Hiện thực

- `docs/superpowers/specs/2026-06-14-demo-dod-design.md` — spec này (ADR-052).
- `.github/scripts/check-demo-deliverable.sh` + `.test.sh` — Lớp B.
- `.github/scripts/check-demo-spec.sh` — thêm nhánh advisory Lớp C (giữ nguyên đường chặn khi có nhãn). `BASE_SHA`/`HEAD_SHA` đã có sẵn trong env job. Test: `.github/scripts/check-demo-spec.test.sh` (repo git tạm, phủ block + advisory + exempt).
- `.github/workflows/ci.yml` — thêm `check-demo-deliverable.sh` vào danh sách job `doc-governance`.
- `CONTRIBUTING.md` — §9 bước 2 + mục Demo spec (Lớp A).
- `.github/ISSUE_TEMPLATE/change-request.md`, `.github/pull_request_template.md` — Lớp A.
- Vòng chạy cục bộ trước push (CONTRIBUTING/AGENTS đề cập) thêm `check-demo-deliverable`.

Không đụng code ứng dụng end-user → không có chiều test (`CHIEU-...`) mới, không anchor `NV-...` mới. Test của thay đổi này là `check-demo-deliverable.test.sh` (đối chiếu ca pass/fail của script) — chạy ở job `tests`/cục bộ như các `*.test.sh` guardrail khác.

## Quyết định (ADR)

### ADR-052: Chốt demo spec ở Definition-of-Done bằng ba lớp phòng-thủ
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Guardrail ADR-040 ép demo spec chỉ ở PR-time và chỉ khi PR đã gắn nhãn `customer-facing`. Quên nhãn, hoặc thiết kế không coi demo là deliverable, đều dẫn tới tính năng khách-thấy-được tới merge mà thiếu demo (backfill #355). Quyết định "đây là việc hướng-khách" đã có từ khâu thiết kế nhưng chưa được ép ở đó.
- **Quyết định:** Khép kín bằng **ba lớp bổ trợ**: (A) demo spec là **DoD hiển ngôn** trong template Issue/PR + `CONTRIBUTING.md` §9, và nhắc gắn `customer-facing` ngay ở triage; (B) **guardrail mức spec** `check-demo-deliverable.sh` — spec có frontmatter `customer_facing: true` phải khai `## Truy vết demo` trỏ một `spec/demo/*_demo_spec.rb` tồn tại (hoặc `DEFERRED #issue`); (C) **suy luận hướng-khách từ path** (`app/views/**`, `app/javascript/controllers/**`) ở `check-demo-spec.sh` dưới dạng **cảnh báo advisory** (exit 0) cho PR không nhãn. Đường chặn cứng khi-có-nhãn của ADR-040 giữ nguyên.
- **Lý do:** Mỗi lớp bắt một lỗ rơi khác nhau (A: thiết kế quên demo; B: ép sớm nhất chạy được bằng máy, cùng họ check-test-dimensions; C: lưới hứng "quên nhãn/quên flag" mà không false-positive chặn). Tái dùng văn hoá guardrail của dự án (opt-in, FAIL-LOUD, portable bash) thay vì dựng quy trình nặng. Khớp "AI lo cơ học — người giữ gate" (ADR-029): máy đòi *sự khai báo*; người vẫn duyệt *nội dung* demo.
- **Tradeoff:** (+) Đóng cả hai lỗ rơi (quên nhãn, thiết kế quên demo); ép sớm hơn PR-time; lưới C không tạo ma sát sai. (−) Thêm một guardrail + một flag frontmatter phải nuôi; Lớp B vẫn phụ thuộc tác giả đặt flag (giảm nhẹ nhờ Lớp C + nhãn ở triage). Path-inference advisory không *chặn* được ca cố tình bỏ qua (chấp nhận: gate người là chốt cuối).
- **Phương án đã loại:** *Chỉ Lớp A (docs)* — không có ép máy, rơi như hiện tại. *Lớp C chặn cứng* — false-positive trên view nội bộ/trang admin, đẻ nhãn-rác dập CI. *Suy luận hướng-khách hoàn toàn tự động bỏ nhãn người* — mất gate quyết định ở triage (ADR-040 cố ý để người quyết); path là tín hiệu, không phải sự thật. *Gộp ràng buộc demo vào check-test-dimensions* — trộn hai trục (chiều test vs deliverable demo), khó đọc lỗi.
- **Điều kiện xem lại:** Nếu dữ liệu cho thấy `customer-facing`/`customer_facing` vẫn hay bị quên dù đã có ba lớp → cân nhắc nâng Lớp C từ advisory lên **chặn** (có cơ chế opt-out tường minh cho PR nội bộ đụng view), hoặc suy luận flag spec từ path khi tạo spec.

## Truy vết

- Issue: [#357](https://github.com/manhcuongdtbk/electric-water-management/issues/357) (intake change-request, milestone 1.3.0, không `priority-high`). Phát sinh từ [#355](https://github.com/manhcuongdtbk/electric-water-management/issues/355).
- Liên quan: [#343](https://github.com/manhcuongdtbk/electric-water-management/issues/343) (engine), [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351) (bundle), [#352](https://github.com/manhcuongdtbk/electric-water-management/issues/352) (scaffold); mở rộng ADR-040.
- Không đụng nghiệp vụ end-user (không anchor `NV-...` mới): đây là tooling/quy trình dev.
- Không có chiều test (`CHIEU-...`): spec quy trình, không phải tính năng nghiệp vụ có ma trận chiều. Test guardrail: `.github/scripts/check-demo-deliverable.test.sh` (đối chiếu pass/fail script).

## Lịch sử thay đổi

| Phiên bản | Ngày | Thay đổi |
|---|---|---|
| 0.1.0 | 2026-06-14 | Bản đầu (#357): chốt demo spec ở DoD bằng ba lớp (DoD template/quy trình, guardrail mức spec, suy luận path advisory). Thêm ADR-052. |
