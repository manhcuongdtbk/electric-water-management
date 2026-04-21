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

  # Standard viewport capture. Used for most screenshots — the visible 1280×900
  # viewport is sufficient for users to recognize the interface in the guide.
  def ss(name)
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png"))
  end

  # True full-page capture. Only #07 needs this — the personnel form has a
  # "Kết quả tính toán" section below the 7-rank-group table that the guide
  # text references explicitly and the viewport cuts off.
  #
  # The app layout (`application.html.erb`) uses `flex h-screen overflow-hidden`
  # on the outer wrapper with scrollable `<main class="overflow-auto">` inside,
  # so `document.body.scrollHeight` is clamped to the viewport. We temporarily
  # flatten these clamps, measure the natural content height, resize the
  # browser window to fit (with ~200px margin for the outer-vs-inner delta),
  # snap, then restore the original window size via `ensure`. DOM mutations
  # don't leak because the next test `visit`s a fresh page.
  def save_full_page_screenshot(name)
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
    window.resize_to(1280, height + 200)
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
  # 07 — Personnel form (7-group headcount entry for a contact point).
  # Full-page: the guide references the "Kết quả tính toán" section below the
  # rank-group table, which falls outside the viewport.
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
  # 12 — 22-column calculation table (adaptive horizontal scroll).
  # Measures scrollWidth / clientWidth of the overflow container, then takes
  # ceil(scrollWidth / clientWidth) screenshots that together cover every
  # column. Files: 12_calculation_table.png, 12b_calculation_table.png, …
  # After capturing, prints which columns appear in each screenshot and
  # asserts that every <th> is covered by at least one capture.
  #
  # NOTE: a "#13 — admin_level1 all-units view" was removed because the seed
  # only creates one cấp-2 unit (SDB) — the view is byte-identical to #12.
  # Re-add when the seed grows.
  # ---------------------------------------------------------------------------
  it "12_calculation_table" do
    login_as @admin_level1, scope: :user
    visit monthly_summary_path(period_id: @period.id, org_id: @sdb.id)

    dims = page.evaluate_script(<<~JS)
      (function() {
        var el = document.querySelector('.overflow-x-auto');
        if (!el) return { scrollWidth: window.innerWidth, clientWidth: window.innerWidth };
        return { scrollWidth: el.scrollWidth, clientWidth: el.clientWidth };
      })()
    JS

    scroll_width = dims["scrollWidth"].to_i
    client_width = dims["clientWidth"].to_i
    num_shots    = (scroll_width.to_f / client_width).ceil.clamp(1, 26)

    # Measure column positions while scroll is at 0 (initial state)
    col_info = page.evaluate_script(<<~JS)
      (function() {
        var container = document.querySelector('.overflow-x-auto');
        if (!container) return [];
        var cRect = container.getBoundingClientRect();
        return Array.from(document.querySelectorAll('table thead th')).map(function(th) {
          var tRect = th.getBoundingClientRect();
          return {
            text: th.innerText.trim().replace(/\\n+/g, ' '),
            left: Math.round(tRect.left - cRect.left),
            width: th.offsetWidth
          };
        });
      })()
    JS

    suffixes = [ "" ] + ("b".."z").to_a
    coverage  = {}

    num_shots.times do |i|
      scroll_pos = (i == num_shots - 1) ? scroll_width : i * client_width

      page.execute_script(
        "var el = document.querySelector('.overflow-x-auto'); if (el) el.scrollLeft = #{scroll_pos};"
      )
      sleep 0.15

      suffix    = suffixes[i]
      file_name = "12#{suffix}_calculation_table"
      ss file_name

      actual_left   = [ scroll_pos, [ scroll_width - client_width, 0 ].max ].min
      visible_start = actual_left
      visible_end   = actual_left + client_width

      coverage[file_name] = col_info.select do |c|
        left  = c["left"].to_i
        right = left + c["width"].to_i
        right > visible_start && left < visible_end
      end.map { |c| c["text"] }

      puts "Screenshot #{file_name}.png: #{coverage[file_name].join(' | ')}"
    end

    all_headers  = col_info.map { |c| c["text"] }.uniq
    covered_hdrs = coverage.values.flatten.uniq
    uncovered    = all_headers - covered_hdrs

    puts "\nTotal columns: #{all_headers.size} | Screenshots: #{num_shots}"
    puts "Uncovered columns: #{uncovered.inspect}" if uncovered.any?

    expect(uncovered).to be_empty,
      "Columns not visible in any screenshot: #{uncovered.join(', ')}"
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
