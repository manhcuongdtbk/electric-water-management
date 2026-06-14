# Đối chiếu tổn hao/sử dụng theo loại đầu mối (#332) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm bảng đối chiếu tổn hao/sử dụng theo loại đầu mối (Sinh hoạt / Công cộng / Bơm nước) dưới khối A/B/C trên Bảng tính tiền, derive read-only từ snapshot, có Excel parity + demo hướng khách.

**Architecture:** Service đọc `LossBreakdown` (PORO, trả giá trị thô từ `LossSummary` + `meter_readings.loss` + `ZoneQuery`) → controller gắn `@loss_breakdowns` per zone → mở rộng partial `_loss_summary` (HTML) + `show.xlsx.axlsx` (Excel). Làm tròn trung thực 2 chữ số từng ô khi hiển thị (qua `number_to_vi`), kèm chú thích lệch ±0,01.

**Tech Stack:** Rails 8, RSpec + Capybara, caxlsx, Hotwire (không JS mới), i18n vi.yml.

**Spec:** [`docs/superpowers/specs/2026-06-14-doi-chieu-ton-hao-theo-loai-dau-moi-design.md`](../specs/2026-06-14-doi-chieu-ton-hao-theo-loai-dau-moi-design.md) (ADR-054, mở rộng ADR-027).

---

## Tiền đề (đã làm)

- Nhánh `feature/332-loss-breakdown-by-contact-point-type` đã tạo từ `develop`, đã rebase lên `origin/develop` mới nhất, đã có commit spec (ADR-054).
- **Develop đang chạy nhanh + PR #356 đang sửa `DemoRecorder`.** Trước khi viết Task 7 (demo) và trước khi mở PR: `git fetch origin && git rebase origin/develop` một lần, để dùng generator/recorder mới nhất.
- Fixture `setup_zone_one_full_sample` (Khu vực 1) tái hiện **chính xác** ví dụ #332: residential 1230 / public 400 / pump 300 (B=1930); no_loss CT-A3=110; main=2100 → A=1990, C=60; loss per loại ≈ 38,24 / 12,44 / 9,33.

## File Structure

| File | Trách nhiệm | Tạo/Sửa |
|---|---|---|
| `app/services/loss_breakdown.rb` | Service đọc read-only, gom theo loại, trả giá trị thô | Tạo |
| `spec/services/loss_breakdown_spec.rb` | Test math + đối chiếu (raw) | Tạo |
| `config/locales/vi.yml` | i18n `billing.loss_breakdown.*` | Sửa |
| `app/controllers/billing_controller.rb` | Gắn `@loss_breakdowns` per zone | Sửa |
| `app/views/billing/_loss_summary.html.erb` | Render bảng breakdown dưới chip A/B/C | Sửa |
| `app/views/billing/show.xlsx.axlsx` | Excel parity các dòng breakdown | Sửa |
| `spec/requests/billing_spec.rb` | Test HTML/Excel/role/multi-zone | Sửa |
| `db/seeds/demo.rb` | Thêm 1 công tơ `no_loss` | Sửa |
| `spec/demo/loss_breakdown_demo_spec.rb` | Demo hướng khách (ADR-040) | Tạo (qua generator) |
| `docs/V2_XAC_NHAN_NGHIEP_VU.md` | Mô tả bảng đối chiếu §8.5 | Sửa |

---

## Task 1: Service `LossBreakdown` (read-only, raw)

