---
title: Soạn nháp demo spec có trợ lý AI + scaffold `g demo:spec`
version: 0.1.0
date: 2026-06-14
---

# Soạn nháp demo spec có trợ lý AI + scaffold `g demo:spec`

Thiết kế cho [#352](https://github.com/manhcuongdtbk/electric-water-management/issues/352) — **follow-up** của [#343](https://github.com/manhcuongdtbk/electric-water-management/issues/343) (tự động hoá demo, đã merge `develop`, ships 1.2.0). Hạ tầng #343 đã có: DSL `DemoRecorder`, `spec/demo/`, seed demo, CI job ghi hình + transcode, guardrail bắt-buộc-tồn-tại (ADR-040). Việc còn lại là **giảm ma sát SOẠN nội dung** một demo spec: (1) biến "trợ lý AI soạn nháp demo spec khi làm tính năng hướng-khách" thành **thói quen có ghi**, và (2) một **scaffold** đẻ khung rỗng để khỏi gõ lại boilerplate.

Liên quan: anti-drift "demo là spec xanh-mới-merge" và "KHÔNG sinh mù" (ADR-037 trong [tự động hoá demo](2026-06-13-tu-dong-hoa-demo-design.md)); guardrail bắt-buộc-tồn-tại (ADR-040, cùng spec); "trợ lý AI lo cơ học — người giữ gate" (ADR-029 trong [tổng quan SDLC](2026-06-07-sdlc-overview-design.md)); anchor `NV-...` và truy vết (ADR-013/014 trong [truy vết & quản lý thay đổi](2026-06-08-truy-vet-quan-ly-thay-doi-design.md)).

> **Cách đọc:** quyết định viết theo **ADR** (Trạng thái → Bối cảnh → Quyết định → Lý do → Tradeoff → Phương án đã loại → Điều kiện xem lại). ADR đánh số toàn cục; spec này thêm **ADR-050 … ADR-051**. (Khoảng 047–049 dành cho [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351) chạy song song — số chưa-merge vô hình với `develop`, đặt số theo nhánh/PR đang mở; max trên `develop` = 046.)

## Goals

- **Soạn demo spec như một phần của việc làm feature** — giống viết test: khi làm tính năng hướng-khách, trợ lý AI soạn nháp hành trình + caption tiếng Việt từ acceptance criteria `NV-...` và UI thật.
- **Khung rỗng chạy được trong vài giây** — `rails g demo:spec <feature>` đẻ boilerplate đúng cấu trúc (`type: :demo`, DSL, seed/teardown, chỗ gắn anchor `NV-...`, caption TODO) để tác giả chỉ điền hành trình.
- **Giữ "người giữ gate"** — AI **tác giả nháp**, người **duyệt video** trước khi tới khách; demo vẫn **xanh-mới-merge** (anti-drift). KHÔNG có đường máy lén sinh-rồi-gửi.
- **Không trùng, dễ nuôi** — gom phần seed/teardown lặp của demo spec vào một shared context để scaffold và spec hiện có dùng chung.

## Non-Goals (cố ý KHÔNG làm)

- **Generator "thông minh" đọc acceptance criteria để tự điền bước/caption** — lệch về phía "máy soạn hành trình", đúng thất bại mà ADR-037 loại; caption vẫn chưa-duyệt (ADR-051).
- **CI tự-soạn demo khi thiếu rồi commit** — caption chưa qua người, vi phạm "người giữ gate" + "không sinh mù" (ADR-050).
- **Đổi guardrail ADR-040** — guardrail vẫn ép *sự tồn tại* demo spec cho PR hướng-khách; việc này lo phần *soạn nội dung*, không thay nó.
- **Crawl UI tự bấm / biến đổi system spec thành demo** — đã loại ở ADR-037 (#343).
- **Đụng cơ chế gom/bundle clip ở release** — đó là phạm vi [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351).
- **Skill Claude Code riêng để nhắc soạn demo** — cân nhắc rồi loại vòng này (nặng, gắn một công cụ); để dành nếu thói quen hay rơi (xem ADR-050 "Điều kiện xem lại").

## Bối cảnh & hiện trạng

- `DemoRecorder` (DSL `visit`/`fill`/`click`, mỗi bước `caption:`) ở `spec/support/demo_recorder.rb`; driver Playwright ở `spec/support/demo_recorder_config.rb`; smoke demo ở `spec/demo/smoke_demo_spec.rb`.
- `spec/demo/smoke_demo_spec.rb` chứa một **hành trình có seed**: tắt transactional tests, `load db/seeds/demo.rb` trong `before(:each)`, teardown một danh sách model trong `after(:each)` (vì demo lái Playwright thật → data phải **commit** để các kết nối DB riêng của Puma thấy). **Khối seed/teardown này sẽ bị scaffold nhân bản** nếu để nguyên inline.
- `config.autoload_lib(ignore: %w[assets tasks rubocop])` (`config/application.rb`) — **không** bỏ qua `generators`. Một generator ở `lib/generators/**` sẽ làm `rails zeitwerk:check` (CI chạy) **đỏ** vì hằng số không khớp đường dẫn autoload-root `lib`.
- Anchor `NV-...` ở `docs/V2_XAC_NHAN_NGHIEP_VU.md`; demo spec gắn anchor qua metadata example (đã nêu ở #343 spec §1) nhưng smoke spec chưa dùng (nó là smoke, không phải demo tính năng).

## Kiến trúc & thành phần

### 1. Thói quen soạn nháp có trợ lý AI (ADR-050)
- **Canonical (tài liệu quyết định):** ADR-050 trong spec này.
- **Quy trình cho người (tool-neutral):** thêm vào `CONTRIBUTING.md` §9 ("Quản lý thay đổi & truy vết", bước 4 *Hiện thực + test*) một ghi chú: với tính năng **hướng-khách**, soạn demo spec (hành trình + caption tiếng Việt từ `NV-...` + UI) **cùng lúc với code/test**; chạy `rails g demo:spec <feature>` lấy khung; người duyệt video; guardrail ADR-040 ép sự tồn tại.
- **Ánh xạ Claude Code (cơ học):** thêm một bullet vào `CONTRIBUTING.md` §8 (lớp ánh xạ ADR-029) — trợ lý AI soạn nháp hành trình + caption khi PR hướng-khách.
- **Nhắc nhẹ:** một dòng checklist trong `.github/pull_request_template.md` (chỉ áp khi PR hướng-khách).

### 2. Generator `rails g demo:spec <feature>` (ADR-051)
- `lib/generators/demo/spec/spec_generator.rb` — `Demo::SpecGenerator < Rails::Generators::NamedBase`; `source_root` trỏ `templates/`; một method `create_demo_spec` gọi `template "demo_spec.rb.tt", File.join("spec/demo", "#{file_name}_demo_spec.rb")`.
- `lib/generators/demo/spec/templates/demo_spec.rb.tt` — khung **rỗng nhưng chạy được**: `require "rails_helper"`, `RSpec.describe "Demo: <human_name>", type: :demo`, `include_context "demo seeded world"`, một `it` đăng nhập `demo_admin` (đủ để ghi ra video), `demo_nv: %w[NV-TODO]` placeholder, và các dòng `demo.visit/fill/click(..., caption: "TODO: ...")` mẫu kèm comment hướng dẫn (xoá phần thừa, điền caption từ `NV-...`).
- **Không đọc** acceptance criteria — tác giả/AI điền hành trình (anti "sinh mù").
- `config/application.rb` — thêm `generators` vào `autoload_lib(ignore:)` để `zeitwerk:check` xanh.

### 3. Shared context "demo seeded world"
- `spec/support/shared_contexts/demo_seeded_world.rb` — gom `self.use_transactional_tests = false` + `before(:each) { load db/seeds/demo.rb }` + teardown danh sách model; kèm comment giải thích vì sao phải commit (Playwright + Puma kết nối riêng).
- Refactor `spec/demo/smoke_demo_spec.rb` (khối "seeded journey") để `include_context "demo seeded world"` — chứng minh shared context chạy đúng; template dùng cùng context (DRY, không lặp danh sách model dễ vỡ).
- Tự nạp qua glob sẵn có `spec/support/**/*.rb` trong `spec/rails_helper.rb`.

### 4. Test cho generator
- `spec/generators/demo/spec_generator_spec.rb` — chạy generator vào thư mục tạm (`Demo::SpecGenerator.start([name], destination_root: tmp)`) và assert: tạo đúng file `spec/demo/<file_name>_demo_spec.rb`; nội dung chứa `type: :demo`, `DemoRecorder.new(self)`, `include_context "demo seeded world"`, `demo_nv:`, `NV-`, `caption:`; humanize đúng tiêu đề `describe` và underscore đúng tên file (ví dụ `chi-so-dau-moi` → `chi_so_dau_moi_demo_spec.rb`); và **Ruby sinh ra parse được** (`RubyVM::InstructionSequence.compile(content)` không raise). Test này nằm ngoài `spec/demo` nên chạy ở job `tests` thường (không cần Playwright).

## Quyết định (ADR)

### ADR-050: Soạn nháp demo spec là một phần của việc làm tính năng hướng-khách (thói quen có ghi)
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Hạ tầng #343 đã đủ để soạn demo spec "ngay hôm nay", và guardrail ADR-040 ép *sự tồn tại*. Nhưng *soạn nội dung* (hành trình + caption tiếng Việt sát nghiệp vụ) vẫn là việc tay; nếu không có thói quen rõ, demo spec dễ thành việc-làm-sau, sơ sài, hoặc nhồi sát giờ gửi khách. Cần một cách làm cho việc soạn nháp tự nhiên như viết test, mà **không** vượt sang sinh-mù/tự-gửi.
- **Quyết định:** Khi triển khai một tính năng **hướng-khách**, **trợ lý AI soạn nháp demo spec** (hành trình + caption tiếng Việt suy ra từ acceptance criteria `NV-...` + UI thật) **như một phần của việc làm feature**, song song với code/test. Ghi canonical ở ADR này; quy trình cho người ở `CONTRIBUTING.md` §9 (trung lập công cụ); ánh xạ Claude Code ở §8; nhắc nhẹ một dòng ở PR template. **Người duyệt video** trước khi tới khách; demo **xanh-mới-merge** (anti-drift). **CI KHÔNG tự-soạn-rồi-commit.**
- **Lý do:** Khớp "AI lo cơ học — người giữ gate" (ADR-029): AI làm phần soạn nháp tốn-công-cơ-học, người giữ hai gate đã có (xanh-mới-merge của máy + duyệt video của người). Ghi ở CONTRIBUTING khớp mô hình quản trị tài liệu (một nơi canonical, nơi khác trỏ về) và tái dùng văn hoá guardrail thay vì dựng quy trình nặng.
- **Tradeoff:** (+) Demo spec thành thói quen cùng-nhịp với feature, ít rơi rớt, caption do người duyệt. (−) Phụ thuộc thói quen được làm theo (giảm nhẹ vì guardrail ADR-040 vẫn ép tồn tại + người gắn nhãn hướng-khách ở triage).
- **Phương án đã loại:** *Skill Claude Code riêng nhắc soạn demo* — nhắc chủ động hơn nhưng nặng nuôi và gắn một công cụ (đội nay chỉ Claude Code); để dành. *Chỉ một dòng checklist PR template* — thiếu phần kể "vì sao/làm sao", guidance yếu. *CI tự-soạn-và-commit khi thiếu* — caption chưa-duyệt, vi phạm "người giữ gate" + sinh-mù (ADR-037).
- **Điều kiện xem lại:** Nếu thói quen hay rơi dù đã có guardrail + PR template → cân nhắc dựng skill Claude Code chủ động kích hoạt khi làm feature hướng-khách.

### ADR-051: Scaffold `g demo:spec` đẻ khung RỖNG (không đọc acceptance criteria)
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Kể cả khi đã thành thói quen, mỗi demo spec vẫn lặp boilerplate dễ sai: `type: :demo`, khởi tạo recorder, khối seed/teardown (commit để Playwright thấy), chỗ gắn anchor `NV-...`, dạng gọi DSL. Gõ tay lặp lại tốn công và dễ đặt sai anchor. Câu hỏi: có nên làm generator không, và "thông minh" tới đâu?
- **Quyết định:** Cung cấp `rails g demo:spec <feature>` đẻ **khung rỗng nhưng chạy được**: boilerplate DSL `DemoRecorder`, `include_context "demo seeded world"`, caption TODO, placeholder metadata `demo_nv: %w[NV-TODO]`, comment hướng dẫn. **KHÔNG** đọc acceptance criteria, **KHÔNG** tự điền hành trình. Thêm `generators` vào `autoload_lib(ignore:)` để `zeitwerk:check` xanh. Gom seed/teardown vào shared context để template + smoke spec dùng chung.
- **Lý do:** Bỏ được ma sát boilerplate và **đảm bảo cấu trúc + chỗ-gắn-anchor đúng** (giá trị thật của scaffold), trong khi để hành trình + caption cho người/AI — đứng tránh xa sinh-mù (ADR-037). Khung rỗng *chạy được* (đăng nhập + ghi video) nên `g demo:spec` ra ngay thứ xanh, tác giả chỉ điền.
- **Tradeoff:** (+) Hết gõ boilerplate, anchor đặt đúng chỗ, khung xanh ngay. (−) Không tiết kiệm phần "nghĩ" hành trình/caption (đúng chủ đích); thêm một generator phải nuôi (nhỏ).
- **Phương án đã loại:** *Generator thông minh đọc `NV-...` tự điền bước/caption* — lệch về máy-soạn-hành-trình (thất bại ADR-037), caption vẫn chưa-duyệt. *Không scaffold, chỉ template-bằng-ví-dụ* — mất đảm bảo boilerplate, dễ đặt sai/sót anchor, dễ lệch khối seed/teardown.
- **Điều kiện xem lại:** Nếu sau này muốn điểm-khởi-đầu giàu hơn, generator có thể **liệt kê các anchor `NV-...` của tính năng dưới dạng comment** (không tự điền thành bước) để tác giả tham chiếu nhanh.

## Truy vết

- Issue: [#352](https://github.com/manhcuongdtbk/electric-water-management/issues/352) (intake change-request, follow-up #343). Song song: [#351](https://github.com/manhcuongdtbk/electric-water-management/issues/351).
- Generator có test: `spec/generators/demo/spec_generator_spec.rb` (tạo file, nội dung đúng, Ruby parse được).
- Không đụng nghiệp vụ end-user (không anchor `NV-...` mới): đây là tooling/quy trình dev. Demo spec **do generator đẻ ra** mới mang anchor `NV-...` (placeholder `NV-TODO` để tác giả điền) — giữ truy vết xuôi tới `docs/V2_XAC_NHAN_NGHIEP_VU.md` cho từng tính năng.
- Không có chiều test (`CHIEU-...`): spec tooling, không phải tính năng nghiệp vụ có ma trận chiều.

## Lịch sử thay đổi

| Phiên bản | Ngày | Thay đổi |
|---|---|---|
| 0.1.0 | 2026-06-14 | Bản đầu (#352): thói quen soạn nháp demo spec có trợ lý AI + scaffold `g demo:spec` đẻ khung rỗng. Thêm ADR-050, ADR-051. |
