# 10. Test Suite — v1.0.0

> **Đọc lần đầu?** Đọc 01_OVERVIEW trước để hiểu dự án là gì.
>
> **Mục đích file này:** Tài liệu test suite — cấu trúc, conventions, cách chạy, cách thêm test mới.
>
> **Đối tượng đọc:** Developer cần chạy tests, thêm tests, hoặc debug test failures.
>
> **CI pipeline:** Xem 08_INFRASTRUCTURE mục 6.

---

## Mục lục

1. [Tổng quan test suite](#1-tổng-quan-test-suite)
2. [Directory structure](#2-directory-structure)
3. [Factories](#3-factories)
4. [Shared examples và support](#4-shared-examples-và-support)
5. [Test conventions](#5-test-conventions)
6. [CI workflow](#6-ci-workflow)
7. [Cách chạy tests](#7-cách-chạy-tests)
8. [Cách thêm test mới](#8-cách-thêm-test-mới)
9. [TODO — sai lệch giữa code và docs](#todo--sai-lệch-giữa-code-và-docs)

---

## 1. Tổng quan test suite

### 1.1 Số liệu

| Metric | Giá trị |
|---|---|
| Tổng examples (mặc định) | **853** |
| Tổng examples (gồm screenshots) | **869** |
| Số file spec | 70 |
| Số factory | 13 |
| Thời gian dry-run | < 2s |
| Thời gian full run thực tế | ~2–4 phút (đa số là system specs với headless Chrome) |

### 1.2 Breakdown theo type

Đếm chính xác qua `bundle exec rspec <path> --dry-run` (các test type tự nhận diện qua đường dẫn nhờ `config.infer_spec_type_from_file_location!` trong `spec/rails_helper.rb`):

| Type | Số examples | Số file | Đường dẫn | Mục đích |
|---|---:|---:|---|---|
| `:model` | 277 | 13 | `spec/models/` | Validations, associations, scopes, callbacks, business methods |
| `:request` | 278 | 15 | `spec/requests/` | HTTP route + status + body, authorization, redirect |
| `:service` (POJO) | 71 | 4 | `spec/services/` | Service objects: `CalculationEngine`, `PeriodInheritanceService`, `ImportFeb2026Service`, `BackupService` |
| `:system` | 222 | 22 | `spec/system/` | End-to-end flow F01–F21 qua browser (Capybara + rack_test/Selenium) |
| `:task` | 5 | 1 | `spec/tasks/` | Rake task `admin:reset_password` |
| `:system` (screenshots) | 16 | 1 | `spec/screenshots/` | Tiện ích chụp ảnh user guide (mặc định bị filter ra) |
| **Tổng (default)** | **853** | 56 | — | — |
| **Tổng (incl. screenshots)** | **869** | 57 | — | — |

> `spec_helper.rb:19` có `config.filter_run_excluding screenshots: true`, nên `bundle exec rspec` mặc định bỏ qua 16 screenshot specs.

### 1.3 Test framework

Stack chính (xem `Gemfile.lock`):

| Gem | Phiên bản | Vai trò |
|---|---|---|
| `rspec-rails` | 8.0.4 | Framework test cốt lõi, tích hợp Rails 8 |
| `factory_bot_rails` | 6.5.1 | FactoryBot — định nghĩa factory, sequence, trait, association |
| `shoulda-matchers` | 7.0.1 | One-liner matchers cho validation/association/scope (`is_expected.to validate_presence_of(:name)`) |
| `capybara` | 3.40.0 | DSL điều khiển browser cho system specs |
| `selenium-webdriver` | 4.43.0 | Driver Chrome headless cho system specs có `:js` |

### 1.4 Coverage tool

**Không có** SimpleCov hay tool đo coverage nào trong project. Đã verify qua `Gemfile.lock` — không có gem `simplecov`, `coveralls`, hoặc tương tự. Quyết định này phù hợp với context solo developer + deadline: code coverage không phải metric ưu tiên, thay vào đó developer tập trung test các path nghiệp vụ quan trọng (engine bảng 24 cột, scope isolation, auth) — xem mục 5.

### 1.5 Database cleaner strategy

**Không** dùng gem `database_cleaner`. Dùng RSpec built-in transactional fixtures (`spec/rails_helper.rb:31` — `config.use_transactional_fixtures = true`). Cơ chế:
- Mỗi example chạy trong một transaction.
- Sau example, transaction rollback → DB sạch cho example tiếp theo.
- Đủ dùng vì rack_test và Selenium chia sẻ DB connection trong rspec-rails 8.

**Trường hợp đặc biệt** — `spec/screenshots/user_guide_screenshots_spec.rb` dùng `before(:context)` để import data tháng 02 một lần (mất 5–10s qua `ImportFeb2026Service`), sau đó `after(:context)` thực thi `TRUNCATE TABLE ... RESTART IDENTITY CASCADE` để dọn sạch — vì data tạo ngoài transaction của example, transactional fixtures không rollback được.

---

## 2. Directory structure

```
spec/
├── factories/           # 13 file FactoryBot — xem mục 3
├── models/              # 13 model specs — xem 1.2
├── requests/            # 15 request specs — xem 1.2
├── services/            # 4 service specs (1 cho mỗi service trong app/services/)
├── system/              # 22 system specs (F01–F21 + cross-cutting)
├── screenshots/         # 1 spec sinh ảnh user guide (tag :screenshots)
├── tasks/               # 1 spec cho rake task admin:reset_password
├── support/             # 4 file config + shared_examples/
│   ├── capybara.rb              # Driver setup, headless Chrome args
│   ├── chrome_stale_node_fix.rb # Workaround Chrome 136+ -32000 error
│   ├── devise.rb                # Devise integration helpers cho :request
│   ├── system_spec_helpers.rb   # Helpers riêng cho system specs
│   └── shared_examples/
│       ├── nested_resource_authorization.rb  # 1 shared_example
│       └── role_access.rb                    # 2 shared_examples
├── rails_helper.rb      # Setup chính: env, tailwind build, support load
└── spec_helper.rb       # Config tối thiểu (rspec-only, screenshots filter)
```

### 2.1 spec/factories — 13 file

Một file cho mỗi model nghiệp vụ. Tên file = số nhiều của model (snake_case). Xem mục 3 cho chi tiết từng factory.

### 2.2 spec/models — 13 file (277 examples)

Mỗi file test 1 model. Pattern chung: `associations` → `validations` → `scopes` → các method nghiệp vụ. Có 1 file đặc biệt là `ability_spec.rb` test `Ability` class (không phải ActiveRecord model nhưng nằm trong `spec/models/` theo convention CanCanCan).

Danh sách: `ability_spec.rb`, `contact_point_spec.rb`, `meter_reading_spec.rb`, `meter_spec.rb`, `monthly_calculation_spec.rb`, `monthly_period_spec.rb`, `organization_spec.rb`, `personnel_spec.rb`, `pump_station_assignment_spec.rb`, `pump_station_spec.rb`, `rank_quota_spec.rb`, `unit_config_spec.rb`, `user_spec.rb`.

### 2.3 spec/requests — 15 file (278 examples)

HTTP-level test, không bật browser. Có 2 nhóm chính:
- **Resource controllers:** `contact_points_spec.rb`, `meters_spec.rb`, `personnel_spec.rb`, `meter_readings_spec.rb`, `monthly_periods_spec.rb`, `monthly_summary_spec.rb`, `unit_configs_spec.rb`, `users_spec.rb`, `electricity_supplies_spec.rb`, `personnel_reviews_spec.rb`, `backups_spec.rb`.
- **Auth + middleware:** `sessions_spec.rb` (F16 + endpoint extend), `password_changes_spec.rb` (F18), `f17_lockable_spec.rb` (Devise auto-lock), `rack_attack_spec.rb` (throttle login + sessions extend + blocklist bot path).

### 2.4 spec/services — 4 file (71 examples)

| File | Service tested | Số example |
|---|---|---:|
| `calculation_engine_spec.rb` | `CalculationEngine` (engine bảng 24 cột) | ~30 |
| `period_inheritance_service_spec.rb` | `PeriodInheritanceService` (kế thừa quân số tháng mới) | ~12 |
| `import_feb_2026_service_spec.rb` | `ImportFeb2026Service` (import Excel khách) | ~22 |
| `backup_service_spec.rb` | `BackupService` (pg_dump/pg_restore) | ~7 |

### 2.5 spec/system — 22 file (222 examples)

Pattern đặt tên: `f<NN>_<feature>_spec.rb` (1 file/F-number — F01 đến F21) + cross-cutting:

- F01–F07: `f01_contact_points_spec.rb`, `f02_meters_spec.rb`, `f03_personnel_spec.rb`, `f04_unit_configs_spec.rb`, `f05_electricity_supply_spec.rb`, `f06_meter_readings_spec.rb`, `f07_period_inheritance_spec.rb`
- F08–F11: `f08_f11_calculation_engine_spec.rb` (gộp 4 F-number)
- F12–F14: `f12_dashboard_spec.rb`, `f13_history_spec.rb`, `f14_csv_export_spec.rb`
- F15–F18: `f15_user_management_spec.rb`, `f16_force_password_change_spec.rb` (lưu ý: spec file F16 thực ra test F18 force-password-change theo nội dung — xem TODO #1), `f17_lockable_spec.rb`, `f18_session_timeout_spec.rb`
- F19–F21: `f19_audit_log_spec.rb`, `f20_unit_prices_spec.rb`, `f21_rank_quotas_spec.rb`
- Cross-cutting: `authorization_cross_cutting_spec.rb`, `backup_spec.rb`, `devise_sessions_spec.rb`, `import_feb2026_spec.rb`

### 2.6 spec/screenshots — 1 file (16 examples)

`user_guide_screenshots_spec.rb` — không phải test thật, là utility chụp ảnh cho 11_USER_GUIDE. Bị `spec_helper` filter mặc định. Output ở `tmp/screenshots/*.png` (gitignored). Xem mục 7 cho cách chạy.

### 2.7 spec/tasks — 1 file (5 examples)

`admin_rake_spec.rb` test rake task `admin:reset_password` — escape hatch khi admin_level1 cuối cùng bị auto-lock. Xem 06_AUTH_SECURITY mục 2.9.

### 2.8 spec/support

4 file thêm vào auto-loaded chain (`Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }` ở `rails_helper.rb:21`).

| File | Vai trò |
|---|---|
| `capybara.rb` | Đăng ký driver `:headless_chrome` qua Selenium Manager. `Capybara.default_driver = :rack_test`, `javascript_driver = :headless_chrome`. Auto include `Warden::Test::Helpers` cho `type: :system`. |
| `chrome_stale_node_fix.rb` | Patch `Capybara::Selenium::ChromeNode#visible?` rescue `Selenium::WebDriver::Error::UnknownError` "does not belong to the document" → trả `false` thay vì raise. Xem mục 4.3. |
| `devise.rb` | Include `Devise::Test::IntegrationHelpers` cho `type: :request` (cung cấp `sign_in user`). |
| `system_spec_helpers.rb` | 3 helper: `setup_basic_scenario`, `create_full_calculation_data`, `setup_history_scenario`, `sign_in_via_form`. Xem mục 4.2. |
| `shared_examples/role_access.rb` | 2 shared_examples: `redirects with access_denied`, `silently redirects tech to users_path`. |
| `shared_examples/nested_resource_authorization.rb` | 1 shared_example: `denies cross-org parent access`. |

### 2.9 spec/fixtures

**Thư mục không tồn tại** dù `rails_helper.rb:30` config `config.fixture_paths = [Rails.root.join('spec/fixtures')]`. Project không dùng Rails fixtures — toàn bộ data test sinh qua FactoryBot. File data thật để test engine nằm ở `test/fixtures/files/bang_tinh_thang_02.xlsx` (đường dẫn `test/`, không phải `spec/`) — đây là file Excel khách cung cấp tháng 02/2026, được `ImportFeb2026Service` đọc trong test (`spec/system/import_feb2026_spec.rb`, `spec/screenshots/user_guide_screenshots_spec.rb`).

---

## 3. Factories

13 factory tương ứng 13 model nghiệp vụ. Mọi factory đều dùng `FactoryBot.define do ... end` block. Không có factory cho `User` mới hơn (dùng chung 1 factory + traits cho 4 role).

### 3.1 `:organization` — `Organization`

```ruby
sequence(:code) { |n| "ORG#{n.to_s.rjust(3, '0')}" }  # ORG001, ORG002, ...
sequence(:name) { |n| "Organization #{n}" }
level    { :unit }
position { 0 }
```

| Trait | Tác dụng |
|---|---|
| `:division` | `level: :division`, `parent: nil`, sequence code/name riêng (`DIV001`, `Division 1`...). |
| `:unit` | `level: :unit`, `association :parent, factory: [:organization, :division]` — auto sinh parent Division khi tạo Unit. |

**Lưu ý:** `factory :organization` mặc định là `:unit` nhưng KHÔNG tự sinh parent (Rails default `level=unit` không kèm parent). Phải dùng `create(:organization, :unit, parent: division)` hoặc trait `:unit` để kèm parent.

### 3.2 `:user` — `User`

```ruby
sequence(:email)        { |n| "user#{n}@example.com" }
password               { "Password1!" }
password_confirmation  { "Password1!" }
full_name              { "Nguyen Van A" }
role                   { :admin_unit }     # default
force_password_change  { false }            # default false dù DB default true — tránh bounce trong test
association :organization, strategy: :create
```

| Trait | Tác dụng |
|---|---|
| `:admin_level1` | `role: :admin_level1` |
| `:admin_unit` | `role: :admin_unit` (giống default) |
| `:commander` | `role: :commander` |
| `:tech` | `role: :tech` |
| `:locked` | `locked_at: Time.current`, `failed_attempts: 5` (mô phỏng auto-lock sau 5 lần sai) |
| `:force_change_password` | `force_password_change: true` (mô phỏng user mới chưa đổi mật khẩu) |

**Lưu ý:** Password `"Password1!"` thỏa validation `password_complexity` (1 chữ + 1 số) trong `User#password_complexity` — xem 06_AUTH_SECURITY mục 2.6.

### 3.3 `:contact_point` — `ContactPoint`

```ruby
sequence(:name) { |n| "Contact Point #{n}" }
group_name      { "Group A" }
position        { 0 }
association :organization
```

Không có trait. Tên unique theo `organization_id` (xem `validate_uniqueness_of(:name).scoped_to(:organization_id)` trong model).

### 3.4 `:meter` — `Meter`

```ruby
sequence(:name)          { |n| "Meter #{n}" }
sequence(:serial_number) { |n| "SN#{n.to_s.rjust(6, '0')}" }
meter_type               { :normal }
notes                    { nil }
position                 { 0 }
association :organization
```

| Trait | Tác dụng |
|---|---|
| `:normal` | `meter_type: :normal`, `association :contact_point` (link to CP) |
| `:public_meter` | `meter_type: :public_meter` (KHÔNG có association :contact_point — caller phải truyền) |
| `:pump_station` | `meter_type: :pump_station` (KHÔNG có association :contact_point) |

**Lưu ý:** Chỉ trait `:normal` tự link `contact_point`. Loại `:public_meter` và `:pump_station` thường gắn organization-level, caller phải truyền `contact_point: cp` nếu cần. Loại `:no_loss` chưa implement — xem 04_DATABASE_MODELS TODO #1.

### 3.5 `:meter_reading` — `MeterReading`

```ruby
association :meter
association :monthly_period
reading_start { 1000 }
reading_end   { 1250 }
consumption   { 250 }
```

Không có trait. Caller phải truyền giá trị thực tế khi cần test engine.

### 3.6 `:personnel` — `Personnel`

```ruby
association :contact_point
association :monthly_period
rank1_count { 2 }
rank2_count { 5 }
rank3_count { 10 }
rank4_count { 20 }
rank5_count { 0 }
rank6_count { 3 }
rank7_count { 0 }
```

Không có trait. Default tổng = 40 người (test engine spec hay override theo kịch bản cụ thể).

### 3.7 `:rank_quota` — `RankQuota`

```ruby
sequence(:rank_group)     { |n| ((n - 1) % 7) + 1 }   # 1..7 cycle
rank_name                { "Si quan cap cao" }
quota_kw                 { 570 }
sequence(:effective_from) { |n| Date.new(2020, 1, 1) + ((n - 1) / 7).years }
```

7 trait `:rank1` đến `:rank7` với đầy đủ mapping định mức + tên (theo Nghị định 02 cũ, không khớp 100% mapping mới — xem TODO #2):

| Trait | rank_group | rank_name | quota_kw |
|---|---:|---|---:|
| `:rank1` | 1 | Si quan cap cao | 570 |
| `:rank2` | 2 | Si quan | 440 |
| `:rank3` | 3 | Ha si quan | 305 |
| `:rank4` | 4 | Binh si | 130 |
| `:rank5` | 5 | Chuyen nghiep | 210 |
| `:rank6` | 6 | Cong nhan vien quoc phong | 110 |
| `:rank7` | 7 | Hoc vien | 24 |

Tất cả trait set `effective_from: Date.new(2024, 1, 1)`.

**Sequence quan trọng:** `((n-1) % 7) + 1` đảm bảo nếu test tạo nhiều rank_quota qua sequence, `rank_group` chu kỳ 1..7 — nhưng `effective_from` tăng theo năm (mỗi 7 lần tạo, năm tăng 1). Pattern này cho phép tạo `RankQuota` history qua thời gian. Cột DB unique scoped: `(rank_group, effective_from)`.

### 3.8 `:monthly_period` — `MonthlyPeriod`

```ruby
sequence(:year)  { |n| 2026 + ((n - 1) / 12) }   # 2026, 2026, ..., 2027 sau 12 lần
sequence(:month) { |n| ((n - 1) % 12) + 1 }      # 1..12 cycle
unit_price       { 2000 }
locked           { false }
```

| Trait | Tác dụng |
|---|---|
| `:locked` | `locked: true`, `locked_at: Time.current`, `association :locked_by, factory: :user` |

### 3.9 `:monthly_calculation` — `MonthlyCalculation`

Snapshot đầy đủ 24 cột với giá trị mẫu (40 người, 1140 kW rank1, ..., total_amount 14_900_000). Dùng cho render-only system test (seed thẳng vào DB, không qua engine).

```ruby
total_personnel        { 40 }
rank1_kw .. rank7_kw   # 1140, 2200, 3050, 2600, 0, 330, 0
water_pump_standard_kw { 378 }
water_pump_actual_kw   { 350 }
total_standard_kw      { 9320 }
savings_deduction_kw   { 466 }
loss_deduction_kw      { 93 }
division_public_deduction_kw { 932 }
unit_public_deduction_kw     { 466 }
other_deduction_kw     { 0 }
total_deduction_kw     { 1957 }
remaining_standard_kw  { 7363 }
meter_usage_kw         { 7100 }
total_usage_kw         { 7450 }
over_under_kw          { -87 }   # signed: -87 = thừa 87 kW (xem TODO #3)
unit_price             { 2000 }
total_amount           { 14_900_000 }
```

**Lưu ý sign convention `over_under_kw`:** 02_GLOSSARY mục 14 + 13_BUSINESS_RULES quy định `over_under_kw > 0 = thiếu`, `< 0 = thừa`. Default factory `over_under_kw: -87` ứng với "thừa". Nhưng một số system spec (ví dụ `f08_f11_calculation_engine_spec.rb:74`) override `over_under_kw: 87` ứng với "thiếu" — tham khảo `total_amount: 174_000` ở dòng đó để xác nhận. Caller phải đặt giá trị đúng kịch bản.

### 3.10 `:unit_config` — `UnitConfig`

```ruby
association :organization
association :monthly_period
savings_rate          { 0.05 }    # 5%
division_public_rate  { 0.10 }    # 10%
unit_public_rate      { 0.05 }    # 5%
other_deduction_type  { :fixed_kw }
other_deduction_value { 0 }
electricity_supply_kw { nil }     # admin_unit nhập riêng qua F05
```

Không có trait.

### 3.11 `:contact_point_other_deduction` — `ContactPointOtherDeduction`

```ruby
association :contact_point
association :monthly_period
other_type  { :fixed_kw }
other_value { 0 }
```

Không có trait. Cho phép `other_value` âm — model đã gỡ validation `greater_than_or_equal_to: 0` ở PR#61.

### 3.12 `:pump_station` — `PumpStation`

```ruby
sequence(:name) { |n| "Tram bom #{n}" }
association :organization
meter { nil }
```

Không có trait. Caller truyền `meter: meter_pump_station_factory` khi cần liên kết.

### 3.13 `:pump_station_assignment` — `PumpStationAssignment`

```ruby
association :pump_station
association :organization
```

Bảng nối đơn thuần.

---

## 4. Shared examples và support

### 4.1 Shared examples (3)

#### 4.1.1 `redirects with access_denied` (role_access.rb)

Dùng cho request specs khi user không có quyền.

```ruby
it_behaves_like "redirects with access_denied"
```

Assert: `redirect_to(root_path)` + `flash[:alert] == I18n.t("flash.access_denied")`.

#### 4.1.2 `silently redirects tech to users_path` (role_access.rb)

Dùng cho request specs khi role `tech` truy cập nhầm nghiệp vụ — bounce về `/users` không kèm flash.

```ruby
it_behaves_like "silently redirects tech to users_path"
```

Assert: `redirect_to(users_path)` + `flash[:alert]` blank.

#### 4.1.3 `denies cross-org parent access` (nested_resource_authorization.rb)

Dùng cho nested resource controllers (ví dụ `MetersController` nested under `contact_points/:id`). Yêu cầu spec định nghĩa `subject { make_request }` và `before { sign_in user_with_access }`.

```ruby
context "when contact_point does not exist (existence enumeration)" do
  before  { sign_in admin_unit_a }
  subject { get contact_point_path(id: 999_999) }
  it_behaves_like "denies cross-org parent access"
end
```

Mục đích: confirm response cho "ID không tồn tại" và "ID cross-org" giống hệt nhau (close enumeration side channel — xem 06_AUTH_SECURITY mục 4.4).

### 4.2 SystemSpecHelpers — 4 helper

Tự động include vào `type: :system` qua `RSpec.configure` trong `spec/support/system_spec_helpers.rb`.

#### 4.2.1 `setup_basic_scenario(year: 2026, month: 2)`

Tạo baseline data cho system spec:
- 1 Division (parent)
- 1 Unit (con của Division)
- 7 RankQuota (rank1..rank7 với định mức 570/440/305/130/210/110/24)
- 1 MonthlyPeriod (year, month)
- 4 user, 1 cho mỗi role: `admin_unit`, `admin_level1`, `commander`, `tech`

Trả về `OpenStruct` truy cập qua dot notation:

```ruby
let(:scenario) { setup_basic_scenario }
# scenario.division, scenario.unit, scenario.period
# scenario.admin_level1, scenario.admin_unit, scenario.commander, scenario.tech
```

#### 4.2.2 `create_full_calculation_data(scenario, personnel_counts: { rank1: 2, rank5: 10 })`

Thêm data đủ để engine sinh `MonthlyCalculation` cho 1 đầu mối:
- 1 ContactPoint thuộc `scenario.unit`
- 1 Personnel theo `personnel_counts` (default: rank1=2, rank5=10)
- 1 Meter `:normal` + 1 MeterReading (start=100, end=500, consumption=400)
- 1 UnitConfig (savings 5%, div_public 10%, unit_public 0%, electricity_supply 50.000 kW)

Trả về `ContactPoint` vừa tạo. Dùng cho test engine end-to-end (xem `spec/system/f08_f11_calculation_engine_spec.rb:17`).

#### 4.2.3 `setup_history_scenario`

Mở rộng `setup_basic_scenario` cho F13 (so sánh cùng kỳ năm trước):
- 1 ContactPoint
- 1 MonthlyCalculation cho period hiện tại (2026/02)
- 1 MonthlyPeriod (2025/02) + 1 MonthlyCalculation cho period đó

Trả về `OpenStruct` mở rộng: thêm `contact_point`, `current_calc`, `prior_period`, `prior_calc`.

#### 4.2.4 `sign_in_via_form(email, password)`

Đăng nhập qua form Devise thật (không qua `login_as` của Warden helper). Dùng khi cần test flow Devise đầy đủ — F16 redirect, F17 lockable counter, F18 force password change. `login_as` của Warden bypass form nên không exercise được các path này.

```ruby
visit new_user_session_path
fill_in "Email",    with: email
fill_in "Mật khẩu", with: password
click_button "Đăng nhập"
```

### 4.3 Chrome stale-node workaround

`spec/support/chrome_stale_node_fix.rb` patch `Capybara::Selenium::ChromeNode#visible?` rescue lỗi `-32000` "Node with given id does not belong to the document" mà Chrome 136+ thỉnh thoảng raise.

**Bản chất lỗi:** Race condition giữa Selenium element reference và DOM mutation (Stimulus update textContent rất nhanh). Selenium tìm element qua CSS, nhưng node ID nội bộ Chrome đã bị invalidate trước khi `isElementDisplayed` được gọi.

**Cách fix:** Khi `visible?` raise lỗi này, trả `false` (= "không thấy") thay vì propagate. Capybara's `synchronize` loop sẽ retry toàn bộ query — đó chính là recovery path đúng. Không có patch này, system specs có :js fail không deterministic.

```ruby
def visible?
  super
rescue Selenium::WebDriver::Error::UnknownError => e
  raise unless e.message.include?("does not belong to the document")
  false
end
```

### 4.4 Capybara configuration

`spec/support/capybara.rb`:

| Setting | Giá trị | Lý do |
|---|---|---|
| `default_driver` | `:rack_test` | Mặc định không bật browser — nhanh, đủ cho system spec không cần JS. |
| `javascript_driver` | `:headless_chrome` | Khi spec có `:js`, Capybara dùng Selenium + Chrome headless. |
| `server` | `:puma, { Silent: true }` | Puma cho real HTTP server (Selenium cần). `Silent` để log không ô nhiễm RSpec output. |
| Window size | `1400×900` | Vừa đủ để render bảng 24 cột không bị cuộn ngang trong screenshot. |
| Chrome args | `--headless=new`, `--no-sandbox`, `--disable-dev-shm-usage`, `--disable-gpu`, `--disable-software-rasterizer` | Headless mới (Chrome 109+) + flags giúp chạy CI/Docker không lỗi. |

**Selenium Manager:** Resolve ChromeDriver động qua `Selenium::WebDriver::SeleniumManager.binary_paths("--browser", "chrome", "--skip-driver-in-path")` để bỏ qua chromedriver homebrew cũ trong PATH.

### 4.5 Hooks mặc định cho system specs

```ruby
config.before(:each, type: :system)            { driven_by :rack_test }
config.before(:each, type: :system, js: true)  { driven_by :headless_chrome }
config.after(:each, type: :system)             { Warden.test_reset! }
```

`Warden.test_reset!` xóa session warden sau mỗi example — tránh leak login giữa các examples.

---

## 5. Test conventions

### 5.1 Model specs — pattern

Mọi model spec mở đầu bằng `require "rails_helper"` + `RSpec.describe ModelClass, type: :model do`. Cấu trúc 4 section:

```ruby
RSpec.describe ContactPoint, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:meters) }
  end

  describe "validations" do
    subject { build(:contact_point) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id) }
  end

  describe "scopes" do
    let!(:cp1) { create(:contact_point, position: 2) }
    let!(:cp2) { create(:contact_point, position: 1) }
    it ".ordered sorts by position" do
      expect(ContactPoint.ordered.first).to eq(cp2)
    end
  end

  describe "<business method>" do
    # method-specific tests
  end
end
```

**Quy ước:**
- One-liner với `is_expected.to ...` cho associations và validations đơn giản — dùng shoulda-matchers.
- Test scope phải có `let!` (eager evaluation) để bản ghi tồn tại trước khi `subject` chạy.
- Edge cases (allow blank, prevent duplicate, allow same name in different orgs) dùng `it "..." do ... end` với assertion rõ ràng.

### 5.2 Request specs — pattern

`type: :request` tự động infer qua `spec/requests/` (vì `infer_spec_type_from_file_location!`). Pattern chung:

```ruby
RSpec.describe "ContactPoints", type: :request do
  let(:org_a) { create(:organization, level: :unit) }
  let(:admin_unit_a) { create(:user, role: :admin_unit, organization: org_a) }

  describe "GET /contact_points" do
    context "as admin_unit" do
      it "shows only own organization's contact points" do
        sign_in admin_unit_a   # Devise::Test::IntegrationHelpers
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        get contact_points_path
        expect(response).to redirect_to(users_path)
      end
    end
  end
end
```

**Quy ước:**
- Mỗi action HTTP có 1 `describe` block.
- Mỗi role có 1 `context` block.
- Assert đầy đủ: status code (`have_http_status(:ok)` hoặc `redirect_to(...)`) + body content (`include(...)`/`not_to include(...)`) hoặc flash (`expect(flash[:alert]).to eq(...)`).
- Existence enumeration test: dùng shared example `denies cross-org parent access` với ID `999_999` — confirm response giống cross-org access.
- Login: `sign_in user` (alias Devise integration helper). Không cần truyền password — bypass mật khẩu.
- Logout: `sign_out user` (ít dùng vì transactional fixtures rollback).

### 5.3 Service specs — pattern

`type: :service` không tồn tại auto trong RSpec — service spec nằm `spec/services/` rơi về type mặc định (nil). Vẫn require `rails_helper` để load Rails environment + factories.

```ruby
RSpec.describe CalculationEngine do
  let(:organization)    { create(:organization, level: :unit) }
  let(:period)          { create(:monthly_period, year: 2026, month: 2) }
  let!(:rank_quota1)    { create(:rank_quota, rank_group: 1, quota_kw: 570) }
  # ... seed data đầy đủ ...

  describe "#call" do
    it "computes total_standard_kw correctly" do
      result = described_class.new(organization: organization, monthly_period: period).call
      expect(result.first[:total_standard_kw]).to eq(BigDecimal("1149.45"))
    end

    it "is idempotent — calling twice does not duplicate rows" do
      service = described_class.new(organization: organization, monthly_period: period)
      service.call
      expect { service.call }.not_to change(MonthlyCalculation, :count)
    end
  end
end
```

**Quy ước:**
- Setup data đầy đủ qua `let!` (eager) — engine cần đọc input từ DB.
- Compute expected value bằng BigDecimal trong comment ở đầu spec (ví dụ `calculation_engine_spec.rb:88–98`) — giúp reviewer verify công thức.
- Test BigDecimal precision: dùng `eq(BigDecimal("..."))` cho equality chính xác, dùng `be_within(0.01).of(...)` chỉ khi có làm tròn ở display layer.
- Service idempotent: gọi `call` 2 lần, count không đổi — quan trọng cho engine và import service.

**Riêng `BackupService`:** stub `Open3.capture3` để không thực sự gọi `pg_dump`/`pg_restore` (xem `backup_service_spec.rb:15–18`). Stub `BACKUP_DIR` thành `tmp/test_backups` để cleanup được.

### 5.4 System specs — pattern

`type: :system` infer từ `spec/system/`. Pattern chung F-number-based:

```ruby
RSpec.describe "F01 — Contact points", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }   # Warden helper

    it "creates, edits, and destroys a contact point" do
      visit contact_points_path
      click_on I18n.t("contact_points.index.new_button")
      fill_in I18n.t("contact_points.form.name"), with: "Test Đầu Mối"
      click_on I18n.t("contact_points.form.submit_create")
      expect(page).to have_content(I18n.t("flash.contact_points.created"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }
    it "sees the list but not the create/edit/delete affordances" do
      # ...
      expect(page).not_to have_link(I18n.t("contact_points.index.new_button"))
    end
  end
end
```

**Quy ước:**
- Cấu trúc: `RSpec.describe "F<NN> — <feature>"` → `let(:scenario) { setup_basic_scenario }` → 1 `describe` block cho mỗi role.
- Login: `login_as user, scope: :user` (Warden helper, bypass form). Dùng `sign_in_via_form` chỉ khi cần test form Devise (F16/F17/F18).
- Match UI: `I18n.t(...)` với key đầy đủ — không hardcode tiếng Việt.
- Selectors ổn định: `[data-testid='detail-table']`, `[data-cp-id='...']`, `[data-role='other-value']`. **Không** dựa vào class Tailwind (class có thể đổi mà không ảnh hưởng nghiệp vụ). Xem `f13_history_spec.rb` cho ví dụ điển hình.
- Stimulus interactions: tag `:js` để dùng headless Chrome. Ví dụ `f04_unit_configs_spec.rb:30` test toggle "Khác" type.
- `within(...)`: scope assertion vào DOM region cụ thể, tránh false positive khi text xuất hiện ở nhiều chỗ.
- Click destroy: dùng `click_button` (không phải `click_on`) vì `click_on` match cả link "Xóa bộ lọc" — xem comment ở `f01_contact_points_spec.rb:38`.

**Setup heavy:** Engine end-to-end specs dùng `create_full_calculation_data(scenario)` để tạo CP + meter + reading + config + personnel cùng lúc (xem `f08_f11_calculation_engine_spec.rb:17`).

### 5.5 Screenshot specs — pattern

`spec/screenshots/user_guide_screenshots_spec.rb` (16 examples). Tag bắt buộc: `js: true, screenshots: true, type: :system`. Không phải test thật — sinh ảnh cho 11_USER_GUIDE.

```ruby
RSpec.describe "User Guide Screenshots", type: :system, js: true, screenshots: true do
  before(:context) do
    # Tạo 1 lần data đầy đủ qua ImportFeb2026Service
    @division = FactoryBot.create(:organization, :division, name: "Sư đoàn")
    @result = ImportFeb2026Service.new.call
    # ...
  end

  after(:context) do
    ApplicationRecord.connection.execute(
      "TRUNCATE TABLE organizations, monthly_periods, ... RESTART IDENTITY CASCADE"
    )
  end

  it "01_login_page" do
    visit root_path
    ss "01_login_page"
  end
  # ... 15 cảnh khác
end
```

**Quy ước:**
- `before(:context)` (không phải `before(:each)`) — data setup dùng chung tất cả examples, save thời gian (`ImportFeb2026Service` mất 5–10s).
- `after(:context)` TRUNCATE manual — vì data ngoài transaction example, transactional fixtures không rollback.
- 2 helper riêng: `ss(name)` chụp viewport thường (1280×900); `save_full_page_screenshot(name)` chụp toàn trang (chỉ dùng cho cảnh F03 với section "Kết quả tính toán" dài hơn viewport).
- Output: `tmp/screenshots/<NN>_<name>.png` — tmp gitignored, mỗi lần chạy tự ghi đè.
- Tag `:screenshots` để filter ra khỏi default run.

### 5.6 Task specs — pattern

`type: :task` không tồn tại auto. Convention: file ở `spec/tasks/`, manual `RSpec.describe "...", type: :task`.

```ruby
RSpec.describe "admin:reset_password rake task", type: :task do
  let(:task_name) { "admin:reset_password" }

  before(:all) { Rails.application.load_tasks }
  before       { Rake::Task[task_name].reenable }    # Reenable mỗi lần để invoke lại

  it "resets password and unlocks the account" do
    Rake::Task[task_name].invoke(user.email)
    user.reload
    expect(user.locked_at).to be_nil
    expect(user.failed_attempts).to eq(0)
    expect(user.force_password_change).to be true
  end
end
```

**Quy ước:**
- `Rails.application.load_tasks` 1 lần ở `before(:all)`.
- `Rake::Task[name].reenable` ở `before` — vì task mặc định chỉ chạy 1 lần per process.
- Test exit codes: `expect { ... }.to raise_error(SystemExit)` cho abort path.
- Test stdout: `expect { ... }.to output(/regex/m).to_stdout`.

---

## 6. CI workflow

### 6.1 File `.github/workflows/ci.yml`

**Trigger:**
```yaml
on:
  pull_request:
  push:
    branches: [ main ]
```

→ Mọi PR và mỗi push lên `main` đều trigger CI.

### 6.2 Ba job song song

| Job | Step chính | Mục đích |
|---|---|---|
| `scan_ruby` | `bin/brakeman --no-pager` + `bin/bundler-audit` | Tĩnh phân tích lỗ hổng Rails + audit gem có CVE đã biết |
| `scan_js` | `bin/importmap audit` | Audit JavaScript dependency (importmap-rails, không có Node) |
| `lint` | `bin/rubocop -f github` | Style Ruby. Cache RuboCop ở `tmp/rubocop` qua `actions/cache@v5` để speed up |

Chi tiết format GitHub Actions output: `-f github` cho rubocop sinh annotation inline trong PR diff.

### 6.3 KHÔNG có RSpec trong CI

CI **không chạy `bundle exec rspec`**. Lý do (bối cảnh M1–M5 solo developer + deadline):
- System specs cần Chrome headless + Selenium Manager — setup phức tạp trong GitHub Actions runner.
- Engine spec đọc factories phức tạp — chạy chậm trên free runner.
- Developer chạy local (qua `bundle exec rspec`) trước khi commit — đã có guardrail khác (rubocop, brakeman, bundler-audit).
- Trade-off: chấp nhận risk regression không bị bắt bởi CI để giữ pipeline xanh nhanh, không block PR merge.

**Hệ quả:** Trách nhiệm chạy test thuộc về developer trước khi mở PR. PR description (theo memory feedback) phải có `## Test plan` checklist liệt kê manual testing đã làm. Xem TODO #5.

### 6.4 `bin/ci` — local CI runner

File `bin/ci` chạy `config/ci.rb`:

```ruby
# config/ci.rb
CI.run do
  step "Setup",                                  "bin/setup --skip-server"
  step "Style: Ruby",                             "bin/rubocop"
  step "Security: Gem audit",                     "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis",        "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
```

Chạy `bin/ci` local sẽ thực thi đúng các step như GitHub Actions. **Vẫn không có RSpec** — phải chạy `bundle exec rspec` riêng.

### 6.5 PostgreSQL service container

CI **không cần** PostgreSQL container vì 3 job CI hiện tại (brakeman, bundler-audit, rubocop) đều chạy tĩnh, không touch DB. Khi (nếu) thêm RSpec vào CI, sẽ cần `services: postgres:` block trong `ci.yml`.

### 6.6 Artifacts

Hiện không upload artifacts. Khi thêm RSpec, có thể upload `tmp/screenshots/`, `coverage/`, hoặc test report (junit-xml format) để trace failure trên CI.

---

## 7. Cách chạy tests

### 7.1 Cheat sheet

```bash
# Toàn bộ default suite (853 examples, exclude screenshots)
bundle exec rspec

# 1 file
bundle exec rspec spec/services/calculation_engine_spec.rb

# 1 example tại line N (line là dòng `it "..."` hoặc trong block)
bundle exec rspec spec/services/calculation_engine_spec.rb:42

# 1 directory
bundle exec rspec spec/system/
bundle exec rspec spec/models/

# Theo tag — chỉ chạy screenshot specs (16 examples)
bundle exec rspec --tag screenshots

# Loại trừ tag — bỏ system specs (chỉ chạy ~631 non-system examples)
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"

# Đếm specs (dry-run, không thực thi)
bundle exec rspec --dry-run

# Chạy theo tag :js (Stimulus interactions, headless Chrome)
bundle exec rspec --tag js

# Chạy lại chỉ failures lần trước
bundle exec rspec --only-failures

# Verbose documentation format (output đẹp khi debug 1 file)
bundle exec rspec spec/models/user_spec.rb --format documentation

# Seed cố định để reproduce flake test
bundle exec rspec --seed 12345

# Local CI (rubocop + audit, KHÔNG chạy rspec)
bin/ci
```

### 7.2 Chạy nhanh (skip system)

System specs (222 examples) dùng Capybara + browser → chậm nhất. Để feedback loop nhanh khi sửa model/service:

```bash
bundle exec rspec spec/models/ spec/services/ spec/requests/ spec/tasks/
# 277 + 71 + 278 + 5 = 631 examples, ~30s
```

### 7.3 Chạy screenshot specs

```bash
bundle exec rspec --tag screenshots
# Output: tmp/screenshots/01_login_page.png ... 16_*.png
# Mất ~1–2 phút (ImportFeb2026Service + 16 cảnh)
```

Trước khi chạy lần đầu, đảm bảo `tmp/screenshots/` có thể tạo + Chrome headless cài sẵn (Selenium Manager tự cài driver).

### 7.4 Pre-commit checklist (theo feedback memory)

Theo memory feedback `feedback_rubocop_full_project.md`:

```bash
bin/rubocop -f github       # KHÔNG giới hạn path
bundle exec rspec           # Trước khi push
```

Đặc biệt với code engine (calculation_engine.rb), service (period_inheritance, import, backup), hoặc Ability — chạy spec tương ứng + rspec full để đảm bảo không regression.

---

## 8. Cách thêm test mới

### 8.1 Thêm model spec

1. Tạo file `spec/models/<model>_spec.rb`. Ví dụ thêm test cho `WaterMeter`:

```ruby
require "rails_helper"

RSpec.describe WaterMeter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
  end

  describe "validations" do
    subject { build(:water_meter) }
    it { is_expected.to validate_presence_of(:serial_number) }
    it { is_expected.to validate_uniqueness_of(:serial_number) }
  end

  describe "scopes" do
    let!(:active_meter) { create(:water_meter, active: true) }
    let!(:inactive_meter) { create(:water_meter, active: false) }
    it ".active filters by active flag" do
      expect(WaterMeter.active).to include(active_meter)
      expect(WaterMeter.active).not_to include(inactive_meter)
    end
  end
end
```

2. Tạo factory tương ứng `spec/factories/water_meters.rb`:

```ruby
FactoryBot.define do
  factory :water_meter do
    sequence(:serial_number) { |n| "WM#{n.to_s.rjust(6, '0')}" }
    active { true }
    association :contact_point
  end
end
```

3. Chạy `bundle exec rspec spec/models/water_meter_spec.rb`.

### 8.2 Thêm request spec

1. Tạo file `spec/requests/<resource>_spec.rb`.
2. Pattern chuẩn:

```ruby
require "rails_helper"

RSpec.describe "WaterMeters", type: :request do
  let(:org)         { create(:organization, :unit) }
  let(:admin_unit)  { create(:user, :admin_unit, organization: org) }
  let!(:meter)      { create(:water_meter, organization: org) }

  describe "GET /water_meters" do
    context "as admin_unit" do
      before { sign_in admin_unit }   # Devise::Test::IntegrationHelpers
      it "lists own organization's meters" do
        get water_meters_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meter.serial_number)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get water_meters_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /water_meters/:id" do
    context "as admin_unit accessing another org's meter" do
      let(:other_org) { create(:organization, :unit) }
      let(:foreign_meter) { create(:water_meter, organization: other_org) }
      before { sign_in admin_unit }
      it_behaves_like "redirects with access_denied" do
        before { get water_meter_path(foreign_meter) }
      end
    end
  end
end
```

3. Khi nested resource, dùng shared example `denies cross-org parent access` cho parent ID không tồn tại + cross-org.

### 8.3 Thêm service spec

1. Tạo file `spec/services/<service>_spec.rb` (không cần `type:` declaration).
2. Setup data qua `let!` (eager) — service đọc từ DB:

```ruby
require "rails_helper"

RSpec.describe WaterUsageEngine do
  let(:org)    { create(:organization, :unit) }
  let(:period) { create(:monthly_period, year: 2026, month: 3) }
  let!(:meter) { create(:water_meter, organization: org) }
  let!(:reading) do
    create(:water_meter_reading, meter: meter, monthly_period: period,
           reading_start: 100, reading_end: 250)
  end

  describe "#call" do
    subject { described_class.new(organization: org, monthly_period: period).call }

    it "computes consumption from start/end" do
      result = subject
      expect(result.first[:consumption_m3]).to eq(BigDecimal("150"))
    end

    it "is idempotent" do
      described_class.new(organization: org, monthly_period: period).call
      expect {
        described_class.new(organization: org, monthly_period: period).call
      }.not_to change(WaterUsageRecord, :count)
    end

    it "handles empty period gracefully" do
      empty_period = create(:monthly_period, year: 2026, month: 4)
      result = described_class.new(organization: org, monthly_period: empty_period).call
      expect(result).to be_empty
    end
  end
end
```

3. Edge cases bắt buộc cover: empty input, idempotent (run twice, no duplicate), BigDecimal precision (no rounding in intermediate).
4. External commands (`pg_dump`, HTTP API) phải stub qua `allow(Open3).to receive(:capture3)` tương tự `BackupService` spec.

### 8.4 Thêm system spec

1. Tạo file `spec/system/f<NN>_<feature>_spec.rb` (1 file/F-number).
2. Pattern:

```ruby
require "rails_helper"

RSpec.describe "F22 — Water meter management", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }   # Warden helper

    it "creates a water meter via the form" do
      visit water_meters_path
      click_on I18n.t("water_meters.index.new_button")
      fill_in I18n.t("water_meters.form.serial_number"), with: "WM123456"
      click_on I18n.t("water_meters.form.submit_create")

      expect(page).to have_content(I18n.t("flash.water_meters.created"))
      expect(page).to have_content("WM123456")
    end

    it "filters by active flag", :js do
      create(:water_meter, organization: scenario.unit, active: true,  serial_number: "WM-A")
      create(:water_meter, organization: scenario.unit, active: false, serial_number: "WM-B")

      visit water_meters_path
      within("[data-testid='filter-bar']") do
        select I18n.t("water_meters.filter.active_only"),
               from: "q[active_eq]"
      end
      expect(page).to have_content("WM-A")
      expect(page).not_to have_content("WM-B")
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }
    it "sees the list but not create/edit/destroy buttons" do
      create(:water_meter, organization: scenario.unit)
      visit water_meters_path
      expect(page).not_to have_link(I18n.t("water_meters.index.new_button"))
    end
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }
    it "is bounced to /users" do
      visit water_meters_path
      expect(page).to have_current_path(users_path)
    end
  end
end
```

3. **Selectors ổn định:** Trong view template, thêm `data-testid="filter-bar"` thay vì dựa vào class Tailwind. Spec chỉ assert qua `[data-testid='...']` — view styling đổi không phá test.
4. **Stimulus / JS interactions:** Tag `:js` để chuyển sang headless Chrome. Test `data-action`, `data-controller`, `data-role` qua `find("[data-role='...']")`.
5. **I18n key:** Mọi text UI phải qua `I18n.t(...)`. Không hardcode "Tạo mới" — vì nếu vi.yml đổi thành "Thêm mới", spec break không cần thiết.
6. **F-number cho file mới:** Nếu là feature mở rộng (không thuộc F01–F21), dùng F22+ hoặc đặt tên không có F-prefix (`spec/system/water_meter_spec.rb`). Đăng ký F-number mới vào 02_GLOSSARY mục 8 + 12_SCOPE.

### 8.5 Thêm screenshot spec

Hiếm khi cần — đa số chỉ thêm scenes vào `user_guide_screenshots_spec.rb`. Nếu thêm scene mới:

```ruby
it "17_water_meter_form" do
  login_as @admin_unit, scope: :user
  visit new_water_meter_path
  ss "17_water_meter_form"   # tmp/screenshots/17_water_meter_form.png
end
```

Tag bắt buộc trên `RSpec.describe`: `type: :system, js: true, screenshots: true`. Sau đó cập nhật 11_USER_GUIDE để reference ảnh mới.

### 8.6 Thêm rake task spec

```ruby
require "rails_helper"
require "rake"

RSpec.describe "data:cleanup_old_periods rake task", type: :task do
  let(:task_name) { "data:cleanup_old_periods" }

  before(:all) { Rails.application.load_tasks }
  before       { Rake::Task[task_name].reenable }

  it "deletes monthly_periods older than 5 years" do
    old = create(:monthly_period, year: 2019, month: 1)
    new = create(:monthly_period, year: 2026, month: 2)

    expect { Rake::Task[task_name].invoke }
      .to change(MonthlyPeriod, :count).by(-1)
    expect(MonthlyPeriod.exists?(old.id)).to be false
    expect(MonthlyPeriod.exists?(new.id)).to be true
  end
end
```

### 8.7 Update factory khi thay schema

Khi thêm cột vào model:
1. Migration tạo cột.
2. Update `spec/factories/<model>.rb` — thêm default cho cột mới (nullable thì OK, NOT NULL bắt buộc add default).
3. Chạy `bundle exec rspec` — bắt regression nếu có spec dựa vào factory.

Khi đổi `meter_type` enum (ví dụ thêm `:no_loss`):
1. Update model `Meter` — thêm value vào enum.
2. Update factory `spec/factories/meters.rb` — thêm trait `:no_loss`.
3. Update `02_GLOSSARY` mục 2 — đóng TODO #1 nếu áp dụng.
4. Thêm spec cho behavior mới (engine bỏ qua khi tính tổn hao).

---

## TODO — sai lệch giữa code và docs

### TODO #1 — Tên file system spec F18 không khớp F-number

**File:** `spec/system/f16_force_password_change_spec.rb`

**Sai lệch:** File tên `f16_*` (= F16 Đăng nhập) nhưng nội dung test **F18 — Bắt buộc đổi mật khẩu lần đầu** (`force_password_change`). F16 (form đăng nhập) đã được test ở `spec/system/devise_sessions_spec.rb`.

**Đề xuất:** Rename file thành `spec/system/f18_force_password_change_spec.rb` để khớp 02_GLOSSARY mục 8.5. Đồng thời rename `spec/system/f18_session_timeout_spec.rb` (đang test session timeout — không có F-number riêng theo glossary, là tính năng Devise Timeoutable) thành `spec/system/session_timeout_spec.rb` hoặc giữ nguyên nếu coi session timeout là phần của F16. Quyết định: ưu tiên đổi để tránh nhầm lẫn cho người mới đọc spec.

### TODO #2 — Tên rank trong factory không khớp 02_GLOSSARY

**File:** `spec/factories/rank_quotas.rb`

**Sai lệch:** 7 trait `:rank1`..`:rank7` mapping `rank_name` thành: `Si quan cap cao` / `Si quan` / `Ha si quan` / `Binh si` / `Chuyen nghiep` / `Cong nhan vien quoc phong` / `Hoc vien`.

Theo 02_GLOSSARY mục 9, tên đầy đủ phải là:
| Group | Glossary name | Factory name (sai) |
|---|---|---|
| 1 | Chỉ huy Sư đoàn; SQ có trần Đại tá | Si quan cap cao |
| 2 | Chỉ huy Trung đoàn; SQ có trần Thượng tá | Si quan |
| 3 | Chỉ huy Tiểu đoàn; SQ có trần Trung tá/Thiếu tá | Ha si quan |
| 4 | Chỉ huy Đại đội; SQ cấp Úy | Binh si |
| 5 | Cơ quan Sư đoàn, Trung đoàn | Chuyen nghiep |
| 6 | Tiểu đoàn, Đại đội | Cong nhan vien quoc phong |
| 7 | Hạ sĩ quan, Binh sĩ | Hoc vien |

Định mức (`quota_kw`) thì khớp glossary (570/440/305/130/210/110/24).

**Đề xuất:** Cập nhật factory để khớp tên glossary. Ảnh hưởng: ~30 spec assertion có dùng `rank_name` text — cần sửa hoặc dùng id thay vì text. Đây là task low-risk, làm trong slot consolidation tài liệu.

### TODO #3 — Sign convention `over_under_kw` trong factory không có trait

**File:** `spec/factories/monthly_calculations.rb`

**Sai lệch:** Default `over_under_kw: -87` ứng với "thừa" (theo glossary `over_under_kw < 0 = thừa`), nhưng nhiều spec override thành dương. Không có trait `:surplus` hoặc `:deficit` để rõ intent.

**Đề xuất:** Thêm 2 trait:
```ruby
trait :surplus do
  over_under_kw { -87 }
  total_amount  { -174_000 }
end
trait :deficit do
  over_under_kw { 87 }
  total_amount  { 174_000 }
end
```
Để spec viết `create(:monthly_calculation, :deficit, ...)` thay vì truyền số tay → đọc spec rõ intent hơn. Default factory có thể giữ `:surplus` semantic.

### TODO #4 — `spec/fixtures` không tồn tại nhưng config trỏ vào

**File:** `spec/rails_helper.rb:30`

**Sai lệch:** `config.fixture_paths = [Rails.root.join('spec/fixtures')]` nhưng thư mục không tồn tại. Project không dùng Rails fixtures — toàn bộ data sinh qua FactoryBot. File data Excel khách thật ở `test/fixtures/files/bang_tinh_thang_02.xlsx` (đường dẫn `test/`, không phải `spec/`).

**Đề xuất:** Hoặc (a) gỡ dòng config (cleanup config dead), hoặc (b) tạo `spec/fixtures/files/` symlink/copy `bang_tinh_thang_02.xlsx` để config có ý nghĩa. Phương án (a) đơn giản hơn — file Excel đang được đọc qua đường dẫn tuyệt đối trong service, không qua fixture loader.

### TODO #5 — CI không chạy RSpec

**File:** `.github/workflows/ci.yml`

**Sai lệch (so với best practice):** CI hiện chỉ chạy rubocop + brakeman + bundler-audit + importmap audit. Không chạy `bundle exec rspec`. Risk: regression engine hoặc auth có thể merge nếu developer quên chạy local.

**Đề xuất (sau M6):** Thêm job `test` vào `ci.yml`:
- Service container `postgres:16`.
- Cài Chrome headless qua `browser-actions/setup-chrome`.
- Step `bundle exec rspec --exclude-pattern "spec/screenshots/**/*"` để skip screenshot specs (cần data thật, slow).

Hiện tại chấp nhận risk vì developer chạy local + có guardrail rubocop/brakeman + PR review thủ công. Khi mở rộng team M6+, ưu tiên thêm step này.

### TODO #6 — Spec cho `Ability` nằm trong `spec/models/`

**File:** `spec/models/ability_spec.rb`

**Quan sát:** `Ability` không phải ActiveRecord model, đặt trong `spec/models/` theo convention CanCanCan. Đây không phải sai lệch — chỉ note để developer mới không nhầm. Không cần action.

---

## Changelog

| Version | Ngày | Thay đổi |
|---|---|---|
| v1.0.0 | 01/05/2026 | Khởi tạo. Tổng quan 853+16 specs, breakdown theo type, factories, conventions, CI workflow, hướng dẫn thêm test mới. |
