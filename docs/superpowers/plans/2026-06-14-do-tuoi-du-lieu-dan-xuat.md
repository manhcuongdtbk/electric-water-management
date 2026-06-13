# Chỉ báo độ tươi dữ liệu dẫn xuất (#334) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Làm cho trạng thái "cũ" của dữ liệu dẫn xuất (calculations, loss snapshots, dashboard) nhìn-thấy-được per khu vực, và chặn rò rỉ dữ liệu cũ ra file Excel — không đổi mô hình snapshot, không auto-recalc.

**Architecture:** Một bảng `calculation_states(zone_id, period_id, inputs_changed_at, last_calculated_at)`. Concern `TouchesCalculationState` bump `inputs_changed_at` qua `after_commit` (create/update/destroy) trên 7 input model; `CalculationOrchestrator` set `last_calculated_at` khi tính xong zone-kỳ. Query object `CalculationFreshness` suy trạng thái per-zone cho 5 trang; partial chỉ báo + guard xuất Excel ba lớp (Stimulus confirm → server redirect → đóng dấu trong file).

**Tech Stack:** Rails 8, PostgreSQL, RSpec + Capybara (system + request + demo), Hotwire/Stimulus, caxlsx, CanCanCan, Discard, i18n (vi.yml).

**Spec:** `docs/superpowers/specs/2026-06-14-do-tuoi-du-lieu-dan-xuat-design.md` (ADR-049, v1.2.1).

---

## Quy ước chung khi thực thi

- **Chạy test:** `bin/docker rspec <path>`. KHÔNG chạy rubocop locally (CI lo).
- **Anchor chiều test (ADR-030):** mỗi `it` mang đúng mã `CHIEU-do-tuoi-...` ở đầu mô tả. CI `check-test-dimensions.sh` đối chiếu bảng spec ↔ test — sau khi hoàn tất các task, mọi mã trong bảng spec phải có ít nhất một test nhắc tới.
- **i18n (ADR-032):** mọi text người-dùng mới trong view phải qua `t(...)` + `config/locales/vi.yml`. CI `check-view-i18n.sh` kiểm.
- **BigDecimal / no-abbrev / 6 vai trò:** theo AGENTS.md.
- **Commit message:** Conventional Commits, tiếng Anh, subject KHÔNG mở đầu bằng token chữ HOA. Mỗi task commit ít nhất một lần (TDD: test đỏ → code → test xanh → commit).
- **Sáu vai trò** (xem `docs/V2_HANH_VI_HE_THONG.md` mục 1): system_admin (SA), unit_admin (UA), unit_admin manager (UA-ZM), commander (CMD), commander manager (CMD-ZM), technician (TECH).

## File structure (tạo/sửa)

**Tạo:**
- `db/migrate/<ts>_create_calculation_states.rb` — bảng marker.
- `app/models/calculation_state.rb` — model + logic suy trạng thái.
- `app/models/concerns/touches_calculation_state.rb` — concern bump `inputs_changed_at`.
- `app/queries/calculation_freshness.rb` — zones+period → danh sách trạng thái per-zone.
- `app/controllers/concerns/freshness_indicatable.rb` — controller concern: `freshness_zones`, `assign_freshness_states`.
- `app/views/shared/_freshness_indicator.html.erb` — partial chỉ báo dùng chung.
- `app/javascript/controllers/stale_export_controller.js` — Stimulus confirm khi xuất Excel cũ.
- `spec/demo/freshness_demo_spec.rb` — demo spec (ADR-040).
- Specs: `spec/models/calculation_state_spec.rb`, `spec/models/concerns/touches_calculation_state_spec.rb`, `spec/queries/calculation_freshness_spec.rb`, `spec/requests/billing_freshness_spec.rb`, `spec/requests/entry_pages_freshness_spec.rb`, `spec/requests/billing_export_guard_spec.rb`, `spec/system/stale_export_confirm_spec.rb`, `spec/requests/freshness_roles_spec.rb`.

**Sửa:**
- 7 input model: `app/models/meter_reading.rb`, `main_meter_reading.rb`, `personnel_entry.rb`, `other_deduction.rb`, `non_establishment_snapshot.rb`, `pump_allocation.rb`, `unit_config.rb` — `include TouchesCalculationState` + resolver.
- `app/models/meter.rb`, `app/models/contact_point.rb` — bump tường minh ở 2 propagation dùng `update_column`.
- `app/services/calculation_orchestrator.rb` — set `last_calculated_at`.
- `app/controllers/billing_controller.rb` — `assign_freshness_states` + guard xuất Excel; refactor `zones_in_scope` dùng `freshness_zones`.
- `app/controllers/dashboard_controller.rb`, `electricity_supply_controller.rb`, `app/controllers/concerns/meter_reading_entry.rb` — `assign_freshness_states`.
- 5 view (`billing/show`, `dashboard/show`, `meter_entries/show`, `pump_entries/show`, `electricity_supply/show`) — render partial chỉ báo; billing thêm `data-controller` cho nút Xuất Excel.
- `app/views/billing/show.xlsx.axlsx` — dòng cảnh báo đóng dấu khi stale.
- `config/locales/vi.yml` — khóa `calculation_states.*` + `billing.export.*`.
- `docs/THUAT_NGU.md` — gloss "độ tươi dữ liệu dẫn xuất" / "stale".

---

## Task 1: Bảng + model `calculation_states`

**Files:**
- Create: `db/migrate/<ts>_create_calculation_states.rb`
- Create: `app/models/calculation_state.rb`
- Test: `spec/models/calculation_state_spec.rb`

- [ ] **Step 1: Viết migration**

Tạo file (dùng timestamp hiện tại, ví dụ `20260614120000`):

```ruby
class CreateCalculationStates < ActiveRecord::Migration[8.0]
  def change
    create_table :calculation_states do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.datetime :inputs_changed_at
      t.datetime :last_calculated_at
      t.timestamps
    end
    add_index :calculation_states, %i[zone_id period_id], unique: true,
      name: "idx_calculation_states_unique"
  end
end
```

- [ ] **Step 2: Chạy migration**

Run: `bin/docker bash -c "bin/rails db:migrate"` (hoặc `bin/docker rails db:migrate`)
Expected: tạo bảng + cập nhật `db/schema.rb`.

- [ ] **Step 3: Viết test đỏ cho logic trạng thái**

