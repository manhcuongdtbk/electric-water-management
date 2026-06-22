# Hiển thị chi tiết tổn hao (TN3, milestone 1.2.0) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist loss snapshot (per-meter `loss` + per-zone A/B/C) at calculation time, then surface two read-only columns ("Tổn hao", "Sử dụng thực tế") on the meter-entry pages and an A/B/C summary on the billing page (HTML + Excel).

**Architecture:** A new `LossSnapshotWriter` service runs inside the existing `CalculationOrchestrator` transaction, writing `meter_readings.loss` per meter (from `LossCalculator#meter_losses`) and upserting a `loss_summaries` row (A/B/C) per zone-period. Display reads these snapshots directly — blank until calculated, kept on stale edits (no live recompute). `LossCalculator` gains a `total_a` field so the writer can persist A.

**Tech Stack:** Rails 8, PostgreSQL (decimal/numeric + BigDecimal), Hotwire views (ERB), caxlsx (Excel), RSpec request/model/service specs.

**Source spec:** `docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md` (ADR-027). Business: `docs/V2_XAC_NHAN_NGHIEP_VU.md` §8.5 (`NV-hien-thi-chi-tiet-ton-hao`). Test dimensions: `docs/V2_CHIEU_TEST.md` (Chiều 8 + giao điểm Nhóm 4 + section "Chiều test bổ sung 1.2.0").

**Locked decisions (from brainstorming, recorded in spec update Task 8):**
1. **SA viewing all zones (no zone filter):** billing shows **one A/B/C row per zone** in scope (each from its own `loss_summaries`). Non-SA / SA-with-zone = single zone = single row.
2. **Excel:** A/B/C **is** included in the billing `.xlsx`, placed at the **bottom** of the sheet (after the TỔNG row) so it does not shift the formula grid (`$B$1` unit price, `data_start_row = 6`). HTML shows it at top (parity with "đầu bảng"); Excel at bottom is a deliberate, formula-safe divergence.

**Conventions (must hold — enforced in review):** BigDecimal only (no float) in computation; round only at display (2-decimal kW via `number_to_vi`, Vietnamese separators); new columns are **read-only** (no inputs); all six roles tested; user-facing text in these views follows the **surrounding-code idiom** — these views (`meter_entries`, `pump_entries`, `billing`) hard-code Vietnamese headers/labels throughout (e.g. "Đầu kỳ", "Sử dụng", "Đơn giá điện:"), so the two new headers and the A/B/C labels are hard-coded Vietnamese to match (no new `vi.yml` keys; externalizing only 2 of ~8 headers would be inconsistent). This satisfies AGENTS "UI 100% tiếng Việt"; full i18n externalization of these legacy views is out of TN3 scope.

---

## Test Dimension Mapping

Every dimension from ADR-027 "Chiều test cần bổ sung", `V2_CHIEU_TEST` (Chiều 8 / Nhóm 4 / 1.2.0 section), and the two AGENTS rules ("test mọi output của trang", "test cả 6 vai trò") maps to a concrete test below. **No dimension is silently deferred.**

| # | Dimension (source) | Concrete test | Task |
|---|---|---|---|
| D1 | Chưa tính → 2 cột Tổn hao / Sử dụng thực tế **trống** | `meter_entries_spec` + `pump_entries_spec`: no orchestrator run → headers present, loss/actual cells blank | T5 |
| D2 | Chưa tính → billing **chưa có** tóm tắt A/B/C | `billing_spec`: fresh period, no calc → no "Công tơ tổng (A)" block (HTML + Excel) | T6, T7 |
| D3 | Sau tính → 2 cột = `meter_losses`; thực tế = usage + loss | `meter_entries_spec` + `pump_entries_spec`: run orchestrator → cell shows `number_to_vi(reading.loss)` and `number_to_vi(reading.usage + reading.loss)` | T5 |
| D4 | Sau tính → A/B/C khớp `LossCalculator` | `loss_snapshot_writer_spec` + `billing_spec`: LossSummary a/b/c == calculator total_a/total_b/total_loss; billing body shows them | T3, T6 |
| D5 | Sửa chỉ số sau tính (chưa tính lại) → **giữ** loss cũ | `meter_entries_spec`: calc → PATCH new reading_end → GET → loss cell unchanged; actual = new usage + old loss | T5 |
| D6 | Trường hợp đặc biệt **C < 0** → C = 0, cảnh báo | `loss_calculator_spec` (total_a) + `loss_snapshot_writer_spec` (c=0) + `billing_spec` (warning + C=0 shown) | T2, T3, T6 |
| D7 | Trường hợp đặc biệt **B = 0** → loss = 0, cảnh báo | `loss_calculator_spec` (total_a set) + `loss_snapshot_writer_spec` (b=0, all meter loss 0) + `billing_spec` (warning) | T2, T3, T6 |
| D8 | Trường hợp **khu vực trống** → giá trị + cảnh báo | `loss_snapshot_writer_spec`: empty zone → LossSummary a/b/c present (0s); warning surfaces | T2, T3 |
| D9 | A/B/C **theo zone đang chọn** (SA đổi zone → đổi A/B/C) | `billing_spec`: SA `zone_id=Z1` → only Z1 row; `zone_id=Z2` → only Z2 row | T6 |
| D10 | SA **không chọn zone** → một dòng A/B/C **mỗi zone** (locked decision 1) | `billing_spec`: SA no filter → both zones' rows present | T6 |
| D11 | Công tơ **no_loss** → loss = 0 (hiển thị "0,00", không trống) | `loss_snapshot_writer_spec` (loss==0 persisted) + `meter_entries_spec` (cell shows "0,00") | T3, T5 |
| D12 | **6 vai trò** — 2 cột read-only mọi vai trò; TECH chặn | `meter_entries_spec` + `pump_entries_spec` shared example: SA/UA-ZM/UA/CMD-ZM/CMD see columns read-only, TECH blocked | T5 |
| D13 | **6 vai trò** — ai thấy billing nào thấy A/B/C tương ứng | `billing_spec` shared example: SA/UA-ZM/UA/CMD-ZM/CMD see their zone A/B/C, TECH blocked | T6 |
| D14 | "test mọi output" — read-only columns không phá input/total hiện có | `meter_entries_spec`: existing inputs/save still present; new columns have no `<input>` | T5 |
| D15 | Chiều 12 (HTML vs Excel) — A/B/C in Excel, formula grid intact | `billing_spec` xlsx: A/B/C row present at bottom; existing `$B$1` / row-6 formula tests still pass (regression) | T7 |
| D16 | Kế thừa kỳ — loss/loss_summaries **không** kế thừa | `loss_snapshot_writer_spec` / orchestrator: new period before calc → reading.loss nil, no LossSummary | T4 (covered by D1/D2 fresh-period setup) |