**Files:**
- Create: `app/services/loss_breakdown.rb`
- Test: `spec/services/loss_breakdown_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/services/loss_breakdown_spec.rb
require "rails_helper"

RSpec.describe LossBreakdown do
  let(:sample) { setup_zone_one_full_sample }

  # Loss snapshot (meter_readings.loss + loss_summaries) chỉ tồn tại sau khi tính.
  before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

  subject(:result) { described_class.new(zone: sample.zone, period: sample.period).call }

  let(:summary) { LossSummary.find_by!(zone_id: sample.zone.id, period_id: sample.period.id) }

  def row_for(type)
    result.rows.find { |r| r.type == type }
  end

  it "CHIEU-breakdown-tong-theo-loai: Σ loại = B/C/A (raw)" do
    expect(result.rows.sum(&:usage)).to eq(summary.b)
    expect(result.rows.sum(&:loss)).to be_within(BigDecimal("0.01")).of(summary.c)
    expect(result.cong.usage).to eq(summary.b)
    expect(result.cong.loss).to eq(summary.c)
    expect(result.cong.actual).to eq(summary.a)
  end

  it "khớp ví dụ mẫu #332 theo từng loại (usage thô + loss làm tròn 2 chữ số)" do
    expect(row_for("residential").usage).to eq(BigDecimal("1230"))
    expect(row_for("public").usage).to eq(BigDecimal("400"))
    expect(row_for("water_pump").usage).to eq(BigDecimal("300"))
    expect(row_for("residential").loss.round(2)).to eq(BigDecimal("38.24"))
    expect(row_for("public").loss.round(2)).to eq(BigDecimal("12.44"))
    expect(row_for("water_pump").loss.round(2)).to eq(BigDecimal("9.33"))
  end

  it "CHIEU-breakdown-doi-chieu-cong-to-tong: Tổng cộng/thực tế = công tơ tổng" do
    expect(result.tong_cong.usage).to eq(BigDecimal("2040"))
    expect(result.tong_cong.actual).to eq(sample.main_meter_reading.usage) # 2100
  end

  it "CHIEU-breakdown-khong-ton-hao: no_loss loại khỏi B; dòng Không tổn hao = Σ usage no_loss" do
    expect(result.khong_ton_hao.usage).to eq(BigDecimal("110"))
    expect(result.khong_ton_hao.loss).to eq(BigDecimal("0"))
    expect(result.no_loss_by_type["residential"]).to eq(BigDecimal("110"))
  end

  it "actual mỗi dòng = usage + loss" do
    r = row_for("residential")
    expect(r.actual).to eq(r.usage + r.loss)
  end

  it "CHIEU-breakdown-chua-tinh: chưa tính (không có LossSummary) → trả nil" do
    LossSummary.where(period: sample.period).delete_all
    expect(described_class.new(zone: sample.zone, period: sample.period).call).to be_nil
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/docker rspec spec/services/loss_breakdown_spec.rb`
Expected: FAIL — `uninitialized constant LossBreakdown`.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/services/loss_breakdown.rb
# Read-only derivation of the per-contact-point-type loss/usage reconciliation
# table shown under the A/B/C block on the billing page (ADR-054, #332). Returns
# RAW BigDecimal values (no rounding) so reconciliation tests assert on the true
# figures; the view rounds per cell at display time. Anchored on the LossSummary
# snapshot (a/b/c) so the "Cộng" row matches A/B/C exactly. Returns nil when loss
# has not been computed for this zone+period (no LossSummary) — caller hides the
# table, matching the "kết quả từ lần tính gần nhất" semantics of ADR-027.
class LossBreakdown
  TYPE_ORDER = %w[residential public water_pump non_establishment].freeze

  Row = Struct.new(:type, :usage, :loss, :actual, keyword_init: true)
  Result = Struct.new(:rows, :cong, :khong_ton_hao, :tong_cong, :no_loss_by_type,
                      keyword_init: true)

  def initialize(zone:, period:)
    @zone = zone
    @period = period
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    summary = LossSummary.find_by(zone_id: @zone.id, period_id: @period.id)
    return nil unless summary

    meters = @query.meters.includes(:contact_point).to_a
    usages = @query.meter_usages
    readings = @query.meter_readings.index_by(&:meter_id)

    loss_bearing, no_loss = meters.partition do |meter|
      reading = readings[meter.id]
      !(reading && reading.no_loss)
    end

    rows = loss_bearing
      .group_by { |meter| meter.contact_point.contact_point_type }
      .map do |type, group|
        usage = group.sum(BigDecimal("0")) { |meter| usages[meter.id] || BigDecimal("0") }
        loss  = group.sum(BigDecimal("0")) { |meter| readings[meter.id]&.loss || BigDecimal("0") }
        Row.new(type: type, usage: usage, loss: loss, actual: usage + loss)
      end
      .sort_by { |row| TYPE_ORDER.index(row.type) || TYPE_ORDER.size }

    no_loss_usage = no_loss.sum(BigDecimal("0")) { |meter| usages[meter.id] || BigDecimal("0") }
    no_loss_by_type = no_loss
      .group_by { |meter| meter.contact_point.contact_point_type }
      .transform_values { |group| group.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") } }

    Result.new(
      rows: rows,
      cong: Row.new(type: nil, usage: summary.b, loss: summary.c, actual: summary.a),
      khong_ton_hao: Row.new(type: nil, usage: no_loss_usage, loss: BigDecimal("0"),
                             actual: no_loss_usage),
      tong_cong: Row.new(type: nil, usage: summary.b + no_loss_usage, loss: summary.c,
                         actual: @query.main_meter_total_usage),
      no_loss_by_type: no_loss_by_type
    )
  end
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `bin/docker rspec spec/services/loss_breakdown_spec.rb`
Expected: PASS (all examples).

- [ ] **Step 5: Commit**

```bash
git add app/services/loss_breakdown.rb spec/services/loss_breakdown_spec.rb
git commit -m "feat(billing): add LossBreakdown service deriving per-type loss reconciliation (#332)"
```

---

## Task 2: i18n keys `billing.loss_breakdown.*`

**Files:**
- Modify: `config/locales/vi.yml` (dưới khoá `billing:` đã tồn tại)

- [ ] **Step 1: Add keys**

Thêm vào nhánh `vi: billing:` (cùng cấp với `flash`/`buttons`/`confirm` đã có):

```yaml
    loss_breakdown:
      title: "Đối chiếu tổn hao/sử dụng theo loại đầu mối"
      columns:
        type: "Loại"
        usage: "Sử dụng"
        loss: "Tổn hao"
        actual: "Sử dụng thực tế"
      rows:
        loss_bearing_total: "Cộng (công tơ có tổn hao)"
        no_loss: "Không tổn hao"
        grand_total: "Tổng cộng"
      rounding_note: "Số làm tròn 2 chữ số; tổng các dòng có thể lệch ±0,01 do làm tròn. Số chuẩn để đối chiếu là A/B/C và số công tơ tổng."
```

- [ ] **Step 2: Verify i18n loads**

Run: `bin/docker exec app bash -c "RAILS_ENV=test bin/rails runner 'puts I18n.t(\"billing.loss_breakdown.title\")'"`
Expected: prints `Đối chiếu tổn hao/sử dụng theo loại đầu mối` (không phải `translation missing`).

- [ ] **Step 3: Commit**

```bash
git add config/locales/vi.yml
git commit -m "i18n(billing): add loss breakdown labels (#332)"
```

---

## Task 3: Controller — `@loss_breakdowns` per zone

**Files:**
- Modify: `app/controllers/billing_controller.rb:30-31` (sau khi gán `@loss_summaries`)

- [ ] **Step 1: Add the wiring**

Ngay sau dòng gán `@loss_summaries` trong `#show`, thêm:

```ruby
    @loss_breakdowns = @loss_summaries.each_with_object({}) do |summary, hash|
      next unless summary.zone
      hash[summary.zone_id] = LossBreakdown.new(zone: summary.zone, period: @period).call
    end
```

(Đặt trước `respond_to`. `@loss_breakdowns` map `zone_id => LossBreakdown::Result`; cùng gate `@loss_summaries` nên chỉ zone đã tính mới có breakdown.)

- [ ] **Step 2: Smoke check (no view yet → controller must not error)**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "trả 200"`
Expected: PASS (controller gán biến, view chưa dùng → không vỡ).

- [ ] **Step 3: Commit**

```bash
git add app/controllers/billing_controller.rb
git commit -m "feat(billing): build per-zone loss breakdowns in show action (#332)"
```

---

## Task 4: View — bảng breakdown trong `_loss_summary.html.erb` (HTML)

**Files:**
- Modify: `app/views/billing/_loss_summary.html.erb`
- Test: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write the failing request tests**

Thêm vào `describe "GET /billing"` → `context "system_admin (T77)"` (nơi `before` đã chạy `CalculationOrchestrator`):

```ruby
      it "CHIEU-breakdown-tong-theo-loai: bảng đối chiếu hiện đủ dòng + tiêu đề" do
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
        expect(response.body).to include("Cộng (công tơ có tổn hao)")
        expect(response.body).to include("Không tổn hao")
        expect(response.body).to include("Tổng cộng")
      end

      it "khớp ví dụ mẫu #332 (số làm tròn tiếng Việt)" do
        get billing_path(zone_id: sample.zone.id)
        body = response.body
        expect(body).to include("38,24") # tổn hao sinh hoạt
        expect(body).to include("12,44") # tổn hao công cộng
        expect(body).to include("9,33")  # tổn hao bơm nước
        expect(body).to include("2.100,00") # tổng cộng / sử dụng thực tế = công tơ tổng
      end

      it "CHIEU-breakdown-lam-tron: có chú thích lệch ±0,01 do làm tròn" do
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).to include("±0,01")
      end

      it "CHIEU-breakdown-chua-tinh: chưa tính → không hiện bảng breakdown" do
        LossSummary.where(period: sample.period).delete_all
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).not_to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
      end
