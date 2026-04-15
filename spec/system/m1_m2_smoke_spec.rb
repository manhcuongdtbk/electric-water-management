require "rails_helper"

# Smoke tests for M1 + M2 UI. Purpose: verify all pages load, forms submit,
# and the Stimulus controllers (F03, F04, F06) compute values realtime.
# Does NOT cover edge cases — happy path only. Runs before M3 permission refactor.
RSpec.describe "M1+M2 smoke", type: :system do
  let(:division)          { create(:organization, :division) }
  let(:unit)              { create(:organization, :unit, parent: division) }
  let(:other_unit)        { create(:organization, :unit, parent: division) }
  let(:admin_unit_user)   { create(:user, :admin_unit,   organization: unit) }
  let(:admin_level1_user) { create(:user, :admin_level1, organization: division) }
  let(:commander_user)    { create(:user, :commander,    organization: unit) }

  before do
    # Rank quotas (needed by F03 and calculation engine)
    (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
  end

  # ============================================================================
  # admin_unit flow — CRUD + data entry (F01–F07, F11)
  # ============================================================================
  describe "admin_unit flow" do
    before { login_as admin_unit_user, scope: :user }

    # -------------------------------------------------------------------------
    # F01 — Contact points CRUD
    # -------------------------------------------------------------------------
    it "F01 — lists, creates, edits, and destroys a contact point" do
      visit contact_points_path

      expect(page).to have_content(I18n.t("contact_points.index.title"))
      expect(page).to have_css("table")

      # Create
      click_on I18n.t("contact_points.index.new_button")
      fill_in I18n.t("contact_points.form.name"), with: "Test Đầu Mối"
      fill_in I18n.t("contact_points.form.group_name"), with: "Ban Tham Mưu"
      click_on I18n.t("contact_points.form.submit_create")

      expect(page).to have_content(I18n.t("flash.contact_points.created"))
      expect(page).to have_content("Test Đầu Mối")

      # Edit
      cp = ContactPoint.find_by!(name: "Test Đầu Mối")
      visit edit_contact_point_path(cp)
      fill_in I18n.t("contact_points.form.name"), with: "Đầu Mối Đã Sửa"
      click_on I18n.t("contact_points.form.submit_update")

      expect(page).to have_content(I18n.t("flash.contact_points.updated"))
      expect(page).to have_content("Đầu Mối Đã Sửa")

      # Destroy — click_button only matches form buttons (avoids "Xóa bộ lọc" link)
      click_button I18n.t("contact_points.actions.delete")
      expect(page).to have_content(I18n.t("flash.contact_points.destroyed"))
      expect(page).not_to have_content("Đầu Mối Đã Sửa")
    end

    # -------------------------------------------------------------------------
    # F02 — Meters CRUD
    # -------------------------------------------------------------------------
    it "F02 — creates both a 'normal' and a 'pump_station' meter" do
      cp = create(:contact_point, organization: unit)

      visit contact_point_meters_path(cp)
      expect(page).to have_content(I18n.t("meters.index.title"))

      # Create a normal meter
      click_on I18n.t("meters.index.new_button")
      fill_in I18n.t("meters.form.name"), with: "Công tơ thường test"
      select I18n.t("meters.meter_types.normal"), from: I18n.t("meters.form.meter_type")
      click_on I18n.t("meters.form.submit_create")

      expect(page).to have_content("Công tơ thường test")
      expect(page).to have_content(I18n.t("meters.meter_types.normal"))

      # Create a pump_station meter
      click_on I18n.t("meters.index.new_button")
      fill_in I18n.t("meters.form.name"), with: "Công tơ trạm bơm test"
      select I18n.t("meters.meter_types.pump_station"), from: I18n.t("meters.form.meter_type")
      click_on I18n.t("meters.form.submit_create")

      expect(page).to have_content("Công tơ trạm bơm test")
      expect(page).to have_content(I18n.t("meters.meter_types.pump_station"))
    end

    # -------------------------------------------------------------------------
    # F03 — Personnel declaration (Stimulus realtime calculator)
    # -------------------------------------------------------------------------
    it "F03 — Stimulus calculates totals realtime before submit", :js do
      cp = create(:contact_point, organization: unit)
      create(:monthly_period, year: 2026, month: 2)

      visit contact_point_personnel_path(cp)

      # All 7 rank input fields should be present
      (1..7).each do |i|
        expect(page).to have_css("input#personnel_rank#{i}_count")
      end

      # Fill 7 ranks (Stimulus calculates on input)
      fill_in "personnel_rank1_count", with: 1
      fill_in "personnel_rank2_count", with: 2
      fill_in "personnel_rank3_count", with: 3
      fill_in "personnel_rank4_count", with: 5
      fill_in "personnel_rank5_count", with: 10
      fill_in "personnel_rank6_count", with: 20
      fill_in "personnel_rank7_count", with: 50

      # Stimulus target: totalCount — `exact_text` avoids substring match on
      # "910" / "1910"; `have_css` auto-retries so we wait for the DOM update.
      expect(page).to have_css(
        "[data-personnel-calculator-target='totalCount']",
        exact_text: "91"
      )

      # Living/water/total standards must all be populated (matches a number
      # with fractional part — see Intl.NumberFormat vi-VN output "1.234,56").
      %w[livingStandard waterStandard totalStandard].each do |target|
        expect(page).to have_css(
          "[data-personnel-calculator-target='#{target}']",
          text: /\d[.,]\d/
        )
      end

      # Submit and verify persistence
      click_on I18n.t("personnel.form.submit")
      expect(page).to have_content(I18n.t("flash.personnel.saved"))

      personnel = cp.personnel_records.first
      expect(personnel.rank1_count).to eq(1)
      expect(personnel.rank7_count).to eq(50)
      expect(personnel.total_count).to eq(91)
    end

    # -------------------------------------------------------------------------
    # F04 — Unit config: public_rate + "Khác" Stimulus toggle
    # -------------------------------------------------------------------------
    it "F04 — saves unit_public_rate and toggles 'Khác' type realtime", :js do
      cp = create(:contact_point, organization: unit)
      period = create(:monthly_period, year: 2026, month: 2)
      create(:personnel,
             contact_point: cp, monthly_period: period,
             rank1_count: 2, rank2_count: 3, rank3_count: 5,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) # total = 10

      visit unit_config_path
      expect(page).to have_content(I18n.t("unit_configs.show.title"))

      # Save unit_public_rate = 3.0
      find("input[name='unit_config[unit_public_rate]']").set("3.0")
      click_on I18n.t("unit_configs.section_unit.submit")

      # The page redirects back; the new value should show
      expect(page).to have_content(I18n.t("flash.unit_configs.unit_updated"))
      new_val = find("input[name='unit_config[unit_public_rate]']").value
      expect(new_val.to_f).to eq(3.0)

      # Now test Stimulus toggle on "Khác" column
      row_selector = "tr[data-cp-id='#{cp.id}']"
      within(row_selector) do
        # Fill value 10 with type = fixed_kw (default). Result should be 10.xx
        find("input[data-role='other-value']").set("10")
        expect(page).to have_css("[data-role='other-result']", text: /\A10[.,]/)

        # Toggle to factor_per_person → 10 * personnel_count (10) = 100.xx
        find("select[data-role='other-type']")
          .select(I18n.t("unit_configs.other_types.factor_per_person"))
        expect(page).to have_css("[data-role='other-result']", text: /\A100[.,]/)
      end
    end

    # -------------------------------------------------------------------------
    # F05 — Electricity supply entry
    # -------------------------------------------------------------------------
    it "F05 — saves electricity supply kWh for the unit" do
      create(:monthly_period, year: 2026, month: 2)

      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.show.title"))

      fill_in I18n.t("electricity_supplies.section_input.field_label"), with: "50000"
      click_on I18n.t("electricity_supplies.section_input.submit")

      # Value shows in the input after save
      field = find("input[name='electricity_supply[electricity_supply_kw]']")
      expect(field.value.to_f).to eq(50_000.0)
    end

    # -------------------------------------------------------------------------
    # F06 — Meter readings (Stimulus realtime consumption)
    # -------------------------------------------------------------------------
    it "F06 — Stimulus shows consumption = end - start realtime", :js do
      cp = create(:contact_point, organization: unit)
      create(:meter, :normal, contact_point: cp, organization: unit, name: "Công tơ A")
      create(:monthly_period, year: 2026, month: 2)

      visit meter_readings_path
      expect(page).to have_content(I18n.t("meter_readings.show.title"))
      expect(page).to have_content("Công tơ A")

      # One meter → one row with Stimulus controller attached
      within("tr[data-controller='meter-reading']") do
        find("input[data-meter-reading-target='start']").set("100")
        find("input[data-meter-reading-target='end']").set("250")

        # Stimulus computes 250 - 100 = 150 → vi-VN "150,00" or "150.00"
        expect(page).to have_css(
          "[data-meter-reading-target='consumption']",
          text: /\A150[.,]/
        )
      end

      # Save and verify
      click_on I18n.t("meter_readings.save_all")
      expect(page).to have_content(I18n.t("flash.meter_readings.saved"))
    end

    # -------------------------------------------------------------------------
    # F07 — Personnel review (inheritance + lock on prior period)
    # -------------------------------------------------------------------------
    it "F07 — shows inherited personnel and locks old period" do
      cp = create(:contact_point, organization: unit)
      old_period = create(:monthly_period, year: 2026, month: 1, locked: false)
      create(:personnel,
             contact_point: cp, monthly_period: old_period,
             rank1_count: 2, rank2_count: 3, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      new_period = create(:monthly_period, year: 2026, month: 2, locked: false)
      # Simulate inheritance — copy same personnel into new period
      create(:personnel,
             contact_point: cp, monthly_period: new_period,
             rank1_count: 2, rank2_count: 3, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      # Lock the old period
      old_period.update!(locked: true, locked_at: Time.current, locked_by: admin_unit_user)

      visit personnel_review_path(period_id: new_period.id)

      expect(page).to have_content(I18n.t("personnel_reviews.show.title"))
      expect(page).to have_content(cp.name)
      # New period is unlocked → edit/toggle buttons visible
      expect(page).to have_content(I18n.t("personnel_reviews.lock_banner.unlocked"))
      expect(page).to have_link(I18n.t("personnel_reviews.actions.edit"))

      # Old period is locked → toggle-review button NOT shown
      visit personnel_review_path(period_id: old_period.id)
      expect(page).to have_content(I18n.t("personnel_reviews.lock_banner.locked"))
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.toggle_review"))
      expect(page).not_to have_button(I18n.t("personnel_reviews.actions.unmark_review"))
    end

    # -------------------------------------------------------------------------
    # F11 — 22-column monthly summary table
    # -------------------------------------------------------------------------
    it "F11 — renders 22-column table with group headers and totals row" do
      cp = create(:contact_point, organization: unit)
      period = create(:monthly_period, year: 2026, month: 2)
      create(:monthly_calculation,
             contact_point: cp, monthly_period: period,
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

      visit monthly_summary_path(period_id: period.id)

      # Group headers (4 groups)
      expect(page).to have_content(I18n.t("monthly_summary.groups.personnel"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.standard"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.deductions"))
      expect(page).to have_content(I18n.t("monthly_summary.groups.result"))

      # Contact point row is present
      expect(page).to have_content(cp.name)

      # Totals row is present
      expect(page).to have_content(I18n.t("monthly_summary.total_row"))

      # Specific formatted values from the seeded calculation. Uses the full
      # rendered string (not a substring) to avoid accidental matches.
      expect(page).to have_content("9,320.00")  # total_standard_kw
      expect(page).to have_content("174,000")   # total_amount
    end
  end

  # ============================================================================
  # admin_level1 flow — cross-unit visibility
  # ============================================================================
  describe "admin_level1 flow" do
    before { login_as admin_level1_user, scope: :user }

    it "sees an organization filter on the contact points list" do
      create(:contact_point, organization: unit, name: "CP Unit 1")
      create(:contact_point, organization: other_unit, name: "CP Unit 2")

      visit contact_points_path
      expect(page).to have_content("CP Unit 1")
      expect(page).to have_content("CP Unit 2")
      # Organization filter select should exist (only for admin_level1)
      expect(page).to have_css("select[name='q[organization_id_eq]']")
    end

    it "sees a unit filter/dropdown on the 22-column monthly summary" do
      # Controller renders the org dropdown only when at least one unit exists.
      create(:organization, :unit, parent: division, name: "Unit A")
      create(:organization, :unit, parent: division, name: "Unit B")
      create(:monthly_period, year: 2026, month: 2)

      visit monthly_summary_path
      expect(page).to have_css("select[name='org_id']")
    end
  end

  # ============================================================================
  # commander flow — read-only verification
  # ============================================================================
  describe "commander flow" do
    before { login_as commander_user, scope: :user }

    it "has no 'create' button on contact points list" do
      create(:contact_point, organization: unit, name: "CP Read Only")
      visit contact_points_path

      expect(page).to have_content("CP Read Only")
      expect(page).not_to have_link(I18n.t("contact_points.index.new_button"))
    end

    it "has no 'Tính lại' button on monthly summary" do
      cp = create(:contact_point, organization: unit)
      period = create(:monthly_period, year: 2026, month: 2)
      create(:monthly_calculation, contact_point: cp, monthly_period: period)

      visit monthly_summary_path(period_id: period.id)

      # Data is visible
      expect(page).to have_content(cp.name)
      # But no recalculate button
      expect(page).not_to have_button(I18n.t("monthly_summary.recalculate"))
    end
  end
end
