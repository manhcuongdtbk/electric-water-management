---
title: Guardrail role-coverage — ép mọi trang test đủ 6 vai trò (meta-spec data-driven)
version: 0.1.0
date: 2026-06-14
governed_by: 2026-06-07-sdlc-overview-design.md
---

# Guardrail role-coverage

Ép **máy** luật "**mọi trang phải test cả 6 vai trò**" (AGENTS.md; 6 vai trò định nghĩa ở [`docs/V2_HANH_VI_HE_THONG.md` mục 1](../../V2_HANH_VI_HE_THONG.md)). Hôm nay luật này mới là **quy ước**: ma trận `spec/requests/role_access_matrix_spec.rb` thực tế đã phủ mọi trang × 6 vai trò, nhưng **không có gì đo/ép** — thêm một trang mới mà quên một/vài vai trò (hoặc quên đưa trang vào ma trận hẳn) thì CI vẫn xanh. Đúng tinh thần [ADR-002](2026-06-07-sdlc-overview-design.md) (luật nào máy ép được thì để máy ép, đừng viết prose rồi mong người nhớ) và cùng họ guardrail với [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (truy vết chiều test).

**Ràng buộc cốt lõi định hình thiết kế:** muốn guardrail *thật sự* đóng được lỗ hổng, **nguồn-sự-thật của "tập trang" không được là một danh sách giữ tay** — vì một registry tay cũng bị quên y hệt như hiện trạng (thêm trang mới → quên thêm vào registry → guardrail im). Nguồn-sự-thật phải **suy ra từ thứ bắt buộc phải đụng khi thêm một trang**: lớp controller. Một trang mới = một controller mới kế thừa `ApplicationController` → tự khắc bị guardrail "nhìn thấy".

## Goals

- **Trang mới không lọt:** thêm một controller-trang mà quên đưa vào ma trận vai trò → **CI đỏ ngay**, không thể quên như hôm nay.
- **Đủ 6 vai trò mỗi trang:** mỗi trang trong ma trận phải nêu kỳ vọng truy cập cho cả **6 vai trò chuẩn** (SA, UA-ZM, UA, CMD-ZM, CMD, TECH) — thiếu một vai trò → CI đỏ.
- **Chống lệch (anti-stale):** một entry ma trận trỏ tới controller đã xóa/đổi tên → CI đỏ (bắt rác).
- **False-positive thấp:** không parse mỏng manh; cách đo phải tự nhiên đúng, không cần bảo trì danh sách song song.
- **Single source of truth:** đúng một cấu trúc dữ liệu sinh ra **cả** test access **lẫn** assertion đủ-phủ — không có hai nơi để lệch nhau.

## Non-Goals (cố ý KHÔNG làm)

- **Đo hành vi chi tiết per vai trò** (data scoping, ẩn/hiện cột, commander read-only disable, biến thể ZM) — guardrail này chỉ ép *độ phủ ma trận truy cập* (ai vào được trang nào), tức **chiều 2/3** của [`docs/V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md). Quét coverage cho thấy hành vi chi tiết non-SA hiện test lệch/SA-nặng — nhưng **đo bằng máy rất khó/false-positive cao**, là bài toán riêng (chuẩn hoá shared example hành vi + cách đo độ phủ), tách sang [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373). KHÔNG trộn vào guardrail access sạch này.
- **Script bash `.github/scripts/check-*.sh`** — phương án này đã cân nhắc và loại (xem Phương án đã loại): parse Ruby bằng bash là nguồn false-positive; hướng B đo bằng chính RSpec nên không thêm script bash, không thêm `.test.sh`.
- **Job CI mới / sửa `ci.yml`** — guardrail là spec, chạy sẵn trong job `rspec`. Không thêm moving-part.
- **Ép các loại test khác đủ 6 vai trò** (system spec, per-page request spec) — chỉ ma trận truy cập là nguồn canonical "ai vào được trang nào"; các spec khác bổ trợ, không nhân đôi luật ép ở đây (YAGNI).

## Glossary (khoá nghĩa — không viết tắt)

| Thuật ngữ | Nghĩa |
|---|---|
| **Trang (page)** | Một khu vực giao diện người-dùng phục vụ bởi một controller kế thừa `ApplicationController`, có kỳ vọng truy cập **khác nhau theo vai trò**. |
| **6 vai trò chuẩn** | `sa, ua_zm, ua, cmd_zm, cmd, tech` — sáu vai trò thực tế ([`V2_HANH_VI_HE_THONG.md` mục 1](../../V2_HANH_VI_HE_THONG.md)). UA-ZM/CMD-ZM là biến thể "quản lý khu vực" của unit_admin/commander. |
| **Ma trận truy cập** | `spec/requests/role_access_matrix_spec.rb` — bảng "trang × vai trò → 200 hay redirect"; nguồn canonical cho chiều 2/3. |
| **Controller-trang** | Controller kế thừa `ApplicationController` và phục vụ một trang phân-vai-trò (loại trừ self-service/non-page). |
| **Trang không-phân-vai-trò** | Controller có-đăng-nhập nhưng mọi vai trò dùng như nhau (ví dụ đổi mật khẩu) → cố ý nằm ngoài ma trận, khai trong `EXCLUDED_CONTROLLERS`. |
| **coverage gap** | Trang có controller nhưng thiếu entry ma trận (`missing`), hoặc entry ma trận không có controller thật (`stale`). |
| **role gap** | Một trang trong ma trận thiếu kỳ vọng cho ≥1 trong 6 vai trò. |

## Thiết kế

### Nguồn-sự-thật: `spec/support/role_access_matrix.rb`

Một module `RoleAccessMatrix` (test infrastructure, auto-require qua `spec/support/**`) giữ **toàn bộ** dữ liệu + chính sách:

- `ROLES = %i[sa ua_zm ua cmd_zm cmd tech]` — 6 vai trò chuẩn, định nghĩa **đúng một nơi**.
- `EXCLUDED_CONTROLLERS = %w[PasswordChangesController]` — controller có-đăng-nhập nhưng **không phân-vai-trò**, cố ý ngoài ma trận. Lý do từng cái ghi inline. Cây auth Devise (`Devise::*`, `DeviseController`, `Users::SessionsController`) **cũng** kế thừa `ApplicationController` (qua `Devise.parent_controller`) nhưng được lọc **theo cấu trúc** trong spec completeness (`klass <= DeviseController`), không liệt kê tay — tránh phải đuổi theo từng subclass Devise. `VersionController` (kế thừa `ActionController::Base`, endpoint JSON công khai) **không** kế thừa `ApplicationController` nên không bao giờ lọt vào `descendants`.
- `PAGES` — hash `slug => { category:, path:, expect: { role => :ok | :redirect } }`. `slug` là tên controller dạng snake_case không hậu tố (ví dụ `"contact_points"` ↔ `ContactPointsController`). Mã hoá trung thực 18 trang hiện hữu.
- Hàm thuần (pure, test offline được — KHÔNG đụng DB/Rails):
  - `controller_name_for(slug)` → `"#{camelize(slug)}Controller"`.
  - `declared_controllers` → danh sách tên controller suy từ `PAGES`.
  - `coverage_gaps(actual_controller_names)` → `{ missing:, stale: }` (đối xứng hai chiều: trang thiếu entry **và** entry rác).
  - `role_gaps` → `{ slug => [vai_trò_thiếu] }` cho mọi trang thiếu vai trò.

Tách **chính sách** (hàm thuần) khỏi **thu thập dữ liệu** (eager-load runtime) là chìa khoá để test được chính guardrail bằng input tổng hợp.

### Sinh test + assertion từ một nguồn: `role_access_matrix_spec.rb` (viết lại)

File ma trận viết lại để **sinh** test thay vì liệt kê tay:

1. **Test access (giữ nguyên hành vi, 108 examples):** lặp `RoleAccessMatrix::PAGES`, với mỗi `(slug, cfg)` và mỗi vai trò trong `cfg[:expect]`, sinh một `it` đăng nhập đúng user của vai trò rồi `get cfg[:path]` và kỳ vọng `:ok`/`:redirect`. User mỗi vai trò dựng từ factory như bản cũ (zone + unit-quản-lý + unit-khác + kỳ mở).
2. **Block guardrail "completeness (#359)":**
   - `Rails.application.eager_load!` → `actual = ApplicationController.descendants` (loại cây Devise theo cấu trúc: `reject { |k| k <= DeviseController }`) `.map(&:name)` → `gaps = coverage_gaps(actual)` → **`gaps[:missing]` và `gaps[:stale]` đều phải rỗng** (thông báo lỗi chỉ rõ phải thêm vào `PAGES` hoặc `EXCLUDED_CONTROLLERS` kèm lý do).
   - **`role_gaps` phải rỗng** — mỗi trang đủ 6 vai trò.

Vì test access lặp đúng `cfg[:expect]`, thiếu một vai trò chỉ làm *ít test đi* (không tự đỏ) → assertion `role_gaps` là cái biến "thiếu" thành "đỏ".

### Test cho chính guardrail: `spec/lib/role_access_matrix_spec.rb`

Vì hướng B không thêm script bash nên không có `.test.sh`; thay vào đó test **chứng minh guardrail cắn** bằng input tổng hợp lên các hàm thuần:

- thêm `"NewThingController"` vào `actual` → `coverage_gaps[:missing]` bắt được.
- bỏ một controller khỏi `actual` → `coverage_gaps[:stale]` bắt được.
- `EXCLUDED_CONTROLLERS` không bị tính là `missing`.
- `role_gaps` rỗng trên ma trận thật (sanity của chính dữ liệu).

Đây là "test kèm guardrail" tương đương `.test.sh` của họ bash, nhưng bằng RSpec.

### CI

Không sửa `ci.yml`: cả ma trận lẫn block completeness lẫn unit-test là spec, chạy trong job `rspec` sẵn có (cần DB cho phần access; phần hàm thuần không cần). Không thêm job/script.

## Kiểm thử

- `bin/docker rspec spec/requests/role_access_matrix_spec.rb` — vẫn 108 example access **+** block completeness xanh.
- `bin/docker rspec spec/lib/role_access_matrix_spec.rb` — unit-test hàm thuần chứng minh guardrail cắn (missing/stale/role-gap).
- **Kiểm chứng guardrail thật (ghi trong plan):** tạm thêm một controller-trang giả (hoặc xoá một entry `PAGES`) cục bộ → `rspec` đỏ đúng chỗ; hoàn tác → xanh lại.
- `bin/docker rspec` toàn bộ + guardrail doc-governance cục bộ vẫn xanh.

## Giới hạn (không phóng đại "đảm bảo")

Guardrail **chỉ** đảm bảo: mọi controller kế thừa `ApplicationController` (trừ `EXCLUDED_CONTROLLERS`) có entry trong ma trận, và mỗi entry nêu kỳ vọng cho đủ 6 vai trò. **KHÔNG** đảm bảo:

1. **Kỳ vọng đúng nghiệp vụ** — máy ép *có mặt đủ 6 vai trò*, không ép `:ok`/`:redirect` *đúng*; sai kỳ vọng vẫn phải bắt bằng review/đọc thiết kế.
2. **Hành vi chi tiết per vai trò** (scoping/cột/commander-disable/biến thể ZM) — ngoài phạm vi; coverage hiện lệch SA-nặng, theo dõi ở [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373).
3. **Trang phục vụ bởi controller không kế thừa `ApplicationController`** — nếu sau này có trang người-dùng kế thừa base khác, phải mở rộng nguồn thu thập (điều kiện xem lại).
4. **Lạm dụng `EXCLUDED_CONTROLLERS`** — loại trừ là cửa thoát; thêm bừa vào đây sẽ né được guardrail. Giảm thiểu bằng review (mỗi mục phải có lý do inline) — máy không phán đoán "đáng loại trừ hay không".

## Quyết định (ADR)

### ADR-056: Guardrail role-coverage bằng meta-spec data-driven, nguồn-trang từ `ApplicationController.descendants`
- **Trạng thái:** Accepted · 2026-06-14
- **Bối cảnh:** Luật AGENTS "mọi trang test đủ 6 vai trò" chỉ là quy ước; `role_access_matrix_spec.rb` phủ đủ hôm nay nhưng không có cơ chế ép trang mới phải vào ma trận hay phải đủ 6 vai trò → trang mới quên vai trò mà CI vẫn xanh. Cần guardrail false-positive thấp. Điểm khó là **cách đo** "tập trang" mà không tự tạo một danh sách giữ tay (vốn quên y hệt hiện trạng).
- **Quyết định:** Đo bằng **chính RSpec** (không script bash). Một module `RoleAccessMatrix` (`spec/support/`) giữ `ROLES` (6 vai trò), `EXCLUDED_CONTROLLERS`, `PAGES` (slug→path+expect per role) và các **hàm thuần** `coverage_gaps`/`role_gaps`. `role_access_matrix_spec.rb` **sinh** test access từ `PAGES` (giữ 108 example) và thêm block completeness: eager-load rồi đối chiếu `ApplicationController.descendants` (trừ `EXCLUDED_CONTROLLERS`) với `PAGES` (đối xứng missing/stale) + ép mỗi trang đủ 6 vai trò. Unit-test `spec/lib/role_access_matrix_spec.rb` chứng minh guardrail cắn. Không sửa `ci.yml`.
- **Lý do:** Nguồn-trang = `descendants` là thứ **bắt buộc đụng** khi thêm trang (controller mới) → fail-safe, không thể quên. Một hash duy nhất sinh cả test lẫn assertion → không có hai nơi để lệch. Đo trong Ruby tránh parse Ruby bằng bash (nguồn false-positive). Tách hàm thuần → guardrail tự test được offline.
- **Tradeoff:** (+) false-positive thấp, single source of truth, tự đóng lỗ hổng "quên trang mới", không thêm script/job. (−) chạy trong job `rspec` (cần DB, chậm hơn doc-governance tĩnh); viết lại file ma trận (thay đổi lớn hơn thêm 1 script); `EXCLUDED_CONTROLLERS` là cửa thoát phụ thuộc review.
- **Phương án đã loại:**
  - *Script bash `check-role-coverage.sh` (họ doc-governance):* parse `describe "<slug>"` + đếm token vai trò trong file Ruby. Loại — parse Ruby bằng bash mong manh (false-positive), và nguồn-trang vẫn phải lấy từ controllers/routes nên không nhẹ hơn thực chất.
  - *Registry trang giữ tay (YAML/hash khai tay danh sách trang):* loại — chính là lỗ hổng hiện tại đội lốt khác (quên trang = quên registry).
  - *Suy tập trang từ `bin/rails routes`:* loại — routes lẫn API/devise/member-collection, lọc phức tạp, false-positive cao, phải boot Rails trong bash.
  - *Job CI riêng:* loại theo YAGNI — guardrail là spec, job `rspec` chạy sẵn.
- **Điều kiện xem lại:** Khi xuất hiện trang người-dùng phục vụ bởi controller **không** kế thừa `ApplicationController` (phải mở rộng nguồn thu thập), hoặc khi `EXCLUDED_CONTROLLERS` phình ra (dấu hiệu cửa thoát bị lạm dụng — cân nhắc bắt buộc lý do máy-đọc-được), hoặc khi cần ép độ phủ 6-vai-trò cho cả system/per-page spec.

## Truy vết

- **Issue:** [`#359`](https://github.com/manhcuongdtbk/electric-water-management/issues/359) (`change-request`, milestone `1.3.0`, không `priority-high`) → PR mang **`Refs #359`**; phạm vi access-only của #359 hoàn tất ở PR này, chủ dự án đóng #359 khi xác nhận (gate đóng issue thuộc người). Phần hành vi tách sang [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373).
- **Lên:** [ADR-002](2026-06-07-sdlc-overview-design.md) (luật nào máy ép được thì để máy ép), [ADR-030](2026-06-13-truy-vet-chieu-test-design.md) (họ guardrail truy vết chiều test — mẫu fail-loud/test-kèm), [ADR-029](2026-06-07-sdlc-overview-design.md) (máy lo cơ học, người giữ phán đoán).
- **Nghiệp vụ/hành vi:** [`V2_HANH_VI_HE_THONG.md` mục 1](../../V2_HANH_VI_HE_THONG.md) (6 vai trò), [`V2_CHIEU_TEST.md`](../../V2_CHIEU_TEST.md) (chiều 2/3 ma trận truy cập).
- **Xuống (follow-up):** [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373) — độ phủ **hành vi chi tiết** per-role (ngoài phạm vi guardrail access này).
- **Test:** `spec/requests/role_access_matrix_spec.rb` (block completeness) + `spec/lib/role_access_matrix_spec.rb` (hàm thuần). Guardrail tooling thuần — không khai chiều test mới (`## Truy vết chiều test` không áp; ADR-030 chỉ áp khi có chiều test nghiệp vụ mới).

## Lịch sử thay đổi

- **0.1.0 (2026-06-14):** Bản thảo đầu — ADR-056 (guardrail role-coverage bằng meta-spec data-driven). Nguồn-trang = `ApplicationController.descendants` (fail-safe, không registry tay) lọc cây Devise theo cấu trúc (`<= DeviseController`); module `RoleAccessMatrix` (`spec/support/`) giữ `ROLES`/`ROLE_LABELS`/`EXCLUDED_CONTROLLERS`/`PAGES` + hàm thuần `coverage_gaps`/`role_gaps`; `role_access_matrix_spec.rb` sinh 108 test access + block completeness (eager-load, đối xứng missing/stale, đủ-6-vai-trò); unit-test `spec/lib/role_access_matrix_spec.rb` chứng minh guardrail cắn. Không thêm script bash/`.test.sh`, không sửa `ci.yml`. Phạm vi cố ý **chỉ access** — hành vi chi tiết per-role (coverage hiện lệch SA-nặng) tách sang follow-up [`#373`](https://github.com/manhcuongdtbk/electric-water-management/issues/373). Loại: script bash parse Ruby, registry tay, suy từ `rails routes`, job CI riêng. Triage: milestone 1.3.0, không priority-high.
