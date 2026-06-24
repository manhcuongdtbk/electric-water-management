---
title: Guardrail behavior-coverage — ép mọi trang test HÀNH VI đủ vai trò (meta-spec data-driven)
version: 0.1.0
date: 2026-06-14
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Guardrail behavior-coverage per-role

> **Ghi chú (25/06/2026):** Spec viết khi hệ thống có 6 vai trò thực tế. Nay 7 vai trò (thêm Chỉ huy Sư đoàn `division_commander` — xem [ADR-061](2026-06-25-division-commander-role-design.md), Issue #419).
Nối tiếp [guardrail role-coverage (ADR-056, #359)](2026-06-14-role-coverage-guardrail-design.md). #359 ép **máy** rằng mọi trang phủ đủ **6 vai trò** ở mức **access** (200 hay redirect — [chiều 2/3](../../V2_CHIEU_TEST.md)). Nhưng access xanh **không** nói gì về **hành vi chi tiết theo vai trò**: data scoping (non-SA chỉ thấy data đơn vị/khu vực mình), ẩn/hiện cột Khu vực+Đơn vị, commander read-only (input `disabled` + ẩn nút Lưu — luật AGENTS "Commander trên mọi trang"), và biến thể zone-manager. Quét coverage (ghi trong [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373)) cho thấy hành vi này hiện test **lệch, SA-nặng**: request spec của `blocks`/`groups`/`pump_allocations`/`ranks` chỉ chạm `system_admin`; phần lớn system spec cũng chỉ SA.

Guardrail này đóng nốt khe đó — **bằng đúng mô hình đã ship của #359**: một matrix khai báo, sinh test, và một block completeness ép không-được-bỏ-sót. Khác biệt: đối tượng là **hành vi**, không phải access.

**Ràng buộc cốt lõi định hình thiết kế — điểm khó của #373:** "tạo user vai trò" **KHÔNG** bằng "assert hành vi vai trò". Một guardrail đếm assertion, hay chỉ kiểm "có dựng user non-SA", thì **gian lận được** (dựng user rồi không assert gì vẫn xanh) — đúng loại false-positive cần diệt. Cách đo phải làm cho "phủ giả" **rớt test**, không pass câm.

## Goals

- **Trang có hành vi per-role mà không test → đỏ:** mỗi trang trong [ma trận truy cập](2026-06-14-role-coverage-guardrail-design.md) phải khai **đủ 4 dimension hành vi**, mỗi cái là `applies` (có test thật) hoặc `na` (kèm lý do) — thiếu/khai mơ hồ → CI đỏ.
- **Phủ giả là bất khả:** mỗi dimension có **precondition** làm cho trang rỗng-input / text trùng / data không thật **rớt test**. Không thể đánh dấu "đã phủ" mà không chạy assertion thật.
- **Một nguồn-trang với #359:** tập trang = `RoleAccessMatrix::PAGES` keys (không có danh sách giữ tay thứ hai để lệch). Thêm trang vào access-matrix mà quên khai hành vi → đỏ.
- **`na` phải có lý do:** mọi loại trừ kèm chuỗi lý do non-empty (cửa thoát minh bạch, như `EXCLUDED_CONTROLLERS` của #359).
- **False-positive thấp, không moving-part mới:** đo bằng chính RSpec (request type, Nokogiri), không script bash, không job CI mới.

## Non-Goals (cố ý KHÔNG làm)

- **Đo access** — đã thuộc #359 (ADR-056). Guardrail này chỉ lo hành vi; không nhân đôi luật access.
- **Biến thể ZM thuần-access** — chỗ UA-ZM/CMD-ZM **vào được** trang mà UA/CMD bị redirect (vd `electricity_supply`, `pump_allocations`) đã do ma trận access ép. `zone_manager_variant` ở đây chỉ lo **hành vi khác nhau khi đã cùng vào được** một trang (vd UA-ZM quản lý đầu mối zone-level mà UA không); chỗ chỉ khác access → khai `na` trỏ #359.
- **System spec (Capybara)** — shared example hành vi viết **request type** (nhanh, tất định, ít flaky); không đụng/không nhân đôi các system shared example sẵn có (`role_based_filter_visibility.rb`, `zone_unit_column_visibility.rb`) — chúng phục vụ per-page system spec, giữ nguyên.
- **Đúng-sai nghiệp vụ của hành vi** — máy ép *có assert hành vi đủ vai trò*, không ép *kỳ vọng đúng nghiệp vụ*; sai kỳ vọng vẫn cần review/đọc thiết kế.
- **Job CI / sửa `ci.yml`** — guardrail là spec, chạy trong job `rspec` sẵn có.

## Glossary (khoá nghĩa — không viết tắt)

| Thuật ngữ | Nghĩa |
|---|---|
| **Dimension hành vi** | Một khía cạnh hành vi phụ-thuộc-vai-trò của một trang: `data_scoping`, `zone_unit_columns`, `commander_readonly`, `zone_manager_variant`. |
| **`data_scoping`** | Non-SA chỉ thấy data đơn vị/khu vực mình; SA thấy mọi đơn vị. |
| **`zone_unit_columns`** | SA thấy cột Khu vực + Đơn vị trong bảng index; non-SA bị ẩn (thừa context). |
| **`commander_readonly`** | CMD/CMD-ZM xem được nhưng mọi input nghiệp vụ `disabled` và nút Lưu disabled/ẩn (luật "Commander trên mọi trang"). |
| **`zone_manager_variant`** | UA-ZM/CMD-ZM có hành vi riêng khi **đã cùng vào được** trang (không phải khác-access — cái đó thuộc #359). |
| **`applies(params)`** | Khai một trang **có** dimension này → sinh test thật chạy shared example với `params`. |
| **`na: "lý do"`** | Khai một trang **không** có dimension này, kèm lý do máy-đọc-được (non-empty). |
| **precondition (chống vacuous)** | Assertion mồi trong shared example chứng minh "có gì đó thật để phân biệt" trước khi assert hành vi vai trò — làm phủ giả rớt test. |
| **scenario** | Method dựng thế giới test cho một trang (`RoleBehaviorScenarios.<slug>`), trả struct fixtures (path, own/foreign text, form selectors, zm). |

## Thiết kế

### Nguồn-sự-thật: `spec/support/role_behavior_matrix.rb`

Module `RoleBehaviorMatrix` (test infra, auto-require qua `spec/support/**`), song sinh với `RoleAccessMatrix`:

- `DIMENSIONS = %i[data_scoping zone_unit_columns commander_readonly zone_manager_variant]` — 4 dimension, định nghĩa **một nơi**.
- `BEHAVIORS` — hash `slug => { dimension => entry }`, mỗi `entry` là `{ applies: {params} }` **hoặc** `{ na: "lý do" }`. `slug` dùng **chung** vựng trang với `RoleAccessMatrix::PAGES`.
- Hàm thuần (pure, test offline được — KHÔNG đụng DB/Rails):
  - `coverage_gaps(page_slugs)` → `{ missing:, stale: }`: mọi slug trong `RoleAccessMatrix::PAGES` phải có trong `BEHAVIORS` (`missing`); entry `BEHAVIORS` không có trang access tương ứng (`stale`).
  - `dimension_gaps` → `{ slug => [dimension_thiếu] }`: trang nào không khai đủ 4 dimension.
  - `invalid_entries` → `{ slug => [dimension] }`: entry vừa-không-`applies`-vừa-không-`na`, hoặc `na` rỗng/không phải chuỗi, hoặc `applies` thiếu `:scenario`. (Ép hình thức entry — chống khai nửa vời.)

Tách **chính sách** (hàm thuần) khỏi **thu thập dữ liệu** + **assertion runtime** là chìa để test chính guardrail bằng input tổng hợp.

### Setup per-trang: `spec/support/role_behavior_scenarios.rb`

Matrix giữ **data thuần** (đọc/diff dễ); setup khác nhau từng trang nằm trong method có tên trong module `RoleBehaviorScenarios`. `applies: { scenario: :blocks }` → gọi `RoleBehaviorScenarios.blocks(world)` trả struct:

```
path:            URL trang (string hoặc symbol path-helper)
own_text:        chuỗi DUY NHẤT chỉ xuất hiện vì record đơn vị "own"
foreign_text:    chuỗi DUY NHẤT chỉ xuất hiện vì record đơn vị "foreign"
commander_form:  { input_selector:, submit_selector: }   # cho commander_readonly
zm:              { sees:, absent_for_non_zm: }            # cho zone_manager_variant
```

Tái dùng `sample_data.rb` (`setup_zone_one/two_full_sample`) cho thế giới hai-zone/hai-unit. Scenario là Ruby method đọc-được, debug-được; matrix chỉ trỏ tên — không nhồi lambda vào data.

### Shared example request-type: `spec/support/shared_examples/requests/`

Bốn file, mỗi cái nhận fixtures từ scenario. **Cốt lõi chống false-positive là precondition** — không phải "có dựng user non-SA":

| Shared example | Precondition (chống vacuous) | Assertion vai trò |
|---|---|---|
| `role_data_scoping` | `own_text != foreign_text` **và** SA `get path` thấy **cả hai** (2 record thật, render thật) | mỗi non-SA scoped role: thấy `own_text`, **KHÔNG** thấy `foreign_text` |
| `role_zone_unit_columns` | SA thấy `thead` chứa "Khu vực" **và** "Đơn vị" | non-SA: `thead` **không** chứa hai cột |
| `role_commander_readonly` | role control (UA tương ứng) có ≥1 input `commander_form[:input_selector]` **không** `disabled` ở cùng view | CMD/CMD-ZM: **mọi** input khớp selector `disabled`; submit disabled/ẩn |
| `role_zone_manager_variant` | UA-ZM thấy `zm[:sees]` | UA (non-ZM) **không** thấy `zm[:absent_for_non_zm]` (hoặc bị chặn hành vi tương ứng) |

Precondition "SA thấy cả hai" / "UA có input enabled" / "SA thấy cột" làm cho trang **không có gì để phân biệt** (text trùng, không input, không cột) **rớt** — đó là cái biến "tạo user mà không assert" thành đỏ.

### Spec sinh + completeness: `spec/requests/role_behavior_matrix_spec.rb`

Mirror `role_access_matrix_spec.rb`:

1. **Sinh test hành vi:** lặp `BEHAVIORS`; với mỗi `(slug, dims)` và mỗi dimension `applies`, dựng scenario rồi `include_examples` shared example tương ứng, truyền fixtures.
2. **Block `completeness (#373)`:**
   - `coverage_gaps(RoleAccessMatrix::PAGES.keys)` → `missing` và `stale` đều rỗng (thông báo lỗi chỉ rõ thêm vào `BEHAVIORS` — `applies` hoặc `na` kèm lý do).
   - `dimension_gaps` rỗng — mọi trang khai đủ 4 dimension.
   - `invalid_entries` rỗng — mọi entry đúng hình thức (`na` có lý do, `applies` có scenario).

Vì test hành vi chỉ sinh cho dimension `applies`, "quên test" biểu hiện thành *thiếu khai* → `dimension_gaps`/`coverage_gaps` bắt; "khai applies nhưng phủ giả" → precondition trong shared example bắt.

### Test cho chính guardrail: `spec/lib/role_behavior_matrix_spec.rb`

Như #359, chứng minh guardrail cắn bằng input tổng hợp lên hàm thuần:

- thêm slug giả vào access-pages mà không có trong `BEHAVIORS` → `coverage_gaps[:missing]` bắt.
- entry `BEHAVIORS` cho slug không tồn tại → `coverage_gaps[:stale]` bắt.
- trang thiếu 1 dimension → `dimension_gaps` bắt.
- `na` rỗng / `applies` thiếu scenario / entry không-applies-không-na → `invalid_entries` bắt.
- ma trận thật: `dimension_gaps`/`invalid_entries` rỗng (sanity dữ liệu).

### Backfill (toàn bộ 4 dimension, mọi trang)

Khai đủ 4 dimension cho **cả 18 trang** trong access-matrix. Test thật nơi `applies` (đóng khe blocks/groups/pump_allocations/ranks + các trang system-spec chỉ-SA), `na`+lý do nơi không áp dụng (vd `zones`/`units`/`pricing` chỉ-SA → `data_scoping` na "không có non-SA truy cập để scope"; trang chỉ-xem `billing`/`history`/`dashboard` → `commander_readonly` na "không có input nghiệp vụ để disable"). Khe non-SA của các trang chỉ-SA được đóng **tập trung** ở spec sinh, không phải sửa rải từng per-page spec.

## Kiểm thử

- `bin/docker rspec spec/requests/role_behavior_matrix_spec.rb` — test hành vi sinh + block completeness xanh.
- `bin/docker rspec spec/lib/role_behavior_matrix_spec.rb` — hàm thuần chứng minh guardrail cắn.
- **Kiểm chứng guardrail thật (ghi trong plan):** tạm đổi một `applies` thành `na` rỗng, hoặc làm `foreign_text == own_text` trong một scenario → `rspec` đỏ đúng chỗ; hoàn tác → xanh.
- `bin/docker rspec` toàn bộ + guardrail doc-governance cục bộ xanh.

## Giới hạn (không phóng đại "đảm bảo")

Guardrail **chỉ** đảm bảo: mọi trang access-matrix khai đủ 4 dimension; mỗi `applies` chạy shared example có precondition chống-vacuous; mỗi `na` có lý do. **KHÔNG** đảm bảo:

1. **Kỳ vọng đúng nghiệp vụ** — máy ép *có assert hành vi*, không ép *đúng/đủ mọi nhánh nghiệp vụ* của hành vi đó.
2. **`na` trung thực** — khai `na` cho một dimension thật-sự-applies sẽ né được test (cửa thoát). Giảm thiểu bằng review (lý do inline) + precondition (nếu sau này đổi sang `applies` thì không phủ giả được).
3. **Dimension chưa mô hình hoá** — hành vi per-role mới ngoài 4 dimension (xem điều kiện xem lại).

## Quyết định (ADR)

### ADR-058: Guardrail behavior-coverage bằng meta-spec data-driven, precondition chống-vacuous làm thước đo
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** [#359/ADR-056](2026-06-14-role-coverage-guardrail-design.md) ép access đủ 6 vai trò nhưng cố ý để hành vi chi tiết per-role ngoài phạm vi; coverage hiện lệch SA-nặng (request spec blocks/groups/pump_allocations/ranks chỉ SA; phần lớn system spec chỉ SA). Điểm khó: "tạo user vai trò" ≠ "assert hành vi" — guardrail đếm assertion hay kiểm "có dựng user non-SA" thì gian lận được, đúng loại false-positive cần diệt.
- **Quyết định:** Lặp mô hình #359 cho **hành vi**. Module `RoleBehaviorMatrix` (`spec/support/`) giữ `DIMENSIONS` (4) + `BEHAVIORS` (slug→dimension→`applies(params)`|`na(reason)`), dùng chung vựng trang với `RoleAccessMatrix::PAGES`, + hàm thuần `coverage_gaps`/`dimension_gaps`/`invalid_entries`. Setup per-trang trong `RoleBehaviorScenarios`. Bốn shared example **request-type** (`spec/support/shared_examples/requests/`), mỗi cái mang **precondition chống-vacuous** (SA thấy cả hai record / UA có input enabled / SA thấy cột) làm phủ giả rớt test. `role_behavior_matrix_spec.rb` sinh test + block completeness; `spec/lib/role_behavior_matrix_spec.rb` chứng minh guardrail cắn. Backfill đủ 4 dimension cho cả 18 trang (applies hoặc na+lý do). Không script bash, không job CI mới.
- **Lý do:** Thước đo không phải "đếm assertion" (gian lận được) mà là **precondition** — assertion mồi chứng minh có-gì-thật-để-phân-biệt trước khi assert vai trò; trang rỗng/ text trùng tự rớt. Dùng chung vựng trang với #359 → không có danh sách thứ hai để lệch, thêm trang mà quên hành vi → đỏ. Request-type → nhanh, tất định, ít flaky hơn Capybara. Tách hàm thuần → guardrail tự test offline. Đồng-họ với ADR-056/ADR-030 (máy ép, fail-loud, test-kèm).
- **Tradeoff:** (+) chống được false-positive cốt lõi của #373, single source vựng-trang, đóng khe non-SA tập trung, không moving-part mới. (−) test hành vi sinh ở file tập trung tách khỏi per-page spec (hơi lặp setup); shared example phải đủ tham-số-hoá để chạy standalone; `na` là cửa thoát phụ thuộc review; scenario per-trang là chỗ phải bảo trì khi UI đổi.
- **Phương án đã loại:**
  - *Include shared example trong từng per-page spec + registry runtime đối chiếu matrix:* loại — "quên include" chỉ lộ khi chạy **trọn** suite (registry-after-suite mong manh), và hai nguồn (matrix khai + include rải) dễ lệch — đúng cái #373 muốn diệt.
  - *Hybrid (matrix khai + bắt buộc include_examples trong per-page spec, verify bằng grep/registry):* loại — vẫn hai nguồn dễ lệch, grep parse spec mong manh.
  - *Đếm assertion / kiểm "có dựng user non-SA":* loại — gian lận được (dựng user không assert vẫn xanh), chính false-positive cần diệt.
  - *System-type shared example (Capybara):* loại — chậm, flaky hơn; hành vi này (scoping/cột/disabled) kiểm được ở request-level bằng Nokogiri.
- **Điều kiện xem lại:** Khi xuất hiện dimension hành vi per-role mới ngoài 4 cái (thêm vào `DIMENSIONS` + shared example), khi `na` phình ra (dấu hiệu cửa thoát bị lạm dụng — cân nhắc lý do máy-kiểm-được), hoặc khi cần ép hành vi cho cả system/per-page spec.

## Truy vết

- **Issue:** [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373) (`change-request`; milestone + priority do chủ dự án chốt — đề xuất 1.3.0, không `priority-high`) → PR mang **`Closes #373`**.
- **Lên:** [ADR-056](2026-06-14-role-coverage-guardrail-design.md) (#359, guardrail access — guardrail này nối tiếp phần hành vi), [ADR-002](2026-06-07-sdlc-overview-design.md) (luật nào máy ép được thì để máy ép), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (họ guardrail fail-loud/test-kèm).
- **Nghiệp vụ/hành vi:** [`V2_HANH_VI_HE_THONG.md` mục 1](../../V2_HANH_VI_HE_THONG.md) (6 vai trò) + mục 8 (test mọi output), [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) (chiều 2/3 nền access; hành vi scoping/cột/disable là phần "mọi output").
- **Test:** `spec/requests/role_behavior_matrix_spec.rb` (sinh + completeness) + `spec/lib/role_behavior_matrix_spec.rb` (hàm thuần). Guardrail tooling thuần — không khai chiều test mới (ADR-030 chỉ áp khi có chiều test nghiệp vụ mới).

## Lịch sử thay đổi

- **0.1.0 (2026-06-14):** Bản thảo đầu — ADR-058 (guardrail behavior-coverage per-role). Nối tiếp #359/ADR-056 (access) lo phần **hành vi**: module `RoleBehaviorMatrix` (`spec/support/`) giữ `DIMENSIONS` (data_scoping/zone_unit_columns/commander_readonly/zone_manager_variant) + `BEHAVIORS` (applies|na) dùng chung vựng trang với `RoleAccessMatrix::PAGES`, + hàm thuần `coverage_gaps`/`dimension_gaps`/`invalid_entries`; `RoleBehaviorScenarios` dựng thế giới per-trang; 4 shared example request-type với **precondition chống-vacuous** làm thước đo (không đếm assertion); `role_behavior_matrix_spec.rb` sinh test + completeness; `spec/lib/role_behavior_matrix_spec.rb` chứng minh guardrail cắn. Backfill đủ 4 dimension cho cả 18 trang. Loại: include+registry, hybrid, đếm assertion, system-type Capybara. Triage đề xuất: milestone 1.3.0, không priority-high (chủ dự án chốt).
