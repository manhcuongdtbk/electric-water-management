require "rails_helper"

# Not a real test — navigation + screenshot utility for the user guide.
# Run with: bundle exec rspec spec/screenshots/user_guide_screenshots_spec.rb
#
# Output: tmp/screenshots/*.png (covered by /tmp/* in .gitignore)
# ImportFeb2026Service takes ~5-10s — data is set up once via before(:context).
RSpec.describe "User Guide Screenshots", type: :system, js: true do
  # ---------------------------------------------------------------------------
  # One-time data setup: import Feb 2026 real data + supporting records
  # ---------------------------------------------------------------------------
  before(:context) do
    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))

    @division = FactoryBot.create(:organization, :division, name: "Sư đoàn")
    @sdb      = FactoryBot.create(:organization, :unit, parent: @division,
                                   code: "SDB", name: "Sư đoàn bộ")

    # Users must be created before monthly_periods so locked_by FK can reference them
    @admin_level1 = FactoryBot.create(:user, :admin_level1, organization: @division)
    @admin_unit   = FactoryBot.create(:user, :admin_unit,   organization: @sdb)
    @force_user   = FactoryBot.create(:user, :admin_unit,   organization: @sdb,
                                       force_password_change: true)
    @tech         = FactoryBot.create(:user, :tech,          organization: @division)

    # Rank quotas required by ImportFeb2026Service
    (1..7).each { |g| FactoryBot.create(:rank_quota, :"rank#{g}") }

    # Import real February 2026 data (~79 contact points, meters, readings, personnel)
    @result = ImportFeb2026Service.new.call
    @period = @result.period

    # Separate locked period (2026-01) for the unlock-button screenshot
    @locked_period = FactoryBot.create(:monthly_period, :locked,
                                        year: 2026, month: 1,
                                        locked_by: @admin_level1)

    # Pick a contact point from SDB for nested-resource screenshots
    @cp = ContactPoint.where(organization_id: @sdb.id).first
  end

  after(:context) do
    ApplicationRecord.connection.execute(
      "TRUNCATE TABLE organizations, monthly_periods, rank_quotas, users, " \
      "contact_points, meters, personnel, meter_readings, unit_configs, " \
      "pump_stations, pump_station_assignments, monthly_calculations, " \
      "contact_point_other_deductions, versions RESTART IDENTITY CASCADE"
    )
  end

  before do
    page.driver.browser.manage.window.resize_to(1280, 900)
  end

  def ss(name)
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    # Resize window to page height so the full page is captured in one viewport
    height = page.evaluate_script("document.body.scrollHeight").to_i
    page.driver.browser.manage.window.resize_to(1280, [ height, 900 ].max)
    page.save_screenshot(path)
  end

  # Full-page variant: uses documentElement.scrollHeight (more reliable than body
  # for flex/grid layouts that clamp body height to viewport), capped at 3000px.
  def ss_full(name)
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    height = page.evaluate_script(
      "Math.min(Math.max(document.documentElement.scrollHeight, document.body.scrollHeight, 900), 3000)"
    ).to_i
    page.driver.browser.manage.window.resize_to(1280, height)
    page.save_screenshot(path)
  end

  # ---------------------------------------------------------------------------
  # 01 — Login page (unauthenticated, root redirects to sign-in)
  # ---------------------------------------------------------------------------
  it "01_login_page" do
    visit root_path
    ss "01_login_page"
  end

  # ---------------------------------------------------------------------------
  # 02 — Force password change (login_as user with flag, root redirects)
  # ---------------------------------------------------------------------------
  it "02_force_password_change" do
    login_as @force_user, scope: :user
    visit root_path
    ss "02_force_password_change"
  end

  # ---------------------------------------------------------------------------
  # 03 — Contact points list (SDB has 79 contact points after import)
  # ---------------------------------------------------------------------------
  it "03_contact_points_list" do
    login_as @admin_unit, scope: :user
    visit contact_points_path
    ss "03_contact_points_list"
  end

  # ---------------------------------------------------------------------------
  # 04 — New contact point form
  # ---------------------------------------------------------------------------
  it "04_contact_point_new" do
    login_as @admin_unit, scope: :user
    visit new_contact_point_path
    ss "04_contact_point_new"
  end

  # ---------------------------------------------------------------------------
  # 05 — Meters list (nested under a contact point from SDB)
  # ---------------------------------------------------------------------------
  it "05_meters_list" do
    login_as @admin_unit, scope: :user
    visit contact_point_meters_path(@cp)
    ss "05_meters_list"
  end

  # ---------------------------------------------------------------------------
  # 06 — New meter form
  # ---------------------------------------------------------------------------
  it "06_meter_new" do
    login_as @admin_unit, scope: :user
    visit new_contact_point_meter_path(@cp)
    ss "06_meter_new"
  end

  # ---------------------------------------------------------------------------
  # 07 — Personnel form (7-group headcount entry for a contact point)
  # ---------------------------------------------------------------------------
  it "07_personnel_form" do
    login_as @admin_unit, scope: :user
    visit contact_point_personnel_path(@cp, period_id: @period.id)
    ss "07_personnel_form"
  end

  # ---------------------------------------------------------------------------
  # 08 — Unit config (savings rate, public rates, etc.)
  # ---------------------------------------------------------------------------
  it "08_unit_config" do
    login_as @admin_unit, scope: :user
    visit unit_config_path
    ss "08_unit_config"
  end

  # ---------------------------------------------------------------------------
  # 09 — Electricity supply (F05 — total kWh supplied this period)
  # ---------------------------------------------------------------------------
  it "09_electricity_supply" do
    login_as @admin_unit, scope: :user
    visit electricity_supply_path
    ss "09_electricity_supply"
  end

  # ---------------------------------------------------------------------------
  # 10 — Meter readings batch form (F06 — all meters for the unit)
  # ---------------------------------------------------------------------------
  it "10_meter_readings" do
    login_as @admin_unit, scope: :user
    visit meter_readings_path
    ss "10_meter_readings"
  end

  # ---------------------------------------------------------------------------
  # 11 — Personnel review (F07 — all contact points with review status)
  # ---------------------------------------------------------------------------
  it "11_personnel_review" do
    login_as @admin_level1, scope: :user
    visit personnel_review_path(period_id: @period.id)
    ss "11_personnel_review"
  end

  # ---------------------------------------------------------------------------
  # 12 — 22-column calculation table for SDB (F11)
  # ---------------------------------------------------------------------------
  it "12_calculation_table" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id, org_id: @sdb.id)
    ss "12_calculation_table"
  end

  # ---------------------------------------------------------------------------
  # 13 — Admin level-1 view: org dropdown visible (no org_id → shows selector)
  # ---------------------------------------------------------------------------
  it "13_admin_l1_all_units" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id)
    ss "13_admin_l1_all_units"
  end

  # ---------------------------------------------------------------------------
  # 14 — Unlock button on a locked period (admin_level1 only)
  # ---------------------------------------------------------------------------
  it "14_admin_l1_unlock" do
    login_as @admin_level1, scope: :user
    visit personnel_review_path(period_id: @locked_period.id)
    ss "14_admin_l1_unlock"
  end

  # ---------------------------------------------------------------------------
  # 15 — Users list (F15 — tech user can see all accounts)
  # ---------------------------------------------------------------------------
  it "15_users_list" do
    login_as @tech, scope: :user
    visit users_path
    ss "15_users_list"
  end

  # ---------------------------------------------------------------------------
  # 16 — New user form (F15 — create account form)
  # ---------------------------------------------------------------------------
  it "16_user_new" do
    login_as @tech, scope: :user
    visit new_user_path
    ss "16_user_new"
  end

  # ===========================================================================
  # SUPPLEMENTAL — full-page + horizontal-scroll captures
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # 03_full — Contact points list, full page (79 rows, no viewport clipping)
  # ---------------------------------------------------------------------------
  it "03_full_contact_points_list" do
    login_as @admin_unit, scope: :user
    visit contact_points_path
    ss_full "03_full_contact_points_list"
  end

  # ---------------------------------------------------------------------------
  # 08_full — Unit config, full page (includes Khác section below the fold)
  # ---------------------------------------------------------------------------
  it "08_full_unit_config" do
    login_as @admin_unit, scope: :user
    visit unit_config_path
    ss_full "08_full_unit_config"
  end

  # ---------------------------------------------------------------------------
  # 11_full — Personnel review, full page (all contact points visible)
  # ---------------------------------------------------------------------------
  it "11_full_personnel_review" do
    login_as @admin_level1, scope: :user
    visit personnel_review_path(period_id: @period.id)
    ss_full "11_full_personnel_review"
  end

  # ---------------------------------------------------------------------------
  # 12a — 22-column table, left half (Quân số + Tiêu chuẩn columns)
  # ---------------------------------------------------------------------------
  it "12a_calculation_table_left" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id, org_id: @sdb.id)
    # Reset any horizontal scroll to show the leftmost columns
    page.execute_script(<<~JS)
      var el = document.querySelector('.overflow-x-auto') ||
               document.querySelector('[style*="overflow-x"]') ||
               (document.querySelector('table') && document.querySelector('table').closest('div'));
      if (el) el.scrollLeft = 0;
    JS
    ss_full "12a_calculation_table_left"
  end

  # ---------------------------------------------------------------------------
  # 12b — 22-column table, right half (Sử dụng + Chênh lệch + Thành tiền)
  # ---------------------------------------------------------------------------
  it "12b_calculation_table_right" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id, org_id: @sdb.id)
    page.execute_script(<<~JS)
      var el = document.querySelector('.overflow-x-auto') ||
               document.querySelector('[style*="overflow-x"]') ||
               (document.querySelector('table') && document.querySelector('table').closest('div'));
      if (el) el.scrollLeft = 800;
    JS
    ss_full "12b_calculation_table_right"
  end

  # ---------------------------------------------------------------------------
  # 17 — Session timeout warning modal
  # Triggered via JS by setting expires-at to 300s from now (< 600s threshold).
  # Skipped if the Stimulus controller is not present on the page.
  # ---------------------------------------------------------------------------
  it "17_timeout_warning" do
    login_as @admin_level1, scope: :user
    visit contact_points_path

    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller="session-timeout"]');
      if (el) {
        el.setAttribute(
          'data-session-timeout-expires-at-value',
          Math.floor(Date.now() / 1000) + 300
        );
      }
    JS

    if page.has_selector?('[data-session-timeout-target="modal"]', visible: true, wait: 5)
      ss "17_timeout_warning"
    else
      skip "session-timeout Stimulus controller not found on page — modal cannot be triggered via JS"
    end
  end
end
