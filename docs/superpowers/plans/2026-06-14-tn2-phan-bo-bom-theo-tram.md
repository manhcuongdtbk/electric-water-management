# TN2 — Phân bổ bơm nước theo từng trạm bơm — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phân bổ điện bơm nước **theo từng trạm bơm** (mỗi đầu mối `water_pump` = một trạm), mỗi trạm có danh sách đối tượng nhận riêng; mở rộng đối tượng nhận sang **khối / nhóm / đầu mối sinh hoạt thuộc đơn vị**; giữ nguyên hành vi kỳ cũ (gộp toàn khu vực).

**Architecture:** Theo ADR-026 (spec `docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md`). Trạm bơm = đầu mối `water_pump` đã có (không model mới). `PumpAllocation` thêm khóa ngoại rời `pump_contact_point_id` (trạm nguồn) + `block_id` + `group_id`; ràng buộc **đúng một trong bốn** recipient `{unit_id, block_id, group_id, contact_point_id}`. Cờ `Period#pump_allocation_per_station` (boolean) phân biệt cơ chế; `PumpAllocationCalculator` rẽ nhánh. Kỳ mở sau khi tính năng lên = `true`; mọi kỳ đang tồn tại (kể cả kỳ mở hiện tại) = `false`.

**Tech Stack:** Rails 8.1, PostgreSQL (numeric/BigDecimal, ROUND_HALF_UP), Hotwire (Stimulus), CanCanCan, Discard, RSpec + Capybara, demo engine (`DemoRecorder`).

**Lệnh test:** `bin/docker rspec <path>` (RAILS_ENV=test), `bin/docker demo spec/demo/<file>` cho demo. Chạy `bin/docker rspec` sau mỗi task.

---

## Quyết định khóa trước khi code (đọc kỹ — không tự đổi)

1. **Recipient = đúng một trong bốn:** `unit_id` / `block_id` / `group_id` / `contact_point_id`. Thay validation XOR-hai hiện tại bằng exactly-one-of-four.
2. **Nới recipient đầu mối:** `contact_point` recipient cho phép **residential thuộc đơn vị** HOẶC zone-level HOẶC `non_establishment` (ngoài biên chế). Bỏ ràng buộc "phải zone-level".
3. **`pump_contact_point_id`** (khóa ngoại → `contact_points`, nullable): trỏ tới đầu mối `water_pump` nguồn cùng zone. **Bắt buộc** khi `period.pump_allocation_per_station = true`; **để trống** khi `false`.
4. **`Period#pump_allocation_per_station`** (boolean, `null: false, default: false`). Migration để **default `false`** → mọi kỳ đang tồn tại (kể cả kỳ mở hiện tại) giữ hành vi gộp cũ. `PeriodService.open_new_period` set `true` cho kỳ **mới mở**. Hệ quả: kỳ per-station đầu tiên là kỳ mới đầu tiên sau khi deploy.
5. **Kế thừa kỳ:** `copy_pump_allocations` chỉ copy khi **cả kỳ nguồn lẫn kỳ đích** đều `per_station = true`. Qua ranh giới `false → true` (kỳ per-station đầu tiên) → **không copy → bắt đầu trống**.
6. **Tính toán per-trạm:** `D_trạm` = Σ (sử dụng thô + tổn hao) công tơ của trạm đó; Σ `D_trạm` = `D` toàn khu vực (bất biến cũ). Thuật toán fixed%-trước-rồi-hệ-số×quân-số áp **trong phạm vi từng trạm**. Tổn hao vẫn tính zone-wide (`LossCalculator` không đổi), chỉ gán `meter_losses` về trạm tương ứng.
7. **Ràng buộc per-trạm:** Σ `fixed_percentage` ≤ 100 **theo từng trạm** (scope thêm `pump_contact_point_id`); uniqueness recipient cũng scope thêm `pump_contact_point_id`.
8. **Cảnh báo:** trạm có công tơ nhưng **chưa có recipient** → cảnh báo (cơ chế warnings hiện có), không chặn tính toán.

---

## File Structure

**Tạo mới:**
- `db/migrate/20260614130000_add_per_station_to_pump_allocations_and_periods.rb` — cột mới.
- `spec/demo/pump_allocation_per_station_demo_spec.rb` — demo ADR-059.

**Sửa:**
- `app/models/pump_allocation.rb` — associations + validations mới (recipient 4-loại, per-trạm).
- `app/models/period.rb` — không cần method mới (cột tự có accessor); thêm chỉ nếu cần `per_station?` alias.
- `app/models/block.rb`, `app/models/group.rb` — helper rollup residential CP.
- `app/services/period_service.rb` — set cờ khi mở kỳ + nhánh `copy_pump_allocations`.
- `app/services/pump_allocation_calculator.rb` — nhánh per-trạm + cache personnel cho block/group.
- `app/controllers/pump_allocations_controller.rb` — permit FK mới + nhóm index theo trạm.
- `app/views/pump_allocations/_form.html.erb` — chọn trạm + 4 loại recipient.
- `app/views/pump_allocations/index.html.erb` — nhóm bảng theo trạm + DOM hook demo + cột trạm.
- `app/javascript/controllers/pump_allocation_form_controller.js` — mở rộng target/loại recipient + lọc theo trạm.
- `config/locales/vi.yml` — i18n recipient mới + trạm + lỗi per-trạm + cảnh báo.
- `db/seeds/demo.rb` — thêm trạm bơm thứ 2 + gán `pump_contact_point_id` cho pump allocation seed (per-station).
- `docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md` — `customer_facing: true` + `## Truy vết demo` + lật 8 `CHIEU-...` sang "có test" + bump version + changelog.
- `spec/support/role_behavior_matrix.rb` — cập nhật scenario `pump_allocations_data` nếu mở rộng (giữ kỳ vọng access).
- Specs: `spec/models/pump_allocation_spec.rb`, `spec/services/pump_allocation_calculator_spec.rb`, `spec/requests/pump_allocations_spec.rb`, `spec/services/period_service_spec.rb` (hoặc nơi test mở kỳ), `spec/models/block_spec.rb`, `spec/models/group_spec.rb`.

---

## Task 1: Migration — cột mới

**Files:**
- Create: `db/migrate/20260614130000_add_per_station_to_pump_allocations_and_periods.rb`
- Modify: `db/schema.rb` (tự sinh khi migrate)

- [ ] **Step 1: Viết migration**

```ruby
class AddPerStationToPumpAllocationsAndPeriods < ActiveRecord::Migration[8.1]
  def change
    add_reference :pump_allocations, :pump_contact_point,
      foreign_key: { to_table: :contact_points }, null: true
    add_reference :pump_allocations, :block, foreign_key: true, null: true
    add_reference :pump_allocations, :group, foreign_key: true, null: true
    add_index :pump_allocations, [:zone_id, :period_id, :pump_contact_point_id],
      name: "index_pump_allocations_on_zone_period_station"

    add_column :periods, :pump_allocation_per_station, :boolean, null: false, default: false
  end
end
```

- [ ] **Step 2: Chạy migrate trong Docker**

Run: `bin/docker bash -c "RAILS_ENV=development bin/rails db:migrate && RAILS_ENV=test bin/rails db:migrate"`
Expected: tạo cột, cập nhật `db/schema.rb` (version `2026_06_14_130000`), `pump_allocations` có `block_id`/`group_id`/`pump_contact_point_id` + index, `periods` có `pump_allocation_per_station default false null:false`.

- [ ] **Step 3: Kiểm schema không lệch**

Run: `bin/docker rspec spec/models/pump_allocation_spec.rb` (phải vẫn xanh — chưa đổi model/validation)
Expected: PASS (cột mới nullable, chưa ảnh hưởng).

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20260614130000_add_per_station_to_pump_allocations_and_periods.rb db/schema.rb
git commit -m "feat(pump): add per-station columns to pump_allocations and periods"
```

---

## Task 2: Period — cờ per-station khi mở kỳ mới

**Files:**
- Modify: `app/services/period_service.rb` (build_period_attributes / open_new_period)
- Test: `spec/services/period_service_spec.rb`

- [ ] **Step 1: Viết test thất bại**

```ruby
# spec/services/period_service_spec.rb — thêm describe block
RSpec.describe PeriodService do
  describe "#open_new_period — cờ pump_allocation_per_station (TN2)" do
    it "kỳ mới mở có pump_allocation_per_station = true" do
      result = described_class.new.open_new_period(year: 2030, month: 1, unit_price: BigDecimal("3500"))
      expect(result.period.pump_allocation_per_station).to be(true)
    end
  end
