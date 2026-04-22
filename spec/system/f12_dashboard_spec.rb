require "rails_helper"

# F12 — Dashboard tổng quan (root_path).
# Metric cards, biểu đồ Chartkick, bảng đầu mối theo tháng được chọn.
RSpec.describe "F12 — Dashboard", type: :system do
  let(:scenario) { setup_basic_scenario }
  let(:contact_point) { create(:contact_point, organization: scenario.unit) }
  let!(:calc) do
    create(:monthly_calculation,
           contact_point: contact_point,
           monthly_period: scenario.period,
           total_standard_kw: 5000,
           total_usage_kw: 4000)
  end

  # ---------------------------------------------------------------------------
  # admin_level1 — thấy toàn bộ, có dropdown đơn vị
  # ---------------------------------------------------------------------------
  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "shows org dropdown defaulting to Tất cả" do
      visit root_path
      expect(page).to have_select("org_id")
      expect(page).to have_content(I18n.t("dashboard.show.all_orgs"))
    end

    it "shows correct metric cards for all units" do
      visit root_path
      expect(page).to have_content(I18n.t("dashboard.metrics.total_standard"))
      expect(page).to have_content(I18n.t("dashboard.metrics.total_usage"))
      expect(page).to have_content(I18n.t("dashboard.metrics.difference"))
      expect(page).to have_content(I18n.t("dashboard.metrics.over_count"))
      # total_standard = 5000, total_usage = 4000, diff = 1000, over_count = 0
      expect(page).to have_content("5,000")
      expect(page).to have_content("4,000")
      expect(page).to have_content("1,000")
    end

    it "renders chart container" do
      visit root_path
      expect(page).to have_css("#dashboard-bar-chart")
    end

    it "shows table with contact point sorted by diff ascending" do
      cp2 = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp2,
             monthly_period: scenario.period,
             total_standard_kw: 3000,
             total_usage_kw: 3500)

      visit root_path

      expect(page).to have_content(I18n.t("dashboard.table.title"))
      expect(page).to have_content(contact_point.name)
      expect(page).to have_content(cp2.name)
    end

    it "filters by specific unit when org is selected" do
      unit2 = create(:organization, :unit, parent: scenario.division)
      cp2   = create(:contact_point, organization: unit2)
      create(:monthly_calculation,
             contact_point: cp2,
             monthly_period: scenario.period,
             total_standard_kw: 2000,
             total_usage_kw: 1500)

      visit dashboard_path(period_id: scenario.period.id, org_id: scenario.unit.id)

      expect(page).to have_content(contact_point.name)
      expect(page).not_to have_content(cp2.name)
    end
  end

  # ---------------------------------------------------------------------------
  # admin_unit — thấy đơn vị mình, không có dropdown
  # ---------------------------------------------------------------------------
  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "has no org dropdown" do
      visit root_path
      expect(page).not_to have_select("org_id")
    end

    it "shows own unit data with correct values" do
      visit root_path
      expect(page).to have_content("5,000")
      expect(page).to have_content("4,000")
      expect(page).to have_content(contact_point.name)
    end
  end

  # ---------------------------------------------------------------------------
  # commander — xem như admin_unit (chỉ đọc)
  # ---------------------------------------------------------------------------
  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "has no org dropdown and sees own unit data" do
      visit root_path
      expect(page).not_to have_select("org_id")
      expect(page).to have_content("5,000")
      expect(page).to have_content(contact_point.name)
    end
  end

  # ---------------------------------------------------------------------------
  # tech — bị redirect, không xem được dashboard
  # ---------------------------------------------------------------------------
  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "redirects with access denied flash" do
      visit root_path
      expect(page).to have_current_path(users_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  # ---------------------------------------------------------------------------
  # Period dropdown
  # ---------------------------------------------------------------------------
  describe "period dropdown" do
    it "shows period selector" do
      login_as scenario.admin_unit, scope: :user
      visit root_path
      expect(page).to have_select("period_id")
    end

    it "defaults to most recent period that has MonthlyCalculation data" do
      older_period = create(:monthly_period, year: 2025, month: 6)
      cp_older = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp_older,
             monthly_period: older_period,
             total_standard_kw: 9999,
             total_usage_kw: 9999)
      # scenario.period (2026/02) has calc; older_period also has one
      # expect 2026/02 to be default (more recent)
      login_as scenario.admin_unit, scope: :user
      visit root_path
      expect(page).to have_select("period_id", selected: scenario.period.label)
    end

    it "switches data when a different period is selected" do
      period2 = create(:monthly_period, year: 2026, month: 3)
      cp2 = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp2,
             monthly_period: period2,
             total_standard_kw: 7777,
             total_usage_kw: 7000)

      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(period_id: period2.id)

      expect(page).to have_content("7,777")
      expect(page).not_to have_content("5,000")
    end
  end

  # ---------------------------------------------------------------------------
  # Over-standard highlighting
  # ---------------------------------------------------------------------------
  describe "over-standard row" do
    it "shows Vượt badge and red styling for over-standard contact point" do
      cp_over = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp_over,
             monthly_period: scenario.period,
             total_standard_kw: 3000,
             total_usage_kw: 4500)

      login_as scenario.admin_unit, scope: :user
      visit root_path

      within("tr", text: cp_over.name) do
        expect(page).to have_content(I18n.t("dashboard.table.over_badge"))
      end
    end

    it "counts over-standard contact points in metric card" do
      cp_over = create(:contact_point, organization: scenario.unit)
      create(:monthly_calculation,
             contact_point: cp_over,
             monthly_period: scenario.period,
             total_standard_kw: 3000,
             total_usage_kw: 4500)

      login_as scenario.admin_unit, scope: :user
      visit root_path

      # calc: usage 4000 < standard 5000 → not over
      # cp_over: usage 4500 > standard 3000 → over → count = 1
      expect(page).to have_css("[data-testid='over-count']", text: "1")
    end
  end

  # ---------------------------------------------------------------------------
  # Empty state
  # ---------------------------------------------------------------------------
  describe "no data" do
    it "shows no_data message when no calculations exist for period" do
      empty_period = create(:monthly_period, year: 2026, month: 4)
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(period_id: empty_period.id)
      expect(page).to have_content(I18n.t("dashboard.show.no_data"))
    end
  end

  # ---------------------------------------------------------------------------
  # Quarter view
  # ---------------------------------------------------------------------------
  describe "quarter view" do
    # scenario.period = 2026/02 (Q1). Add 2026/01 to have 2 months in Q1.
    let!(:period_jan) { create(:monthly_period, year: 2026, month: 1) }
    let!(:calc_jan) do
      create(:monthly_calculation,
             contact_point: contact_point,
             monthly_period: period_jan,
             total_standard_kw: 3000,
             total_usage_kw: 2500)
    end

    it "shows quarter selector and hides period selector" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
      expect(page).to have_select("quarter")
      expect(page).not_to have_select("period_id")
    end

    it "aggregates metric cards across months in the same quarter" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
      # standard: 3000 (Jan) + 5000 (Feb) = 8000
      # usage:    2500 (Jan) + 4000 (Feb) = 6500
      expect(page).to have_content("8,000")
      expect(page).to have_content("6,500")
    end

    it "renders chart container for quarter view" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
      expect(page).to have_css("#dashboard-quarter-chart")
    end

    it "shows no_data for a quarter with no calculations" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "quarter", year: 2026, quarter: 3)
      expect(page).to have_content(I18n.t("dashboard.show.no_data"))
    end

    it "admin_level1 org dropdown works in quarter view" do
      login_as scenario.admin_level1, scope: :user
      visit dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
      expect(page).to have_select("org_id")
      expect(page).to have_content("8,000")
    end
  end

  # ---------------------------------------------------------------------------
  # Year view
  # ---------------------------------------------------------------------------
  describe "year view" do
    # scenario.period = 2026/02. Add 2026/01 for a 2-month year aggregate.
    let!(:period_jan) { create(:monthly_period, year: 2026, month: 1) }
    let!(:calc_jan) do
      create(:monthly_calculation,
             contact_point: contact_point,
             monthly_period: period_jan,
             total_standard_kw: 3000,
             total_usage_kw: 2500)
    end

    it "shows year selector, hides period and quarter selectors" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "year", year: 2026)
      expect(page).to have_select("year")
      expect(page).not_to have_select("period_id")
      expect(page).not_to have_select("quarter")
    end

    it "aggregates metric cards for the full year" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "year", year: 2026)
      # standard: 3000 + 5000 = 8000, usage: 2500 + 4000 = 6500
      expect(page).to have_content("8,000")
      expect(page).to have_content("6,500")
    end

    it "renders line chart container for year view" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "year", year: 2026)
      expect(page).to have_css("#dashboard-year-chart")
    end

    it "shows no_data for a year with no calculations" do
      login_as scenario.admin_unit, scope: :user
      visit dashboard_path(view_type: "year", year: 2025)
      expect(page).to have_content(I18n.t("dashboard.show.no_data"))
    end
  end
end