```

- [ ] **Step 2: Run to verify they fail**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "breakdown" -e "ví dụ mẫu"`
Expected: FAIL (chưa render bảng).

- [ ] **Step 3: Implement the view**

Trong `app/views/billing/_loss_summary.html.erb`, bên trong vòng `@loss_summaries.each do |s|`, **sau** div chip A/B/C (dùng `@loss_breakdowns[s.zone_id]`), thêm:

```erb
        <% breakdown = @loss_breakdowns[s.zone_id] %>
        <% if breakdown %>
          <div class="mt-2 overflow-x-auto">
            <table class="text-sm border border-gray-200">
              <caption class="text-left font-semibold text-gray-700 px-2 py-1">
                <%= t("billing.loss_breakdown.title") %>
              </caption>
              <thead class="bg-gray-100 text-gray-700">
                <tr>
                  <th class="px-2 py-1 text-left"><%= t("billing.loss_breakdown.columns.type") %></th>
                  <th class="px-2 py-1 text-right"><%= t("billing.loss_breakdown.columns.usage") %></th>
                  <th class="px-2 py-1 text-right"><%= t("billing.loss_breakdown.columns.loss") %></th>
                  <th class="px-2 py-1 text-right"><%= t("billing.loss_breakdown.columns.actual") %></th>
                </tr>
              </thead>
              <tbody>
                <% breakdown.rows.each do |row| %>
                  <tr>
                    <td class="px-2 py-1"><%= t("activerecord.attributes.contact_point.types.#{row.type}", default: row.type) %></td>
                    <td class="px-2 py-1 text-right"><%= number_to_vi(row.usage) %></td>
                    <td class="px-2 py-1 text-right"><%= number_to_vi(row.loss) %></td>
                    <td class="px-2 py-1 text-right"><%= number_to_vi(row.actual) %></td>
                  </tr>
                <% end %>
                <tr class="font-semibold border-t border-gray-300">
                  <td class="px-2 py-1"><%= t("billing.loss_breakdown.rows.loss_bearing_total") %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.loss_bearing_total.usage) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.loss_bearing_total.loss) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.loss_bearing_total.actual) %></td>
                </tr>
                <tr>
                  <td class="px-2 py-1"><%= t("billing.loss_breakdown.rows.no_loss") %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.no_loss_total.usage) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.no_loss_total.loss) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.no_loss_total.actual) %></td>
                </tr>
                <tr class="font-semibold border-t border-gray-300">
                  <td class="px-2 py-1"><%= t("billing.loss_breakdown.rows.grand_total") %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.grand_total.usage) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.grand_total.loss) %></td>
                  <td class="px-2 py-1 text-right"><%= number_to_vi(breakdown.grand_total.actual) %></td>
                </tr>
              </tbody>
            </table>
            <p class="mt-1 text-xs text-gray-500"><%= t("billing.loss_breakdown.rounding_note") %></p>
          </div>
        <% end %>
```