end
```

- [ ] **Step 2: Chạy để thấy fail**

Run: `bin/docker rspec spec/services/period_service_spec.rb -e "cờ pump_allocation_per_station"`
Expected: FAIL (mặc định false).

- [ ] **Step 3: Set cờ trong `build_period_attributes`**

Trong `app/services/period_service.rb`, hàm `build_period_attributes` (nơi dựng hash attrs cho `Period.create!`), thêm khóa:

```ruby
pump_allocation_per_station: true,
```

(Đặt cùng nhóm với `unit_price`, `savings_rate`… để mọi kỳ tạo qua service đều `true`.)

- [ ] **Step 4: Chạy lại — pass**

Run: `bin/docker rspec spec/services/period_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/period_service.rb spec/services/period_service_spec.rb
git commit -m "feat(pump): new periods open in per-station mode"
```

---

## Task 3: Block/Group — rollup đầu mối residential

**Files:**
- Modify: `app/models/block.rb`, `app/models/group.rb`
- Test: `spec/models/block_spec.rb`, `spec/models/group_spec.rb`

- [ ] **Step 1: Viết test thất bại (Block)**

```ruby
# spec/models/block_spec.rb
RSpec.describe Block do
  describe "#kept_residential_contact_points" do
    it "trả về đầu mối residential còn sống thuộc khối" do
      unit = create(:unit)
      block = create(:block, unit: unit)
      cp = create(:contact_point, :residential, unit: unit, block: block)
      create(:contact_point, :public_type, unit: unit, block: block) # không tính
      discarded = create(:contact_point, :residential, unit: unit, block: block)
      discarded.discard
      expect(block.kept_residential_contact_points).to contain_exactly(cp)
    end
  end
end
```

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/models/block_spec.rb -e kept_residential_contact_points`
Expected: FAIL (NoMethodError).

- [ ] **Step 3: Thêm method vào Block và Group**

`app/models/block.rb`:
```ruby
def kept_residential_contact_points
  contact_points.kept.where(contact_point_type: "residential")
end
```

`app/models/group.rb`:
```ruby
def kept_residential_contact_points
  contact_points.kept.where(contact_point_type: "residential")
end
```

- [ ] **Step 4: Viết test Group tương tự + chạy pass**

```ruby
# spec/models/group_spec.rb — analog test với create(:group, unit: unit), cp.group = group
```

Run: `bin/docker rspec spec/models/block_spec.rb spec/models/group_spec.rb`
Expected: PASS.

> Lưu ý closed-period discard: calculator (Task 5) sẽ dùng `with_discarded` khi `period.closed?` thay cho method này (giống nhánh `unit`). Method này dùng cho kỳ mở (cache build) — đủ.

- [ ] **Step 5: Commit**

```bash
git add app/models/block.rb app/models/group.rb spec/models/block_spec.rb spec/models/group_spec.rb
git commit -m "feat(pump): block/group residential contact point rollup helper"
```

---

## Task 4: PumpAllocation — recipient 4-loại + ràng buộc per-trạm

**Files:**
- Modify: `app/models/pump_allocation.rb`
- Modify: `config/locales/vi.yml` (lỗi mới)
- Test: `spec/models/pump_allocation_spec.rb`

- [ ] **Step 1: Viết test thất bại (exactly-one-of-four + per-station)**

```ruby
# spec/models/pump_allocation_spec.rb — thêm describe "TN2 — recipient bốn loại & per-trạm"
RSpec.describe PumpAllocation do
  describe "TN2 — recipient bốn loại & per-trạm" do
    let(:zone) { create(:zone, name: "KV TN2") }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let(:unit) { create(:unit, zone: zone) }
    let(:block) { create(:block, unit: unit) }
    let(:group) { create(:group, unit: unit) }
    let(:station) { create(:contact_point, :water_pump, name: "Trạm 1", zone: zone) }

    def base_attrs
      { zone: zone, period: period, coefficient: 1, pump_contact_point: station }
    end

    it "hợp lệ khi đúng một recipient = khối" do
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: nil, block: block, group: nil)
      expect(alloc).to be_valid
    end

    it "không hợp lệ khi không có recipient nào" do
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_required"))
    end

    it "không hợp lệ khi có hai recipient (đơn vị + khối)" do
      alloc = build(:pump_allocation, **base_attrs, unit: unit, contact_point: nil, block: block, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_must_be_one"))
    end

    it "cho phép contact_point recipient là residential thuộc đơn vị (nới ràng buộc)" do
      cp = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: cp, block: nil, group: nil)
      expect(alloc).to be_valid
    end

    it "kỳ per-trạm: thiếu pump_contact_point → chặn" do
      alloc = build(:pump_allocation, zone: zone, period: period, coefficient: 1,
                    pump_contact_point: nil, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:pump_contact_point_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.pump_contact_point_id.required_for_station"))
    end

    it "kỳ per-trạm: pump_contact_point phải là water_pump cùng zone" do
      not_pump = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, coefficient: 1,
                    pump_contact_point: not_pump, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:pump_contact_point_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.pump_contact_point_id.must_be_water_pump"))
    end

    it "Σ fixed_percentage ≤ 100 tính THEO TỪNG TRẠM" do
      station2 = create(:contact_point, :water_pump, name: "Trạm 2", zone: zone)
      create(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, fixed_percentage: 70)
      # Trạm 2 vẫn cho 80% vì khác trạm
      ok = build(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station2,
                 unit: create(:unit, zone: zone), contact_point: nil, block: nil, group: nil, fixed_percentage: 80)
      expect(ok).to be_valid
      # Cùng trạm 1 thêm 40% → tổng 110 > 100 → chặn
      bad = build(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station,
                  unit: create(:unit, zone: zone), contact_point: nil, block: nil, group: nil, fixed_percentage: 40)
      expect(bad).not_to be_valid
      expect(bad.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.fixed_percentage_sum_exceeds_one_hundred"))
    end

    it "kỳ cũ (per_station=false): pump_contact_point để trống, ràng buộc theo zone như cũ" do
      old = create(:period, closed: true, pump_allocation_per_station: false)
      alloc = build(:pump_allocation, zone: zone, period: old, coefficient: 1,
                    pump_contact_point: nil, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).to be_valid
    end
  end
end
```

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/models/pump_allocation_spec.rb -e "TN2"`
Expected: FAIL.

- [ ] **Step 3: Viết lại validations trong `app/models/pump_allocation.rb`**

Thay khối association + validation hiện tại bằng:

```ruby
class PumpAllocation < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  RECIPIENT_KEYS = %i[unit_id block_id group_id contact_point_id].freeze

  belongs_to :zone
  belongs_to :period
  belongs_to :unit, optional: true
  belongs_to :block, optional: true
  belongs_to :group, optional: true
  belongs_to :contact_point, optional: true
  belongs_to :pump_contact_point, class_name: "ContactPoint", optional: true

  validates :coefficient, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fixed_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }

  # Uniqueness recipient trong cùng (zone, period, trạm). allow_nil vì 3/4 khóa luôn nil.
  validates :unit_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :block_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :group_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :contact_point_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }

  validate :validate_exactly_one_recipient
  validate :validate_recipient_belongs_to_zone
  validate :validate_station_for_period_mode
  validate :validate_fixed_percentage_sum_within_limit

  private

  def calculation_state_targets
    [[zone_id, period_id]]
  end

  def recipient_count
    RECIPIENT_KEYS.count { |k| public_send(k).present? }
  end

  def validate_exactly_one_recipient
    case recipient_count
    when 0 then errors.add(:base, :recipient_required)
    when 1 then nil
    else errors.add(:base, :recipient_must_be_one)
    end
  end

  # Nới so với bản cũ: đầu mối nhận có thể residential thuộc đơn vị / zone-level / non_establishment.
  # Chỉ cần thuộc đúng zone (qua zone trực tiếp hoặc qua đơn vị).
  def validate_recipient_belongs_to_zone
    return if zone_id.blank?

    if unit.present? && unit.zone_id != zone_id
      errors.add(:unit_id, :zone_mismatch)
    end
    if block.present? && block.unit&.zone_id != zone_id
      errors.add(:block_id, :zone_mismatch)
    end
    if group.present? && group.unit&.zone_id != zone_id
      errors.add(:group_id, :zone_mismatch)
    end
    if contact_point.present?
      cp_zone_id = contact_point.zone_id || contact_point.unit&.zone_id
      errors.add(:contact_point_id, :zone_mismatch) if cp_zone_id != zone_id
    end
  end

  def validate_station_for_period_mode
    return if period.blank?

    if period.pump_allocation_per_station
      if pump_contact_point_id.blank?
        errors.add(:pump_contact_point_id, :required_for_station)
      elsif pump_contact_point.present?
        if pump_contact_point.contact_point_type != "water_pump" ||
           pump_contact_point.zone_id != zone_id
          errors.add(:pump_contact_point_id, :must_be_water_pump)
        end
      end
    elsif pump_contact_point_id.present?
      errors.add(:pump_contact_point_id, :not_allowed_legacy)
    end
  end

  def validate_fixed_percentage_sum_within_limit
    return if fixed_percentage.blank?
    return if zone_id.blank? || period_id.blank?

    scope = PumpAllocation.where(zone_id: zone_id, period_id: period_id,
                                 pump_contact_point_id: pump_contact_point_id)
                          .where.not(fixed_percentage: nil)
    scope = scope.where.not(id: id) if persisted?
    existing_sum = BigDecimal(scope.sum(:fixed_percentage).to_s)
    total = existing_sum + BigDecimal(fixed_percentage.to_s)

    errors.add(:base, :fixed_percentage_sum_exceeds_one_hundred) if total > 100
  end