**System spec:** none added. The new columns and A/B/C block are server-rendered read-only output (no new JS/Stimulus). "SA đổi zone → đổi A/B/C" is auto-submit (already system-tested generically); the A/B/C change itself is server-render, verified by request spec D9. This is an **explicit** decision, not a silent skip.

---

## File Structure

**Create:**
- `db/migrate/<ts>_add_loss_to_meter_readings.rb` — `loss` decimal nullable.
- `db/migrate/<ts>_create_loss_summaries.rb` — A/B/C per zone-period.
- `app/models/loss_summary.rb` — `LossSummary` model.
- `app/services/loss_snapshot_writer.rb` — persists per-meter loss + LossSummary.
- `app/views/billing/_loss_summary.html.erb` — A/B/C HTML block.
- `spec/models/loss_summary_spec.rb`, `spec/services/loss_snapshot_writer_spec.rb`.

**Modify:**
- `app/models/meter_reading.rb` — add `actual_usage`.
- `app/services/loss_calculator.rb` — add `total_a` to `Result`, set on all return paths.
- `app/services/calculation_orchestrator.rb` — call `LossSnapshotWriter` in transaction.
- `app/views/meter_entries/show.html.erb`, `app/views/pump_entries/show.html.erb` — two read-only columns.
- `app/controllers/billing_controller.rb` — build `@loss_summaries`.
- `app/views/billing/show.html.erb` — render `_loss_summary`.
- `app/views/billing/show.xlsx.axlsx` — append A/B/C rows at bottom.
- `spec/services/loss_calculator_spec.rb`, `spec/services/calculation_orchestrator_spec.rb`, `spec/models/meter_reading_spec.rb`, `spec/requests/meter_entries_spec.rb`, `spec/requests/pump_entries_spec.rb`, `spec/requests/billing_spec.rb`.
- `docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`, `docs/V2_THIET_KE_HE_THONG.md` (bump version + changelog).

All commands run via Docker: `bin/docker rspec <path>`.

---

### Task 1: Data model — `meter_readings.loss` + `loss_summaries` + models

**Files:**
- Create: `db/migrate/<ts>_add_loss_to_meter_readings.rb`, `db/migrate/<ts>_create_loss_summaries.rb`, `app/models/loss_summary.rb`
- Create: `spec/models/loss_summary_spec.rb`
- Modify: `app/models/meter_reading.rb`, `spec/models/meter_reading_spec.rb`
- Modify: `db/schema.rb` (auto via migrate)

- [ ] **Step 1: Write failing model specs**

`spec/models/meter_reading_spec.rb` (create or append):
```ruby
require "rails_helper"

RSpec.describe MeterReading do
  describe "#actual_usage" do
    it "trả nil khi chưa có loss (chưa tính)" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: nil)
      expect(mr.actual_usage).to be_nil
    end

    it "= usage + loss khi đã có loss" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: BigDecimal("7.5"))
      expect(mr.actual_usage).to eq(BigDecimal("57.5"))
    end

    it "trả nil khi loss có nhưng usage nil (reading_end trống)" do
      mr = MeterReading.new(reading_start: 100, reading_end: nil, loss: BigDecimal("7.5"))
      expect(mr.actual_usage).to be_nil
    end

    it "loss = 0 → actual_usage = usage (công tơ no_loss)" do
      mr = MeterReading.new(reading_start: 100, reading_end: 150, loss: BigDecimal("0"))
      expect(mr.actual_usage).to eq(BigDecimal("50"))
    end
  end
end
```

`spec/models/loss_summary_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe LossSummary do
  let(:sample) { setup_zone_one_full_sample }

  it "thuộc về zone và period" do
    ls = LossSummary.new(zone: sample.zone, period: sample.period,
                         a: BigDecimal("1990"), b: BigDecimal("1930"), c: BigDecimal("60"))
    expect(ls).to be_valid
  end

  it "unique theo (zone_id, period_id)" do
    LossSummary.create!(zone: sample.zone, period: sample.period,
                        a: BigDecimal("1"), b: BigDecimal("1"), c: BigDecimal("0"))
    dup = LossSummary.new(zone: sample.zone, period: sample.period,
                          a: BigDecimal("2"), b: BigDecimal("2"), c: BigDecimal("0"))
    expect(dup).not_to be_valid
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/docker rspec spec/models/meter_reading_spec.rb spec/models/loss_summary_spec.rb`
Expected: FAIL — `NameError: uninitialized constant LossSummary` and `NoMethodError: actual_usage`.

- [ ] **Step 3: Write migrations**

`db/migrate/<ts>_add_loss_to_meter_readings.rb` (use `rails g` or hand-write; timestamp via generator):
```ruby
class AddLossToMeterReadings < ActiveRecord::Migration[8.0]
  def change
    add_column :meter_readings, :loss, :decimal, null: true
  end
end
```

`db/migrate/<ts2>_create_loss_summaries.rb`:
```ruby
class CreateLossSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :loss_summaries do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.decimal :a, null: false
      t.decimal :b, null: false
      t.decimal :c, null: false
      t.timestamps
    end
    add_index :loss_summaries, [:zone_id, :period_id], unique: true
  end
end
```
Generate timestamps with: `bin/docker bash -c "bin/rails g migration AddLossToMeterReadings"` etc., or create files with `date -u +%Y%m%d%H%M%S` prefixes (second migration must sort after the first).