```ruby
require "rails_helper"

RSpec.describe CalculationState do
  let(:zone) { create(:zone) }
  let(:period) { create(:period) }

  def state(inputs_changed_at:, last_calculated_at:)
    described_class.new(zone: zone, period: period,
      inputs_changed_at: inputs_changed_at, last_calculated_at: last_calculated_at)
  end

  it "is never_calculated when last_calculated_at is nil" do
    s = state(inputs_changed_at: Time.current, last_calculated_at: nil)
    expect(s.status).to eq(:never_calculated)
    expect(s.stale?).to be(false)
  end

  it "is fresh when calculated and no later input change" do
    t = Time.current
    s = state(inputs_changed_at: t - 1.minute, last_calculated_at: t)
    expect(s.status).to eq(:fresh)
    expect(s.stale?).to be(true).or be(false) # see explicit below
    expect(s.fresh?).to be(true)
  end

  it "is stale when an input changed after the last calculation" do
    t = Time.current
    s = state(inputs_changed_at: t, last_calculated_at: t - 1.minute)
    expect(s.status).to eq(:stale)
    expect(s.stale?).to be(true)
  end

  it "is fresh when calculated and inputs_changed_at is nil" do
    s = state(inputs_changed_at: nil, last_calculated_at: Time.current)
    expect(s.status).to eq(:fresh)
  end
end
```

> Lưu ý: sửa dòng `.or` ở ví dụ trên thành `expect(s.stale?).to be(false)` — đã tính, input đổi TRƯỚC khi tính ⟹ không stale. (Để rõ ràng, viết assertion dứt khoát, không dùng `.or`.)

Run: `bin/docker rspec spec/models/calculation_state_spec.rb`
Expected: FAIL (`uninitialized constant CalculationState` hoặc thiếu method).

- [ ] **Step 4: Viết model**

```ruby
class CalculationState < ApplicationRecord
  belongs_to :zone
  belongs_to :period

  # Bump dấu thời gian input đổi cho (zone, period) — idempotent, không đụng
  # last_calculated_at. Dùng upsert để tránh race + giữ created_at.
  def self.touch_inputs!(zone_id:, period_id:, at: Time.current)
    upsert_all(
      [{ zone_id: zone_id, period_id: period_id, inputs_changed_at: at,
         created_at: at, updated_at: at }],
      unique_by: %i[zone_id period_id],
      on_duplicate: Arel.sql("inputs_changed_at = EXCLUDED.inputs_changed_at, updated_at = EXCLUDED.updated_at")
    )
  end

  # Ghi mốc đã-tính cho (zone, period). Gọi trong transaction của orchestrator.
  def self.mark_calculated!(zone_id:, period_id:, at: Time.current)
    upsert_all(
      [{ zone_id: zone_id, period_id: period_id, last_calculated_at: at,
         created_at: at, updated_at: at }],
      unique_by: %i[zone_id period_id],
      on_duplicate: Arel.sql("last_calculated_at = EXCLUDED.last_calculated_at, updated_at = EXCLUDED.updated_at")
    )
  end

  def never_calculated?
    last_calculated_at.nil?
  end

  def stale?
    return false if last_calculated_at.nil?
    inputs_changed_at.present? && inputs_changed_at > last_calculated_at
  end

  def fresh?
    last_calculated_at.present? && !stale?
  end

  def status
    return :never_calculated if never_calculated?
    stale? ? :stale : :fresh
  end
end
```

- [ ] **Step 5: Chạy test xanh**

Run: `bin/docker rspec spec/models/calculation_state_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrate db/schema.rb app/models/calculation_state.rb spec/models/calculation_state_spec.rb
git commit -m "feat(calculation-state): add calculation_states table and freshness state logic"
```

---

## Task 2: Concern `TouchesCalculationState` + tích hợp 7 input model

**Files:**
- Create: `app/models/concerns/touches_calculation_state.rb`
- Modify: 7 input model (mỗi model `include` + định nghĩa resolver)
- Modify: `app/models/meter.rb`, `app/models/contact_point.rb` (2 propagation dùng `update_column`)
- Test: `spec/models/concerns/touches_calculation_state_spec.rb`

- [ ] **Step 1: Viết test đỏ — bump khi create/update/destroy, mọi nguồn**

```ruby
require "rails_helper"

RSpec.describe TouchesCalculationState do
  # Helper: đọc inputs_changed_at hiện tại của (zone, period)
  def changed_at(zone, period)
    CalculationState.find_by(zone_id: zone.id, period_id: period.id)&.inputs_changed_at
  end

  let(:period) { Period.current || create(:period) }

  describe "meter_reading qua meter -> contact_point -> effective_zone" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let(:contact_point) { create(:contact_point, :residential, unit: unit) }
    let(:meter) { contact_point.meters.first || create(:meter, contact_point: contact_point) }

    it "CHIEU-do-tuoi-nguon-input: bumps on meter_reading update" do
      reading = MeterReading.find_by(meter_id: meter.id, period_id: period.id)
      expect { reading.update!(reading_end: 100) }
        .to change { changed_at(zone, period) }
    end

    it "CHIEU-do-tuoi-bump-khi-xoa: bumps on meter_reading destroy" do
      reading = MeterReading.find_by(meter_id: meter.id, period_id: period.id)
      expect { reading.destroy! }.to change { changed_at(zone, period) }
    end
  end

  describe "pump_allocation (zone_id trực tiếp)" do
    let(:zone) { create(:zone) }
    it "CHIEU-do-tuoi-nguon-input: bumps on create" do
      expect { create(:pump_allocation, zone: zone, period: period) }
        .to change { changed_at(zone, period) }
    end
  end

  describe "unit_config qua unit.zone" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    it "CHIEU-do-tuoi-nguon-input: bumps on update" do
      config = create(:unit_config, unit: unit, period: period)
      expect { config.update!(unit_public_rate: 5) }
        .to change { changed_at(zone, period) }
    end
  end
end
```

> Nếu factory cho từng model chưa có, tạo tối thiểu trong `spec/factories/`. Kiểm `ls spec/factories` trước; tái dùng factory sẵn có (đa số đã có vì engine có test).

Run: `bin/docker rspec spec/models/concerns/touches_calculation_state_spec.rb`
Expected: FAIL (`uninitialized constant TouchesCalculationState`).

- [ ] **Step 2: Viết concern**

```ruby
# Bump CalculationState#inputs_changed_at mỗi khi một input model thay đổi
# (create/update/destroy), để chỉ báo độ tươi (#334, ADR-049) phát hiện được
# "dữ liệu dẫn xuất đã cũ". Mỗi model include phải định nghĩa
# #calculation_state_targets trả mảng [[zone_id, period_id], ...] (thường 1 phần tử).
#
# Chạy ở after_commit (sau khi transaction commit) nên thấy đúng trạng thái cuối,
# kể cả destroy. Engine recalc KHÔNG ghi các bảng này qua callback (LossSnapshotWriter
# dùng update_all; PumpAllocationCalculator chỉ đọc) nên không có race báo-cũ-sai.
module TouchesCalculationState
  extend ActiveSupport::Concern

  included do
    after_commit :bump_calculation_state, on: %i[create update destroy]
  end

  private

  def bump_calculation_state
    calculation_state_targets.each do |zone_id, period_id|
      next if zone_id.nil? || period_id.nil?
      CalculationState.touch_inputs!(zone_id: zone_id, period_id: period_id)
    end
  end

  # Mặc định: model không khai báo → không bump (an toàn). Override ở từng model.
  def calculation_state_targets
    []
  end
end
```