end
```

- [ ] **Step 4: Thêm i18n lỗi mới vào `config/locales/vi.yml`**

Trong `activerecord.errors.models.pump_allocation.attributes` (đang có `base`, `unit_id`, `contact_point_id`), bổ sung:

```yaml
pump_allocation:
  attributes:
    base:
      recipient_required: "Vui lòng chọn đối tượng nhận phân bổ (đơn vị, khối, nhóm hoặc đầu mối)."
      recipient_must_be_one: "Chỉ được chọn 1 đối tượng nhận phân bổ — đơn vị, khối, nhóm hoặc đầu mối."
      fixed_percentage_sum_exceeds_one_hundred: "Tổng phần trăm cố định của các phân bổ trong cùng trạm bơm không được vượt quá 100"
    unit_id:
      zone_mismatch: "phải thuộc cùng khu vực với phân bổ"
    block_id:
      zone_mismatch: "phải thuộc cùng khu vực với phân bổ"
    group_id:
      zone_mismatch: "phải thuộc cùng khu vực với phân bổ"
    contact_point_id:
      zone_mismatch: "phải thuộc cùng khu vực với phân bổ"
    pump_contact_point_id:
      required_for_station: "phải chọn trạm bơm cho phân bổ của kỳ này"
      must_be_water_pump: "phải là một trạm bơm (đầu mối bơm nước) thuộc khu vực"
      not_allowed_legacy: "kỳ cũ không phân bổ theo trạm — không được chọn trạm bơm"
```

> Bỏ key cũ `target_required`, `target_must_be_one`, `must_be_zone_level` nếu không còn chỗ dùng. Giữ `fixed_percentage_sum_exceeds_one_hundred` (đã đổi câu chữ sang "trong cùng trạm bơm").

- [ ] **Step 5: Cập nhật factory `spec/factories/pump_allocations.rb`**

```ruby
FactoryBot.define do
  factory :pump_allocation do
    association :zone
    association :period
    unit { association(:unit, zone: zone) }
    contact_point { nil }
    block { nil }
    group { nil }
    coefficient { 1 }

    # Kỳ per-station: cần gán trạm. Trait tiện dụng.
    trait :for_station do
      transient { station_zone { zone } }
      pump_contact_point { association(:contact_point, :water_pump, zone: station_zone) }
    end

    trait :for_contact_point do
      unit { nil }
      contact_point do
        cp_unit = association(:unit, zone: zone)
        association(:contact_point, :residential, unit: cp_unit, zone: nil)
      end
    end
  end
end
```

> Nếu test cũ tạo `:pump_allocation` với period `per_station: true` factory mặc định (closed: true → per_station false) thì không cần trạm. Test mới dùng `pump_contact_point:` tường minh như Step 1.

- [ ] **Step 6: Chạy model spec — pass**

Run: `bin/docker rspec spec/models/pump_allocation_spec.rb`
Expected: PASS (cả test cũ lẫn TN2). Nếu test cũ dùng key i18n đã bỏ → cập nhật chúng sang key mới.

- [ ] **Step 7: Commit**

```bash
git add app/models/pump_allocation.rb config/locales/vi.yml spec/factories/pump_allocations.rb spec/models/pump_allocation_spec.rb
git commit -m "feat(pump): four recipient types + per-station validations on PumpAllocation"
```

---

## Task 5: PumpAllocationCalculator — nhánh per-trạm

**Files:**
- Modify: `app/services/pump_allocation_calculator.rb`
- Modify: `config/locales/vi.yml` (cảnh báo trạm chưa cấu hình)
- Test: `spec/services/pump_allocation_calculator_spec.rb`

- [ ] **Step 1: Viết test thất bại — hai trạm, Σ per-trạm = D (CHIEU-phan-bo-tram-tong)**

```ruby
# spec/services/pump_allocation_calculator_spec.rb — thêm describe "per-trạm (TN2)"
describe "#call — per-trạm (TN2)" do
  def open_per_station_period
    PeriodService.new.open_new_period(year: 2031, month: 1, unit_price: BigDecimal("2000")).period
  end

  it "hai trạm có recipient riêng; tổng phân bổ mỗi trạm = D_trạm; tổng = D toàn khu vực" do
    zone = create(:zone, name: "KV hai trạm")
    period = open_per_station_period
    expect(period.pump_allocation_per_station).to be(true)

    station_a = create(:contact_point, :water_pump, name: "Trạm A", zone: zone)
    station_b = create(:contact_point, :water_pump, name: "Trạm B", zone: zone)
    meter_a = create(:meter, name: "CT-A", contact_point: station_a, no_loss: true)
    meter_b = create(:meter, name: "CT-B", contact_point: station_b, no_loss: true)
    meter_a.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
    meter_b.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 60)

    unit_a = create(:unit, name: "ĐV A", zone: zone)
    cp_a = create(:contact_point, :residential, name: "Đầu mối A", unit: unit_a,
                  initial_personnel_counts: { rank_for(period).id => 1 })
    unit_b = create(:unit, name: "ĐV B", zone: zone)
    cp_b = create(:contact_point, :residential, name: "Đầu mối B", unit: unit_b,
                  initial_personnel_counts: { rank_for(period).id => 1 })

    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
           unit: unit_a, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)
    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_b,
           unit: unit_b, contact_point: nil, block: nil, group: nil, coefficient: 1, fixed_percentage: nil)

    result = call_pump(zone, period)
    expect(result.total_d).to eq(BigDecimal("160"))
    expect(result.contact_point_allocations[cp_a.id]).to eq(BigDecimal("100")) # trạm A → ĐV A
    expect(result.contact_point_allocations[cp_b.id]).to eq(BigDecimal("60"))  # trạm B → ĐV B
    total = result.contact_point_allocations.values.sum(BigDecimal("0"))
    expect(total).to eq(BigDecimal("160"))
  end

  it "trạm chưa có recipient → cảnh báo, không chặn (CHIEU-phan-bo-tram-chua-cau-hinh)" do
    zone = create(:zone, name: "KV trạm trống")
    period = open_per_station_period
    station = create(:contact_point, :water_pump, name: "Trạm cô đơn", zone: zone)
    meter = create(:meter, name: "CT-CD", contact_point: station, no_loss: true)
    meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 50)

    result = call_pump(zone, period)
    expect(result.warnings).to include(
      I18n.t("services.pump_allocation_calculator.warnings.station_without_recipient", station: "Trạm cô đơn")
    )
    expect(result.total_d).to eq(BigDecimal("50"))
  end

  it "recipient khối: chia xuống đầu mối residential trong khối theo quân số (CHIEU-phan-bo-tram-bon-recipient)" do
    zone = create(:zone, name: "KV khối")
    period = open_per_station_period
    station = create(:contact_point, :water_pump, name: "Trạm khối", zone: zone)
    meter = create(:meter, name: "CT-K", contact_point: station, no_loss: true)
    meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 90)

    unit = create(:unit, name: "ĐV khối", zone: zone)
    block = create(:block, name: "Khối X", unit: unit)
    cp1 = create(:contact_point, :residential, name: "ĐM1", unit: unit, block: block,
                 initial_personnel_counts: { rank_for(period).id => 2 })
    cp2 = create(:contact_point, :residential, name: "ĐM2", unit: unit, block: block,
                 initial_personnel_counts: { rank_for(period).id => 1 })

    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
           unit: nil, contact_point: nil, block: block, group: nil, coefficient: 1, fixed_percentage: nil)

    result = call_pump(zone, period)
    expect(result.contact_point_allocations[cp1.id]).to eq(BigDecimal("60")) # 2/3 × 90
    expect(result.contact_point_allocations[cp2.id]).to eq(BigDecimal("30")) # 1/3 × 90
  end