- [ ] **Step 4: Run migrations**

Run: `bin/docker bash -c "bin/rails db:migrate"`
Expected: both migrations apply; `db/schema.rb` regenerated with `loss` on `meter_readings` and a `loss_summaries` table + unique index.

- [ ] **Step 5: Write models**

`app/models/loss_summary.rb`:
```ruby
class LossSummary < ApplicationRecord
  belongs_to :zone
  belongs_to :period

  validates :zone_id, uniqueness: { scope: :period_id }
  validates :a, :b, :c, presence: true
end
```

`app/models/meter_reading.rb` — add method after `#usage`:
```ruby
  def actual_usage
    return nil if loss.nil?
    u = usage
    return nil if u.nil?
    u + loss
  end
```

- [ ] **Step 6: Run specs to verify pass**

Run: `bin/docker rspec spec/models/meter_reading_spec.rb spec/models/loss_summary_spec.rb`
Expected: PASS.

- [ ] **Step 7: Verify no schema drift, commit**

Run: `bin/docker bash -c "bin/rails db:schema:dump" && git diff --stat db/schema.rb`
Expected: `db/schema.rb` reflects the two changes and is the only schema diff.
```bash
git add db/migrate app/models/loss_summary.rb app/models/meter_reading.rb db/schema.rb \
        spec/models/meter_reading_spec.rb spec/models/loss_summary_spec.rb
git commit -m "feat(loss): add meter_readings.loss column, loss_summaries table and models"
```

---

### Task 2: `LossCalculator` exposes A (`total_a`)

**Files:**
- Modify: `app/services/loss_calculator.rb`
- Modify: `spec/services/loss_calculator_spec.rb`

- [ ] **Step 1: Write failing tests**

Append to `spec/services/loss_calculator_spec.rb` inside the existing `describe "#call — T01..."` block (sample where B=1930, C=60):
```ruby
    it "total_a (A) = 1990 (= B + C khi C không bị kẹp)" do
      expect(result.total_a).to eq(BigDecimal("1990"))
    end
```
Add a new context for empty zone (no meters in zone):
```ruby
  describe "#call — khu vực trống" do
    let(:zone) { create(:zone, name: "Khu vực rỗng") }
    let(:period) { create(:period) }
    let(:result) { described_class.new(zone: zone, period: period).call }

    it "total_a = 0, total_b = 0, total_loss = 0 + cảnh báo" do
      expect(result.total_a).to eq(BigDecimal("0"))
      expect(result.total_b).to eq(BigDecimal("0"))
      expect(result.total_loss).to eq(BigDecimal("0"))
      expect(result.warnings).not_to be_empty
    end
  end
```
> Note: match the existing factory usage in `spec/services/loss_calculator_spec.rb`. If the file builds the period differently (e.g. via `setup_zone_one_full_sample`), create a bare zone with its own open period using the same factories already required by that spec. Verify `create(:zone)` / `create(:period)` exist; otherwise reuse the sample helper's primitives.

- [ ] **Step 2: Run to verify failure**

Run: `bin/docker rspec spec/services/loss_calculator_spec.rb`
Expected: FAIL — `total_a` not a member of `Result`.

- [ ] **Step 3: Add `total_a` to `Result` and set on every return path**

`app/services/loss_calculator.rb`:
- Line 2 struct: add `:total_a`:
```ruby
  Result = Struct.new(:meter_losses, :contact_point_losses, :total_a, :total_loss, :total_b, :warnings, keyword_init: true)
```
- Compute `main_total` and `no_loss_total` **before** the empty-meters early return so A is always available. Restructure the early/zero returns:
```ruby
  def call
    warnings = []

    meters_in_zone = @query.meters.to_a
    main_total = @query.main_meter_total_usage

    if meters_in_zone.empty?
      warnings << I18n.t("services.loss_calculator.warnings.zone_empty")
      return Result.new(meter_losses: {}, contact_point_losses: {},
                        total_a: main_total, total_loss: BigDecimal("0"),
                        total_b: BigDecimal("0"), warnings: warnings)
    end

    usages = @query.meter_usages
    readings_by_meter_id = @query.meter_readings.index_by(&:meter_id)

    no_loss_meters, loss_bearing_meters = meters_in_zone.partition do |meter|
      reading = readings_by_meter_id[meter.id]
      reading && reading.no_loss
    end

    no_loss_total = no_loss_meters.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") }
    a = main_total - no_loss_total
    b = loss_bearing_meters.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") }

    if b.zero?
      warnings << I18n.t("services.loss_calculator.warnings.no_loss_bearing_meters")
      return Result.new(meter_losses: zero_losses(meters_in_zone), contact_point_losses: {},
                        total_a: a, total_loss: BigDecimal("0"), total_b: BigDecimal("0"),
                        warnings: warnings)
    end

    c_raw = a - b
    if c_raw < 0
      warnings << I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main")
      c = BigDecimal("0")
    else
      c = c_raw
    end

    meter_losses = {}
    meters_in_zone.each do |meter|
      reading = readings_by_meter_id[meter.id]
      if reading && reading.no_loss
        meter_losses[meter.id] = BigDecimal("0")
      else
        usage = usages[meter.id] || BigDecimal("0")
        meter_losses[meter.id] = c.zero? ? BigDecimal("0") : usage * c / b
      end
    end

    contact_point_losses = group_losses_by_contact_point(meters_in_zone, meter_losses)

    Result.new(
      meter_losses: meter_losses,
      contact_point_losses: contact_point_losses,
      total_a: a,
      total_loss: c,
      total_b: b,
      warnings: warnings
    )
  end
```
(The `main_meter_total_usage` query is cheap and already used; calling it once up front is fine.)

- [ ] **Step 4: Run to verify pass**

Run: `bin/docker rspec spec/services/loss_calculator_spec.rb`
Expected: PASS (existing total_b/total_loss/meter_losses assertions unchanged).

