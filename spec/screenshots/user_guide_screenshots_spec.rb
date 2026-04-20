require "rails_helper"

# Not a real test — navigation + screenshot utility for the user guide.
# Excluded from the default rspec run via `screenshots: true` tag.
#
# Run with: bundle exec rspec --tag screenshots
# Output:   tmp/screenshots/*.png (covered by /tmp/* in .gitignore)
# ImportFeb2026Service takes ~5-10s — data is set up once via before(:context).
RSpec.describe "User Guide Screenshots", type: :system, js: true, screenshots: true do
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

  # Capture a true full-page screenshot.
  #
  # The app layout (`application.html.erb`) uses `flex h-screen overflow-hidden`
  # on the outer wrapper with scrollable `<main class="overflow-auto">` inside,
  # so `document.body.scrollHeight` is clamped to the viewport. We temporarily
  # flatten these clamps, measure the natural content height, resize the
  # browser window to fit (with ~140px margin for the outer-vs-inner delta),
  # snap, then restore the original window size via `ensure`. DOM mutations
  # don't leak because the next test `visit`s a fresh page.
  #
  # `width:` overrides the capture width (default 1280). Test #12 passes a
  # wider value so the full 22-column calculation table is captured without
  # horizontal clipping.
  def save_full_page_screenshot(name, width: 1280)
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    window = page.driver.browser.manage.window
    original = window.size

    page.execute_script(<<~JS)
      document.querySelectorAll('.h-screen').forEach(function(el) { el.style.height = 'auto'; });
      document.querySelectorAll('.overflow-hidden, .overflow-auto, .overflow-y-auto').forEach(function(el) {
        el.style.overflow = 'visible';
      });
    JS

    height = page.evaluate_script(
      "Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)"
    ).to_i
    window.resize_to(width, height + 200)
    sleep 0.3
    page.save_screenshot(path)
  ensure
    window.resize_to(original.width, original.height) if original
  end

  # ---------------------------------------------------------------------------
  # 01 — Login page (unauthenticated, root redirects to sign-in)
  # ---------------------------------------------------------------------------
  it "01_login_page" do
    visit root_path
    save_full_page_screenshot "01_login_page"
  end

  # ---------------------------------------------------------------------------
  # 02 — Force password change (login_as user with flag, root redirects)
  # ---------------------------------------------------------------------------
  it "02_force_password_change" do
    login_as @force_user, scope: :user
    visit root_path
    save_full_page_screenshot "02_force_password_change"
  end

  # ---------------------------------------------------------------------------
  # 03 — Contact points list (SDB has 79 contact points after import)
  # ---------------------------------------------------------------------------
  it "03_contact_points_list" do
    login_as @admin_unit, scope: :user
    visit contact_points_path
    save_full_page_screenshot "03_contact_points_list"
  end

  # ---------------------------------------------------------------------------
  # 04 — New contact point form
  # ---------------------------------------------------------------------------
  it "04_contact_point_new" do
    login_as @admin_unit, scope: :user
    visit new_contact_point_path
    save_full_page_screenshot "04_contact_point_new"
  end

  # ---------------------------------------------------------------------------
  # 05 — Meters list (nested under a contact point from SDB)
  # ---------------------------------------------------------------------------
  it "05_meters_list" do
    login_as @admin_unit, scope: :user
    visit contact_point_meters_path(@cp)
    save_full_page_screenshot "05_meters_list"
  end

  # ---------------------------------------------------------------------------
  # 06 — New meter form
  # ---------------------------------------------------------------------------
  it "06_meter_new" do
    login_as @admin_unit, scope: :user
    visit new_contact_point_meter_path(@cp)
    save_full_page_screenshot "06_meter_new"
  end

  # ---------------------------------------------------------------------------
  # 07 — Personnel form (7-group headcount entry for a contact point)
  # ---------------------------------------------------------------------------
  it "07_personnel_form" do
    login_as @admin_unit, scope: :user
    visit contact_point_personnel_path(@cp, period_id: @period.id)
    save_full_page_screenshot "07_personnel_form"
  end

  # ---------------------------------------------------------------------------
  # 08 — Unit config (savings rate, public rates, etc.)
  # ---------------------------------------------------------------------------
  it "08_unit_config" do
    login_as @admin_unit, scope: :user
    visit unit_config_path
    save_full_page_screenshot "08_unit_config"
  end

  # ---------------------------------------------------------------------------
  # 09 — Electricity supply (F05 — total kWh supplied this period)
  # ---------------------------------------------------------------------------
  it "09_electricity_supply" do
    login_as @admin_unit, scope: :user
    visit electricity_supply_path
    save_full_page_screenshot "09_electricity_supply"
  end

  # ---------------------------------------------------------------------------
  # 10 — Meter readings batch form (F06 — all meters for the unit)
  # ---------------------------------------------------------------------------
  it "10_meter_readings" do
    login_as @admin_unit, scope: :user
    visit meter_readings_path
    save_full_page_screenshot "10_meter_readings"
  end

  # ---------------------------------------------------------------------------
  # 11 — Personnel review (F07 — all contact points with review status)
  # ---------------------------------------------------------------------------
  it "11_personnel_review" do
    login_as @admin_level1, scope: :user
    visit personnel_review_path(period_id: @period.id)
    save_full_page_screenshot "11_personnel_review"
  end

  # ---------------------------------------------------------------------------
  # 12 — 22-column calculation table for SDB (F11), full width (no clipping)
  # Temporarily drops overflow-x clip on the container so the full table renders
  # into the capture when the window is widened to the table's intrinsic width.
  # ---------------------------------------------------------------------------
  it "12_calculation_table" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id, org_id: @sdb.id)
    full_width = page.evaluate_script(<<~JS).to_i
      (function() {
        var el = document.querySelector('.overflow-x-auto');
        if (!el) return 1280;
        el.style.overflowX = 'visible';
        var t = el.querySelector('table');
        return Math.max(el.scrollWidth, t ? t.scrollWidth : 0);
      })();
    JS
    save_full_page_screenshot "12_calculation_table", width: [ full_width + 40, 1280 ].max
  end

  # ---------------------------------------------------------------------------
  # 13 — Admin level-1 view: org dropdown visible (no org_id → shows selector)
  # ---------------------------------------------------------------------------
  it "13_admin_l1_all_units" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id)
    save_full_page_screenshot "13_admin_l1_all_units"
  end

  # ---------------------------------------------------------------------------
  # 14 — Unlock button on a locked period (admin_level1 only)
  # ---------------------------------------------------------------------------
  it "14_admin_l1_unlock" do
    login_as @admin_level1, scope: :user
    visit personnel_review_path(period_id: @locked_period.id)
    save_full_page_screenshot "14_admin_l1_unlock"
  end

  # ---------------------------------------------------------------------------
  # 15 — Users list (F15 — tech user can see all accounts)
  # ---------------------------------------------------------------------------
  it "15_users_list" do
    login_as @tech, scope: :user
    visit users_path
    save_full_page_screenshot "15_users_list"
  end

  # ---------------------------------------------------------------------------
  # 16 — New user form (F15 — create account form)
  # ---------------------------------------------------------------------------
  it "16_user_new" do
    login_as @tech, scope: :user
    visit new_user_path
    save_full_page_screenshot "16_user_new"
  end

  # ===========================================================================
  # SUPPLEMENTAL — full-page + horizontal-scroll captures
  # ===========================================================================

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
    save_full_page_screenshot "12a_calculation_table_left"
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
    save_full_page_screenshot "12b_calculation_table_right"
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
      save_full_page_screenshot "17_timeout_warning"
    else
      skip "session-timeout Stimulus controller not found on page — modal cannot be triggered via JS"
    end
  end
end