- [ ] **Step 3: Tích hợp vào từng model**

`app/models/meter_reading.rb` — thêm trong class:
```ruby
  include TouchesCalculationState

  private

  def calculation_state_targets
    cp = meter&.contact_point
    [[cp&.effective_zone&.id, period_id]]
  end
```

`app/models/main_meter_reading.rb`:
```ruby
  include TouchesCalculationState

  private

  def calculation_state_targets
    [[main_meter&.zone_id, period_id]]
  end
```

`app/models/personnel_entry.rb`, `app/models/other_deduction.rb`, `app/models/non_establishment_snapshot.rb` (đều qua contact_point):
```ruby
  include TouchesCalculationState

  private

  def calculation_state_targets
    [[contact_point&.effective_zone&.id, period_id]]
  end
```

`app/models/pump_allocation.rb`:
```ruby
  include TouchesCalculationState

  private

  def calculation_state_targets
    [[zone_id, period_id]]
  end
```

`app/models/unit_config.rb`:
```ruby
  include TouchesCalculationState

  private

  def calculation_state_targets
    [[unit&.zone_id, period_id]]
  end
```

> Với từng model: đọc file, đặt `include TouchesCalculationState` cùng nhóm include đầu class; nếu model đã có `private` thì gộp method vào đó (không tạo hai khối `private`). `belongs_to` cho phép load association sau destroy vì các bảng cha (meter, contact_point, zone, unit, main_meter) dùng Discard (soft) — row vẫn còn.

- [ ] **Step 4: Vá 2 propagation dùng `update_column` (bypass after_commit)**

`app/models/meter.rb` — trong `propagate_no_loss_to_current_period_reading`, sau khi update_column, bump tường minh:
```ruby
  def propagate_no_loss_to_current_period_reading
    period = Period.current
    return unless period
    meter_readings.find_by(period: period)&.update_column(:no_loss, no_loss)
    zone_id = contact_point&.effective_zone&.id
    CalculationState.touch_inputs!(zone_id: zone_id, period_id: period.id) if zone_id
  end
```

`app/models/contact_point.rb` — trong `propagate_personnel_count_to_current_snapshot`:
```ruby
  def propagate_personnel_count_to_current_snapshot
    period = Period.current
    return unless period
    non_establishment_snapshots.find_by(period: period)
      &.update_column(:personnel_count, personnel_count)
    zone_id = effective_zone&.id
    CalculationState.touch_inputs!(zone_id: zone_id, period_id: period.id) if zone_id
  end
```

- [ ] **Step 5: Chạy test xanh + regression model**

Run: `bin/docker rspec spec/models/concerns/touches_calculation_state_spec.rb spec/models`
Expected: PASS (không vỡ test model sẵn có).

- [ ] **Step 6: Commit**

```bash
git add app/models spec/models/concerns/touches_calculation_state_spec.rb spec/factories
git commit -m "feat(calculation-state): bump inputs_changed_at on input model changes"
```

---

## Task 3: Hook `last_calculated_at` trong orchestrator

**Files:**
- Modify: `app/services/calculation_orchestrator.rb`
- Test: `spec/services/calculation_orchestrator_spec.rb` (sửa/thêm) hoặc `spec/requests/billing_freshness_spec.rb` (Task 6). Ở đây thêm test service-level nhỏ.

- [ ] **Step 1: Viết test đỏ**

Thêm vào `spec/services/calculation_orchestrator_spec.rb` (tạo nếu chưa có):
```ruby
require "rails_helper"

RSpec.describe CalculationOrchestrator do
  it "records last_calculated_at for the zone-period after running" do
    period = Period.current || create(:period)
    zone = create(:zone)
    unit = create(:unit, zone: zone)
    create(:contact_point, :residential, unit: unit) # tạo data tối thiểu

    described_class.new(zone: zone, period: period).call

    state = CalculationState.find_by(zone_id: zone.id, period_id: period.id)
    expect(state.last_calculated_at).to be_present
    expect(state.never_calculated?).to be(false)
  end
end
```

Run: `bin/docker rspec spec/services/calculation_orchestrator_spec.rb`
Expected: FAIL (`last_calculated_at` nil).

- [ ] **Step 2: Thêm hook trong transaction**

Sửa `app/services/calculation_orchestrator.rb` — sau khi tính `summary`, trước khi tạo `Result`:
```ruby
      summary = SummaryCalculator.new(
        zone: @zone, period: @period, loss_results: loss, pump_results: pump
      ).call

      CalculationState.mark_calculated!(zone_id: @zone.id, period_id: @period.id)

      Result.new(
```

- [ ] **Step 3: Chạy test xanh**

Run: `bin/docker rspec spec/services/calculation_orchestrator_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/services/calculation_orchestrator.rb spec/services/calculation_orchestrator_spec.rb
git commit -m "feat(calculation-state): record last_calculated_at when recalculating a zone"
```

---

## Task 4: Query object `CalculationFreshness`

**Files:**
- Create: `app/queries/calculation_freshness.rb`
- Test: `spec/queries/calculation_freshness_spec.rb`

- [ ] **Step 1: Viết test đỏ**

```ruby
require "rails_helper"

RSpec.describe CalculationFreshness do
  let(:period) { create(:period) }
  let(:zone_a) { create(:zone, name: "A") }
  let(:zone_b) { create(:zone, name: "B") }

  it "CHIEU-do-tuoi-per-zone: returns one entry per zone that has a state row, sorted by name" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id)
    CalculationState.touch_inputs!(zone_id: zone_b.id, period_id: period.id)

    result = described_class.new(period: period, zones: Zone.where(id: [zone_a.id, zone_b.id]).order(:name)).call

    expect(result.map { |e| e.zone.id }).to eq([zone_a.id, zone_b.id])
    expect(result.map(&:status)).to eq([:fresh, :never_calculated])
  end

  it "CHIEU-do-tuoi-stale-sau-sua: marks stale when inputs changed after calculation" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id, at: 2.minutes.ago)
    CalculationState.touch_inputs!(zone_id: zone_a.id, period_id: period.id, at: Time.current)

    result = described_class.new(period: period, zones: Zone.where(id: zone_a.id)).call
    expect(result.first.status).to eq(:stale)
  end

  it "any_stale? is true when at least one zone is stale" do
    CalculationState.mark_calculated!(zone_id: zone_a.id, period_id: period.id, at: 2.minutes.ago)
    CalculationState.touch_inputs!(zone_id: zone_a.id, period_id: period.id, at: Time.current)
    fresh = described_class.new(period: period, zones: Zone.where(id: zone_a.id))
    expect(fresh.any_stale?).to be(true)
  end
end
```

Run: `bin/docker rspec spec/queries/calculation_freshness_spec.rb`
Expected: FAIL (`uninitialized constant CalculationFreshness`).

- [ ] **Step 2: Viết query object**