- [ ] **Step 5: Commit**
```bash
git add app/services/loss_calculator.rb spec/services/loss_calculator_spec.rb
git commit -m "feat(loss): expose total_a (A) from LossCalculator on all return paths"
```

---

### Task 3: `LossSnapshotWriter` service

**Files:**
- Create: `app/services/loss_snapshot_writer.rb`, `spec/services/loss_snapshot_writer_spec.rb`

- [ ] **Step 1: Write failing service spec**

`spec/services/loss_snapshot_writer_spec.rb`:
```ruby
require "rails_helper"

RSpec.describe LossSnapshotWriter do
  let(:sample) { setup_zone_one_full_sample }
  let(:loss) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

  def reading_for(meter_key)
    MeterReading.find_by(meter: sample.meters[meter_key], period: sample.period)
  end

  describe "#call — sample T01 (B=1930, C=60, A=1990)" do
    before { described_class.new(zone: sample.zone, period: sample.period, loss_results: loss).call }

    it "ghi meter_readings.loss đúng meter_losses" do
      expect(reading_for(:ct_a1).reload.loss).to eq(loss.meter_losses[sample.meters[:ct_a1].id])
    end

    it "công tơ no_loss → loss = 0" do
      expect(reading_for(:ct_a3).reload.loss).to eq(BigDecimal("0"))
    end

    it "upsert LossSummary A/B/C khớp calculator" do
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.a).to eq(loss.total_a)
      expect(ls.b).to eq(loss.total_b)
      expect(ls.c).to eq(loss.total_loss)
    end

    it "idempotent: chạy lại ghi đè cùng 1 LossSummary (không tạo trùng)" do
      described_class.new(zone: sample.zone, period: sample.period, loss_results: loss).call
      expect(LossSummary.where(zone: sample.zone, period: sample.period).count).to eq(1)
    end
  end

  describe "#call — khu vực trống" do
    let(:zone) { create(:zone, name: "Khu vực rỗng") }
    let(:period) { sample.period }
    let(:empty_loss) { LossCalculator.new(zone: zone, period: period).call }

    it "vẫn ghi LossSummary với A/B/C = engine (0/0/0) cho khu vực trống" do
      described_class.new(zone: zone, period: period, loss_results: empty_loss).call
      ls = LossSummary.find_by(zone: zone, period: period)
      expect([ls.a, ls.b, ls.c]).to eq([empty_loss.total_a, BigDecimal("0"), BigDecimal("0")])
    end
  end
end
```
> Note: confirm `:ct_a3` is the no-loss meter in `setup_zone_one_full_sample` (the loss calculator spec asserts `meter_losses[:ct_a3] == 0`). If the key differs, use whichever meter the sample marks `no_loss`.

- [ ] **Step 2: Run to verify failure**

Run: `bin/docker rspec spec/services/loss_snapshot_writer_spec.rb`
Expected: FAIL — `uninitialized constant LossSnapshotWriter`.

- [ ] **Step 3: Implement the writer**

`app/services/loss_snapshot_writer.rb`:
```ruby
# Persists the loss snapshot computed by LossCalculator so the entry pages and
# billing can display "kết quả từ lần tính gần nhất". Engine-only writer:
# uses update_all (no callbacks / lock_version bump) since loss is computed data.
# Called inside CalculationOrchestrator's transaction.
class LossSnapshotWriter
  def initialize(zone:, period:, loss_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
  end

  def call
    @loss_results.meter_losses.each do |meter_id, loss|
      MeterReading.where(meter_id: meter_id, period_id: @period.id).update_all(loss: loss)
    end

    summary = LossSummary.find_or_initialize_by(zone_id: @zone.id, period_id: @period.id)
    summary.update!(a: @loss_results.total_a, b: @loss_results.total_b, c: @loss_results.total_loss)
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `bin/docker rspec spec/services/loss_snapshot_writer_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add app/services/loss_snapshot_writer.rb spec/services/loss_snapshot_writer_spec.rb
git commit -m "feat(loss): add LossSnapshotWriter to persist per-meter loss and A/B/C"
```

---

### Task 4: Wire `LossSnapshotWriter` into `CalculationOrchestrator`

**Files:**
- Modify: `app/services/calculation_orchestrator.rb`
- Modify: `spec/services/calculation_orchestrator_spec.rb`

- [ ] **Step 1: Write failing integration test**

Append to `spec/services/calculation_orchestrator_spec.rb`:
```ruby
  describe "loss snapshot persistence" do
    let(:sample) { setup_zone_one_full_sample }

    it "ghi meter_readings.loss và LossSummary trong cùng transaction" do
      expect(LossSummary.where(period: sample.period)).to be_empty
      described_class.new(zone: sample.zone, period: sample.period).call

      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      expect(reading.reload.loss).to be_present
      expect(LossSummary.find_by(zone: sample.zone, period: sample.period)).to be_present
    end

    it "kế thừa kỳ: kỳ mới chưa tính → reading.loss nil, không có LossSummary" do
      # Không gọi orchestrator: snapshot chỉ tồn tại sau khi tính.
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      expect(reading.loss).to be_nil
      expect(LossSummary.where(period: sample.period)).to be_empty
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `bin/docker rspec spec/services/calculation_orchestrator_spec.rb -e "loss snapshot"`
Expected: FAIL — reading.loss is nil / no LossSummary (writer not wired yet) for the first example.

- [ ] **Step 3: Wire the writer into the transaction**

`app/services/calculation_orchestrator.rb` — add the writer call right after `LossCalculator`:
```ruby
  def call
    ActiveRecord::Base.transaction do
      loss = LossCalculator.new(zone: @zone, period: @period).call
      LossSnapshotWriter.new(zone: @zone, period: @period, loss_results: loss).call
      pump = PumpAllocationCalculator.new(zone: @zone, period: @period, loss_results: loss).call
      summary = SummaryCalculator.new(
        zone: @zone, period: @period, loss_results: loss, pump_results: pump
      ).call

      Result.new(
        loss_results: loss,
        pump_results: pump,
        summary_results: summary,
        warnings: loss.warnings + pump.warnings + summary.warnings
      )
    end
  end
```