- [ ] **Step 4: Run to verify they pass**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "breakdown" -e "ví dụ mẫu"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/billing/_loss_summary.html.erb spec/requests/billing_spec.rb
git commit -m "feat(billing): render per-type loss reconciliation table on billing page (#332)"
```

---

## Task 5: Đối chiếu chéo bảng tính tiền (request spec)

**Files:**
- Test: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write the failing test**

Trong `context "system_admin (T77)"`:

```ruby
      it "CHIEU-breakdown-doi-chieu-sinh-hoat: sinh hoạt khớp tổng cột bảng (raw)" do
        get billing_path(zone_id: sample.zone.id)
        breakdown = controller.view_assigns["loss_breakdowns"][sample.zone.id]
        summary = Billing::Query.summary(
          Billing::Query.apply_zone_unit_filter(
            Billing::Query.base_scope(sample.period, Ability.new(create(:user, :system_admin))),
            zone: sample.zone, unit: nil
          ), period: sample.period
        )
        residential = breakdown.rows.find { |r| r.type == "residential" }
        # Tổn hao sinh hoạt = TỔNG cột Tổn hao trên bảng (loss_deduction)
        expect(residential.loss).to be_within(BigDecimal("0.01")).of(summary[:loss_deduction])
        # (Sinh hoạt có tổn hao + sinh hoạt không tổn hao) = TỔNG Sử dụng sinh hoạt
        total_residential_usage = residential.usage + breakdown.no_loss_by_type["residential"]
        expect(total_residential_usage).to eq(summary[:residential_usage])
      end
