module SidebarHelper
  ALL_ITEMS = {
    dashboard:           { label_key: "sidebar.items.dashboard",          path_helper: :root_path },
    billing:             { label_key: "sidebar.items.billing",            path_helper: :billing_path },
    history:             { label_key: "sidebar.items.history",            path_helper: :history_path },
    electricity_supply:  { label_key: "sidebar.items.electricity_supply", path_helper: :electricity_supply_path },
    meter_entries:       { label_key: "sidebar.items.meter_entries",      path_helper: :meter_entries_path },
    pump_entries:        { label_key: "sidebar.items.pump_entries",       path_helper: :pump_entries_path },
    contact_points:      { label_key: "sidebar.items.contact_points",     path_helper: :contact_points_path },
    blocks:              { label_key: "sidebar.items.blocks",             path_helper: :blocks_path },
    groups:              { label_key: "sidebar.items.groups",             path_helper: :groups_path },
    unit_config:         { label_key: "sidebar.items.unit_config",        path_helper: :unit_config_path },
    zones:               { label_key: "sidebar.items.zones",              path_helper: :zones_path },
    units:               { label_key: "sidebar.items.units",              path_helper: :units_path },
    pump_allocations:    { label_key: "sidebar.items.pump_allocations",   path_helper: :pump_allocations_path },
    pricing:             { label_key: "sidebar.items.pricing",            path_helper: :pricing_path },
    ranks:               { label_key: "sidebar.items.ranks",              path_helper: :ranks_path },
    users:               { label_key: "sidebar.items.users",              path_helper: :users_path },
    audit_logs:          { label_key: "sidebar.items.audit_logs",         path_helper: :audit_logs_path },
    backups:             { label_key: "sidebar.items.backups",            path_helper: :backups_path }
  }.freeze

  GROUPS_STRUCTURE = [
    { key: :view_results,  items: %i[dashboard billing history] },
    { key: :monthly_entry, items: %i[electricity_supply meter_entries pump_entries] },
    { key: :declarations,  items: %i[contact_points blocks groups unit_config] },
    { key: :settings,      items: %i[zones units pump_allocations pricing ranks] },
    { key: :system,        items: %i[users audit_logs backups] }
  ].freeze

  def allowed_sidebar_items
    return [] unless current_user
    role = current_user.role.to_sym
    zone_manager = current_zone_manager?

    case role
    when :technician
      %i[users audit_logs backups]
    when :system_admin
      %i[dashboard billing history electricity_supply meter_entries pump_entries
         contact_points blocks groups unit_config
         zones units pump_allocations pricing ranks
         users audit_logs]
    when :unit_admin
      base = %i[dashboard billing history meter_entries contact_points blocks groups unit_config]
      base += %i[electricity_supply pump_entries zones pump_allocations] if zone_manager
      base
    when :commander
      base = %i[dashboard billing history meter_entries contact_points blocks groups unit_config]
      base += %i[pump_entries zones pump_allocations] if zone_manager
      base
    else
      []
    end
  end

  def sidebar_groups
    allowed = allowed_sidebar_items
    GROUPS_STRUCTURE.map do |group|
      visible = group[:items].select { |i| allowed.include?(i) }
      next if visible.empty?
      {
        label: t("sidebar.groups.#{group[:key]}"),
        items: visible.map do |key|
          item = ALL_ITEMS[key]
          { label: t(item[:label_key]), path: send(item[:path_helper]) }
        end
      }
    end.compact
  end

  def sidebar_item_class(path)
    base = "block pl-3 pr-2 py-1.5 rounded text-sm whitespace-nowrap transition hover:bg-gray-100"
    if current_page?(path)
      "#{base} bg-blue-50 text-blue-700 font-semibold"
    else
      "#{base} text-gray-700"
    end
  end
end