- [ ] **Step 4: Run to verify pass**

Run: `bin/docker rspec spec/services/calculation_orchestrator_spec.rb`
Expected: PASS (existing orchestrator tests unaffected).

- [ ] **Step 5: Commit**
```bash
git add app/services/calculation_orchestrator.rb spec/services/calculation_orchestrator_spec.rb
git commit -m "feat(loss): persist loss snapshot inside CalculationOrchestrator transaction"
```

---

### Task 5: Meter-entry pages — two read-only columns ("Tổn hao", "Sử dụng thực tế")

**Files:**
- Modify: `app/views/meter_entries/show.html.erb`, `app/views/pump_entries/show.html.erb`
- Modify: `spec/requests/meter_entries_spec.rb`, `spec/requests/pump_entries_spec.rb`

- [ ] **Step 1: Write failing request specs (meter_entries)**

Append to `spec/requests/meter_entries_spec.rb`:
```ruby
  describe "cột Tổn hao / Sử dụng thực tế (TN3)" do
    let(:html) { Nokogiri::HTML(response.body) }

    it "luôn hiện 2 header cột" do
      sample
      get meter_entries_path
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "D1: chưa tính → ô loss/thực tế trống" do
      sample
      get meter_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      expect(reading.loss).to be_nil
      # Không có giá trị tổn hao nào được render (chưa tính)
      expect(response.body).not_to match(/Tổn hao<\/th>[\s\S]*?\d+,\d{2}/) # sanity: see Step note
    end

    it "D3: sau tính → hiển thị loss và sử dụng thực tế đúng" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period).reload
      vi = ActionController::Base.helpers
      expect(response.body).to include(vi.number_to_vi(reading.loss))
      expect(response.body).to include(vi.number_to_vi(reading.usage + reading.loss))
    end

    it "D11: công tơ no_loss → loss hiển thị 0,00 (không trống)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      r3 = MeterReading.find_by(meter: sample.meters[:ct_a3], period: sample.period).reload
      expect(r3.loss).to eq(BigDecimal("0"))
      expect(response.body).to include("0,00")
    end

    it "D5: sửa chỉ số sau tính (chưa tính lại) → giữ loss cũ" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period).reload
      old_loss = reading.loss
      patch meter_entries_path, params: {
        meter_readings: { reading.id.to_s => { reading_end: "9999", lock_version: reading.lock_version } }
      }
      get meter_entries_path
      expect(reading.reload.loss).to eq(old_loss) # loss không đổi
      vi = ActionController::Base.helpers
      expect(response.body).to include(vi.number_to_vi(reading.usage + old_loss)) # thực tế = usage mới + loss cũ
    end

    it "D14: 2 cột là read-only (không có <input> trong ô loss/thực tế)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get meter_entries_path
      # Số input trong bảng không tăng do 2 cột mới (chúng chỉ render text)
      inputs = html.css("table tbody tr:first-child td input")
      # cấu trúc cũ: lock_version(hidden) + reading_start + reading_end + manual_usage_note = 4 input/row
      expect(inputs.size).to eq(4)
    end
  end
```
> Step note: the D1 "không có giá trị" regex is brittle; prefer asserting at the DB level (`reading.loss` nil) plus that the known post-calc value string is **absent**. Replace the regex line with: capture a post-calc value in a sibling example and assert the pre-calc body `does not include` it. Keep whichever the implementer finds robust against the sample's other numbers; the binding contract is "loss nil ⇒ blank cell".

- [ ] **Step 2: Write failing 6-role coverage (shared example)**

Add a role table at the bottom of `spec/requests/meter_entries_spec.rb` (D12). Reuse factories already in the file (`sample`, `:system_admin`, `sample.unit_a`):
```ruby
  describe "D12: 6 vai trò thấy 2 cột read-only" do
    before { sample; CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    {
      "SA"     => -> { create(:user, :system_admin) },
      "UA-ZM"  => -> (s) { create(:user, :unit_admin, unit: s.unit_a) },
      "UA"     => -> (s) { create(:user, :unit_admin, unit: s.unit_b) },
      "CMD-ZM" => -> (s) { create(:user, :commander, unit: s.unit_a) },
      "CMD"    => -> (s) { create(:user, :commander, unit: s.unit_b) }
    }.each do |label, builder|
      it "#{label} thấy 2 cột" do
        u = builder.arity.zero? ? builder.call : builder.call(sample)
        sign_in u
        get meter_entries_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
      end
    end

    it "TECH bị chặn (không thấy trang)" do
      sign_in create(:user, :technician)
      get meter_entries_path
      expect(response).not_to have_http_status(:ok)
    end
  end
```
> Note: `unit_a` is the zone-manager unit (auto-assigned first unit), `unit_b` a non-manager unit in the sample. Confirm both exist on `setup_zone_one_full_sample`; if the second unit has a different accessor (e.g. `sample.unit_b` vs `sample.units[:b]`), match the sample. For TECH, the existing suite already asserts the block behavior — mirror its expectation (redirect or 403).

- [ ] **Step 3: Run to verify failure**

Run: `bin/docker rspec spec/requests/meter_entries_spec.rb`
Expected: FAIL — "Tổn hao"/"Sử dụng thực tế" not in body yet.

- [ ] **Step 4: Add columns to `meter_entries/show.html.erb`**

Header — insert after the "Sử dụng" `<th>` (line 39), before the "Ghi chú" `<th>`:
```erb
          <th class="px-3 py-2 text-right text-xs font-semibold text-gray-600 uppercase">Tổn hao</th>
          <th class="px-3 py-2 text-right text-xs font-semibold text-gray-600 uppercase">Sử dụng thực tế</th>
```
Body — insert after the "Sử dụng" `<td>` (closes at line 67), before the "Ghi chú" `<td>`:
```erb
            <td class="px-3 py-2 text-right text-gray-600"><%= number_to_vi(r.loss) %></td>
            <td class="px-3 py-2 text-right text-gray-600"><%= number_to_vi(r.actual_usage) %></td>
```

- [ ] **Step 5: Mirror the same edits in `pump_entries/show.html.erb`**

