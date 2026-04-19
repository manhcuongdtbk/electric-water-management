require "rails_helper"

# F08-F11 — Calculation engine + bảng 22 cột (monthly_summary).
# Mix of two strategies:
#   * End-to-end: admin_unit visits /monthly_summary with full data; the
#     controller auto-runs the engine and persists rows (F08-F10).
#   * Render-only: seed MonthlyCalculation directly and assert the 22-column
#     table shape and formatting (F11).
RSpec.describe "F08-F11 — Calculation engine + 22-column summary", type: :system do
  let(:scenario) { setup_basic_scenario }

  # ---------------------------------------------------------------------------
  # End-to-end — the engine runs on first visit and again via "Tính lại"
  # ---------------------------------------------------------------------------
  describe "engine end-to-end" do
    it "auto-runs the engine on first visit and persists calculation rows" do
      cp = create_full_calculation_data(scenario) # rank1=2, rank5=10
      login_as scenario.admin_unit, scope: :user

      expect {
        visit monthly_summary_path(period_id: scenario.period.id)
      }.to change(MonthlyCalculation, :count).from(0).to(1)

      calc = MonthlyCalculation.find_by!(contact_point: cp, monthly_period: scenario.period)
      # rank1 quota = 570, rank5 quota = 210 → 2×570 + 10×210 = 3240 living
      # Water pump = 9.45 × 12 personnel = 113.40
      expect(calc.total_personnel).to eq(12)
      expect(calc.rank1_kw.to_f).to be_within(0.01).of(1140.0)
      expect(calc.rank5_kw.to_f).to be_within(0.01).of(2100.0)
      expect(calc.water_pump_standard_kw.to_f).to be_within(0.01).of(113.40)
      expect(calc.total_standard_kw.to_f).to be_within(0.01).of(3353.40)

      # Contact point row + totals row show
      expect(page).to have_content(cp.name)
      expect(page).to have_content(I18n.t("monthly_summary.total_row"))
    end

    it "re-runs the engine when admin clicks 'Tính lại'" do
      cp = create_full_calculation_data(scenario)
      login_as scenario.admin_unit, scope: :user
      visit monthly_summary_path(period_id: scenario.period.id)

      # Mutate a reading underneath, then press the button — engine re-aggregates
      reading = MeterReading.find_by!(meter: cp.meters.first, monthly_period: scenario.period)
      reading.update!(reading_end: 800) # was 500
      expect {
        click_on I18n.t("monthly_summary.recalculate")
      }.to change {
        MonthlyCalculation.find_by!(contact_point: cp, monthly_period: scenario.period).total_usage_kw.to_f
      }

      expect(page).to have_content(I18n.t("flash.monthly_summary.recalculated"))
    end
  end

  # ---------------------------------------------------------------------------
  # Render-only — seed calculated rows and verify the 22-column layout
  # ---------------------------------------------------------------------------
  describe "22-column table rendering" do
    it "renders the 4 group headers and a totals row" do
      cp = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp, monthly_period: scenario.period,
             total_personnel: 40,
             rank1_kw: 1140, rank2_kw: 2200, rank3_kw: 3050,
             rank4_kw: 2600, rank5_kw: 0, rank6_kw: 330, rank7_kw: 0,
             water_pump_standard_kw: 378, water_pump_actual_kw: 350,
             total_standard_kw: 9320,
             savings_deduction_kw: 466, loss_deduction_kw: 93,
             division_public_deduction_kw: 932, unit_public_deduction_kw: 466,
             other_deduction_kw: 0, total_deduction_kw: 1957,
             remaining_standard_kw: 7363,
             meter_usage_kw: 7100, total_usage_kw: 7450,
             over_under_kw: 87, unit_price: 2000, total_amount: 174_000)

      login_as scenario.admin_unit, scope: :user
      visit monthly_summary_path(period_id: scenario.period.id)

      # 4 group headers present
      expect(page).to have_content(I18n.t("monthly_summary.groups.personnel"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.standard"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.deductions"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.result"))

      # Contact point row + totals row both rendered with seeded values
      expect(page).to have_content(cp.name)
      expect(page).to have_content(I18n.t("monthly_summary.total_row"))
      expect(page).to have_content("9,320.00")  # total_standard_kw
      expect(page).to have_content("174,000")   # total_amount
    end

    it "only lists contact points belonging to the admin_unit's own organization" do
      other_unit = create(:organization, :unit, parent: scenario.division)
      own_cp = create(:contact_point, organization: scenario.unit, name: "Own CP")
      foreign_cp = create(:contact_point, organization: other_unit, name: "Foreign CP")
      create(:monthly_calculation, contact_point: own_cp, monthly_period: scenario.period)
      create(:monthly_calculation, contact_point: foreign_cp, monthly_period: scenario.period)

      login_as scenario.admin_unit, scope: :user
      visit monthly_summary_path(period_id: scenario.period.id)

      expect(page).to have_content("Own CP")
      expect(page).not_to have_content("Foreign CP")
    end

    it "shows an org dropdown to admin_level1 so they can switch between units" do
      create(:organization, :unit, parent: scenario.division, name: "Unit A")
      create(:organization, :unit, parent: scenario.division, name: "Unit B")

      login_as scenario.admin_level1, scope: :user
      visit monthly_summary_path(period_id: scenario.period.id)

      expect(page).to have_css("select[name='org_id']")
    end
  end

  # ---------------------------------------------------------------------------
  # commander — read-only, no recalculate affordance
  # ---------------------------------------------------------------------------
  describe "commander" do
    it "sees the table but no 'Tính lại' button" do
      cp = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation, contact_point: cp, monthly_period: scenario.period)

      login_as scenario.commander, scope: :user
      visit monthly_summary_path(period_id: scenario.period.id)

      expect(page).to have_content(cp.name)
      expect(page).not_to have_button(I18n.t("monthly_summary.recalculate"))
    end
  end
end