```ruby
# Suy trạng thái độ tươi per khu vực cho một kỳ (#334, ADR-049). Chỉ trả các zone
# có dòng calculation_states (zone chưa từng có input/tính → bỏ qua, bảng trống tự nói).
class CalculationFreshness
  Entry = Struct.new(:zone, :status, keyword_init: true)

  def initialize(period:, zones:)
    @period = period
    @zones = zones
  end

  def call
    return [] if @period.nil?
    states = CalculationState
             .where(period_id: @period.id, zone_id: @zones.map(&:id))
             .index_by(&:zone_id)
    @zones.filter_map do |zone|
      state = states[zone.id]
      next if state.nil?
      Entry.new(zone: zone, status: state.status)
    end
  end

  def any_stale?
    call.any? { |entry| entry.status == :stale }
  end
end
```

> `@zones.map(&:id)` materialize relation một lần; chấp nhận được (số zone nhỏ).

- [ ] **Step 3: Chạy test xanh**

Run: `bin/docker rspec spec/queries/calculation_freshness_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/queries/calculation_freshness.rb spec/queries/calculation_freshness_spec.rb
git commit -m "feat(calculation-state): add CalculationFreshness query for per-zone status"
```

---

## Task 5: i18n + partial chỉ báo + controller concern

**Files:**
- Modify: `config/locales/vi.yml`
- Create: `app/views/shared/_freshness_indicator.html.erb`
- Create: `app/controllers/concerns/freshness_indicatable.rb`

- [ ] **Step 1: Thêm khóa i18n**

Trong `config/locales/vi.yml`, thêm khối top-level (cùng cấp `billing:`, đặt cạnh nó cho dễ tìm):
```yaml
  calculation_states:
    stale: "Cần tính toán lại — dữ liệu đã thay đổi sau lần tính gần nhất"
    stale_zone: "Khu vực %{zone}: cần tính toán lại (dữ liệu đã đổi sau lần tính gần nhất)"
    never_calculated: "Khu vực %{zone}: chưa tính toán lần nào cho kỳ này"
    recalculate_hint: "Vào Bảng tính tiền và bấm \"Tính toán lại\" để cập nhật."
```

Và mở rộng `billing:` thêm nhánh `export:`:
```yaml
    export:
      stale_confirm: "Dữ liệu một số khu vực đã cũ so với lần tính gần nhất. Vẫn xuất Excel?"
      stale_blocked: "Không thể xuất Excel: dữ liệu đã cũ so với lần tính gần nhất. Hãy Tính toán lại hoặc xác nhận xuất bản cũ."
      stale_stamp: "CẢNH BÁO: Dữ liệu trong file có thể đã cũ so với chỉ số hiện tại. Hãy Tính toán lại để cập nhật."
```

> Đọc quanh dòng ~467 (`billing:`) để giữ đúng thụt lề 2 space của YAML. KHÔNG hard-code text này trong view/Excel — luôn `t(...)`.

- [ ] **Step 2: Viết partial chỉ báo**

`app/views/shared/_freshness_indicator.html.erb`:
```erb
<%#
  Chỉ báo độ tươi per khu vực (#334). Cần local: states (mảng CalculationFreshness::Entry).
  Chỉ hiện banner cho zone stale và (tuỳ) never_calculated. Kỳ đóng → controller truyền [].
%>
<% stale = Array(states).select { |e| e.status == :stale } %>
<% if stale.any? %>
  <div class="rounded-md bg-amber-50 border border-amber-300 p-3 mb-4 text-amber-800"
       data-testid="freshness-stale">
    <ul class="list-disc list-inside space-y-1">
      <% stale.each do |entry| %>
        <li><%= t("calculation_states.stale_zone", zone: entry.zone.name) %></li>
      <% end %>
    </ul>
    <p class="mt-1 text-sm"><%= t("calculation_states.recalculate_hint") %></p>
  </div>
<% end %>
```

> Lớp Tailwind theo style sẵn có của `billing/_warnings.html.erb` (đọc file đó để khớp màu/format banner cảnh báo). `data-testid` để request/system spec bám.

- [ ] **Step 3: Viết controller concern**

`app/controllers/concerns/freshness_indicatable.rb`:
```ruby
# Cung cấp danh sách zone (Ability-aligned) + gán @freshness_states cho view.
# Dùng chung cho 5 trang hiển thị/sửa dữ liệu liên quan dữ liệu dẫn xuất (#334).
module FreshnessIndicatable
  extend ActiveSupport::Concern

  private

  # Các zone người dùng hiện tại thấy cho kỳ này (khớp Ability). selected_zone (nếu có)
  # thu hẹp về đúng một zone (SA chọn filter zone).
  def freshness_zones(period, selected_zone: nil)
    return Zone.with_discarded.where(id: selected_zone.id).order(:name) if selected_zone

    if current_user.system_admin?
      Zone.with_discarded.order(:name)
    else
      zone_ids = [current_user.unit&.zone_id].compact
      if current_user.unit_id
        zone_ids += Zone.kept.where(manager_unit_id: current_user.unit_id).pluck(:id)
      end
      Zone.with_discarded.where(id: zone_ids.uniq).order(:name)
    end
  end

  # Kỳ đóng = đông cứng (không sửa input được) → không có "stale" → []. Chỉ tính độ
  # tươi cho kỳ đang mở.
  def assign_freshness_states(period, selected_zone: nil)
    if period.nil? || period.closed?
      @freshness_states = []
      return @freshness_states
    end
    @freshness_states = CalculationFreshness.new(
      period: period, zones: freshness_zones(period, selected_zone: selected_zone)
    ).call
  end
end
```

- [ ] **Step 4: Smoke — boot app, không lỗi i18n/zeitwerk**

Run: `bin/docker bash -c "bin/rails runner 'puts I18n.t(\"calculation_states.stale_zone\", zone: \"X\")'"`
Expected: in ra chuỗi tiếng Việt (không `translation missing`).

Run: `bin/docker bash -c "bin/rails zeitwerk:check"`
Expected: "All is good!".

- [ ] **Step 5: Commit**

```bash
git add config/locales/vi.yml app/views/shared/_freshness_indicator.html.erb app/controllers/concerns/freshness_indicatable.rb
git commit -m "feat(calculation-state): add freshness i18n, indicator partial and controller concern"
```

---

## Task 6: Wire chỉ báo vào Billing + request spec

**Files:**
- Modify: `app/controllers/billing_controller.rb`
- Modify: `app/views/billing/show.html.erb`
- Test: `spec/requests/billing_freshness_spec.rb`

- [ ] **Step 1: Viết request spec đỏ**