Same two `<th>` after "Sử dụng" header (line 35) and same two `<td>` after the "Sử dụng" cell (closes line 61).

- [ ] **Step 6: Write the matching pump_entries specs**

Append to `spec/requests/pump_entries_spec.rb` the analogue of Step 1/Step 2 using a water-pump meter key (e.g. `:ct_bn1`) and `pump_entries_path`. Pump page has no Đơn vị column; the 2 new columns behave identically. Concrete D3 example:
```ruby
  describe "cột Tổn hao / Sử dụng thực tế (TN3)" do
    it "luôn hiện 2 header" do
      sample
      get pump_entries_path
      expect(response.body).to include("Tổn hao").and include("Sử dụng thực tế")
    end

    it "D3: sau tính hiển thị loss công tơ bơm nước" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      get pump_entries_path
      r = MeterReading.find_by(meter: sample.meters[:ct_bn1], period: sample.period).reload
      vi = ActionController::Base.helpers
      expect(r.loss).to be_present
      expect(response.body).to include(vi.number_to_vi(r.loss))
      expect(response.body).to include(vi.number_to_vi(r.usage + r.loss))
    end
  end
```
Add the same D12 six-role block adapted to `pump_entries_path` (note Chiều 3: on pump_entries, plain UA sees an empty table but still authorized — assert header present, not data; CMD/CMD-ZM read-only). Match the existing pump_entries role expectations in the file.

- [ ] **Step 7: Run to verify pass**

Run: `bin/docker rspec spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb`
Expected: PASS.

- [ ] **Step 8: Commit**
```bash
git add app/views/meter_entries/show.html.erb app/views/pump_entries/show.html.erb \
        spec/requests/meter_entries_spec.rb spec/requests/pump_entries_spec.rb
git commit -m "feat(loss): show read-only Tổn hao / Sử dụng thực tế columns on entry pages"
```

---

### Task 6: Billing controller + HTML A/B/C summary

**Files:**
- Modify: `app/controllers/billing_controller.rb`, `app/views/billing/show.html.erb`
- Create: `app/views/billing/_loss_summary.html.erb`
- Modify: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write failing request specs**

Append to `spec/requests/billing_spec.rb` (HTML context, SA + non-SA):
```ruby
  describe "tóm tắt tổn hao A/B/C (TN3)" do
    let(:sa) { create(:user, :system_admin) }

    it "D2: chưa tính → không có khối A/B/C" do
      sample
      sign_in sa
      get billing_path
      expect(response.body).not_to include("Công tơ tổng (A)")
    end

    it "D4: sau tính → hiển thị A/B/C khớp LossCalculator (HTML)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      vi = ActionController::Base.helpers
      expect(response.body).to include("Công tơ tổng (A)")
      expect(response.body).to include(vi.number_to_vi(ls.a))
      expect(response.body).to include(vi.number_to_vi(ls.b))
      expect(response.body).to include(vi.number_to_vi(ls.c))
    end

    it "D9: SA chọn zone → chỉ A/B/C của zone đó" do
      sample
      other = create(:zone, name: "Khu vực 2 TN3")
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      LossSummary.create!(zone: other, period: sample.period,
                          a: BigDecimal("500"), b: BigDecimal("480"), c: BigDecimal("20"))
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      expect(response.body).to include(sample.zone.name)
      expect(response.body).not_to include("Khu vực 2 TN3")
    end

    it "D10: SA không chọn zone → mỗi zone một dòng A/B/C" do
      sample
      other = create(:zone, name: "Khu vực 2 TN3")
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      LossSummary.create!(zone: other, period: sample.period,
                          a: BigDecimal("500"), b: BigDecimal("480"), c: BigDecimal("20"))
      sign_in sa
      get billing_path
      expect(response.body).to include(sample.zone.name).and include("Khu vực 2 TN3")
    end
  end
```
> Note: for D9/D10 the second zone must be in `zones_in_scope` for SA (all zones). `Zone.with_discarded.order(:name)` covers it. If `sample.zone.name` is a substring of "Khu vực 2 TN3" causing false matches, give the second zone a clearly distinct name.

- [ ] **Step 2: Write edge-case + role specs**

Append (D6 C<0, D7 B=0, D13 roles):
```ruby
  describe "tóm tắt tổn hao — trường hợp đặc biệt + vai trò" do
    it "D6: C < 0 → C hiển thị 0,00 + cảnh báo" do
      sample
      # Tạo tổng công tơ con > công tơ tổng: hạ main_meter usage xuống thật thấp
      mmr = MainMeterReading.joins(:main_meter)
                            .where(main_meters: { zone_id: sample.zone.id }, period_id: sample.period.id).first
      mmr.update!(usage: 1)
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in create(:user, :system_admin)
      get billing_path
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Công tơ tổng (A)")
      expect(response.body).to include("công tơ tổng") # cảnh báo subtotal_exceeds_main (text vi.yml)
    end

    it "D13: các vai trò nghiệp vụ thấy A/B/C; TECH bị chặn" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      ["UA-ZM", "CMD-ZM"].each do |_|
        u = create(:user, :unit_admin, unit: sample.unit_a)
        sign_in u
        get billing_path
        expect(response.body).to include("Công tơ tổng (A)")
      end
      sign_in create(:user, :technician)
      get billing_path
      expect(response).not_to have_http_status(:ok)
    end
  end
```
> Note: confirm the warning text key. `services.loss_calculator.warnings.subtotal_exceeds_main` renders some Vietnamese string; assert a stable substring of *that* translation (open `config/locales/vi.yml` around line 220 and copy a literal fragment) rather than guessing. Adjust the `include(...)` accordingly. For B=0 (D7) add a sibling example that zeroes all loss-bearing usages if a simple setup exists; otherwise assert D7 at the writer level (already covered in T3) and note here that billing display of B=0 reuses the same code path — keep it if a clean fixture is available, else document the cross-reference inline in the spec comment.