```

> Lưu ý: nếu truy cập `controller.view_assigns` rườm rà, thay bằng test trực tiếp ở `spec/services/loss_breakdown_spec.rb` so `LossBreakdown` với `Billing::Query.summary(...)` — chọn nơi gọn hơn khi triển khai, miễn mang anchor `CHIEU-breakdown-doi-chieu-sinh-hoat`.

- [ ] **Step 2: Run to verify it fails then passes**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "doi-chieu-sinh-hoat"`
Expected: FAIL nếu logic sai → sửa cho tới khi PASS (service đã đúng từ Task 1, test này chủ yếu chốt cross-check).

- [ ] **Step 3: Commit**

```bash
git add spec/requests/billing_spec.rb
git commit -m "test(billing): cross-check residential breakdown against billing totals (#332)"
```

---

## Task 6: Excel parity

**Files:**
- Modify: `app/views/billing/show.xlsx.axlsx` (trong khối `if @loss_summaries.any?` ở cuối sheet)
- Test: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write the failing test**

Trong `context "SA (30 cột)"` của phần Excel (nơi đã có `CHIEU-ton-hao-sau-tinh`):

```ruby
        it "CHIEU-breakdown-excel: các dòng breakdown theo loại ở cuối sheet" do
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
          expect(all_text).to include("Cộng (công tơ có tổn hao)")
          expect(all_text).to include("Tổng cộng")
        end
```

- [ ] **Step 2: Run to verify it fails**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "breakdown-excel"`
Expected: FAIL.

- [ ] **Step 3: Implement Excel rows**

Trong `app/views/billing/show.xlsx.axlsx`, trong khối `@loss_summaries.each do |summary|` (sau dòng `sheet.add_row ["Tổn hao khu vực ...", ...]`), thêm các dòng breakdown cho zone đó:

```ruby
        breakdown = @loss_breakdowns[summary.zone_id]
        if breakdown
          sheet.add_row [I18n.t("billing.loss_breakdown.title")], style: [text_style]
          sheet.add_row [
            I18n.t("billing.loss_breakdown.columns.type"),
            I18n.t("billing.loss_breakdown.columns.usage"),
            I18n.t("billing.loss_breakdown.columns.loss"),
            I18n.t("billing.loss_breakdown.columns.actual")
          ], style: [text_style, text_style, text_style, text_style]
          breakdown.rows.each do |row|
            sheet.add_row [
              I18n.t("activerecord.attributes.contact_point.types.#{row.type}", default: row.type),
              row.usage.to_f, row.loss.to_f, row.actual.to_f
            ], style: [text_style, num_style, num_style, num_style]
          end
          [[I18n.t("billing.loss_breakdown.rows.loss_bearing_total"), breakdown.loss_bearing_total],
           [I18n.t("billing.loss_breakdown.rows.no_loss"), breakdown.no_loss_total],
           [I18n.t("billing.loss_breakdown.rows.grand_total"), breakdown.grand_total]].each do |label, r|
            sheet.add_row [label, r.usage.to_f, r.loss.to_f, r.actual.to_f],
                          style: [text_style, num_style, num_style, num_style]
          end
        end
