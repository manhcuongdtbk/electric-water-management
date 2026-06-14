---
title: Mutation testing cho lõi tính tiền/điện (harness tự viết)
version: 0.2.0
date: 2026-06-14
---

# Mutation testing cho lõi tính tiền/điện (harness tự viết)

Thiết kế cho [#358](https://github.com/manhcuongdtbk/electric-water-management/issues/358) — bổ khuyết của coverage dòng/nhánh (SimpleCov, [#360](https://github.com/manhcuongdtbk/electric-water-management/issues/360), đã merge). Coverage chỉ chứng minh code **được chạy**, KHÔNG chứng minh assertion **bắt được sai lệch**. Lõi tính tiền/điện (`CalculationOrchestrator` → `LossCalculator`, `PumpAllocationCalculator`, `SummaryCalculator`) là nơi **sai một li đi một dặm** về tài chính: một test chỉ kiểm "tổng đúng" mà không kiểm từng đầu mối sẽ để lọt lỗi đổi `+`↔`-`, `*`↔`/`, sai mẫu số hệ số, hay rớt `:half_up`. **Mutation testing** chèn đúng những đột biến đó rồi chạy lại test: mutant **sống** = lỗ hổng assertion cần bổ test.

Liên quan: SimpleCov (ADR đã merge #360); role-based coverage [#359](https://github.com/manhcuongdtbk/electric-water-management/issues/359) chạy song song; quy ước test bám chiều-test ([#327]/ADR-030) và 6 vai trò (`docs/V2_HANH_VI_HE_THONG.md`).

> **Cách đọc:** quyết định viết theo **ADR** (Trạng thái → Bối cảnh → Quyết định → Lý do → Tradeoff → Phương án đã loại → Điều kiện xem lại). ADR đánh số toàn cục; spec này thêm **ADR-056**. (Dải 054/055 dự kiến cho #358 đã bị chiếm trước: 054 ở [#332](https://github.com/manhcuongdtbk/electric-water-management/issues/332) (PR #364 đang mở), 055 ở #367 (đã merge `develop`); 052/049 do #357/[#334] chiếm trên nhánh chưa-merge. `develop` hiện max = 055, các PR đang mở max = 054 → lấy **056** cho sạch. Số chưa-merge vô hình với `develop` nên đặt theo nhánh/PR đang mở; `check-adr-numbering` bắt nếu trùng.)

## Goals

- **Bắt assertion yếu ở lõi tài chính** — đo bằng đột biến: với mỗi đột biến chèn vào lõi tính toán, ít nhất một test phải đỏ. Mutant sống → có chỗ test không kiểm, phải bổ.
- **Free + không phụ thuộc thứ đã chết** — không tốn phí license, chạy được ngay trên Ruby 3.4.3/Rails 8, và **không thể bị upstream bỏ rơi** (mình làm chủ công cụ).
- **Khoanh đúng lõi, chạy định kỳ** — chỉ phủ vài class tính toán thuần (không phủ cả app — quá đắt); chạy **thủ công/định kỳ** (`rake mutation:core`), KHÔNG gắn vào job `tests` mỗi PR.
- **Báo cáo đọc được, review được** — liệt kê mutant sống kèm `file:line` + nội dung đổi; mutant tương đương được loại minh bạch qua danh sách bỏ qua có lý do.

## Non-Goals (cố ý KHÔNG làm)

- **Dùng gem `mutant`** — công cụ tốt nhất cho Ruby nhưng repo private nên cần subscription trả phí (~250 USD/năm/ghế); owner chưa muốn chi (xem ADR-056 "Phương án đã loại" + "Điều kiện xem lại"). Để dành làm đường nâng cấp.
- **Dùng fork free (`mutest`/`mutiny`/`mentat`/`crude-mutant`)** — đều bỏ hoang 2016–2019, gần như chắc chắn không chạy trên Ruby 3.4.3. Loại.
- **Engine mutation đầy đủ tính năng** — KHÔNG cố sánh `mutant` (phân tích AST sâu, tự dedup mutant tương đương, sinh mutant cho mọi cấu trúc). Harness này có **catalog toán tử hữu hạn** nhắm đúng nhóm lỗi tài chính, đủ cho lõi hẹp.
- **Gắn vào CI mỗi PR** — quá chậm (10–30 phút), không hợp lệ làm cổng chặn PR. Chỉ tùy chọn một job `workflow_dispatch` chạy tay.
- **Phủ ngoài lõi tính toán** — controller/view/model có persistence không vào phạm vi vòng này (mở rộng sau nếu cần).
- **Giết sạch 100% survivor trong PR này** — DoD là harness chạy được + baseline + giết các survivor **giá trị cao**; phần còn lại ghi follow-up (tránh phình PR).

## Bối cảnh & hiện trạng

### Lõi tính toán (subject)

Luồng (đọc `app/services/`):

- `CalculationOrchestrator` — điều phối trong một transaction: `LossCalculator` → `LossSnapshotWriter` → `PumpAllocationCalculator` → `SummaryCalculator`; gom kết quả + cảnh báo.
- `LossCalculator` — phân bổ tổn hao: `C = A − B` (A = công tơ tổng, B = sử dụng chịu tổn hao), mỗi công tơ nhận `usage × C / B`. BigDecimal.
- `PumpAllocationCalculator` — phân bổ bơm `D`: phần `fixed_percentage` (`D × %/100`) và phần hệ số (`còn lại × trọng số / tổng trọng số`, trọng số theo quân số). BigDecimal.
- `SummaryCalculator` — tổng hợp mỗi đầu mối: tiêu chuẩn, các khoản trừ (tiết kiệm, tổn hao, công cộng chia/đơn vị, **"Khác"** theo `other_type` fixed/coefficient/unit_coefficient), chênh lệch, thiếu/thừa, thành tiền. BigDecimal + làm tròn `:half_up` khi hiển thị.

Các class hỗ trợ `ZoneQuery` (gom usage), `LossSnapshotWriter` (ghi snapshot) **để dành mở rộng**, chưa vào phạm vi vòng này (xem ADR-056).

### Ràng buộc môi trường

- Ruby **3.4.3**, Rails 8. Mọi gem mutation free đều quá cũ cho stack này.
- `Ripper` là thư viện **chuẩn** của Ruby (không cần gem) — tokenize được mã Ruby kèm vị trí, phân biệt `:on_op`/`:on_int`/`:on_kw` với `:on_tstring_content`/`:on_comment`. Đây là nền để đột biến **không bao giờ đụng chuỗi/comment**.
- Test lõi chạy qua `bin/docker rspec` (RAILS_ENV=test). Harness gọi `rspec` đúng spec của subject, không chạy cả suite mỗi mutant.

## Kiến trúc & thành phần

### 1. Cơ chế đột biến (Ripper, chỉ stdlib)

Vòng lặp cho mỗi subject:

1. **Sinh mutant.** Đọc file nguồn → `Ripper.lex` → với mỗi token khớp catalog (mục 2), tạo một *mutant* = (file, vị trí token, token gốc → token thay). Bỏ qua token trong chuỗi/comment (loại theo `:on_*` type) và các vị trí trong danh sách bỏ qua (mục 4).
2. **Áp & thử.** Ghi đè file bằng bản đã thay token tại đúng span → chạy **spec của subject đó** với `--fail-fast` → đỏ ⇒ mutant **killed**; xanh ⇒ **survived**. **Luôn khôi phục** file gốc (kể cả khi rspec lỗi/đột biến gây syntax sai — coi như killed).
3. **Báo cáo.** Tổng hợp: tổng mutant, killed, survived, ignored(equivalent); liệt kê **survivor** kèm `file:line` + `gốc → thay`.

> Khôi phục an toàn: harness lưu nội dung gốc trong bộ nhớ và `ensure` ghi lại; chỉ đột biến **một** mutant tại một thời điểm (không chồng đột biến).

### 2. Catalog toán tử đột biến

Nhắm đúng các kiểu "sai một li" tài chính:

| Nhóm | Đột biến | Bắt lỗi gì |
|---|---|---|
| Số học | `+`↔`-`, `*`↔`/` | đảo dấu/đảo nhân-chia trong phân bổ tổn hao, bơm, thành tiền |
| Làm tròn | `:half_up`→`:half_even`; bỏ tham số mode | test có khóa đúng ROUND_HALF_UP không (quy tắc dự án) |
| So sánh/biên | `<`↔`<=`, `>`↔`>=`, `==`↔`!=` | sai biên thiếu/thừa, nhánh zero |
| Hằng số | literal `n`→`n+1`; `n`→`0` | test có chốt đúng mẫu số `100`, hệ số, hằng |
| Điều kiện/logic | `if`↔`unless`; `&&`↔`||`; đảo `zero?` | nhánh `C.zero?`, gộp/tách điều kiện |

Catalog khai trong code (English), dễ thêm operator sau.

### 3. Phạm vi & ánh xạ spec

Bốn subject lõi (ADR-056), map cứng subject → spec trong một file config (`config/mutation.yml` hoặc hằng trong rake task):

| Subject | Spec chạy khi đột biến subject này |
|---|---|
| `app/services/calculation_orchestrator.rb` | `spec/services/calculation_orchestrator_spec.rb` |
| `app/services/loss_calculator.rb` | `spec/services/loss_calculator_spec.rb` |
| `app/services/pump_allocation_calculator.rb` | `spec/services/pump_allocation_calculator_spec.rb` |
| `app/services/summary_calculator.rb` | `spec/services/summary_calculator_spec.rb` |

Chạy hẹp (chỉ spec liên quan + `--fail-fast`) để tổng thời gian định kỳ ở mức chấp nhận. (Đường dẫn spec thực tế chốt ở bước plan — nếu tên khác sẽ map đúng theo cây `spec/`.)

### 4. Mutant tương đương (equivalent)

Một số đột biến **không đổi hành vi** (vd `x * 1` → `x / 1`, hoặc nhánh chết) ⇒ sống giả. Danh sách bỏ qua `config/mutation_ignores.yml`: mỗi mục `{file, line, from, to, reason}` — harness loại khỏi tập sinh và đếm vào "ignored". Minh bạch, review được; thêm mục là một quyết định có ghi lý do, không phải tắt âm thầm.

### 5. Cấu trúc code & cách chạy

- `lib/mutation/` — `Mutation::Operators` (catalog trên nền Ripper), `Mutation::Runner` (vòng áp & thử), `Mutation::Report`. Code/log **tiếng Anh**.
- `lib/tasks/mutation.rake` — `rake mutation:core` chạy toàn bộ lõi; `rake mutation:core[loss_calculator]` chạy một subject. In report cuối.
- **CI:** KHÔNG vào job `tests`. Tùy chọn một job `workflow_dispatch` (`.github/workflows/mutation.yml`) để chạy tay khi cần — không chặn PR (chốt bật/không ở bước plan; mặc định để rake chạy tay trước, thêm workflow sau nếu thấy cần).
- **autoload:** `config/application.rb` có `config.autoload_lib(ignore: %w[assets tasks ...])`. `lib/mutation/**` là mã chạy qua rake, không cần là hằng autoload-root — đặt sao cho `zeitwerk:check` (CI) **không đỏ** (theo cách `lib/tasks` đã được ignore; nếu cần thêm `mutation` vào danh sách ignore thì làm ở plan, kèm lý do).

### 6. Definition of Done (PR này)

- Harness chạy thật trên Ruby 3.4.3 trong Docker (`bin/docker exec app bash -lc "RAILS_ENV=test bin/rails runner ..."` / `rake`), in được report.
- **Một lần chạy baseline** trên 4 subject; số liệu (tổng/killed/survived/ignored) ghi vào mục "Lịch sử thay đổi" hoặc một phụ lục baseline của spec.
- Survivor **giá trị cao** (nhóm số học/làm tròn/hằng số ở `LossCalculator`/`PumpAllocationCalculator`/`SummaryCalculator`): **bổ test giết ngay trong PR**. Survivor còn lại (ít rủi ro, hoặc cần refactor lớn): ghi **follow-up** (Issue), không phình PR.
- `bin/docker rspec` xanh; doc-governance guardrails cục bộ pass.

## Quyết định (ADR)

### ADR-056: Mutation testing lõi tính toán bằng harness tự viết (Ripper), không dùng `mutant` trả phí
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Coverage dòng/nhánh (SimpleCov #360) không bắt assertion yếu. Lõi tính tiền/điện sai một li đi một dặm về tài chính → cần mutation testing. Công cụ Ruby duy nhất còn bảo trì là `mutant`, nhưng repo **private** ⇒ cần subscription trả phí (~250 USD/năm/ghế, ép qua gem `mutant-license`); owner **chưa muốn chi**. Mọi fork free (`mutest` 2019, `mutiny`/`mentat` 2016, `crude-mutant` 2019) đã bỏ hoang, không tương thích Ruby 3.4.3. `moots` mới 1 commit, chưa kiểm chứng. Phạm vi cần phủ rất hẹp (4 class tính toán thuần).
- **Quyết định:** Viết **harness mutation tối giản, do dự án sở hữu**, dùng **`Ripper`** (stdlib) tokenize để đột biến an toàn (không đụng chuỗi/comment). **Catalog toán tử hữu hạn** nhắm lỗi tài chính (số học, làm tròn `:half_up`, so sánh/biên, hằng số, điều kiện/logic). **Phạm vi 4 subject lõi**: `CalculationOrchestrator`, `LossCalculator`, `PumpAllocationCalculator`, `SummaryCalculator`; map cứng subject→spec, chạy hẹp `--fail-fast`. Chạy **thủ công/định kỳ** qua `rake mutation:core`, **KHÔNG** gắn job `tests` mỗi PR. Mutant tương đương loại qua `config/mutation_ignores.yml` có lý do. Code/log tiếng Anh.
- **Lý do:** Là cách duy nhất thỏa **cả** "free" lẫn "không phụ thuộc thứ đã chết" — vì mình làm chủ, không thể bị upstream bỏ rơi và chạy được trên stack hiện tại. Phạm vi hẹp khiến catalog hữu hạn vẫn đủ bắt nhóm lỗi đáng sợ nhất. Hợp **văn hóa tự-viết-guardrail** của dự án (`check-adr-numbering.sh`, recorder demo, các script doc-governance). `Ripper` stdlib tránh thêm phụ thuộc và tránh đột biến vào chuỗi/comment.
- **Tradeoff:** (+) free vĩnh viễn, chạy ngay trên Ruby 3.4.3, nhắm đúng lõi tài chính, làm chủ hoàn toàn. (−) không đầy đủ/tinh vi như `mutant` (không phân tích AST sâu, không tự dedup mutant tương đương → phải nuôi ignore-list và catalog thủ công); chỉ phủ lõi hẹp.
- **Phương án đã loại:** **`mutant` (trả phí)** — tốt nhất nhưng owner chưa muốn chi; để dành nâng cấp. **Fork free** — đã chết, không chạy Ruby 3.4.3. **`moots`** — đồ chơi 1 commit, chưa kiểm chứng. **`mutator_rails`** (2023, MIT) — ít chết nhất nhưng 3 năm không bảo trì, rủi ro hỏng trên 3.4 mà chẳng hơn harness tự viết bao nhiêu. **Gắn CI mỗi PR** — quá chậm, không hợp làm cổng.
- **Điều kiện xem lại:** Khi team sẵn sàng chi ~250 USD/năm → chuyển sang **`mutant`** (đầy đủ, tự dedup tương đương) làm bản chính thức; harness tự viết là bước đệm, không khóa cứng. Hoặc khi phạm vi cần phủ rộng ra ngoài lõi tính toán (catalog/ignore-list thủ công không còn kham nổi) → cũng là tín hiệu chuyển sang `mutant`.

## Lịch sử thay đổi

- **0.2.0 (14/06/2026):** Triển khai xong + baseline lần đầu. `rake mutation:core` trên 4 subject lõi: **107 mutant, 88 killed, 19 survived, 0 ignored** (81% killed). Đã giết survivor giá-trị-cao `summary_calculator.rb:88` (`surplus_amount = surplus * unit_price`, dòng tiền thừa trước đó chưa được assert) bằng một assertion ở `summary_calculator_spec.rb`. 19 survivor còn lại (biên cần fixture edge; logic cảnh báo/kỳ-đóng; fallback `|| 0`/`.sum(0)` quân số) tách follow-up **Issue #376** (không phình PR — đúng DoD). ADR-056.
- **0.1.0 (14/06/2026):** Bản đầu — thiết kế harness mutation testing tự viết (Ripper, stdlib) cho 4 class lõi tính toán; catalog toán tử nhắm lỗi tài chính; chạy định kỳ `rake mutation:core`; ignore-list mutant tương đương; đường nâng cấp `mutant` để ngỏ. ADR-056, Issue #358.
