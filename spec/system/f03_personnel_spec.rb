require "rails_helper"

# F03 — Khai báo quân số (personnel). Tests Stimulus realtime calculator,
# persistence, the period selector, and commander read-only view.
RSpec.describe "F03 — Personnel declaration", type: :system do
  let(:scenario) { setup_basic_scenario }
  let(:cp)       { create(:contact_point, organization: scenario.unit) }

  # ---------------------------------------------------------------------------
  # admin_unit — full interactive flow (needs :js for Stimulus)
  # ---------------------------------------------------------------------------
  describe "admin_unit", :js do
    before { login_as scenario.admin_unit, scope: :user }

    it "calculates totals realtime as ranks are filled" do
      visit contact_point_personnel_path(cp)

      (1..7).each do |i|
        expect(page).to have_css("input#personnel_rank#{i}_count")
      end

      # Fill rank1 first and wait for Stimulus to reflect it. Without this
      # sync, subsequent fills race the controller's connect() callback.
      fill_in "personnel_rank1_count", with: 1
      expect(page).to have_css(
        "[data-personnel-calculator-target='totalCount']",
        exact_text: "1"
      )

      fill_in "personnel_rank2_count", with: 2
      fill_in "personnel_rank3_count", with: 3
      fill_in "personnel_rank4_count", with: 5
      fill_in "personnel_rank5_count", with: 10
      fill_in "personnel_rank6_count", with: 20
      fill_in "personnel_rank7_count", with: 50

      expect(page).to have_css(
        "[data-personnel-calculator-target='totalCount']",
        exact_text: "91"
      )

      # Every standard target has a formatted decimal (vi-VN "1.234,56" or en)
      %w[livingStandard waterStandard totalStandard].each do |target|
        expect(page).to have_css(
          "[data-personnel-calculator-target='#{target}']",
          text: /\d[.,]\d/
        )
      end
    end

    it "persists the submitted counts and shows the saved flash" do
      visit contact_point_personnel_path(cp)

      fill_in "personnel_rank1_count", with: 1
      expect(page).to have_css(
        "[data-personnel-calculator-target='totalCount']",
        exact_text: "1"
      )
      fill_in "personnel_rank5_count", with: 10
      fill_in "personnel_rank7_count", with: 40

      click_on I18n.t("personnel.form.submit")
      expect(page).to have_content(I18n.t("flash.personnel.saved"))

      personnel = cp.personnel_records.find_by!(monthly_period: scenario.period)
      expect(personnel.rank1_count).to eq(1)
      expect(personnel.rank5_count).to eq(10)
      expect(personnel.rank7_count).to eq(40)
      expect(personnel.total_count).to eq(51)
    end

    it "switches periods via the period selector" do
      jan = create(:monthly_period, year: 2026, month: 1)
      create(:personnel,
             contact_point: cp, monthly_period: jan,
             rank1_count: 7, rank2_count: 0, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      visit contact_point_personnel_path(cp, period_id: jan.id)

      # January's saved value is pre-filled in the rank1 input
      expect(find("input#personnel_rank1_count").value).to eq("7")

      # Switching via the select_tag triggers `window.location.href = ...`
      select jan.label, from: "period_id"
      # Ensure we land back at /contact_points/:id/personnel?period_id=X
      expect(page).to have_current_path(contact_point_personnel_path(cp, period_id: jan.id))
    end
  end

  # ---------------------------------------------------------------------------
  # commander — read-only view (inputs disabled, submit hidden)
  # ---------------------------------------------------------------------------
  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "renders inputs disabled and hides the submit button" do
      create(:personnel,
             contact_point: cp, monthly_period: scenario.period,
             rank1_count: 2, rank2_count: 3, rank3_count: 0,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0)

      visit contact_point_personnel_path(cp)

      (1..7).each do |i|
        expect(page).to have_css("input#personnel_rank#{i}_count[disabled]")
      end
      expect(page).not_to have_button(I18n.t("personnel.form.submit"))
    end
  end
end