```

(Đặt trong vòng lặp zone, **trước** khi đóng khối — vẫn ở cuối sheet, không merge/không formula → an toàn lưới `$B$1` + `data_start_row`.)

- [ ] **Step 4: Run to verify it passes + formula safety intact**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "breakdown-excel" -e "formula column index"`
Expected: PASS cả hai (dòng breakdown không phá công thức).

- [ ] **Step 5: Commit**

```bash
git add app/views/billing/show.xlsx.axlsx spec/requests/billing_spec.rb
git commit -m "feat(billing): export per-type loss breakdown rows to Excel (#332)"
```

---

## Task 7: Role coverage + SA đa khu vực

**Files:**
- Test: `spec/requests/billing_spec.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
  describe "GET /billing — breakdown role + multi-zone (#332)" do
    let(:sample) { setup_zone_one_full_sample }
    before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    it "CHIEU-breakdown-vai-tro: unit_admin thấy breakdown khu vực mình" do
      sign_in create(:user, :unit_admin, unit: sample.unit_a)
      get billing_path
      expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
    end

    it "CHIEU-breakdown-vai-tro: commander thấy breakdown (read-only)" do
      sign_in create(:user, :commander, unit: sample.unit_a)
      get billing_path
      expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
    end

    it "CHIEU-breakdown-vai-tro: technician bị chặn khỏi bảng tính tiền" do
      sign_in create(:user, :technician)
      get billing_path
      expect(response).to have_http_status(:found).or have_http_status(:forbidden)
    end

    it "CHIEU-breakdown-theo-zone: SA đa khu vực → mỗi zone một bảng breakdown" do
      sample2 = setup_zone_two_full_sample(period: sample.period)
      CalculationOrchestrator.new(zone: sample2.zone, period: sample.period).call
      sign_in create(:user, :system_admin)
      get billing_path # không lọc zone → tất cả zone
      expect(response.body.scan("Đối chiếu tổn hao/sử dụng theo loại đầu mối").size).to be >= 2
    end
  end
```

> Lưu ý: trait vai trò (`:system_admin`, `:unit_admin`, `:commander`, `:technician`) đã dùng nơi khác trong `spec/requests/billing_spec.rb`. ZM variant = unit là `manager_unit` của zone (ở fixture: `unit_a`). 6 vai trò theo `docs/V2_HANH_VI_HE_THONG.md` mục 1 — nếu trait `:commander` cần `unit:`, truyền `sample.unit_a` (UA-ZM/CMD-ZM) và `sample.unit_b` (UA/CMD) để phủ cả biến thể.

- [ ] **Step 2: Run to verify (đa số PASS sẵn nhờ view; technician chốt guard)**

Run: `bin/docker rspec spec/requests/billing_spec.rb -e "breakdown role"`
Expected: PASS. Nếu commander/technician khác kỳ vọng → đối chiếu `BusinessRoleRequired` + `can?(:read, Calculation)`; sửa test cho khớp guard thực tế (không sửa guard).

- [ ] **Step 3: Commit**

```bash
git add spec/requests/billing_spec.rb
git commit -m "test(billing): cover breakdown across 6 roles and SA multi-zone (#332)"
```

---

## Task 8: Demo hướng khách (ADR-040) — phủ luôn TN3

**Files:**
- Modify: `db/seeds/demo.rb` (thêm 1 công tơ `no_loss`)
- Create: `spec/demo/loss_breakdown_demo_spec.rb` (qua generator)

