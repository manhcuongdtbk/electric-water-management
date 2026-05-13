# frozen_string_literal: true

# Zone-wide electricity loss (tổn hao) calculator.
#
# Extracts the Loss phase from CalculationOrchestrator into a standalone service. A
# zone is the unit of loss computation — supply (MainMeter readings) minus
# no_loss consumption minus loss-pool consumption (B) gives total_zone_loss
# (C). Per-CP loss numerators and per-pump-station loss share are derived
# from C and B.
#
# Nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html, mục 4):
#   A = Σ MainMeterReading.electricity_supply_kw (zone) − Σ no_loss meters (zone)
#   B = Σ (normal + public_meter) meters with_loss in zone + Σ pump meters serving zone
#   C = total_zone_loss = max(A − B, 0)
#   per-CP loss numerator = Σ consumption of CP's loss-pool meters
#   pump_loss_share(ps)   = C × consumption(ps) / B
#
# Interface:
#   calc = LossCalculator.new(zone:, monthly_period:)
#   calc.call               # → { total_zone_loss:, loss_pool_consumption_in_zone:,
#                           #     loss_pool_consumption_by_cp:, zone_supply_kw: }
#   calc.pump_loss_share(ps) # → BigDecimal (called from Pump phase)
#
# zone may be nil (org chưa gán zone) → returns all-zero / nil-supply output.
# All arithmetic uses BigDecimal — no float, no intermediate rounding.
class LossCalculator
  ZERO = BigDecimal("0")

  attr_reader :zone, :monthly_period

  def initialize(zone:, monthly_period:)
    @zone = zone
    @monthly_period = monthly_period
  end

  def call
    {
      total_zone_loss:                total_zone_loss,
      loss_pool_consumption_in_zone:  loss_pool_consumption_in_zone,
      loss_pool_consumption_by_cp:    loss_pool_consumption_by_cp,
      zone_supply_kw:                 zone_supply_kw
    }
  end

  # Tổn hao của pump_station = total_zone_loss × (kW pump ÷ B).
  # Called per-station from the Pump phase to inflate pump pool.
  def pump_loss_share(pump_station)
    return ZERO unless total_zone_loss.positive? && loss_pool_consumption_in_zone.positive?
    ps_consumption = pump_station_consumption(pump_station)
    return ZERO unless ps_consumption.positive?

    total_zone_loss * ps_consumption / loss_pool_consumption_in_zone
  end

  private

  # --- Zone resolution -----------------------------------------------------
  def zone_org_ids
    @zone_org_ids ||= zone ? zone.organizations.pluck(:id) : []
  end

  # Pump meters serving the zone — via PumpStationAssignment so that pump
  # stations administered at division-level still get picked up. A pump is
  # "in the zone" when at least one assignment points to:
  #   - an Organization in the zone,
  #   - a ContactPoint whose Organization is in the zone, or
  #   - a ContactPointGroup with a member ContactPoint whose Organization is
  #     in the zone.
  # WorkGroup assignments do NOT pull a pump into a zone (no CP / org to
  # anchor against).
  def zone_pump_meter_ids
    @zone_pump_meter_ids ||= compute_zone_pump_meter_ids
  end

  def compute_zone_pump_meter_ids
    return [] if zone_org_ids.empty?

    org_ps = PumpStationAssignment
               .where(assignable_type: "Organization", assignable_id: zone_org_ids)
               .pluck(:pump_station_id)
    cp_ps = PumpStationAssignment
              .where(assignable_type: "ContactPoint")
              .joins("INNER JOIN contact_points " \
                     "ON contact_points.id = pump_station_assignments.assignable_id")
              .where(contact_points: { organization_id: zone_org_ids })
              .pluck(:pump_station_id)
    cpg_ps = PumpStationAssignment
               .where(assignable_type: "ContactPointGroup")
               .joins("INNER JOIN contact_point_group_memberships " \
                      "ON contact_point_group_memberships.contact_point_group_id = pump_station_assignments.assignable_id")
               .joins("INNER JOIN contact_points " \
                      "ON contact_points.id = contact_point_group_memberships.contact_point_id")
               .where(contact_points: { organization_id: zone_org_ids })
               .pluck(:pump_station_id)
    ps_ids = (org_ps + cp_ps + cpg_ps).uniq
    return [] if ps_ids.empty?

    Meter.where(pump_station_id: ps_ids,
                meter_type: Meter.meter_types[:pump_station]).pluck(:id)
  end

  # Loss pool B = CP meters in zone (normal + public_meter, no_loss = false)
  # ∪ pump meters serving zone. No-loss meters are subtracted from supply
  # directly and never enter B.
  def loss_pool_meter_ids
    @loss_pool_meter_ids ||= begin
      cp_ids = Meter
        .where(organization_id: zone_org_ids,
               meter_type: [ Meter.meter_types[:normal], Meter.meter_types[:public_meter] ])
        .merge(Meter.with_loss)
        .pluck(:id)
      (cp_ids + zone_pump_meter_ids).uniq
    end
  end

  # --- Loss-pool consumption (per CP) — DB-side group + sum ----------------
  # Pump meters have contact_point_id = nil so they're naturally excluded
  # from this per-CP group; their share lives in `pump_loss_share` and
  # inflates pump pool instead.
  def loss_pool_consumption_by_cp
    @loss_pool_consumption_by_cp ||=
      if loss_pool_meter_ids.empty?
        {}
      else
        MeterReading
          .for_period(monthly_period.id)
          .joins(:meter)
          .where(meter_id: loss_pool_meter_ids)
          .group("meters.contact_point_id")
          .sum(:consumption)
          .transform_values { |v| to_bd(v) }
          .except(nil) # pump meters land in nil bucket
      end
  end

  # B (zone-wide loss-pool denominator). Includes pump meter consumption.
  def loss_pool_consumption_in_zone
    @loss_pool_consumption_in_zone ||= to_bd(
      if loss_pool_meter_ids.empty?
        0
      else
        MeterReading.for_period(monthly_period.id)
                    .where(meter_id: loss_pool_meter_ids)
                    .sum(:consumption)
      end
    )
  end

  # Σ(no_loss) readings — meters at the substation that don't go through
  # internal lines, so their kW must be removed from supply BEFORE computing
  # internal-line loss (they don't contribute to the loss pool).
  def no_loss_consumption_in_zone
    @no_loss_consumption_in_zone ||= to_bd(
      if zone_org_ids.empty?
        0
      else
        MeterReading
          .for_period(monthly_period.id)
          .joins(:meter)
          .where(meters: { organization_id: zone_org_ids })
          .merge(Meter.no_loss)
          .sum(:consumption)
      end
    )
  end

  # Supply = Σ supply across every MainMeter in the zone. Returns nil when
  # the zone is nil or has no MainMeterReading at all (→ loss = 0).
  def zone_supply_kw
    return @zone_supply_kw if defined?(@zone_supply_kw)
    @zone_supply_kw =
      if zone.nil?
        nil
      else
        readings = zone.main_meters.filter_map { |mm| mm.supply_kw_for(monthly_period) }
        readings.empty? ? nil : readings.sum { |kw| to_bd(kw) }
      end
  end

  def total_zone_loss
    return @total_zone_loss if defined?(@total_zone_loss)

    supply = zone_supply_kw
    @total_zone_loss =
      if supply.blank?
        ZERO
      else
        diff = to_bd(supply) - no_loss_consumption_in_zone - loss_pool_consumption_in_zone
        diff.negative? ? ZERO : diff
      end
  end

  def pump_station_consumption(pump_station)
    meter_ids = pump_station.meters.pluck(:id)
    return ZERO if meter_ids.empty?

    to_bd(
      MeterReading.where(meter_id: meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