end
```

> Dùng helper `call_pump`, `rank_for` đã có trong spec hiện tại (xem các test mutation #376). Nếu chưa có `call_pump`, định nghĩa: `def call_pump(zone, period); loss = LossCalculator.new(zone: zone, period: period).call; described_class.new(zone: zone, period: period, loss_results: loss).call; end`.

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/services/pump_allocation_calculator_spec.rb -e "per-trạm"`
Expected: FAIL (chưa rẽ nhánh; tất cả đổ vào logic zone-wide).

- [ ] **Step 3: Viết lại calculator với nhánh per-trạm**

`app/services/pump_allocation_calculator.rb`:

```ruby
class PumpAllocationCalculator
  Result = Struct.new(:contact_point_allocations, :total_d, :warnings, keyword_init: true)

  def initialize(zone:, period:, loss_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    @warnings = []
    pump_meters = @query.pump_meters.to_a

    if pump_meters.empty?
      @warnings << I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter")
      return Result.new(contact_point_allocations: {}, total_d: BigDecimal("0"), warnings: @warnings)
    end

    usages = @query.meter_usages
    @meter_d = pump_meters.each_with_object({}) do |m, h|
      raw = usages[m.id] || BigDecimal("0")
      loss = @loss_results.meter_losses[m.id] || BigDecimal("0")
      h[m.id] = raw + loss
    end
    total_d = @meter_d.values.sum(BigDecimal("0"))

    allocations = load_allocations
    cp_amounts = if @period.pump_allocation_per_station
      allocate_per_station(pump_meters, allocations)
    else
      allocate_zone_wide(total_d, allocations)
    end

    Result.new(contact_point_allocations: cp_amounts, total_d: total_d, warnings: @warnings)
  end

  private

  def load_allocations
    scope = @period.pump_allocations
                    .where(zone: @zone)
                    .left_joins(:unit, :block, :group, :contact_point)
                    .includes(:unit, :block, :group, :contact_point, :pump_contact_point)
    unless @period.closed?
      scope = scope.where("units.discarded_at IS NULL OR units.id IS NULL")
                   .where("blocks.discarded_at IS NULL OR blocks.id IS NULL")
                   .where("groups.discarded_at IS NULL OR groups.id IS NULL")
                   .where("contact_points.discarded_at IS NULL OR contact_points.id IS NULL")
    end
    scope.to_a
  end

  # ---- Nhánh kỳ cũ: gộp toàn khu vực (logic cũ, giữ nguyên hành vi) ----
  def allocate_zone_wide(d, allocations)
    return {} if allocations.empty?
    @personnel_cache = build_personnel_cache(allocations)
    object_amounts = allocate_within(d, allocations)
    distribute_to_recipients(object_amounts)
  end

  # ---- Nhánh per-trạm ----
  def allocate_per_station(pump_meters, allocations)
    @personnel_cache = build_personnel_cache(allocations)
    by_station = allocations.group_by(&:pump_contact_point_id)
    meters_by_station = pump_meters.group_by { |m| m.contact_point_id }

    cp_amounts = Hash.new { |h, k| h[k] = BigDecimal("0") }
    meters_by_station.each do |station_cp_id, station_meters|
      d_station = station_meters.sum(BigDecimal("0")) { |m| @meter_d[m.id] || BigDecimal("0") }
      station_allocs = by_station[station_cp_id] || []
      if station_allocs.empty?
        @warnings << I18n.t("services.pump_allocation_calculator.warnings.station_without_recipient",
                            station: station_name(station_cp_id))
        next
      end
      object_amounts = allocate_within(d_station, station_allocs)
      distribute_to_recipients(object_amounts).each { |cp_id, amt| cp_amounts[cp_id] += amt }
    end
    cp_amounts
  end

  def station_name(cp_id)
    ContactPoint.with_discarded.find_by(id: cp_id)&.name.to_s
  end

  # fixed% trước, phần còn lại theo hệ số × quân số — trong phạm vi `allocations` cho trước.
  def allocate_within(d, allocations)
    fixed, coefficient = allocations.partition { |a| a.fixed_percentage.present? }
    object_amounts = {}
    fixed.each { |a| object_amounts[a] = d * BigDecimal(a.fixed_percentage.to_s) / BigDecimal("100") }
    remaining = d - object_amounts.values.sum(BigDecimal("0"))

    weighted = coefficient.map do |a|
      personnel = personnel_count_for(a)
      if personnel.zero?
        @warnings << I18n.t("services.pump_allocation_calculator.warnings.zero_personnel")
        [a, BigDecimal("0")]
      else
        [a, BigDecimal(personnel.to_s) * BigDecimal(a.coefficient.to_s)]
      end
    end
    total_weighted = weighted.sum(BigDecimal("0")) { |_, w| w }
    if total_weighted > 0
      weighted.each { |a, w| object_amounts[a] = remaining * w / total_weighted }
    end
    object_amounts
  end

  def build_personnel_cache(allocations)
    cache = { unit: {}, block: {}, group: {}, contact_point: {}, residential: {} }
    unit_ids  = allocations.map(&:unit_id).compact.uniq
    block_ids = allocations.map(&:block_id).compact.uniq
    group_ids = allocations.map(&:group_id).compact.uniq
    cp_ids    = allocations.map(&:contact_point_id).compact.uniq

    residential_scope = @period.closed? ? ContactPoint.with_discarded : ContactPoint.kept

    register = lambda do |bucket_key, owner_id, residentials|
      cache[bucket_key][owner_id] = residentials.map(&:id)
      residentials.each { |cp| cache[:residential][cp.id] = cp }
    end

    residential_scope.where(unit_id: unit_ids, contact_point_type: "residential")
                     .group_by(&:unit_id).each { |uid, cps| register.call(:unit, uid, cps) } if unit_ids.any?
    residential_scope.where(block_id: block_ids, contact_point_type: "residential")
                     .group_by(&:block_id).each { |bid, cps| register.call(:block, bid, cps) } if block_ids.any?
    residential_scope.where(group_id: group_ids, contact_point_type: "residential")
                     .group_by(&:group_id).each { |gid, cps| register.call(:group, gid, cps) } if group_ids.any?

    all_residential_ids = cache[:residential].keys
    cache[:cp_counts] = if all_residential_ids.any?
      PersonnelEntry.where(period_id: @period.id, contact_point_id: all_residential_ids)
                    .group(:contact_point_id).sum(:count)
    else
      {}
    end

    if cp_ids.any?
      residential_counts = PersonnelEntry.where(period_id: @period.id, contact_point_id: cp_ids)
                                         .group(:contact_point_id).sum(:count)
      ne_counts = NonEstablishmentSnapshot.where(period_id: @period.id, contact_point_id: cp_ids)
                                          .pluck(:contact_point_id, :personnel_count).to_h
      allocations.each do |a|
        next unless a.contact_point_id
        cp = a.contact_point
        cache[:contact_point][a.contact_point_id] = case cp.contact_point_type
        when "residential" then residential_counts[cp.id] || 0
        when "non_establishment" then ne_counts[cp.id] || 0
        else 0
        end
      end
    end
    cache
  end

  def group_total(bucket_key, owner_id)
    (@personnel_cache[bucket_key][owner_id] || []).sum(0) { |cp_id| @personnel_cache[:cp_counts][cp_id] || 0 }
  end

  def personnel_count_for(a)
    if a.unit_id then group_total(:unit, a.unit_id)
    elsif a.block_id then group_total(:block, a.block_id)
    elsif a.group_id then group_total(:group, a.group_id)
    elsif a.contact_point_id then @personnel_cache[:contact_point][a.contact_point_id] || 0
    else 0
    end
  end

  def distribute_to_recipients(object_amounts)
    cp_amounts = Hash.new { |h, k| h[k] = BigDecimal("0") }
    object_amounts.each do |a, amount|
      next if amount.zero?
      if a.contact_point_id
        cp_amounts[a.contact_point_id] += amount
      else
        bucket_key = a.unit_id ? :unit : (a.block_id ? :block : :group)
        owner_id   = a.unit_id || a.block_id || a.group_id
        total = group_total(bucket_key, owner_id)
        next if total.zero?
        (@personnel_cache[bucket_key][owner_id] || []).each do |cp_id|
          count = @personnel_cache[:cp_counts][cp_id] || 0
          next if count.zero?
          cp_amounts[cp_id] += amount * BigDecimal(count.to_s) / BigDecimal(total.to_s)
        end
      end
    end
    cp_amounts
  end
end
```