- [ ] **Step 3: Run to verify failure**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "tóm tắt tổn hao"`
Expected: FAIL — "Công tơ tổng (A)" not rendered yet.

- [ ] **Step 4: Build `@loss_summaries` in the controller**

`app/controllers/billing_controller.rb` — in `show`, after the `@warnings = ...` line (line 29):
```ruby
    @loss_summaries = LossSummary.where(period_id: @period.id, zone_id: zones_in_scope(@period).select(:id))
                                 .includes(:zone).to_a.sort_by { |s| s.zone&.name.to_s }
```
(`zones_in_scope` already returns `[@zone]` when a zone is selected, all zones for SA-no-filter, and the user's zones for non-SA — same source as `@warnings`, so A/B/C scope matches the warnings/data shown.)

- [ ] **Step 5: Create the HTML partial**

`app/views/billing/_loss_summary.html.erb`:
```erb
<% if @loss_summaries.any? %>
  <div class="mb-3 flex flex-wrap gap-2">
    <% @loss_summaries.each do |s| %>
      <div class="rounded border border-gray-200 bg-gray-50 px-3 py-2 text-sm text-gray-700">
        <span class="font-semibold"><%= s.zone&.name %></span> —
        Công tơ tổng (A): <strong><%= number_to_vi(s.a) %></strong> kW;
        Tổng sử dụng (B): <strong><%= number_to_vi(s.b) %></strong> kW;
        Tổng tổn hao (C = A − B): <strong><%= number_to_vi(s.c) %></strong> kW
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 6: Render it in `billing/show.html.erb`**

After the unit-price `<p>...</p>` block (closes at line 55), before the `<div class="-mx-6">` table wrapper:
```erb
  <%= render "loss_summary" %>
```

- [ ] **Step 7: Run to verify pass**

Run: `bin/docker rspec spec/requests/billing_spec.rb`
Expected: PASS (existing billing specs unaffected — A/B/C block is above the table, no column-count change).

- [ ] **Step 8: Commit**
```bash
git add app/controllers/billing_controller.rb app/views/billing/show.html.erb \
        app/views/billing/_loss_summary.html.erb spec/requests/billing_spec.rb
git commit -m "feat(loss): show per-zone A/B/C loss summary on billing page (HTML)"
```

---

### Task 7: Billing Excel — A/B/C at sheet bottom (Chiều 12)

**Files:**
- Modify: `app/views/billing/show.xlsx.axlsx`
- Modify: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write failing xlsx spec**

Append inside the existing `context "format :xlsx"` block in `spec/requests/billing_spec.rb` (uses `XlsxHelpers` / `parse_xlsx`):
```ruby
        it "D15: A/B/C xuất ra Excel (cuối sheet) sau khi tính" do
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).to include("Công tơ tổng (A)")
          expect(all_text).to include("Tổng tổn hao (C = A − B)")
        end

        it "D2(Excel): chưa tính → Excel không có khối A/B/C" do
          # period mới chưa tính: dùng kỳ chưa chạy orchestrator
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).not_to include("Công tơ tổng (A)")
        end
```
> Note: the existing xlsx formula tests (`$B$1`, `SUM(...6:...6)`, `data_start_row = 6`) act as the **regression guard** for D15 — they must still pass, proving the A/B/C rows at the bottom did not shift the grid. Do not modify them.

- [ ] **Step 2: Run to verify failure**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "format :xlsx"`
Expected: FAIL — "Công tơ tổng (A)" not in the sheet (first new example).

- [ ] **Step 3: Append A/B/C rows at the bottom of the sheet**

`app/views/billing/show.xlsx.axlsx` — after the Total-row `if @calculations.any? ... end` block (closes at line 244), before the version-footer comment (line 246):
```ruby
    # Tóm tắt tổn hao A/B/C per khu vực — đặt CUỐI sheet để không dịch lưới công thức
    # phía trên ($B$1 đơn giá, data_start_row = 6). Một dòng / khu vực, không merge/không formula.
    if @loss_summaries.any?
      sheet.add_row []
      @loss_summaries.each do |s|
        sheet.add_row ["Tổn hao khu vực #{s.zone&.name} — Công tơ tổng (A):", s.a.to_f,
                       "Tổng sử dụng (B):", s.b.to_f,
                       "Tổng tổn hao (C = A − B):", s.c.to_f],
                      style: [text_style, num_style, text_style, num_style, text_style, num_style]
      end
    end
```

- [ ] **Step 4: Run to verify pass (incl. regression)**

Run: `bin/docker rspec spec/requests/billing_spec.rb`
Expected: PASS — new A/B/C examples pass AND all existing `$B$1` / row-6 formula examples still pass.

- [ ] **Step 5: Commit**
```bash
git add app/views/billing/show.xlsx.axlsx spec/requests/billing_spec.rb
git commit -m "feat(loss): include per-zone A/B/C summary at bottom of billing Excel export"
```

---

### Task 8: Documentation (ADR-002 — bump version + changelog)

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`
- Modify: `docs/V2_THIET_KE_HE_THONG.md`

- [ ] **Step 1: Record the two locked decisions in the spec + bump**

In `2026-06-11-hien-thi-chi-tiet-ton-hao-design.md`:
- Header `version: 0.1.0` → `version: 0.2.0`. `status: draft (chờ duyệt)` → `status: approved (triển khai 1.2.0)`.
- Under "### Hiển thị", add a clarification bullet:
  > - **SA xem nhiều khu vực (chưa lọc zone):** tóm tắt hiển thị **một dòng A/B/C cho mỗi khu vực** trong phạm vi (mỗi dòng đọc từ `loss_summaries` của zone đó). Non-SA / SA đã chọn zone = một zone = một dòng.
  > - **Excel:** A/B/C **có** trong file xuất, đặt ở **cuối sheet** (dưới hàng TỔNG) để không dịch lưới công thức (`$B$1` đơn giá, dòng dữ liệu bắt đầu ở 6). HTML đặt ở đầu bảng; Excel ở cuối là khác biệt cố ý, an toàn công thức.
