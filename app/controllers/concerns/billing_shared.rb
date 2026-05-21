# Shared logic giữa BillingController và HistoryController:
# resolve_filter, zones_in_scope, warnings, preload, dropdowns.
# Tách ra concern để sửa 1 chỗ được tất cả.
module BillingShared
  extend ActiveSupport::Concern

  private

  def resolve_filter
    if current_user.role == "system_admin"
      zone = params[:zone_id].present? ? Zone.with_discarded.find_by(id: params[:zone_id]) : nil
      unit = params[:unit_id].present? ? Unit.with_discarded.find_by(id: params[:unit_id]) : nil
      [zone, unit]
    else
      unit = current_user.unit
      zone = unit&.zone
      if zone && Zone.exists?(id: zone.id, manager_unit_id: unit.id)
        [zone, nil]
      else
        [zone, unit]
      end
    end
  end

  def build_calculations_scope
    scope = Billing::Query.base_scope(@period, current_ability)
    scope = Billing::Query.apply_filters(scope, zone: @zone, unit: @unit, q: params[:q])
    scope.order(Arel.sql(Billing::Query::SORT_ORDER))
  end

  def preload_personnel(calculations)
    cp_ids = calculations.map(&:contact_point_id)
    entries = PersonnelEntry
                .where(period_id: @period.id, contact_point_id: cp_ids)
                .includes(:rank)
    @personnel_by_cp_id = Hash.new { |h, k| h[k] = {} }
    entries.each { |e| @personnel_by_cp_id[e.contact_point_id][e.rank_id] = e.count }
  end

  def collect_warnings_for_zones(zones)
    zones.flat_map { |z| ZoneWarningCollector.new(zone: z, period: @period).call }
  end

  # Dùng cho recalculate + warnings. Luôn dùng .with_discarded vì:
  # - Engine cần zone đã xóa để tính kỳ cũ (data còn)
  # - ZoneWarningCollector tự skip zone không có data cho kỳ đó (zone_has_data_for_period?)
  def zones_in_scope(period)
    return Zone.with_discarded.where(id: @zone.id) if @zone

    if current_user.role == "system_admin"
      Zone.with_discarded.order(:name)
    else
      zone_ids = [current_user.unit&.zone_id].compact
      zone_ids += Zone.where(manager_unit_id: current_user.unit_id).pluck(:id) if current_user.unit_id
      Zone.with_discarded.where(id: zone_ids.uniq)
    end
  end

  def available_zones_for_filter
    if current_user.role == "system_admin"
      Zone.with_discarded.order(:name)
    else
      [current_user.unit&.zone].compact
    end
  end

  def available_units_for_filter(zone)
    base = Unit.with_discarded.order(:name)
    base = base.where(zone_id: zone.id) if zone
    base
  end
end
