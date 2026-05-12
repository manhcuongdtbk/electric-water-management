# frozen_string_literal: true

# Standalone, org-agnostic view of pump allocation. Where CalculationEngine
# resolves pump kW per-CP for the engine's organization (and so persists
# only those CP rows), PumpAllocationCalculator answers the broader
# question "for THIS pump station in THIS period, how is its kW pool split
# across every assignee (Organization, ContactPoint, WorkGroup)?".
#
# It mirrors the engine's 30/70 logic but never narrows by `organization`,
# so WorkGroup shares (which never reach MonthlyCalculation) and shares
# belonging to other units can be reported alongside the engine's own
# results. This is what F10 báo cáo phân bổ bơm needs.
class PumpAllocationCalculator
  ZERO = BigDecimal("0")
  BD_100 = BigDecimal("100")

  attr_reader :pump_station, :monthly_period

  def initialize(pump_station:, monthly_period:)
    @pump_station = pump_station
    @monthly_period = monthly_period
  end

  # Returns:
  # {
  #   consumption_kw:  BigDecimal, # meters' raw kWh
  #   loss_share_kw:   BigDecimal, # pump's share of zone loss
  #   total_pool_kw:   BigDecimal, # consumption + loss_share
  #   allocations: [
  #     { assignable_type:, assignable_id:, name:, personnel:,
  #       fixed_pump_percentage:, kw: }, ...
  #   ]
  # }
  def call
    consumption = pump_station_consumption
    loss_share  = pump_loss_share(consumption)
    pool        = consumption + loss_share
    rows        = allocate(pool)

    {
      consumption_kw: consumption,
      loss_share_kw:  loss_share,
      total_pool_kw:  pool,
      allocations:    rows
    }
  end

  private

  def assignments
    @assignments ||= PumpStationAssignment
                       .for_pump_station(pump_station.id)
                       .includes(:assignable)
                       .to_a
  end

  def pump_station_consumption
    meter_ids = pump_station.meters.pluck(:id)
    return ZERO if meter_ids.empty?

    to_bd(
      MeterReading.where(meter_id: meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  # Zone resolved through any Organization served by this pump. If none
  # exists (pump only has WG/CP assignments without an Org), loss_share = 0.
  def pump_loss_share(ps_consumption)
    return ZERO unless ps_consumption.positive?

    zone = zone_org_ids
    return ZERO if zone.empty?

    supply = zone_supply_kw(zone)
    return ZERO if supply.blank?

    no_loss = no_loss_consumption_in_zone(zone)
    loss_pool_b = loss_pool_consumption_in_zone(zone)

    return ZERO unless loss_pool_b.positive?

    total_zone_loss = to_bd(supply) - no_loss - loss_pool_b
    return ZERO if total_zone_loss <= ZERO

    total_zone_loss * ps_consumption / loss_pool_b
  end

  # Zone = unit-level Organization served by this pump (directly or via a
  # ContactPoint), expanded to all orgs sharing the same Zone.
  def zone_org_ids
    return @zone_org_ids if defined?(@zone_org_ids)

    org_ids = assignments.flat_map { |a| seed_org_ids(a) }.uniq
    @zone_org_ids =
      if org_ids.empty?
        []
      else
        zone_ids = Organization.where(id: org_ids).where.not(zone_id: nil)
                               .pluck(:zone_id).uniq
        if zone_ids.empty?
          org_ids
        else
          Organization.where(zone_id: zone_ids).pluck(:id)
        end
      end
  end

  def seed_org_ids(assignment)
    case assignment.assignable
    when Organization then [ assignment.assignable.id ]
    when ContactPoint then [ assignment.assignable.organization_id ]
    else []
    end
  end

  # Supply for the zone = Σ supply across every distinct MainMeter present
  # in the zone. Pumps assigned across two zones therefore see the combined
  # supply, matching what `loss_pool_consumption_in_zone` sums over the same
  # zone. Returns nil only if no MainMeterReading exists for any meter.
  def zone_supply_kw(zone_org_ids)
    zone_ids = Organization.where(id: zone_org_ids).where.not(zone_id: nil)
                           .distinct.pluck(:zone_id)
    return nil if zone_ids.empty?

    readings = MainMeter.where(zone_id: zone_ids).filter_map do |mm|
      mm.supply_kw_for(monthly_period)
    end
    return nil if readings.empty?

    readings.sum { |kw| to_bd(kw) }
  end

  def no_loss_consumption_in_zone(zone)
    to_bd(
      MeterReading.for_period(monthly_period.id)
                  .joins(:meter)
                  .where(meters: { organization_id: zone,
                                   meter_type: Meter.meter_types[:no_loss] })
                  .sum(:consumption)
    )
  end

  def loss_pool_consumption_in_zone(zone)
    cp_meter_ids = Meter.where(
      organization_id: zone,
      meter_type: [ Meter.meter_types[:normal], Meter.meter_types[:public_meter] ]
    ).pluck(:id)

    zone_pump_ids = pump_meter_ids_in_zone(zone)
    meter_ids = (cp_meter_ids + zone_pump_ids).uniq
    return ZERO if meter_ids.empty?

    to_bd(
      MeterReading.where(meter_id: meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  def pump_meter_ids_in_zone(zone)
    org_ps = PumpStationAssignment
               .where(assignable_type: "Organization", assignable_id: zone)
               .pluck(:pump_station_id)
    cp_ps = PumpStationAssignment
              .where(assignable_type: "ContactPoint")
              .joins("INNER JOIN contact_points " \
                     "ON contact_points.id = pump_station_assignments.assignable_id")
              .where(contact_points: { organization_id: zone })
              .pluck(:pump_station_id)
    ps_ids = (org_ps + cp_ps).uniq
    return [] if ps_ids.empty?

    Meter.where(pump_station_id: ps_ids,
                meter_type: Meter.meter_types[:pump_station]).pluck(:id)
  end

  def allocate(pool)
    rows = []
    return rows unless pool.positive?
    return rows if assignments.empty?

    fixed, variable = assignments.partition(&:fixed?)
    sum_fixed_pct = fixed.sum { |a| to_bd(a.fixed_pump_percentage) }
    sum_fixed_pct = BD_100 if sum_fixed_pct > BD_100

    fixed.each do |asg|
      share = pool * to_bd(asg.fixed_pump_percentage) / BD_100
      rows << build_row(asg, share)
    end

    variable_pct = BD_100 - sum_fixed_pct
    if variable_pct.positive?
      head_by_asg = variable.to_h { |a| [ a, headcount(a.assignable) ] }
      total = head_by_asg.values.sum

      variable.each do |asg|
        head = head_by_asg[asg]
        share =
          if total.positive? && head.positive?
            (pool * variable_pct / BD_100) * to_bd(head) / to_bd(total)
          else
            ZERO
          end
        rows << build_row(asg, share)
      end
    else
      variable.each { |asg| rows << build_row(asg, ZERO) }
    end

    rows
  end

  def build_row(assignment, share)
    target = assignment.assignable
    {
      assignable_type:        assignment.assignable_type,
      assignable_id:          assignment.assignable_id,
      name:                   target.respond_to?(:name) ? target.name : nil,
      personnel:              headcount(target),
      fixed_pump_percentage:  assignment.fixed_pump_percentage,
      kw:                     share
    }
  end

  def headcount(target)
    case target
    when Organization
      Personnel.for_period(monthly_period.id)
               .joins(:contact_point)
               .where(contact_points: { organization_id: target.id })
               .sum("rank1_count + rank2_count + rank3_count + rank4_count + " \
                    "rank5_count + rank6_count + rank7_count").to_i
    when ContactPoint
      record = Personnel.for_period(monthly_period.id).for_contact_point(target.id).first
      record ? record.total_count : 0
    when WorkGroup
      target.personnel_count.to_i
    else
      0
    end
  end

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