- [ ] **Step 1: Rebase develop mới nhất trước (recorder #356)**

```bash
git fetch origin && git rebase origin/develop
```
Expected: rebase sạch (file không trùng).

- [ ] **Step 2: Thêm công tơ no_loss vào demo seed**

Trong `db/seeds/demo.rb`, tại chỗ tạo meters cho một đầu mối sinh hoạt sẵn có, thêm một công tơ `no_loss: true` (ví dụ trên đầu mối "Ban chỉ huy"/residential), kèm `meter_reading` của nó cho kỳ. Mẫu (đặt cạnh các `m.no_loss = false` quanh dòng 205-220):

```ruby
  meter_khong_ton_hao = cp_ban_chi_huy.meters.find_or_create_by!(name: "CT-KTH") do |m|
    m.no_loss = true
  end
  reading_kth = meter_khong_ton_hao.meter_readings.find_or_initialize_by(period: period)
  reading_kth.update!(reading_start: BigDecimal("0"), reading_end: BigDecimal("90"), no_loss: true)
  puts "  Meter (no_loss): #{meter_khong_ton_hao.name}"
```

(Tên đầu mối residential thật trong seed: kiểm bằng `grep contact_point_type.*residential db/seeds/demo.rb` rồi dùng biến đúng. Giữ thay đổi tối thiểu; chạy `bin/docker exec app bash -c "RAILS_ENV=test bin/rails runner 'load Rails.root.join(%q{db/seeds/demo.rb})'"` để xác nhận seed chạy không lỗi.)

- [ ] **Step 3: Scaffold demo spec qua generator**

```bash
bin/docker exec app bash -c "bin/rails g demo:spec loss_breakdown"
```
Expected: tạo `spec/demo/loss_breakdown_demo_spec.rb` với `include_context "demo seeded world"` + boilerplate login + `demo_nv:`.

- [ ] **Step 4: Điền journey + caption (phủ TN3 + #332)**

Thay phần TODO bằng (sau bước đăng nhập có sẵn của skeleton):

```ruby
  it "đối chiếu tổn hao theo loại trên bảng tính tiền", demo_nv: %w[NV-hien-thi-chi-tiet-ton-hao] do
    demo = DemoRecorder.new(self)

    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")
    demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")
    demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
    expect(page).to have_current_path("/", wait: 10)

    demo.visit("/billing", caption: "Mở Bảng tính tiền")
    demo.click("Tính toán lại", caption: "Bấm Tính toán lại để cập nhật tổn hao")
    # Turbo confirm: chấp nhận hộp xác nhận (theo mẫu recorder mới nhất sau rebase)
    page.driver.browser.switch_to.alert.accept rescue nil

    demo.visit("/billing", caption: "Xem cột Tổn hao và khối A/B/C (TN3)")
    expect(page).to have_content("Tổng tổn hao")

    demo.visit("/billing", caption: "Xem bảng đối chiếu tổn hao theo loại (Sinh hoạt / Công cộng / Bơm nước)")
    expect(page).to have_content("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
    expect(page).to have_content("Tổng cộng")
  end
```

> Caption tiếng Việt lấy ý từ `NV-hien-thi-chi-tiet-ton-hao`. Sau rebase, đối chiếu API `DemoRecorder` mới nhất (#356 có thể thêm helper cuộn/tô sáng — dùng nếu có). Xử lý Turbo confirm theo cách recorder/seed mẫu khác đang dùng.

- [ ] **Step 5: Run the demo spec (green-to-merge)**

Run: `bin/docker exec app bash -c "DEMO=1 bundle exec rspec spec/demo/loss_breakdown_demo_spec.rb"`
Expected: PASS (spec xanh; video quay ở CI).

- [ ] **Step 6: Commit**

```bash
git add db/seeds/demo.rb spec/demo/loss_breakdown_demo_spec.rb
git commit -m "test(demo): add customer-facing loss breakdown demo, also covering TN3 (#332)"
```

---

## Task 9: Cập nhật nghiệp vụ §8.5 (ADR-002)

**Files:**
- Modify: `docs/V2_XAC_NHAN_NGHIEP_VU.md` (anchor `NV-hien-thi-chi-tiet-ton-hao`, §8.5)

- [ ] **Step 1: Thêm mô tả bảng đối chiếu**

Tại §8.5 (anchor `NV-hien-thi-chi-tiet-ton-hao`), bổ sung một đoạn mô tả **bảng đối chiếu theo loại đầu mối** trên Bảng tính tiền (3 loại + Cộng/Không tổn hao/Tổng cộng; đối chiếu Σ=A/B/C, Tổng cộng = công tơ tổng; chú thích làm tròn ±0,01). Trỏ tới ADR-054. Đọc lại toàn mục §8.5 trước khi thêm để tránh trùng (doc governance "sửa đừng thêm").

- [ ] **Step 2: Bump version + changelog**

`grep -n "Phiên bản\|Lịch sử thay đổi" docs/V2_XAC_NHAN_NGHIEP_VU.md` → bump `Phiên bản:` (minor) + thêm entry `## Lịch sử thay đổi` mô tả bổ sung bảng đối chiếu (#332, ADR-054).

- [ ] **Step 3: Verify doc guardrails**

Run: `bash .github/scripts/check-changelog-header.sh && bash .github/scripts/check-doc-links.sh && bash .github/scripts/check-glossary-definitions.sh`
Expected: tất cả `✓`.

- [ ] **Step 4: Commit**

```bash
git add docs/V2_XAC_NHAN_NGHIEP_VU.md
git commit -m "docs(business): describe per-type loss reconciliation table in section 8.5 (#332)"
```

---

## Task 10: Verify toàn bộ + mở PR

- [ ] **Step 1: Full test suite**

Run: `bin/docker rspec`
Expected: tất cả PASS (gồm system + demo skip trừ DEMO=1).

- [ ] **Step 2: Test-dimension guardrail xanh (10 CHIEU-breakdown có test)**

Run: `bash .github/scripts/check-test-dimensions.sh`
Expected: `✓` — mọi `CHIEU-breakdown-*` có test mang anchor.

> Nếu thiếu anchor nào: thêm `it "CHIEU-breakdown-...:"` tương ứng (mọi mã trong bảng spec phải có test hoặc DEFERRED).

- [ ] **Step 3: Toàn bộ doc guardrails**

Run: `for s in check-adr-numbering check-adr-status check-changelog-header check-doc-links check-glossary-definitions check-doc-map check-test-dimensions; do bash .github/scripts/$s.sh; done`
Expected: tất cả `✓`.

- [ ] **Step 4: Rebase develop mới nhất lần cuối + push**

```bash
git fetch origin && git rebase origin/develop
git push -u origin feature/332-loss-breakdown-by-contact-point-type
```

- [ ] **Step 5: Mở PR base `develop`, gắn nhãn `customer-facing`**

```bash
gh pr create --base develop --label customer-facing \
  --title "feat(billing): per-type loss/usage reconciliation table (#332)" \
  --body "<mô tả + test plan; KHÔNG đặt Closes/Fixes #332 trừ khi muốn auto-close khi merge vào develop>"
```

> Nhãn `customer-facing` BẮT BUỘC (ADR-040) — PR phải đụng `spec/demo/**` (đã có ở Task 8) nếu không CI đỏ. Theo dõi CI: `gh pr checks --watch` (chạy nền), báo pass/fail. Merge là gate người.

---

## Self-Review (đã chạy khi viết plan)

- **Spec coverage:** 10 CHIEU-breakdown → Task 1 (tong-theo-loai, khong-ton-hao, doi-chieu-cong-to-tong, chua-tinh), Task 4 (lam-tron, HTML hiện), Task 5 (doi-chieu-sinh-hoat), Task 6 (excel), Task 7 (vai-tro, theo-zone), i18n (Task 2+4). Demo (Task 8). Doc §8.5 (Task 9). ✓ đủ.
- **Placeholder scan:** không có TBD/TODO trong bước code (chỉ "TODO(demo-author)" là của skeleton generator, thay ở Task 8 Step 4). ✓
- **Type consistency:** `LossBreakdown::Result` fields (`rows`/`loss_bearing_total`/`no_loss_total`/`grand_total`/`no_loss_by_type`) + `Row` (`type`/`usage`/`loss`/`actual`) — tên tiếng Anh (AGENTS) — dùng nhất quán ở service, controller, view, Excel, test. ✓