- [ ] **Step 4: Thêm i18n cảnh báo vào `config/locales/vi.yml`**

Trong `services.pump_allocation_calculator.warnings` (đang có `no_pump_meter`, `zero_personnel`), thêm:

```yaml
station_without_recipient: "Trạm bơm %{station} chưa có đối tượng nhận phân bổ — điện trạm này chưa được chia."
```

- [ ] **Step 5: Chạy calculator spec — pass (cả test cũ regression)**

Run: `bin/docker rspec spec/services/pump_allocation_calculator_spec.rb`
Expected: PASS. Test cũ (`T02`, mutation #376) dùng period `closed: true`/`open_new_period` cũ — kiểm `pump_allocation_per_station`: các test cũ dùng `build_pump_zone` gọi `open_new_period` → nay `per_station=true`. **Cảnh báo:** điều này đổi nhánh cho test cũ. Nếu test cũ giả định zone-wide, cần hoặc (a) set `period.update!(pump_allocation_per_station: false)` trong các test cũ, hoặc (b) gán `pump_contact_point` cho allocation của chúng. Ưu tiên (a) cho test "kỳ cũ"/regression, (b) cho test mô phỏng hành vi mới. Sửa từng test cũ cho khớp ý định của nó.

- [ ] **Step 6: Commit**

```bash
git add app/services/pump_allocation_calculator.rb config/locales/vi.yml spec/services/pump_allocation_calculator_spec.rb
git commit -m "feat(pump): per-station allocation branch in PumpAllocationCalculator"
```

---

## Task 6: PeriodService — kế thừa kỳ theo nhánh per-station

**Files:**
- Modify: `app/services/period_service.rb` (`copy_pump_allocations_from`)
- Test: `spec/services/period_service_spec.rb`

- [ ] **Step 1: Viết test thất bại (CHIEU-phan-bo-tram-chuyen-tiep)**

```ruby
describe "#open_new_period — kế thừa phân bổ bơm per-trạm (TN2)" do
  it "KHÔNG kế thừa qua ranh giới cũ→per-trạm: kỳ per-trạm đầu tiên bắt đầu trống" do
    zone = create(:zone)
    old = create(:period, closed: false, pump_allocation_per_station: false)
    unit = create(:unit, zone: zone)
    create(:pump_allocation, zone: zone, period: old, unit: unit, contact_point: nil,
           block: nil, group: nil, pump_contact_point: nil, coefficient: 1)
    PeriodService.new.send(:close_current_period) rescue nil
    old.update!(closed: true)

    result = PeriodService.new.open_new_period(year: 2032, month: 1, unit_price: BigDecimal("3500"))
    expect(result.period.pump_allocation_per_station).to be(true)
    expect(result.period.pump_allocations).to be_empty
  end

  it "kế thừa khi cả nguồn lẫn đích đều per-trạm (gồm pump_contact_point_id, block_id, group_id)" do
    zone = create(:zone)
    src = create(:period, closed: false, pump_allocation_per_station: true)
    station = create(:contact_point, :water_pump, zone: zone)
    unit = create(:unit, zone: zone)
    create(:pump_allocation, zone: zone, period: src, unit: unit, contact_point: nil,
           block: nil, group: nil, pump_contact_point: station, coefficient: 2, fixed_percentage: nil)
    src.update!(closed: true)

    result = PeriodService.new.open_new_period(year: 2033, month: 1, unit_price: BigDecimal("3500"))
    copied = result.period.pump_allocations
    expect(copied.size).to eq(1)
    expect(copied.first.pump_contact_point_id).to eq(station.id)
    expect(copied.first.unit_id).to eq(unit.id)
    expect(copied.first.coefficient).to eq(BigDecimal("2"))
  end
end
```

> Lưu ý ràng buộc `idx_periods_only_one_open`: chỉ một kỳ mở. Test phải đóng kỳ nguồn (`update!(closed: true)`) trước khi `open_new_period`. Điều chỉnh setup cho khớp (xem [[feedback_rspec_rails_env_test]] về flaky open-period).

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/services/period_service_spec.rb -e "kế thừa phân bổ bơm"`
Expected: FAIL (hiện copy luôn, không gán FK mới).

- [ ] **Step 3: Sửa `copy_pump_allocations_from`**

```ruby
def copy_pump_allocations_from(previous, new_period)
  # Chỉ kế thừa khi cả hai kỳ cùng cơ chế per-trạm. Qua ranh giới cũ→per-trạm:
  # bắt đầu trống (cấu hình gộp cũ không gắn được vào trạm cụ thể) — ADR-026.
  return unless previous.pump_allocation_per_station && new_period.pump_allocation_per_station

  previous.pump_allocations
          .includes(:zone, :unit, :block, :group, :contact_point, :pump_contact_point)
          .find_each do |allocation|
    next if allocation.zone&.discarded?
    next if allocation.unit_id.present? && allocation.unit&.discarded?
    next if allocation.block_id.present? && allocation.block&.discarded?
    next if allocation.group_id.present? && allocation.group&.discarded?
    next if allocation.contact_point_id.present? && allocation.contact_point&.discarded?
    next if allocation.pump_contact_point_id.present? && allocation.pump_contact_point&.discarded?

    new_period.pump_allocations.create!(
      zone_id: allocation.zone_id,
      pump_contact_point_id: allocation.pump_contact_point_id,
      unit_id: allocation.unit_id,
      block_id: allocation.block_id,
      group_id: allocation.group_id,
      contact_point_id: allocation.contact_point_id,
      coefficient: allocation.coefficient,
      fixed_percentage: allocation.fixed_percentage
    )
  end
end
```

- [ ] **Step 4: Chạy pass**

Run: `bin/docker rspec spec/services/period_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/period_service.rb spec/services/period_service_spec.rb
git commit -m "feat(pump): inherit per-station allocations only across per-station periods"
```

---

## Task 7: Controller — permit FK mới + nhóm index theo trạm

**Files:**
- Modify: `app/controllers/pump_allocations_controller.rb`
- Test: `spec/requests/pump_allocations_spec.rb`

- [ ] **Step 1: Viết request test thất bại**

```ruby
# spec/requests/pump_allocations_spec.rb — thêm context per-station
context "kỳ per-station (TN2)" do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
  let!(:zone) { create(:zone, name: "KV req") }
  let!(:station) { create(:contact_point, :water_pump, name: "Trạm req", zone: zone) }
  let!(:unit) { create(:unit, zone: zone, name: "ĐV req") }
  before { sign_in system_admin }

  it "tạo phân bổ với block_id + pump_contact_point_id" do
    block = create(:block, unit: unit, name: "Khối req")
    expect {
      post pump_allocations_path, params: { pump_allocation: {
        zone_id: zone.id, pump_contact_point_id: station.id, block_id: block.id,
        coefficient: "1", fixed_percentage: ""
      } }
    }.to change(PumpAllocation, :count).by(1)
    expect(response).to redirect_to(pump_allocations_path)
    expect(PumpAllocation.last.block_id).to eq(block.id)
    expect(PumpAllocation.last.pump_contact_point_id).to eq(station.id)
  end

  it "index hiện tên trạm bơm" do
    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
           unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
    get pump_allocations_path
    expect(response.body).to include("Trạm req")
  end
end
```

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/requests/pump_allocations_spec.rb -e "per-station"`
Expected: FAIL (params không permit, view chưa hiện trạm).

- [ ] **Step 3: Sửa `allocation_params` + index includes + SORT**

`app/controllers/pump_allocations_controller.rb`:

```ruby
def allocation_params
  params.require(:pump_allocation).permit(
    :zone_id, :pump_contact_point_id, :unit_id, :block_id, :group_id, :contact_point_id,
    :coefficient, :fixed_percentage, :lock_version
  )
end
```

Trong `index`, mở rộng includes + join cho hiển thị trạm + recipient:

```ruby
scope = PumpAllocation.accessible_by(current_ability)
                      .includes(:zone, :unit, :block, :group, :contact_point, :pump_contact_point)
                      .joins(:zone)
                      .left_joins(:unit, :block, :group, :contact_point)
```

Mở rộng `SORT_COLUMNS[:target]` để bao recipient mới:

```ruby
target: "COALESCE(units.name, blocks.name, groups.name, contact_points.name)",
```

(Search columns mở rộng ở `apply_search`: `columns: %w[units.name blocks.name groups.name contact_points.name]`.)

- [ ] **Step 4: Chạy pass**

Run: `bin/docker rspec spec/requests/pump_allocations_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/pump_allocations_controller.rb spec/requests/pump_allocations_spec.rb
git commit -m "feat(pump): permit station + block/group recipients in controller"
```

---

## Task 8: Views + Stimulus — chọn trạm, 4 loại recipient, hook demo

**Files:**
- Modify: `app/views/pump_allocations/_form.html.erb`
- Modify: `app/views/pump_allocations/index.html.erb`
- Modify: `app/javascript/controllers/pump_allocation_form_controller.js`
- Modify: `config/locales/vi.yml` (nhãn trạm/khối/nhóm nếu thiếu)
- Test: `spec/requests/pump_allocations_spec.rb` (render), `spec/system/pump_allocations_spec.rb` (cascade)

- [ ] **Step 1: Viết test render thất bại (form có chọn trạm + radio loại recipient)**

```ruby
# spec/requests/pump_allocations_spec.rb
it "form new (kỳ per-station) có select trạm bơm + radio loại đối tượng nhận" do
  sign_in create(:user, :system_admin)
  create(:period, closed: false, pump_allocation_per_station: true)
  zone = create(:zone)
  create(:contact_point, :water_pump, name: "Trạm form", zone: zone)
  get new_pump_allocation_path
  expect(response.body).to include("Trạm bơm")          # nhãn select trạm
  expect(response.body).to include('value="block"')      # radio loại = khối
  expect(response.body).to include('value="group"')      # radio loại = nhóm
end
```

- [ ] **Step 2: Chạy fail**

Run: `bin/docker rspec spec/requests/pump_allocations_spec.rb -e "select trạm bơm"`
Expected: FAIL.

- [ ] **Step 3: Sửa `_form.html.erb`**

Thêm (ngay sau khối zone, trước fieldset "Đối tượng nhận") khối chọn trạm — chỉ hiện cho kỳ per-station:

```erb
<% per_station = pump_allocation.period&.pump_allocation_per_station %>
<% if per_station %>
  <div data-pump-allocation-form-target="stationWrap">
    <%= f.label :pump_contact_point_id, "Trạm bơm", class: "block text-sm font-medium text-gray-700 mb-1" %>
    <%
      station_options = ContactPoint.kept.accessible_by(current_ability)
        .where(contact_point_type: "water_pump")
        .order(:name)
        .map { |s| [s.name, s.id, { "data-zone-id": s.zone_id }] }
    %>
    <%= f.select :pump_contact_point_id, station_options,
        { include_blank: "— Chọn trạm bơm —" },
        class: "block w-full rounded border border-gray-300 px-3 py-2 text-sm",
        data: { pump_allocation_form_target: "stationSelect" } %>
  </div>
<% end %>
```

Mở rộng fieldset "Đối tượng nhận" — đổi 2 radio thành 4 (`unit` / `block` / `group` / `contact_point`), thêm 2 div recipient (`targetBlock`, `targetGroup`). Theo đúng style hiện có (giữ `targetMode`/`refreshTarget`):

```erb
<div class="flex flex-wrap gap-4 mb-3">
  <% [["unit","Đơn vị"],["block","Khối"],["group","Nhóm"],["contact_point","Đầu mối"]].each do |val, lbl| %>
    <label class="flex items-center gap-2 text-sm">
      <input type="radio" name="target_mode" value="<%= val %>"
             <%= "checked" if target_mode_default == val %>
             data-pump-allocation-form-target="targetMode"
             data-action="change->pump-allocation-form#refreshTarget">
      <span><%= lbl %></span>
    </label>
  <% end %>
</div>

<div data-pump-allocation-form-target="targetUnit"><!-- select unit_id như cũ --></div>

<div data-pump-allocation-form-target="targetBlock">
  <%= f.label :block_id, "Chọn khối", class: "block text-sm font-medium text-gray-700 mb-1" %>
  <%= f.select :block_id,
      Block.kept.accessible_by(current_ability).includes(:unit).order(:name)
           .map { |b| [b.name, b.id, { "data-zone-id": b.unit&.zone_id }] },
      { include_blank: "— Chọn khối —" },
      class: "block w-full rounded border border-gray-300 px-3 py-2 text-sm",
      data: { pump_allocation_form_target: "blockSelect" } %>
</div>

<div data-pump-allocation-form-target="targetGroup">
  <%= f.label :group_id, "Chọn nhóm", class: "block text-sm font-medium text-gray-700 mb-1" %>
  <%= f.select :group_id,
      Group.kept.accessible_by(current_ability).includes(:unit).order(:name)
           .map { |g| [g.name, g.id, { "data-zone-id": g.unit&.zone_id }] },
      { include_blank: "— Chọn nhóm —" },
      class: "block w-full rounded border border-gray-300 px-3 py-2 text-sm",
      data: { pump_allocation_form_target: "groupSelect" } %>
</div>

<div data-pump-allocation-form-target="targetContact">
  <%
    contact_point_options = ContactPoint.kept.accessible_by(current_ability)
      .where(contact_point_type: ["residential", "public", "non_establishment"])
      .order(:name)
      .map { |cp| [cp.name, cp.id, { "data-zone-id": (cp.zone_id || cp.unit&.zone_id) }] }
  %>
  <%= f.select :contact_point_id, contact_point_options,
      { include_blank: "— Chọn đầu mối —" },
      class: "block w-full rounded border border-gray-300 px-3 py-2 text-sm",
      data: { pump_allocation_form_target: "contactSelect" } %>
</div>
```

Cập nhật dòng `target_mode_default` đầu file để nhận 4 loại:

```erb
<%
  target_mode_default =
    if pump_allocation.block_id.present? then "block"
    elsif pump_allocation.group_id.present? then "group"
    elsif pump_allocation.contact_point_id.present? then "contact_point"
    else "unit" end
%>
```

- [ ] **Step 4: Mở rộng Stimulus `pump_allocation_form_controller.js`**

Thêm targets `stationSelect`, `stationWrap`, `targetBlock`, `targetGroup`, `blockSelect`, `groupSelect`. Sửa `refreshTarget` để hiện đúng 1 trong 4 và clear 3 cái còn lại; mở rộng `refreshZoneScope` lọc block/group/station theo zone:

```javascript
static targets = [
  "targetMode", "targetUnit", "targetBlock", "targetGroup", "targetContact", "targetFieldset",
  "allocMode", "allocFixed", "allocCoefficient", "allocFieldset",
  "zoneSelect", "unitSelect", "blockSelect", "groupSelect", "contactSelect",
  "stationSelect", "stationWrap"
]

refreshTarget() {
  const mode = this.selectedTargetMode()
  const map = {
    unit: this.hasTargetUnitTarget && this.targetUnitTarget,
    block: this.hasTargetBlockTarget && this.targetBlockTarget,
    group: this.hasTargetGroupTarget && this.targetGroupTarget,
    contact_point: this.hasTargetContactTarget && this.targetContactTarget
  }
  Object.entries(map).forEach(([key, el]) => {
    if (!el) return
    if (key === mode) { this.show(el) } else { this.hide(el); this.clearSelect(el) }
  })
}
```

Trong `refreshZoneScope`, thêm:

```javascript
if (this.hasBlockSelectTarget) this.filterOptionsByZone(this.blockSelectTarget, zoneId)
if (this.hasGroupSelectTarget) this.filterOptionsByZone(this.groupSelectTarget, zoneId)
if (this.hasStationSelectTarget) this.filterOptionsByZone(this.stationSelectTarget, zoneId)
```

Trong `selectedTargetMode()` default vẫn `"unit"`.

- [ ] **Step 5: Sửa `index.html.erb` — cột trạm + nhóm theo trạm + DOM hook demo**

Thêm cột "Trạm bơm" (hiện `alloc.pump_contact_point&.name`), và đổi ô tên đối tượng để bao 4 loại + gắn hook demo `data-pump-allocation-target-id`:

```erb
<td class="px-4 py-2 text-sm text-gray-600"><%= alloc.pump_contact_point&.name || "—" %></td>
<td class="px-4 py-2 text-sm font-medium text-gray-900"
    data-pump-allocation-target-id="<%= alloc.id %>">
  <%= alloc.unit&.name || alloc.block&.name || alloc.group&.name || alloc.contact_point&.name %>
</td>
<td class="px-4 py-2 text-sm text-gray-600">
  <%= alloc.unit ? "Đơn vị" : alloc.block ? "Khối" : alloc.group ? "Nhóm" : "Đầu mối" %>
</td>
```

(Thêm header `<th>Trạm bơm</th>` tương ứng. Giữ `_list_toolbar` như cũ.)

- [ ] **Step 6: Thêm i18n nhãn còn thiếu vào `config/locales/vi.yml`**

Trong `activerecord.attributes.pump_allocation`:

```yaml
block: "Khối"
block_id: "Khối"
group: "Nhóm"
group_id: "Nhóm"
pump_contact_point: "Trạm bơm"
pump_contact_point_id: "Trạm bơm"
```

- [ ] **Step 7: Viết system test cascade (CHIEU-phan-bo-tram-vai-tro phần UI) + chạy**

```ruby
# spec/system/pump_allocations_spec.rb — thêm
it "chọn loại Khối thì hiện select khối, ẩn select đơn vị", type: :system do
  sign_in create(:user, :system_admin)
  create(:period, closed: false, pump_allocation_per_station: true)
  zone = create(:zone, name: "KV sys")
  create(:contact_point, :water_pump, name: "Trạm sys", zone: zone)
  unit = create(:unit, zone: zone); create(:block, unit: unit, name: "Khối sys")
  visit new_pump_allocation_path
  choose "Khối"
  expect(page).to have_select("pump_allocation_block_id")
  expect(page).not_to have_select("pump_allocation_unit_id", visible: true)
end
```

Run: `bin/docker rspec spec/requests/pump_allocations_spec.rb spec/system/pump_allocations_spec.rb`
Expected: PASS.

- [ ] **Step 8: Verify UI bằng preview (docker-dev)**

Dùng `preview_start docker-dev`, đăng nhập admin, mở `/pump_allocations` + form `new` ở kỳ per-station; chụp `preview_screenshot` chứng minh: select Trạm bơm + 4 radio recipient hiện đúng, cascade lọc theo zone. Kiểm `preview_console_logs` không lỗi Stimulus.

- [ ] **Step 9: Commit**

```bash
git add app/views/pump_allocations app/javascript/controllers/pump_allocation_form_controller.js config/locales/vi.yml spec/requests/pump_allocations_spec.rb spec/system/pump_allocations_spec.rb
git commit -m "feat(pump): per-station UI — station select, four recipient types, cascade filter"
```

---

## Task 9: Demo seed + demo spec (ADR-059)

> **Integration risk — đọc trước:** Sau Task 2, `db/seeds/demo.rb` gọi `open_new_period` → kỳ seed (2026/6) nay `per_station=true`. Pump allocation seed hiện không có `pump_contact_point_id` → sẽ INVALID hoặc không được chia → cảnh báo + đổi số ở billing. Phải (a) thêm trạm bơm thứ 2 vào seed, (b) gán `pump_contact_point_id` cho mọi pump allocation seed, rồi (c) re-verify **toàn bộ** demo specs (loss_breakdown, freshness) vẫn xanh.

**Files:**
- Modify: `db/seeds/demo.rb`
- Create: `spec/demo/pump_allocation_per_station_demo_spec.rb`

- [ ] **Step 1: Sửa `db/seeds/demo.rb` — hai trạm + gán trạm cho allocation**

Thêm trạm bơm thứ hai (`cp_tram_bom_2`) với công tơ + reading riêng (số gọn, ví dụ start 100/finish 180). Gán mỗi `PumpAllocation` seed một `pump_contact_point_id` (trạm 1 hoặc trạm 2) và phân đối tượng nhận khác nhau (trạm 1 → một đơn vị/khối; trạm 2 → đơn vị/đầu mối khác) để demo thể hiện "mỗi trạm danh sách riêng". Đảm bảo `Σ fixed% ≤ 100` per-trạm.

- [ ] **Step 2: Re-verify toàn bộ demo specs (không vỡ loss_breakdown/freshness)**

Run: `bin/docker demo`
Expected: tất cả demo PASS. Nếu `loss_breakdown`/`freshness` đỏ vì số đổi → điều chỉnh seed (giữ tổng D hợp lý) hoặc cập nhật assertion content (chỉ khi assertion là số cụ thể; phần lớn là `have_content` nhãn nên không đổi).

- [ ] **Step 3: Viết demo spec đạt 6 tiêu chí ADR-059**

`spec/demo/pump_allocation_per_station_demo_spec.rb` — bám golden example `cot_khac_he_so_don_vi_demo_spec.rb`:

```ruby
require "rails_helper"

# Demo TN2 — phân bổ bơm nước theo từng trạm bơm. Narrated + recorded (ADR-036..041),
# đạt chuẩn demo tốt ADR-059: cho-thấy bằng highlight, kể chuyện khách (mỗi trạm phục
# vụ một vùng, danh sách nhận riêng), diễn kết quả trên bảng tính tiền, trung thực medium.
# Truy vết: NV-phan-bo-bom-theo-tram (#319, ADR-026).
RSpec.describe "Demo: phân bổ bơm nước theo trạm", type: :demo do
  include_context "demo seeded world"

  it "mỗi trạm bơm có danh sách nhận riêng; điện trạm chỉ chia cho vùng của trạm",
     demo_nv: %w[NV-phan-bo-bom-theo-tram] do
    demo = DemoRecorder.new(self)
    zone = Zone.find_by!(name: "Khu vực Trung tâm")

    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")
    demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")
    demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
    expect(page).to have_current_path("/", wait: 10)

    demo.visit("/pump_allocations", caption: "Mở Phân bổ bơm nước — mỗi trạm một danh sách riêng")
    demo.narrate("Mỗi trạm bơm phục vụ một vùng; điện trạm chỉ chia cho đối tượng của vùng đó")
    # Highlight hai trạm khác nhau trên bảng để THẤY danh sách riêng (tiêu chí #1)
    demo.highlight("[data-pump-allocation-target-id='#{first_station_alloc_id}']",
                   caption: "Trạm bơm 1 — chia cho đơn vị/khối thuộc vùng 1")

    # Diễn KẾT QUẢ trên bảng tính tiền (tiêu chí #3): tính lại rồi highlight ô bơm nước
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Mở bảng tính tiền khu vực")
    demo.click("Tính toán lại", confirm: true, caption: "Tính toán lại theo phân bổ từng trạm")
    expect(page).to have_content("Đã tính toán lại bảng tính tiền.", wait: 15)
    # ... highlight ô phân bổ bơm của một đầu mối thuộc vùng trạm 1, kèm assertion Calculation

    # (Excel: KHÔNG diễn — để billing_spec :xlsx lo, như TN1.)
  end
end
```

> Cần thêm DOM hook `data-pump-allocation-target-id` (Task 8) và một hook ô bơm trên billing nếu chưa có; nếu billing chưa có hook per-cp cho cột bơm, dùng `highlight` theo selector hàng đầu mối đã có. Lấy `first_station_alloc_id` từ seed (`PumpAllocation.where(...).first.id`).

- [ ] **Step 4: Chạy demo spec mới**

Run: `bin/docker demo spec/demo/pump_allocation_per_station_demo_spec.rb`
Expected: PASS.

- [ ] **Step 5: Tự-soi-như-khách (bắt buộc ADR-059)**

Xem lại bản quay như khách chưa biết gì; đối chiếu 6 tiêu chí + so TN1; ghi "đã soi gì" để dán vào PR.

- [ ] **Step 6: Commit**

```bash
git add db/seeds/demo.rb spec/demo/pump_allocation_per_station_demo_spec.rb
git commit -m "feat(pump): per-station demo seed + ADR-059 demo spec for TN2"
```

---

## Task 10: Truy vết — spec doc, chiều test, role matrix, changelog

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md`
- Modify: `spec/support/role_behavior_matrix.rb` (nếu scenario đổi)
- Modify: `docs/V2_CHIEU_TEST.md` (nếu cần anchor `CHIEU-phan-bo-tram-*` — đối chiếu trước)

- [ ] **Step 1: Spec — thêm khai demo (ADR-052) + lật chiều test**

Trong frontmatter spec thêm `customer_facing: true`. Thêm mục cuối:

```markdown
## Truy vết demo

`spec/demo/pump_allocation_per_station_demo_spec.rb`
```

Trong bảng `## Truy vết chiều test`, đổi 8 hàng `DEFERRED #319` → trạng thái "có test", ghi rõ spec phủ mỗi chiều:
- `CHIEU-phan-bo-tram-ky-cu` → `spec/services/pump_allocation_calculator_spec.rb` (regression zone-wide)
- `CHIEU-phan-bo-tram-tong` / `-bon-recipient` / `-chua-cau-hinh` → calculator spec (Task 5)
- `CHIEU-phan-bo-tram-rang-buoc` → `spec/models/pump_allocation_spec.rb` (Task 4)
- `CHIEU-phan-bo-tram-chuyen-tiep` → `spec/services/period_service_spec.rb` (Task 6)
- `CHIEU-phan-bo-tram-da-xoa` → calculator spec (closed period + discarded recipient)
- `CHIEU-phan-bo-tram-vai-tro` → `spec/requests` + `spec/system` + role matrices

- [ ] **Step 2: Bump version + changelog spec**

Theo ADR-002: bump `version:` trong frontmatter (0.2.1 → 0.3.0, feat) + thêm entry `## Lịch sử thay đổi`:

```markdown
### 0.3.0 (2026-06-14)

- Triển khai TN2: per-station calculator, recipient bốn loại, cờ kỳ, kế thừa per-trạm, UI, demo. Khai `customer_facing: true` + `## Truy vết demo` (ADR-052); lật 8 `CHIEU-phan-bo-tram-*` từ DEFERRED sang có-test.
```

- [ ] **Step 3: Role matrix — kiểm `pump_allocations_data` scenario còn đúng**

Mở `spec/support/role_behavior_matrix.rb` + shared example `pump_allocations_data`. Kỳ vọng access (sa/ua_zm/cmd_zm `:ok`; ua/cmd/tech `:redirect`) KHÔNG đổi. Nếu scenario assert nội dung cột mà view đổi (thêm cột Trạm) → cập nhật scenario cho khớp. Chạy guardrail:

Run: `bin/docker rspec spec/support/role_access_matrix_spec.rb spec/support/role_behavior_matrix_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-06-11-phan-bo-bom-theo-tram-design.md spec/support/role_behavior_matrix.rb docs/V2_CHIEU_TEST.md
git commit -m "docs(pump): mark TN2 spec customer-facing, flip test dimensions, changelog 0.3.0"
```

---

## Task 11: Toàn bộ suite + zeitwerk + schema (cổng trước PR)

- [ ] **Step 1: Chạy toàn bộ test**

Run: `bin/docker rspec`
Expected: PASS toàn bộ (gồm system). Sửa hồi quy nếu có.

- [ ] **Step 2: Chạy demo bundle**

Run: `bin/docker demo`
Expected: PASS (TN1, freshness, loss_breakdown, TN2 mới).

- [ ] **Step 3: zeitwerk + schema không lệch**

Run: `bin/docker bash -c "RAILS_ENV=test bin/rails zeitwerk:check && RAILS_ENV=test bin/rails db:schema:load 2>/dev/null; git diff --exit-code db/schema.rb"`
Expected: zeitwerk OK; `db/schema.rb` không lệch (đã commit ở Task 1).

- [ ] **Step 4: Mở PR base `develop`**

Nhánh feature (worktree riêng), PR base `develop`, gắn nhãn `customer-facing`, link `#319`. Body có mục demo + "đã soi gì" (ADR-059). Test plan đánh dấu hết. Theo dõi CI ở background ([[feedback_monitor_ci_after_pr]]).

---

## Self-Review (đối chiếu spec)

**Spec coverage:**
- ADR-026 quyết định 1 (trạm = water_pump) → Task 5 (group meters by contact_point_id). ✓
- Quyết định 2 (`pump_contact_point_id` + recipient 4-loại + nới zone-level) → Task 4. ✓
- Quyết định 3 (cờ `pump_allocation_per_station` + calculator rẽ nhánh) → Task 1, 2, 5. ✓
- Data model (cột mới, index) → Task 1. ✓
- Ràng buộc per-trạm (Σ fixed% ≤ 100 per-trạm, station required khi per_station) → Task 4. ✓
- Calculator per-trạm (D_trạm, distribute, khối/nhóm theo quân số, đầu mối đơn vị trực tiếp) → Task 5. ✓
- Cảnh báo trạm chưa cấu hình → Task 5. ✓
- Trang (một bảng/nhóm theo trạm, form 4 loại + chọn trạm, Stimulus) → Task 7, 8. ✓
- Quyền (SA + zone-manager cấu hình, chỉ huy chỉ xem) → giữ qua `accessible_by` + `SettingsAccessGuard` + `can_edit`; role matrices Task 10. ✓
- Kế thừa kỳ + chuyển tiếp (không copy qua ranh giới, copy khi cùng per-station) → Task 6. ✓
- 8 chiều test → Task 4/5/6 + request/system + Task 10 lật trạng thái. ✓
- Demo ADR-059 + khai customer_facing → Task 9, 10. ✓

**Gaps cần xác nhận khi thực thi (không chặn plan):**
- `LossCalculator.meter_losses` gán đúng `meter_id` cho công tơ trạm — đã verify trả `Hash[meter_id => BigDecimal]`. ✓
- Billing view có cần cột/hook bơm per-cp cho demo highlight không — nếu thiếu, dùng selector hàng đầu mối có sẵn (Task 9 Step 3 đã ghi chú).
- `accessible_by(current_ability)` cho `Block`/`Group` trong form: kiểm Ability có rule `:read` Block/Group cho zone-manager; nếu chưa, thêm (system_admin đã `:manage`). Xác nhận ở Task 8.

**Placeholder scan:** không còn "TBD/implement later"; mọi step logic lõi có code thật. View/Stimulus có code cụ thể + bám source verbatim hiện tại.

**Type consistency:** `pump_contact_point` (association) ↔ `pump_contact_point_id` (cột) nhất quán; `kept_residential_contact_points` dùng đồng nhất Block/Group; `allocate_within`/`distribute_to_recipients`/`group_total` ký hiệu nhất quán giữa Task 5 các nhánh.