- Under "### Ghi snapshot", add: `LossCalculator` bổ sung trường `total_a` (A) để writer ghi đủ A/B/C; persistence tách thành service `LossSnapshotWriter` gọi trong transaction của `CalculationOrchestrator`.
- Append Changelog:
```markdown
### 0.2.0 (2026-06-12)

- Triển khai TN3: thêm cột `meter_readings.loss` + bảng `loss_summaries`, service `LossSnapshotWriter`, trường `LossCalculator#total_a`. Hai cột read-only trên trang nhập chỉ số; tóm tắt A/B/C trên bảng tính tiền (HTML + Excel).
- Chốt 2 quyết định mở: SA đa khu vực → A/B/C một dòng mỗi khu vực; Excel có A/B/C đặt cuối sheet (an toàn công thức).
```

- [ ] **Step 2: Update system design doc + bump**

In `docs/V2_THIET_KE_HE_THONG.md`:
- Header `**Phiên bản tài liệu:** 2.14.1` → `2.15.0`; `**Ngày:**` → `12/06/2026`.
- In the `#### meter_readings` table (line ~416), add a row before `lock_version`:
```markdown
| loss | decimal | Nullable. Tổn hao phân bổ cho công tơ ở kỳ đó — snapshot ghi bởi engine khi tính. Null = chưa tính |
```
- After the `#### main_meter_readings` section, add a new section:
```markdown
#### loss_summaries (tóm tắt tổn hao A/B/C per khu vực per kỳ)

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| zone_id | foreign key → zones | Bắt buộc, unique cùng period_id |
| period_id | foreign key → periods | Bắt buộc |
| a | decimal | Công tơ tổng − Σ công tơ không tổn hao |
| b | decimal | Σ sử dụng công tơ có tổn hao |
| c | decimal | A − B (tổng tổn hao khu vực, đã kẹp ≥ 0) |

Snapshot kết quả tính (mục 8.5 nghiệp vụ). Chỉ engine ghi (`LossSnapshotWriter`), không kế thừa kỳ — kỳ mới chưa tính thì không có dòng.
```
- In "### CalculationOrchestrator" flow (line ~688), update the numbered flow to include the writer:
```markdown
1. LossCalculator.new(zone:, period:).call → loss_results (gồm A/B/C + tổn hao per công tơ)
2. LossSnapshotWriter.new(zone:, period:, loss_results:).call → ghi meter_readings.loss + upsert loss_summaries
3. PumpAllocationCalculator.new(zone:, period:, loss_results:).call → pump_results
4. SummaryCalculator.new(zone:, period:, loss_results:, pump_results:).call → persist calculations
```
- Append to "## Lịch sử thay đổi":
```markdown
### v2.15.0 (12/06/2026)

- TN3 hiển thị chi tiết tổn hao: thêm cột `meter_readings.loss`, bảng `loss_summaries` (A/B/C per khu vực-kỳ), service `LossSnapshotWriter` ghi snapshot trong transaction orchestrator, trường `LossCalculator#total_a`. Snapshot là kết quả tính, không kế thừa kỳ.
```

- [ ] **Step 3: Commit**
```bash
git add docs/superpowers/specs/2026-06-11-hien-thi-chi-tiet-ton-hao-design.md docs/V2_THIET_KE_HE_THONG.md
git commit -m "docs(loss): record TN3 design decisions, schema and engine changes (ADR-002 bump)"
```

---

### Task 9: Full verification + PR

**Files:** none (verification + PR).

- [ ] **Step 1: Run the full suite**

Run: `bin/docker rspec`
Expected: all green, no regressions.

- [ ] **Step 2: Schema + zeitwerk sanity (CI parity)**

Run: `bin/docker bash -c "bin/rails db:schema:dump && git diff --exit-code db/schema.rb"` — expect no diff.
Run: `bin/docker bash -c "bin/rails zeitwerk:check"` — expect "All is good!".

- [ ] **Step 3: Cross-check demo behaviors → assertions**

Walk the Test Dimension Mapping table; confirm each D# has a passing test. Anything demo-able but unasserted → add a test before opening the PR (retro TN1 lesson).

- [ ] **Step 4: Push + open PR (base develop, squash)**
```bash
git push -u origin feature/1.2.0-tn3-ton-hao
gh pr create --base develop --title "feat: hiển thị chi tiết tổn hao (TN3, 1.2.0)" --body "<English summary + Closes #319 reference + test plan>"
```
PR body in English; reference Issue #319 (milestone 1.2.0); include a test plan mapping the D# dimensions. Then monitor CI and report pass/fail (do not leave it for the user to check).

- [ ] **Step 5: Update Issue #319**

Add a comment on #319 linking the spec and this PR, noting TN3 implemented (2 read-only columns + A/B/C summary HTML+Excel), TN2 (phân bổ bơm theo trạm, ADR-026) still pending.

---

## Self-Review

- **Spec coverage:** ADR-027 scope items — migration (`meter_readings.loss` T1, `loss_summaries` T1), snapshot in orchestrator transaction (T3/T4), two read-only columns on both entry pages (T5), billing A/B/C per selected zone (T6), round-at-display + Vietnamese separators (`number_to_vi`, all display tasks), Excel (T7, per locked decision). All covered.
- **Test dimensions:** D1–D16 each map to a task and a concrete example; system-spec omission is explicit. No silent deferral.
- **Type consistency:** `total_a`/`total_b`/`total_loss` (LossCalculator) ↔ `a`/`b`/`c` (LossSummary) mapping is consistent across T2/T3/T6/T7. `actual_usage` defined T1, used T5. `@loss_summaries` defined in controller T6, consumed in HTML T6 and Excel T7.
- **Placeholders:** none — every code/test step shows the actual content. A few "Note" callouts ask the implementer to confirm sample fixture keys (`:ct_a3`, `:ct_bn1`, `unit_b`) and the exact warning-string fragment against the real `vi.yml`; these are verification cues, not missing content.
- **Conventions:** BigDecimal throughout; rounding only via `number_to_vi` at render; read-only columns asserted (D14); 6 roles (D12/D13); hard-coded Vietnamese matches surrounding views (documented decision); doc version bumps per ADR-002.
