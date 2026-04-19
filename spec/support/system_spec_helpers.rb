require "ostruct"

module SystemSpecHelpers
  # Sets up the baseline org tree + 4 role users + 7 rank quotas + one period.
  # Returns a Struct-like object so tests can reach data via `scenario.unit`,
  # `scenario.admin_level1`, etc.
  def setup_basic_scenario(year: 2026, month: 2)
    division = create(:organization, :division)
    unit     = create(:organization, :unit, parent: division)
    (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
    period = create(:monthly_period, year: year, month: month)
    OpenStruct.new(
      division: division,
      unit: unit,
      period: period,
      admin_unit:   create(:user, :admin_unit,   organization: unit),
      admin_level1: create(:user, :admin_level1, organization: division),
      commander:    create(:user, :commander,    organization: unit),
      tech:         create(:user, :tech,         organization: division)
    )
  end

  # Creates a full end-to-end data set for one contact point under the given
  # scenario's unit — personnel + meter + reading + unit_config — so engine
  # spec can run and produce a non-empty monthly_calculation row.
  def create_full_calculation_data(scenario, personnel_counts: { rank1: 2, rank5: 10 })
    cp = create(:contact_point, organization: scenario.unit)
    create(:personnel,
           contact_point: cp, monthly_period: scenario.period,
           rank1_count: personnel_counts[:rank1] || 0,
           rank2_count: 0, rank3_count: 0, rank4_count: 0,
           rank5_count: personnel_counts[:rank5] || 0,
           rank6_count: 0, rank7_count: 0)
    meter = create(:meter, :normal, contact_point: cp, organization: scenario.unit)
    create(:meter_reading,
           meter: meter, monthly_period: scenario.period,
           reading_start: 100, reading_end: 500, consumption: 400)
    create(:unit_config,
           organization: scenario.unit, monthly_period: scenario.period,
           savings_rate: 0.05, division_public_rate: 0.10,
           unit_public_rate: 0.0, electricity_supply_kw: 50_000)
    cp
  end

  # Drives the Devise login form in a browser. F16 / F17 need the real form
  # because Warden's `login_as` bypasses the lockable and force-password
  # redirects we actually want to exercise.
  def sign_in_via_form(email, password)
    visit new_user_session_path
    fill_in "Email",    with: email
    fill_in "Mật khẩu", with: password
    click_button "Đăng nhập"
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