```ruby
require "rails_helper"

RSpec.describe "Billing freshness indicator", type: :request do
  # Dùng helper login sẵn có của repo (xem spec/support). Giả định sign_in(user).
  let(:period) { Period.current || create(:period) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }

  before { sign_in sa }

  it "CHIEU-do-tuoi-sau-tinh-con-dung: no stale banner right after recalculation" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-stale-sau-sua: shows stale banner after an input edit post-calculation" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    reading = MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
    reading.update!(reading_end: 123)

    get billing_path(period_id: period.id)
    expect(response.body).to include("freshness-stale")
    expect(response.body).to include(zone.name)
  end

  it "CHIEU-do-tuoi-ky-dong: no stale banner when viewing a closed period" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    reading = MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
    reading.update!(reading_end: 5)
    period.update!(closed: true)

    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-chua-tinh: no stale banner for an open period never calculated" do
    # Chưa từng tính (không gọi orchestrator). Có thể có dòng inputs_changed_at do
    # seed/callback, nhưng last_calculated_at nil ⟹ never_calculated, KHÔNG stale.
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-recalc-het-stale: recalculating via the real action clears stale" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
                .update!(reading_end: 123)
    get billing_path(period_id: period.id)
    expect(response.body).to include("freshness-stale")

    # Tính lại qua ACTION THẬT (không gọi service trực tiếp) — đúng convention spec.
    post recalculate_billing_path(period_id: period.id)
    get billing_path(period_id: period.id)
    expect(response.body).not_to include("freshness-stale")
  end
end
```

> Kiểm `spec/support` để biết helper đăng nhập (`sign_in`) + factory user traits (`:system_admin`, `:unit_admin`, ...). Tái dùng đúng tên có sẵn.
> **Convention (spec §Truy vết):** hành vi-dưới-test đi qua action thật. Trong các test trên, `CalculationOrchestrator.new(...).call` chỉ dùng ở phần ARRANGE (dựng trạng thái "đã tính"); riêng `CHIEU-do-tuoi-recalc-het-stale` kiểm việc tính-lại nên BẮT BUỘC qua `post recalculate_billing_path`. Tên route: kiểm `bin/docker bash -c "bin/rails routes | grep recalculate"` (dự kiến `recalculate_billing_path`).

Run: `bin/docker rspec spec/requests/billing_freshness_spec.rb`
Expected: FAIL (chưa render banner).

- [ ] **Step 2: Gán states trong controller**

`app/controllers/billing_controller.rb` — thêm `include FreshnessIndicatable` (cạnh các include đầu class). Trong `show`, sau khi đã có `@zone` (cả nhánh SA và non-SA) và trước `respond_to`, thêm:
```ruby
    assign_freshness_states(@period, selected_zone: @zone)
```
> Lưu ý: nhánh SA không set `@zone` trừ khi filter. Đảm bảo `@zone` đã được gán (nil nếu không filter) trước dòng này — với SA, thêm `@zone ||= resolve_filter.first if ...`? KHÔNG cần: nếu `@zone` nil thì `freshness_zones` trả mọi zone (đúng). Chỉ cần `@zone` là biến đã tồn tại (nil ok). Đặt dòng sau block if/else đã gán `@zone` cho non-SA; với SA `@zone` chưa định nghĩa → dùng `@zone` (nil). An toàn: đặt `@zone = nil unless defined?(@zone)` ngay trước, hoặc khởi tạo `@zone = @unit = nil` đầu action.

Refactor (DRY): thay thân `zones_in_scope` dùng chung logic — đặt:
```ruby
  def zones_in_scope(period)
    freshness_zones(period, selected_zone: @zone)
  end
```
> `freshness_zones` trả về cùng tập zone như bản cũ (đã đối chiếu logic). Chạy lại test billing/recalculate cũ để chắc không vỡ.

- [ ] **Step 3: Render partial trong view**

`app/views/billing/show.html.erb` — đọc file, chèn ngay sau phần render cảnh báo hiện có (`_warnings`), trước bảng:
```erb
<%= render "shared/freshness_indicator", states: @freshness_states %>
```

- [ ] **Step 4: Chạy test xanh + regression billing**

Run: `bin/docker rspec spec/requests/billing_freshness_spec.rb spec/requests/billing_spec.rb spec/system`
Expected: PASS (test billing/recalculate sẵn có vẫn xanh — xác nhận refactor `zones_in_scope` không đổi hành vi).

> Nếu tên file spec billing khác (`spec/requests/billing_controller_spec.rb`), chạy đúng tên (kiểm `ls spec/requests | grep billing`).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/billing_controller.rb app/views/billing/show.html.erb spec/requests/billing_freshness_spec.rb
git commit -m "feat(billing): show per-zone freshness indicator on the billing page"
```

---

## Task 7: Wire chỉ báo vào Dashboard + request spec

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `app/views/dashboard/show.html.erb`
- Test: thêm vào `spec/requests/entry_pages_freshness_spec.rb` (tạo file, gộp dashboard + 3 trang nhập + electricity)

- [ ] **Step 1: Viết test đỏ (dashboard phần)**

Tạo `spec/requests/entry_pages_freshness_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Freshness indicator across pages", type: :request do
  let(:period) { Period.current || create(:period) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }

  before { sign_in sa }

  def make_stale!
    CalculationOrchestrator.new(zone: zone, period: period).call
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
                .update!(reading_end: 50)
  end

  it "CHIEU-do-tuoi-5-trang: dashboard shows stale banner" do
    make_stale!
    get dashboard_path
    expect(response.body).to include("freshness-stale")
  end
end
```

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb`
Expected: FAIL.

- [ ] **Step 2: Controller**

`app/controllers/dashboard_controller.rb` — `include FreshnessIndicatable`; trong `show`, sau khi có `@summary` (và `@period` không nil):
```ruby
    assign_freshness_states(@period)
```

- [ ] **Step 3: View**

`app/views/dashboard/show.html.erb` — đọc file, chèn gần đầu nội dung (sau tiêu đề, trước các thẻ thừa/thiếu):
```erb
<%= render "shared/freshness_indicator", states: @freshness_states %>
```

- [ ] **Step 4: Chạy test xanh**

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb`
Expected: PASS (case dashboard).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/dashboard_controller.rb app/views/dashboard/show.html.erb spec/requests/entry_pages_freshness_spec.rb
git commit -m "feat(dashboard): show per-zone freshness indicator on the overview page"
```

---

## Task 8: Wire chỉ báo vào trang nhập chỉ số (meter_entries + pump_entries)

**Files:**
- Modify: `app/controllers/concerns/meter_reading_entry.rb`
- Modify: `app/views/meter_entries/show.html.erb`, `app/views/pump_entries/show.html.erb`
- Test: mở rộng `spec/requests/entry_pages_freshness_spec.rb`

- [ ] **Step 1: Viết test đỏ**

Thêm vào `spec/requests/entry_pages_freshness_spec.rb`:
```ruby
  it "CHIEU-do-tuoi-5-trang: meter_entries shows stale banner" do
    make_stale!
    get meter_entries_path
    expect(response.body).to include("freshness-stale")
  end

  it "CHIEU-do-tuoi-5-trang: pump_entries shows stale banner" do
    make_stale!
    get pump_entries_path
    expect(response.body).to include("freshness-stale")
  end
```

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb`
Expected: FAIL (2 case mới).

- [ ] **Step 2: Concern controller**

`app/controllers/concerns/meter_reading_entry.rb` — trong `included do ... end` thêm `include FreshnessIndicatable`. Trong `show`, cuối method:
```ruby
  def show
    @period = current_period
    @readings = load_readings
    @show_zone_unit = current_user.system_admin?
    assign_freshness_states(@period)
  end
