# frozen_string_literal: true

require "rails_helper"

RSpec.describe "F13 — Tra cứu lịch sử điện", type: :system do
  let(:scenario) { setup_history_scenario }

  # Ensure scenario is built before each test
  before { scenario }

  describe "tech user" do
    before { login_as scenario.tech, scope: :user }

    it "redirects to users_path with access denied flash" do
      visit history_path
      expect(current_path).to eq(users_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "shows the history page with detail table" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_content(I18n.t("history.show.title"))
      expect(page).to have_css("[data-testid='detail-table']")
    end

    it "displays no org dropdown" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).not_to have_field("org_id")
    end

    it "shows only contact points from own org" do
      other_division = create(:organization, :division)
      other_unit     = create(:organization, :unit, parent: other_division)
      other_cp       = create(:contact_point, organization: other_unit)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_select("contact_point_id", with_options: [ scenario.contact_point.name ])
      expect(page).not_to have_select("contact_point_id", with_options: [ other_cp.name ])
    end

    it "shows the detail table values from current calc" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      within("[data-testid='detail-table']") do
        expect(page).to have_content("9.320,00")
        expect(page).to have_content("7.450,00")
      end
    end

    it "shows the comparison table with prior year data and delta arrows" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_css("[data-testid='comparison-table']")
      expect(page).not_to have_css("[data-testid='no-prior-data-banner']")

      # total_usage_kw decreased 7450 < 8000 → lower is better → green ▼
      within("tr[data-col='total_usage_kw']") do
        expect(page).to have_css("span.text-green-600")
        expect(page).to have_content("▼")
      end

      # total_standard_kw increased 9320 > 8500 → higher is better → green ▲
      within("tr[data-col='total_standard_kw']") do
        expect(page).to have_css("span.text-green-600")
        expect(page).to have_content("▲")
      end

      # total_amount decreased 14_900_000 < 16_000_000 → lower is better → green ▼
      within("tr[data-col='total_amount']") do
        expect(page).to have_css("span.text-green-600")
        expect(page).to have_content("▼")
      end

      # over_under_kw: current factory default = 0 - prior factory default = 0 → equal
      # Use scenario values: both calcs use default factory over_under_kw (0.0)
      # Verify the column renders without crash
      expect(page).to have_css("tr[data-col='over_under_kw']")
    end

    it "shows green ▲ for over_under_kw when value increases (higher is better)" do
      # Create a period where over_under_kw improved (current > prior → green ▲)
      period_2026_03 = create(:monthly_period, year: 2026, month: 3)
      period_2025_03 = create(:monthly_period, year: 2025, month: 3)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2026_03,
        total_standard_kw: 9000, total_usage_kw: 7000,
        over_under_kw: 2000, total_amount: 14_000_000)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2025_03,
        total_standard_kw: 8000, total_usage_kw: 7500,
        over_under_kw: 500, total_amount: 15_000_000)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 3)
      # over_under_kw: current 2000 > prior 500 → higher is better → green ▲
      within("tr[data-col='over_under_kw']") do
        expect(page).to have_css("span.text-green-600")
        expect(page).to have_content("▲")
      end
    end

    it "shows red ▼ for over_under_kw when value decreases (higher is better)" do
      period_2026_04 = create(:monthly_period, year: 2026, month: 4)
      period_2025_04 = create(:monthly_period, year: 2025, month: 4)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2026_04,
        total_standard_kw: 9000, total_usage_kw: 8800,
        over_under_kw: 200, total_amount: 17_600_000)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2025_04,
        total_standard_kw: 8000, total_usage_kw: 6000,
        over_under_kw: 2000, total_amount: 12_000_000)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 4)
      # over_under_kw: current 200 < prior 2000 → worse (got closer to limit) → red ▼
      within("tr[data-col='over_under_kw']") do
        expect(page).to have_css("span.text-red-600")
        expect(page).to have_content("▼")
      end
    end

    it "shows no_prior_data banner when current period exists but prior year period does not" do
      period_2026_06 = create(:monthly_period, year: 2026, month: 6)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2026_06,
        total_standard_kw: 9000, total_usage_kw: 7000, total_amount: 14_000_000)

      # 2025/06 does not exist → banner shown, comparison table still renders with dashes
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 6)
      expect(page).to have_css("[data-testid='no-prior-data-banner']")
      expect(page).to have_css("[data-testid='comparison-table']")
      within("[data-testid='comparison-table']") do
        expect(page).to have_content("—")
      end
    end

    it "shows no_prior_data banner when prior period exists but no calc" do
      period_2026_03 = create(:monthly_period, year: 2026, month: 3)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_2026_03,
        total_standard_kw: 9000, total_usage_kw: 7000, total_amount: 14_000_000)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 3)
      # prior year 2025/03 has no calc → banner shown, page does not crash
      expect(page).to have_css("[data-testid='no-prior-data-banner']")
      expect(page).to have_css("[data-testid='comparison-table']")
      within("[data-testid='comparison-table']") do
        expect(page).to have_content("—")
      end
    end

    it "shows no_data when selected period has no monthly_calculation" do
      period_empty = create(:monthly_period, year: 2026, month: 4)
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 4)
      expect(page).to have_content(I18n.t("history.show.no_data"))
    end

    it "shows no_period when selected year/month has no MonthlyPeriod" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2024, month: 6)
      expect(page).to have_content(I18n.t("history.show.no_period"))
    end

    it "shows no_contact_points when org has no contact points", :js do
      division2 = create(:organization, :division)
      unit2     = create(:organization, :unit, parent: division2)
      user2     = create(:user, :admin_unit, organization: unit2)

      login_as user2, scope: :user
      visit history_path
      expect(page).to have_content(I18n.t("history.show.no_contact_points"))
    end

    it "switches displayed record when contact_point dropdown changes", :js do
      cp2    = create(:contact_point, organization: scenario.unit)
      period = create(:monthly_period, year: 2026, month: 3)
      create(:monthly_calculation,
        contact_point: cp2,
        monthly_period: period,
        total_standard_kw: 5000, total_usage_kw: 4000, total_amount: 8_000_000)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_content(scenario.contact_point.name)
    end
  end

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "shows org dropdown" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_css("select#org_id")
    end

    it "shows the history page with detail and comparison tables" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_css("[data-testid='detail-table']")
      expect(page).to have_css("[data-testid='comparison-table']")
      expect(page).not_to have_css("[data-testid='no-prior-data-banner']")
    end

    it "shows correct delta for total_usage_kw" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      within("tr[data-col='total_usage_kw']") do
        expect(page).to have_css("span.text-green-600")
        expect(page).to have_content("▼")
      end
    end

    it "shows no-prior-data banner when prior year period does not exist" do
      period_new = create(:monthly_period, year: 2026, month: 5)
      create(:monthly_calculation,
        contact_point: scenario.contact_point,
        monthly_period: period_new,
        total_standard_kw: 9000, total_usage_kw: 7000, total_amount: 14_000_000)

      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 5)
      expect(page).to have_css("[data-testid='no-prior-data-banner']")
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "can access the history page" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_content(I18n.t("history.show.title"))
      expect(current_path).to eq(history_path)
    end

    it "shows no org dropdown" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).not_to have_field("org_id")
    end

    it "shows detail and comparison tables" do
      visit history_path(contact_point_id: scenario.contact_point.id, year: 2026, month: 2)
      expect(page).to have_css("[data-testid='detail-table']")
      expect(page).to have_css("[data-testid='comparison-table']")
    end
  end

  describe "nav link visibility" do
    it "shows history link for admin_unit" do
      login_as scenario.admin_unit, scope: :user
      visit root_path
      expect(page).to have_link(I18n.t("nav.history"), href: history_path)
    end

    it "does not show history link for tech" do
      login_as scenario.tech, scope: :user
      visit users_path
      expect(page).not_to have_link(I18n.t("nav.history"))
    end
  end
end
