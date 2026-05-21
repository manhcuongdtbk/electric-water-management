require "ostruct"

class DashboardSummary
  def initialize(user:, ability:, period:)
    @user = user
    @ability = ability
    @period = period
  end

  def call
    case @user.role.to_sym
    when :system_admin then build_system_admin_summary
    when :unit_admin, :commander then build_unit_summary
    else
      OpenStruct.new(role: @user.role.to_sym, warnings: [])
    end
  end

  private

  def build_system_admin_summary
    # Lấy units/zones có data cho kỳ này (bao gồm đã xóa — data kỳ cũ giữ nguyên)
    unit_ids_with_data = Calculation.where(period_id: @period.id)
                           .joins(:contact_point)
                           .where.not(contact_points: { unit_id: nil })
                           .pluck(Arel.sql("DISTINCT contact_points.unit_id"))
    units = Unit.with_discarded.where(id: unit_ids_with_data).includes(:zone).to_a
    unit_data = units.map { |u| build_unit_card(u) }
                     .sort_by { |d| -BigDecimal(d[:deficit_kw].to_s) }

    zone_ids_with_data = MeterReading.where(period_id: @period.id)
                           .joins(meter: :contact_point)
                           .joins("LEFT JOIN units ON units.id = contact_points.unit_id")
                           .pluck(Arel.sql("DISTINCT COALESCE(contact_points.zone_id, units.zone_id)"))
                           .compact
    zones = Zone.with_discarded.where(id: zone_ids_with_data).order(:name).to_a
    zone_data = zones.map { |z| build_zone_card(z) }

    warnings = zones.flat_map { |z| ZoneWarningCollector.new(zone: z, period: @period).call }

    OpenStruct.new(
      role: :system_admin,
      period: @period,
      units: unit_data,
      zones: zone_data,
      warnings: warnings
    )
  end

  def build_unit_card(unit)
    cp_ids = Calculation.where(period_id: @period.id)
               .joins(:contact_point)
               .where(contact_points: { unit_id: unit.id })
               .pluck(:contact_point_id)
    calcs = Calculation.where(period_id: @period.id, contact_point_id: cp_ids)
    {
      unit: unit,
      deficit_kw: calcs.sum(:deficit),
      deficit_amount: calcs.sum(:deficit_amount),
      surplus_kw: calcs.sum(:surplus),
      surplus_amount: calcs.sum(:surplus_amount),
      input_status: input_status_for(unit_ids: [unit.id], zone_ids: [])
    }
  end

  def build_unit_summary
    unit = @user.unit
    return OpenStruct.new(role: @user.role.to_sym, period: @period, unit: nil, warnings: []) unless unit

    managed_zone_ids = Zone.where(manager_unit_id: unit.id).pluck(:id)
    cp_scope = ContactPoint.with_discarded.where(unit_id: unit.id)
    if managed_zone_ids.any?
      cp_scope = cp_scope.or(
        ContactPoint.with_discarded.where(zone_id: managed_zone_ids, contact_point_type: "residential")
      )
    end
    cp_ids = cp_scope.pluck(:id)

    calcs = Calculation.where(period_id: @period.id, contact_point_id: cp_ids)

    zone_ids = ([unit.zone_id] + managed_zone_ids).compact.uniq
    warnings = Zone.with_discarded.where(id: zone_ids)
                    .flat_map { |z| ZoneWarningCollector.new(zone: z, period: @period).call }

    OpenStruct.new(
      role: @user.role.to_sym,
      period: @period,
      unit: unit,
      managed_zone_ids: managed_zone_ids,
      deficit_kw: calcs.sum(:deficit),
      deficit_amount: calcs.sum(:deficit_amount),
      surplus_kw: calcs.sum(:surplus),
      surplus_amount: calcs.sum(:surplus_amount),
      deficit_count: calcs.where("deficit > 0").count,
      surplus_count: calcs.where("surplus > 0").count,
      input_status: input_status_for(unit_ids: [unit.id], zone_ids: managed_zone_ids),
      warnings: warnings
    )
  end

  def build_zone_card(zone)
    {
      zone: zone,
      public_usage: aggregate_usage_for_zone("public", zone),
      pump_usage: aggregate_usage_for_zone("water_pump", zone)
    }
  end

  def aggregate_usage_for_zone(contact_point_type, zone)
    MeterReading.joins(meter: :contact_point)
      .where(period_id: @period.id,
             contact_points: { contact_point_type: contact_point_type })
      .merge(ContactPoint.in_zone(zone))
      .sum("COALESCE(meter_readings.manual_usage, COALESCE(meter_readings.reading_end, 0) - COALESCE(meter_readings.reading_start, 0))")
  end

  def input_status_for(unit_ids:, zone_ids:)
    # Đếm trực tiếp từ meter_readings per kỳ (bao gồm entity đã xóa — data giữ nguyên)
    readings = MeterReading.where(period_id: @period.id)
                 .joins(meter: :contact_point)
    conds = []
    conds << readings.where(contact_points: { unit_id: unit_ids }) if unit_ids.any?
    conds << readings.where(contact_points: { zone_id: zone_ids }) if zone_ids.any?
    return :pending if conds.empty?

    scoped = conds.reduce { |a, b| a.or(b) }
    total  = scoped.count
    filled = scoped.where.not(reading_end: nil).or(scoped.where.not(manual_usage: nil)).count
    total > 0 && filled >= total ? :entered : :pending
  end
end