```

- [ ] **Step 3: Views**

Trong cả `app/views/meter_entries/show.html.erb` và `app/views/pump_entries/show.html.erb` — chèn sau chú thích tĩnh #331 hiện có (đọc file để định vị block chú thích, chèn ngay dưới):
```erb
<%= render "shared/freshness_indicator", states: @freshness_states %>
```
> Chú thích tĩnh #331 vẫn giữ (giải thích snapshot là gì); chỉ báo động bổ sung "đang cũ ở zone nào".

- [ ] **Step 4: Chạy test xanh + regression**

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/concerns/meter_reading_entry.rb app/views/meter_entries/show.html.erb app/views/pump_entries/show.html.erb spec/requests/entry_pages_freshness_spec.rb
git commit -m "feat(entries): show per-zone freshness indicator on meter and pump entry pages"
```

---

## Task 9: Wire chỉ báo vào Nhập số điện lực (electricity_supply)

**Files:**
- Modify: `app/controllers/electricity_supply_controller.rb`
- Modify: `app/views/electricity_supply/show.html.erb`
- Test: mở rộng `spec/requests/entry_pages_freshness_spec.rb`

- [ ] **Step 1: Viết test đỏ**

```ruby
  it "CHIEU-do-tuoi-5-trang: electricity_supply shows stale banner" do
    make_stale!
    get electricity_supply_path
    expect(response.body).to include("freshness-stale")
  end
```

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb`
Expected: FAIL (case electricity).

- [ ] **Step 2: Controller**

`app/controllers/electricity_supply_controller.rb` — `include FreshnessIndicatable`; trong `show`, sau `authorize_or_redirect` (chỉ khi không redirect — đặt cuối method là đủ vì redirect đã `return`):
```ruby
  def show
    @period = current_period
    @readings = load_readings
    authorize_or_redirect
    assign_freshness_states(@period)
  end
```

- [ ] **Step 3: View**

`app/views/electricity_supply/show.html.erb` — chèn gần đầu nội dung:
```erb
<%= render "shared/freshness_indicator", states: @freshness_states %>
```

- [ ] **Step 4: Chạy test xanh**

Run: `bin/docker rspec spec/requests/entry_pages_freshness_spec.rb`
Expected: PASS (toàn bộ 5 trang).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/electricity_supply_controller.rb app/views/electricity_supply/show.html.erb spec/requests/entry_pages_freshness_spec.rb
git commit -m "feat(electricity): show per-zone freshness indicator on the supply entry page"
```

---

## Task 10: Guard xuất Excel — Lớp 2 (server redirect)

**Files:**
- Modify: `app/controllers/billing_controller.rb`
- Test: `spec/requests/billing_export_guard_spec.rb`

- [ ] **Step 1: Viết test đỏ**

```ruby
require "rails_helper"

RSpec.describe "Billing Excel export guard", type: :request do
  let(:period) { Period.current || create(:period) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }
  before { sign_in sa }

  def make_stale!
    CalculationOrchestrator.new(zone: zone, period: period).call
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
                .update!(reading_end: 77)
  end

  it "CHIEU-do-tuoi-excel-block: redirects with alert when exporting stale data without acknowledgement" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).to include(I18n.t("billing.export.stale_blocked"))
  end

  it "allows export of fresh data" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("spreadsheetml")
  end

  it "allows export of stale data when acknowledged" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
  end
end
```

Run: `bin/docker rspec spec/requests/billing_export_guard_spec.rb`
Expected: FAIL (chưa có guard — stale vẫn xuất).

- [ ] **Step 2: Thêm guard trong `format.xlsx`**

`app/controllers/billing_controller.rb` — trong `respond_to`, đầu block `format.xlsx`:
```ruby
      format.xlsx do
        @export_stale = CalculationFreshness.new(
          period: @period, zones: freshness_zones(@period, selected_zone: @zone)
        ).any_stale? && @period.open?
        if @export_stale && params[:acknowledged_stale].blank?
          next redirect_to(billing_path(redirect_filter_params),
                           alert: t("billing.export.stale_blocked"))
        end
        @calculations = scope.to_a
        preload_personnel(@calculations)
        response.headers["Content-Disposition"] =
          %(attachment; filename="bang-tinh-tien-#{@period.month}-#{@period.year}.xlsx")
      end
```
> `next` thoát block `respond_to` đúng cách trong Rails (block format). `@export_stale` còn dùng ở Task 11 để đóng dấu. Kỳ đóng không stale → `&& @period.open?`.

- [ ] **Step 3: Chạy test xanh**

Run: `bin/docker rspec spec/requests/billing_export_guard_spec.rb`
Expected: PASS (block + acknowledged + fresh).

- [ ] **Step 4: Commit**

```bash
git add app/controllers/billing_controller.rb spec/requests/billing_export_guard_spec.rb
git commit -m "feat(billing): block stale Excel export server-side unless acknowledged"
```

---

## Task 11: Guard xuất Excel — Lớp 3 (đóng dấu cảnh báo trong file)

**Files:**
- Modify: `app/views/billing/show.xlsx.axlsx`
- Test: mở rộng `spec/requests/billing_export_guard_spec.rb`

- [ ] **Step 1: Viết test đỏ**

```ruby
  it "CHIEU-do-tuoi-excel-stamp: stamps a warning into the file when exporting acknowledged stale data" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
    # Mở workbook trả về và kiểm có chuỗi cảnh báo
    require "roo" rescue nil
    tmp = Tempfile.new(["billing", ".xlsx"]); tmp.binmode; tmp.write(response.body); tmp.rewind
    book = Roo::Spreadsheet.open(tmp.path)
    text = book.sheet(0).to_a.flatten.compact.map(&:to_s).join(" ")
    expect(text).to include("CẢNH BÁO")
  ensure
    tmp&.close!
  end
```
> Nếu `roo` chưa có trong Gemfile test group, thay bằng cách đơn giản hơn: dùng `axlsx`/`zip` đọc `xl/sharedStrings.xml`. Kiểm `grep -i roo Gemfile*`; nếu không có, dùng:
> ```ruby
> require "zip"
> entries_text = ""
> Zip::File.open_buffer(StringIO.new(response.body)) do |zip|
>   entries_text = zip.read("xl/sharedStrings.xml")
> end
> expect(entries_text).to include("CẢNH BÁO")
> ```
> `rubyzip` thường có sẵn (caxlsx phụ thuộc). Dùng biến thể nào chạy được trong repo.

Run: `bin/docker rspec spec/requests/billing_export_guard_spec.rb`
Expected: FAIL (chưa đóng dấu).

