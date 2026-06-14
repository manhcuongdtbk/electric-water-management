# Per-page setup for the behavior guardrail (#373, ADR-058). The matrix
# (RoleBehaviorMatrix) is pure data; the divergent setup each page needs lives
# here as named methods, so `applies: { scenario: :blocks }` -> .blocks builds
# the world and returns a uniform Scenario struct the shared examples consume.
module RoleBehaviorScenarios
  Scenario = Struct.new(:path, :sa_user, :all_texts, :checks,
                        :columns, :column_users, :commander, :zm, keyword_init: true)

  module_function

  # Non-SA roles that can OPEN the page per the access matrix (so are subject to
  # scoping / commander / column behavior). Derived from the single source.
  def accessible_non_sa_roles(slug)
    RoleAccessMatrix::PAGES.fetch(slug)[:expect]
      .select { |_role, outcome| outcome == :ok }.keys - %i[sa tech]
  end

  # A zone with a manager-unit and an other-unit, plus an open period.
  # Mirrors role_access_matrix_spec.rb's world.
  def base_world
    zone = FactoryBot.create(:zone, name: "KV-#{SecureRandom.hex(3)}")
    unit_manager = FactoryBot.create(:unit, zone: zone, name: "DV-QL-#{SecureRandom.hex(3)}")
    unit_other   = FactoryBot.create(:unit, zone: zone, name: "DV-Khac-#{SecureRandom.hex(3)}")
    zone.update!(manager_unit_id: unit_manager.id)
    FactoryBot.create(:period, closed: false)
    { zone: zone, unit_manager: unit_manager, unit_other: unit_other }
  end

  # role -> the unit that role belongs to in base_world.
  def unit_for(role, world)
    %i[ua_zm cmd_zm].include?(role) ? world[:unit_manager] : world[:unit_other]
  end

  def make_user(role, world)
    case role
    when :sa     then FactoryBot.create(:user, :system_admin)
    when :ua_zm, :ua  then FactoryBot.create(:user, :unit_admin, unit: unit_for(role, world))
    when :cmd_zm, :cmd then FactoryBot.create(:user, :commander, unit: unit_for(role, world))
    when :tech   then FactoryBot.create(:user, :technician)
    end
  end

  # SampleData lives in a module included into example groups; this module uses
  # module_function, so build a tiny proxy that can call it (+ FactoryBot create).
  def sample_world
    proxy = Object.new
    proxy.extend(FactoryBot::Syntax::Methods)
    proxy.extend(SampleData)
    proxy.setup_zone_one_full_sample
  end

  # Users for the 4 accessible non-SA roles mapped onto the sample's units.
  def sample_role_users(sample)
    { ua_zm:  FactoryBot.create(:user, :unit_admin, unit: sample.unit_a),
      ua:     FactoryBot.create(:user, :unit_admin, unit: sample.unit_b),
      cmd_zm: FactoryBot.create(:user, :commander,  unit: sample.unit_a),
      cmd:    FactoryBot.create(:user, :commander,  unit: sample.unit_b) }
  end

  # Build data_scoping checks: unit_a-roles see own_a not own_b; unit_b-roles vice-versa.
  def unit_scoped_checks(users, text_a, text_b)
    [{ user: users[:ua_zm],  sees: text_a, hides: [text_b] },
     { user: users[:ua],     sees: text_b, hides: [text_a] },
     { user: users[:cmd_zm], sees: text_a, hides: [text_b] },
     { user: users[:cmd],    sees: text_b, hides: [text_a] }]
  end

  # Contact-point names that render on the target page, for unit_a and unit_b.
  # Picks the first kept CP (by id) that appears in the given scope for each unit.
  def sample_cp_names_for_meter_entries(sample)
    types = %w[residential public]
    a = ContactPoint.kept
                    .joins(:meters)
                    .where(unit: sample.unit_a, contact_point_type: types)
                    .order(:id).first&.name
    b = ContactPoint.kept
                    .joins(:meters)
                    .where(unit: sample.unit_b, contact_point_type: types)
                    .order(:id).first&.name
    [a, b]
  end

  def sample_cp_names_for_billing(sample)
    a = Calculation.where(period: sample.period)
                   .joins(:contact_point)
                   .where(contact_points: { unit: sample.unit_a,
                                            contact_point_type: "residential" })
                   .order("contact_points.id").first&.contact_point&.name
    b = Calculation.where(period: sample.period)
                   .joins(:contact_point)
                   .where(contact_points: { unit: sample.unit_b,
                                            contact_point_type: "residential" })
                   .order("contact_points.id").first&.contact_point&.name
    [a, b]
  end

  # --- blocks (pilot) -------------------------------------------------------
  def blocks
    w = base_world
    mgr = FactoryBot.create(:block, unit: w[:unit_manager], name: "Khoi-QL-#{SecureRandom.hex(3)}")
    oth = FactoryBot.create(:block, unit: w[:unit_other],   name: "Khoi-Khac-#{SecureRandom.hex(3)}")
    checks = accessible_non_sa_roles("blocks").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      foreign = owned == mgr.name ? oth.name : mgr.name
      { user: user, sees: owned, hides: [foreign] }
    end
    Scenario.new(path: Rails.application.routes.url_helpers.blocks_path,
                 sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: accessible_non_sa_roles("blocks").map { |r| make_user(r, w) })
  end

  # --- groups (unit-scoped index, clone of blocks) --------------------------
  def groups
    w = base_world
    mgr = FactoryBot.create(:group, unit: w[:unit_manager], name: "Nhom-QL-#{SecureRandom.hex(3)}")
    oth = FactoryBot.create(:group, unit: w[:unit_other],   name: "Nhom-Khac-#{SecureRandom.hex(3)}")
    checks = accessible_non_sa_roles("groups").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      { user: user, sees: owned, hides: [owned == mgr.name ? oth.name : mgr.name] }
    end
    Scenario.new(path: Rails.application.routes.url_helpers.groups_path,
                 sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: accessible_non_sa_roles("groups").map { |r| make_user(r, w) })
  end

  # The open period's rank for personnel counts (residential CP needs it).
  def open_period_rank
    period = Period.order(:year, :month).last
    period.ranks.first || period.ranks.create!(name: "Hạ sĩ", quota: 1, position: 1)
  end

  # --- contact_points_index (unit-scoped index) -----------------------------
  def contact_points_index
    w = base_world
    rank = open_period_rank
    mgr = FactoryBot.create(:contact_point, :residential, unit: w[:unit_manager],
            name: "DM-QL-#{SecureRandom.hex(3)}", initial_personnel_counts: { rank.id => 1 })
    oth = FactoryBot.create(:contact_point, :residential, unit: w[:unit_other],
            name: "DM-Khac-#{SecureRandom.hex(3)}", initial_personnel_counts: { rank.id => 1 })
    path = Rails.application.routes.url_helpers.contact_points_path(type: "residential")
    checks = accessible_non_sa_roles("contact_points").map do |role|
      user = make_user(role, w)
      owned = unit_for(role, w) == w[:unit_manager] ? mgr.name : oth.name
      { user: user, sees: owned, hides: [owned == mgr.name ? oth.name : mgr.name] }
    end
    Scenario.new(path: path, sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [mgr.name, oth.name], checks: checks,
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: accessible_non_sa_roles("contact_points").map { |r| make_user(r, w) })
  end

  # --- contact_points (new-form zone-manager variant) -----------------------
  def contact_points
    w = base_world
    Scenario.new(
      path: Rails.application.routes.url_helpers.contact_points_path,
      sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      zm: { zm_user: FactoryBot.create(:user, :unit_admin, unit: w[:unit_manager]),
            non_zm_user: FactoryBot.create(:user, :unit_admin, unit: w[:unit_other]),
            marker_css: "select#type option",
            marker_values: %w[water_pump non_establishment] }
    )
  end

  # --- meter_entries --------------------------------------------------------
  def meter_entries
    # SampleData is included into RSpec example groups (config.include SampleData),
    # not available at plain module-function level. Bind it via a lightweight helper
    # object that has both FactoryBot::Syntax::Methods and SampleData.
    sample = sample_world
    path = Rails.application.routes.url_helpers.meter_entries_path
    commander_users = [FactoryBot.create(:user, :commander, unit: sample.unit_a),
                       FactoryBot.create(:user, :commander, unit: sample.unit_b)]
    control_user = FactoryBot.create(:user, :unit_admin, unit: sample.unit_a)
    Scenario.new(
      path: path, sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      commander: { commander_users: commander_users, control_user: control_user,
                   input_css: "table input[type='number'], table input[type='text']",
                   submit_css: "form[method='post'] input[name='commit'][value='Lưu toàn bộ']",
                   submit_optional: false }
    )
  end

  # --- meter_entries_data (data scoping + zone/unit columns) ----------------
  # Separate scenario from `meter_entries` (commander_readonly) because these
  # dimensions need different Scenario fields (all_texts / checks / columns).
  def meter_entries_data
    sample = sample_world
    users  = sample_role_users(sample)
    text_a, text_b = sample_cp_names_for_meter_entries(sample)
    Scenario.new(path: Rails.application.routes.url_helpers.meter_entries_path,
                 sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [text_a, text_b],
                 checks: unit_scoped_checks(users, text_a, text_b),
                 columns: ["Khu vực", "Đơn vị"],
                 column_users: users.values_at(:ua_zm, :ua, :cmd_zm, :cmd))
  end

  # --- billing --------------------------------------------------------------
  def billing
    sample = sample_world
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    users = sample_role_users(sample)
    text_a, text_b = sample_cp_names_for_billing(sample)
    # zone_unit_columns: "Khu vực" is hidden for ALL non-SA (SA-only).
    # "Đơn vị" IS shown to UA-ZM/CMD-ZM (zone-managers see the unit column because
    # @unit is nil for them — resolve_current_user_zone_unit returns [zone, nil]).
    # So column_users covers all 4 non-SA roles for "Khu vực" only; "Đơn vị"
    # visibility for zone-managers is tracked under zone_manager_variant (na here).
    Scenario.new(path: Rails.application.routes.url_helpers.billing_path,
                 sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [text_a, text_b],
                 checks: unit_scoped_checks(users, text_a, text_b),
                 columns: ["Khu vực"],
                 column_users: users.values_at(:ua_zm, :ua, :cmd_zm, :cmd))
  end

  # --- unit_config (commander readonly) ------------------------------------
  # sample_world builds unit_a (zone-manager) with residential CPs (Ban Tác huấn,
  # Văn thư, Kho vật tư) and unit_b with Đại đội 1. Both units have OtherDeduction
  # rows so unit_config renders number/select inputs for them.
  # Control user = unit_admin of unit_b (plain UA, not ZM); commanders from both
  # units are tested. Submit button (input[name='commit']) is ABSENT for commanders
  # (view hides it entirely), so submit_optional: true.
  def unit_config_commander
    sample = sample_world
    commander_users = [
      FactoryBot.create(:user, :commander, unit: sample.unit_a),
      FactoryBot.create(:user, :commander, unit: sample.unit_b)
    ]
    control_user = FactoryBot.create(:user, :unit_admin, unit: sample.unit_b)
    Scenario.new(
      path: Rails.application.routes.url_helpers.unit_config_path,
      sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      commander: {
        commander_users: commander_users,
        control_user:    control_user,
        input_css:       "form input[type='number'], form select",
        submit_css:      "input[name='commit']",
        submit_optional: true
      }
    )
  end

  # --- unit_config (zone-manager variant) -----------------------------------
  # UA-ZM (unit manages a zone) sees "thuộc khu vực" section when there is at
  # least one zone_residential contact_point in the managed zone — mirrors the
  # setup in unit_config_spec.rb lines 127-143. Plain UA (unit_other, no zone)
  # does NOT see that section.
  def unit_config_zm
    w = base_world
    rank = open_period_rank
    # Create a zone_residential CP in the zone managed by unit_manager so the
    # "thuộc khu vực" section renders for that unit's admin.
    FactoryBot.create(:contact_point, :zone_residential, zone: w[:zone],
                      name: "ZCP-ZM-#{SecureRandom.hex(3)}",
                      initial_personnel_counts: { rank.id => 1 })
    zm_user     = FactoryBot.create(:user, :unit_admin, unit: w[:unit_manager])
    non_zm_user = FactoryBot.create(:user, :unit_admin, unit: w[:unit_other])
    Scenario.new(
      path: Rails.application.routes.url_helpers.unit_config_path,
      sa_user: FactoryBot.create(:user, :system_admin),
      all_texts: [], checks: [], columns: [], column_users: [],
      zm: { zm_user: zm_user, non_zm_user: non_zm_user, marker_text: "thuộc khu vực" }
    )
  end

  # --- history --------------------------------------------------------------
  # Range mode renders period-level aggregate rows (no CP names); compare mode
  # requires ≥2 periods and the view blocks with a "need at least 2" notice when
  # only one period exists. Neither mode renders distinguishable per-unit strings
  # suitable for the data_scoping shared example. Declared na in the matrix.
  # (Zone/unit columns: history ALWAYS shows both columns for every role — na too.)
  def history
    sample = sample_world
    users  = sample_role_users(sample)
    path   = Rails.application.routes.url_helpers.history_path(
               mode: "range",
               from_period_id: sample.period.id,
               to_period_id:   sample.period.id)
    Scenario.new(path: path, sa_user: FactoryBot.create(:user, :system_admin),
                 all_texts: [], checks: [],
                 columns: [], column_users: [])
  end
end
