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
end