- [ ] **Step 2: Thêm dòng cảnh báo vào template Excel**

`app/views/billing/show.xlsx.axlsx` — đọc đầu file để biết biến `wb`/`sheet`. Ngay sau khi mở sheet (trước header bảng), thêm:
```ruby
if @export_stale
  sheet.add_row [t("billing.export.stale_stamp")], types: [:string]
  sheet.add_row [] # dòng trống ngăn cách
end
```
> Tên biến `sheet`/`wb` theo template hiện có (đọc 15 dòng đầu). Đặt dòng cảnh báo ở trên cùng để hiện ngay khi mở file.

- [ ] **Step 3: Chạy test xanh + regression export**

Run: `bin/docker rspec spec/requests/billing_export_guard_spec.rb`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/views/billing/show.xlsx.axlsx spec/requests/billing_export_guard_spec.rb
git commit -m "feat(billing): stamp a stale-data warning into the exported Excel file"
```

---

## Task 12: Guard xuất Excel — Lớp 1 (Stimulus confirm) + system spec

**Files:**
- Create: `app/javascript/controllers/stale_export_controller.js`
- Modify: `app/views/billing/show.html.erb` (nút Xuất Excel)
- Test: `spec/system/stale_export_confirm_spec.rb`

- [ ] **Step 1: Viết Stimulus controller**

`app/javascript/controllers/stale_export_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

// Khi dữ liệu cũ (data-stale="true"), chặn click nút Xuất Excel để xác nhận trước.
// Xác nhận → thêm acknowledged_stale=1 vào URL rồi đi tiếp.
export default class extends Controller {
  static values = { stale: Boolean, message: String, url: String }

  confirm(event) {
    if (!this.staleValue) return
    event.preventDefault()
    if (window.confirm(this.messageValue)) {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("acknowledged_stale", "1")
      window.location.href = url.toString()
    }
  }
}
```

- [ ] **Step 2: Gắn vào nút Xuất Excel**

`app/views/billing/show.html.erb` — đọc file, tìm link/nút xuất Excel (link tới `billing_path(..., format: :xlsx)`). Bọc/sửa thành:
```erb
<% export_url = billing_path(request.query_parameters.merge(format: :xlsx)) %>
<%= link_to t("billing.buttons.export") , export_url,
      data: {
        controller: "stale-export",
        action: "stale-export#confirm",
        "stale-export-stale-value": @freshness_states.any? { |e| e.status == :stale },
        "stale-export-message-value": t("billing.export.stale_confirm"),
        "stale-export-url-value": export_url
      },
      class: "..." %>
```
> Giữ nguyên class/label hiện có (đọc nút cũ). Nếu khóa `billing.buttons.export` chưa có, dùng đúng khóa label nút xuất hiện tại (kiểm trong view + vi.yml). Không tạo text hard-code.

- [ ] **Step 3: Viết system spec**

`spec/system/stale_export_confirm_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Stale Excel export confirmation", type: :system do
  let(:period) { Period.current || create(:period) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }

  before { driven_by(:headless_chrome); sign_in sa } # dùng đúng helper system sẵn có

  it "CHIEU-do-tuoi-excel-confirm: asks for confirmation before exporting stale data" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
                .update!(reading_end: 88)

    visit billing_path(period_id: period.id)
    dismiss_confirm do
      click_link I18n.t("billing.buttons.export") # hoặc label nút xuất thực tế
    end
    # Bị dismiss → vẫn ở trang billing, không tải file
    expect(page).to have_current_path(/billing/)
  end
end
```
> Kiểm `spec/support` cho cấu hình Capybara/`driven_by` + helper `sign_in` cho system spec; theo mẫu trong `spec/system/`. Dùng `accept_confirm`/`dismiss_confirm` của Capybara.

Run: `bin/docker rspec spec/system/stale_export_confirm_spec.rb`
Expected: lần đầu có thể FAIL → sửa cho khớp helper thật → PASS.

- [ ] **Step 4: Chạy test xanh**

Run: `bin/docker rspec spec/system/stale_export_confirm_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/stale_export_controller.js app/views/billing/show.html.erb spec/system/stale_export_confirm_spec.rb
git commit -m "feat(billing): confirm before exporting stale data via Stimulus"
```

---

## Task 13: Phủ 6 vai trò + gating nút hành động

**Files:**
- Test: `spec/requests/freshness_roles_spec.rb`
- (Có thể) Modify: `app/views/shared/_freshness_indicator.html.erb` nếu cần phân biệt vai trò có quyền recalc.

- [ ] **Step 1: Viết request spec 6 vai trò**

`spec/requests/freshness_roles_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Freshness indicator across the six roles", type: :request do
  let(:period) { Period.current || create(:period) }
  let(:zone) { create(:zone) }
  let!(:unit) { create(:unit, zone: zone) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }

  def make_stale!
    CalculationOrchestrator.new(zone: zone, period: period).call
    MeterReading.find_by(meter_id: contact_point.meters.first.id, period_id: period.id)
                .update!(reading_end: 91)
  end

  # Map 6 vai trò → user factory traits thực tế của repo (kiểm spec/factories + V2_HANH_VI mục 1).
  roles = {
    "CHIEU-do-tuoi-vai-tro: system_admin sees stale banner" => :system_admin,
    "CHIEU-do-tuoi-vai-tro: unit_admin sees stale banner for own zone" => :unit_admin,
    "CHIEU-do-tuoi-vai-tro: commander sees stale banner (read-only)" => :commander,
    "CHIEU-do-tuoi-vai-tro: technician is blocked from billing" => :technician
  }

  it "shows stale banner to roles that can view billing; blocks TECH" do
    make_stale!
    # SA
    sign_in create(:user, :system_admin)
    get billing_path(period_id: period.id)
    expect(response.body).to include("freshness-stale")
  end

  # Bổ sung từng vai trò theo helper/traits thật. UA/UA-ZM/CMD/CMD-ZM thuộc zone →
  # thấy banner cho zone của mình; TECH bị chặn billing (redirect/403) — assert tương ứng.
end
```
> Đây là khung. Khi thực thi: đọc `spec/factories/users.rb` + `docs/V2_HANH_VI_HE_THONG.md` mục 1 để ánh xạ đúng 6 vai trò (gồm 2 biến thể manager UA-ZM, CMD-ZM). Mỗi vai trò một `it` mang anchor `CHIEU-do-tuoi-vai-tro`. CMD/CMD-ZM: chỉ xem (không nút Tính toán lại) — assert không có nút recalc (`can?(:recalculate, Calculation)` false). TECH: bị chặn trang billing.

- [ ] **Step 2: (Nếu cần) phân biệt hành động theo quyền**

Chỉ báo hiện cho mọi vai trò xem được trang. Hint "vào Bảng tính tiền bấm Tính toán lại" áp dụng chung. Không cần đổi partial trừ khi muốn ẩn hint cho vai trò không có quyền recalc — không bắt buộc cho #334. Giữ đơn giản (YAGNI).

- [ ] **Step 3: Chạy test xanh**

Run: `bin/docker rspec spec/requests/freshness_roles_spec.rb`
Expected: PASS (mọi vai trò).

- [ ] **Step 4: Commit**

```bash
git add spec/requests/freshness_roles_spec.rb app/views/shared/_freshness_indicator.html.erb
git commit -m "test(calculation-state): cover freshness indicator across the six roles"
```

---

## Task 14: Demo spec (ADR-040, customer-facing)

**Files:**
- Create: `spec/demo/freshness_demo_spec.rb`
- (Có thể) Modify: `db/seeds/demo.rb` nếu cần dữ liệu thể hiện stale.

- [ ] **Step 1: Scaffold qua generator + đọc mẫu demo có sẵn**

`develop` đã có generator `rails g demo:spec` (#352) và shared context `spec/support/shared_contexts/demo_seeded_world.rb`. Ưu tiên:
```bash
bin/docker bash -c "bin/rails g demo:spec freshness"
```
rồi đọc `spec/demo/cot_khac_he_so_don_vi_demo_spec.rb` (ví dụ demo THẬT, mới hơn `smoke_demo_spec.rb`) + `lib/generators/demo/spec/templates/demo_spec.rb.tt` + `db/seeds/demo.rb` để biết khung `DemoRecorder`, shared context seed, và zone/đầu mối seed sẵn. Dùng đúng khung generator sinh ra thay vì viết tay từ đầu (template dưới chỉ là tham chiếu nội dung kịch bản).

- [ ] **Step 2: Viết demo spec theo kịch bản spec**

`spec/demo/freshness_demo_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe "Demo: chỉ báo độ tươi dữ liệu dẫn xuất (#334)", type: :demo do
  self.use_transactional_tests = false

  before(:each) { load Rails.root.join("db", "seeds", "demo.rb") }
  after(:each) do
    [MeterReading, MainMeterReading, PersonnelEntry, OtherDeduction, UnitConfig,
     NonEstablishmentSnapshot, Calculation, PumpAllocation, CalculationState,
     Meter, ContactPoint, Block, Group, Rank, Period, Unit, MainMeter, Zone]
      .each { |m| m.unscoped.delete_all rescue nil }
    User.where(username: "demo_admin").delete_all
  end

  it "CHIEU-do-tuoi-5-trang: shows freshness going stale and the export guard" do
    demo = DemoRecorder.new(self)
    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    # ... đăng nhập demo_admin theo mẫu smoke_demo_spec ...

    demo.visit("/billing", caption: "Bảng tính tiền — bấm Tính toán lại để có kết quả mới")
    # click Tính toán lại theo selector thực tế

    demo.visit("/meter_entries", caption: "Sửa một chỉ số đầu mối")
    # điền reading_end mới + submit

    demo.visit("/billing", caption: "Chỉ báo 'cần tính lại' xuất hiện cho khu vực vừa đổi")
    expect(page).to have_css('[data-testid="freshness-stale"]')

    # Thử Xuất Excel khi cũ → hộp xác nhận (dismiss để minh hoạ)
    demo.caption("Xuất Excel khi dữ liệu cũ → hệ thống hỏi xác nhận")
    # dismiss_confirm { click_link "Xuất Excel" }

    demo.visit("/billing", caption: "Bấm Tính toán lại → chỉ báo biến mất")
    # click Tính toán lại
    expect(page).not_to have_css('[data-testid="freshness-stale"]')
  end
end
```
> Hoàn thiện các bước thao tác (selector, đăng nhập, click) theo `smoke_demo_spec.rb` + view thực tế. Mỗi bước có `caption` tiếng Việt. Anchor `CHIEU-do-tuoi-5-trang` thoả demo.

- [ ] **Step 3: Chạy demo spec**

Run: `bin/docker rspec spec/demo/freshness_demo_spec.rb`
Expected: PASS (quay video trong CI; local cần Playwright theo Dockerfile.dev — nếu môi trường local không quay được, đảm bảo ít nhất logic spec đúng; CI là nơi quay chuẩn).

- [ ] **Step 4: Commit**

```bash
git add spec/demo/freshness_demo_spec.rb db/seeds/demo.rb
git commit -m "test(demo): record freshness indicator and export guard walkthrough"
```

---

## Task 15: Glossary + chốt traceability + chạy guardrails

**Files:**
- Modify: `docs/THUAT_NGU.md`
- Verify: toàn bộ doc-governance + test-dimensions.

- [ ] **Step 1: Thêm gloss**

`docs/THUAT_NGU.md` — đọc, đối chiếu (không append mù). Thêm (nếu chưa có) định nghĩa: "độ tươi dữ liệu dẫn xuất", "stale (dữ liệu dẫn xuất cũ)", "marker (calculation_states)". Bump version + thêm entry `## Lịch sử thay đổi` của file đó (ADR-002).

- [ ] **Step 2: Chạy đối chiếu chiều test (ADR-030)**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: ✓ (mọi mã `CHIEU-do-tuoi-*` trong spec có test nhắc tới). Nếu còn mã thiếu test → bổ sung test mang đúng anchor (vd `CHIEU-do-tuoi-chua-tinh`, `CHIEU-do-tuoi-recalc-het-stale`, `CHIEU-do-tuoi-excel-stamp` — đảm bảo mọi mã trong bảng spec đã xuất hiện ở một `it`).

- [ ] **Step 3: Chạy i18n + các guardrail còn lại**

Run:
```bash
LABELS_JSON='[{"name":"customer-facing"}]' bash .github/scripts/check-view-i18n.sh || true
bash .github/scripts/check-doc-links.sh
bash .github/scripts/check-changelog-header.sh
bash .github/scripts/check-adr-status.sh
```
Expected: tất cả ✓. Sửa nếu có text view chưa i18n.

- [ ] **Step 4: Chạy toàn bộ test**

Run: `bin/docker rspec`
Expected: toàn xanh.

- [ ] **Step 5: Commit**

```bash
git add docs/THUAT_NGU.md
git commit -m "docs(glossary): define derived-data freshness terms for #334"
```

---

## Sau khi hoàn tất tất cả task

1. **Demo/nhãn:** mở PR base `develop`, **gắn nhãn `customer-facing`** (đã chốt — guardrail demo cần label + đã có `spec/demo/freshness_demo_spec.rb`).
2. **PR body:** mô tả tiếng Anh; **`Refs #334`** (KHÔNG dùng `Closes #334` trừ khi chốt đóng — đóng issue là gate người sau merge + reconcile milestone/label theo close-traceability ADR-035).
3. **Test plan trong PR:** liệt kê các `CHIEU-do-tuoi-*` + 6 vai trò + guard Excel, đánh dấu hoàn tất (ưu tiên automation).
4. **Theo dõi CI** (`gh pr checks --watch` ở background), báo pass/fail. Merge là gate người.
5. Subject commit/PR KHÔNG mở đầu bằng token chữ HOA (rule subject-case).
