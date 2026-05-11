# frozen_string_literal: true

# F08 + F09 + F10 — Engine tính toán bảng 22 cột cho một đơn vị (organization)
# trong một chu kỳ tháng (monthly_period).
#
# Tuân thủ nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html):
#
#   * 7 nhóm cấp bậc, lấy định mức từ RankQuota (effective_at period start).
#   * Tiêu chuẩn bơm nước = 9.45 kW/người/tháng (Personnel::WATER_PUMP_RATE).
#   * "Số phải trừ" gồm: Tiết kiệm, Tổn hao, Công cộng Sư đoàn, Công cộng đơn vị, Khác.
#     Tổn hao TRỪ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng.
#   * Tổn hao tính trên TOÀN KHU VỰC dùng chung đồng hồ tổng (MainMeter zone):
#       A = MainMeterReading.electricity_supply_kw − Σ công tơ no_loss trong zone
#       B = Σ công tơ (normal + public_meter) trong zone + Σ công tơ pump phục vụ zone
#       Tổn hao zone = A − B
#       Phân bổ công tơ X: tổn hao × (kW công tơ X ÷ B)
#     Pump tham gia loss pool (nằm trong B); tổn hao pump cộng vào pump pool phân bổ:
#       pump pool = pump consumption + pump_loss_share
#     Fallback: nếu org chưa được gán MainMeter, supply lấy từ UnitConfig.electricity_supply_kw
#     và zone = [organization.id] (giữ tương thích cho seed/migration).
#   * Bơm nước thực tế: mỗi trạm bơm phục vụ đơn vị (qua pump_station_assignments)
#     phân bổ pump pool cho từng đầu mối theo tỷ lệ
#     quân số đầu mối / tổng quân số trên TẤT CẢ các đơn vị mà trạm bơm phục vụ.
#     Mô hình 30/70 (M6): assignment có thể có fixed_pump_percentage (fixed slot trên
#     pump pool), còn lại chia theo personnel.
#   * Mọi phép tính dùng BigDecimal. KHÔNG làm tròn ở bước trung gian.
#
# Interface:
#
#   engine = CalculationEngine.new(organization:, monthly_period:)
#   engine.compute  # → Array<Hash> (full-precision BigDecimal, not persisted)
#   engine.call     # → persists MonthlyCalculation rows (upsert), returns results
#
# Instance is one-shot: caches are built on first access. Create a new instance
# if underlying data changed between computations.
class CalculationEngine
  ZERO = BigDecimal("0")
  WATER_PUMP_RATE = Personnel::WATER_PUMP_RATE

  attr_reader :organization, :monthly_period

  def initialize(organization:, monthly_period:)
    @organization = organization
    @monthly_period = monthly_period
  end

  # Compute all 22-column values for every contact point in the organization.
  # Returns an Array of Hashes — one per contact point — with full-precision
  # BigDecimal values. Does NOT touch the database.
  def compute
    contact_points.map do |cp|
      row = build_standard_row(cp)
      apply_deductions_usage_and_billing(row)
      row.except(:contact_point)
    end
  end

  # Compute and persist results to monthly_calculations (upsert per contact point).
  # Runs inside a transaction — any validation failure rolls back all rows.
  def call
    results = compute
    ActiveRecord::Base.transaction do
      results.each { |row| persist(row) }
    end
    results
  end

  private

  # ============================================================ data caching

  def contact_points
    @contact_points ||= organization.contact_points.ordered.to_a
  end

  def contact_point_ids
    @contact_point_ids ||= contact_points.map(&:id)
  end

  def unit_config
    @unit_config ||= UnitConfig.find_by(organization: organization, monthly_period: monthly_period)
  end

  def personnel_by_cp
    @personnel_by_cp ||= Personnel.for_period(monthly_period.id)
                                  .where(contact_point_id: contact_point_ids)
                                  .index_by(&:contact_point_id)
  end

  def rank_quotas
    @rank_quotas ||= begin
      effective_date = Date.new(monthly_period.year, monthly_period.month, 1)
      RankQuota::RANK_GROUPS.each_with_object({}) do |group, hash|
        quota = RankQuota.for_rank(group).effective_at(effective_date).first
        hash[group] = quota&.quota_kw || ZERO
      end
    end
  end

  def other_deductions_by_cp
    @other_deductions_by_cp ||= ContactPointOtherDeduction
                                .where(monthly_period: monthly_period,
                                       contact_point_id: contact_point_ids)
                                .index_by(&:contact_point_id)
  end

  # --- Meter usage (per CP) — DB-side group + sum ---------------------------
  def meter_usage_by_cp
    @meter_usage_by_cp ||= MeterReading
                           .for_period(monthly_period.id)
                           .joins(:meter)
                           .where(meters: { organization_id: organization.id,
                                            meter_type: Meter.meter_types[:normal] })
                           .group("meters.contact_point_id")
                           .sum(:consumption)
                           .transform_values { |v| to_bd(v) }
  end

  def meter_usage_for(cp_id)
    meter_usage_by_cp[cp_id] || ZERO
  end

  # --- Zone resolution -----------------------------------------------------
  # Org may belong to a MainMeter (shared zone). If not, zone = [org.id] for
  # backward compat with pre-PR1 seeds / specs.
  def main_meter
    @main_meter ||= organization.main_meter
  end

  def zone_org_ids
    @zone_org_ids ||= main_meter ? main_meter.organizations.pluck(:id) : [ organization.id ]
  end

  # Pump meters serving the zone — resolved via PumpStationAssignment so that
  # pump stations administered at division-level still get picked up. A pump
  # is "in the zone" when at least one assignment points to:
  #   - an Organization in the zone, OR
  #   - a ContactPoint whose Organization is in the zone.
  # WorkGroup assignments do NOT pull a pump into a zone (a WG sits outside
  # the org tree — in practice it always co-exists with at least one Org/CP
  # assignment on the same pump).
  def zone_pump_meter_ids
    @zone_pump_meter_ids ||= begin
      org_ps = PumpStationAssignment
                 .where(assignable_type: "Organization", assignable_id: zone_org_ids)
                 .pluck(:pump_station_id)
      cp_ps = PumpStationAssignment
                .where(assignable_type: "ContactPoint")
                .joins("INNER JOIN contact_points " \
                       "ON contact_points.id = pump_station_assignments.assignable_id")
                .where(contact_points: { organization_id: zone_org_ids })
                .pluck(:pump_station_id)
      ps_ids = (org_ps + cp_ps).uniq
      if ps_ids.empty?
        []
      else
        Meter.where(pump_station_id: ps_ids,
                    meter_type: Meter.meter_types[:pump_station]).pluck(:id)
      end
    end
  end

  # Loss pool B = CP meters in zone (normal + public_meter) ∪ pump meters serving zone.
  # No-loss meters are subtracted from supply directly and never enter B.
  def loss_pool_meter_ids
    @loss_pool_meter_ids ||= begin
      cp_ids = Meter
        .where(organization_id: zone_org_ids,
               meter_type: [ Meter.meter_types[:normal], Meter.meter_types[:public_meter] ])
        .pluck(:id)
      (cp_ids + zone_pump_meter_ids).uniq
    end
  end

  # --- Loss-pool consumption (per CP) — DB-side group + sum ----------------
  # Used as the numerator for loss allocation. Pump meters have contact_point_id = nil
  # so they're naturally excluded from this per-CP group; their share lives in
  # `pump_loss_share` and inflates pump pool instead.
  def loss_pool_consumption_by_cp
    @loss_pool_consumption_by_cp ||= MeterReading
                                     .for_period(monthly_period.id)
                                     .joins(:meter)
                                     .where(meter_id: loss_pool_meter_ids)
                                     .group("meters.contact_point_id")
                                     .sum(:consumption)
                                     .transform_values { |v| to_bd(v) }
                                     .except(nil) # pump meters land in nil bucket
  end

  def loss_pool_consumption_for(cp_id)
    loss_pool_consumption_by_cp[cp_id] || ZERO
  end

  # B (zone-wide loss-pool denominator). Includes pump meter consumption.
  def loss_pool_consumption_in_zone
    @loss_pool_consumption_in_zone ||= to_bd(
      MeterReading.for_period(monthly_period.id)
                  .where(meter_id: loss_pool_meter_ids)
                  .sum(:consumption)
    )
  end

  # Σ(no_loss) readings — meters at the substation that don't go through
  # internal lines, so their kW must be removed from supply BEFORE computing
  # internal-line loss (they don't contribute to the loss pool).
  def no_loss_consumption_in_zone
    @no_loss_consumption_in_zone ||= to_bd(
      MeterReading
        .for_period(monthly_period.id)
        .joins(:meter)
        .where(meters: { organization_id: zone_org_ids,
                         meter_type: Meter.meter_types[:no_loss] })
        .sum(:consumption)
    )
  end

  # Supply: MainMeterReading first, UnitConfig as fallback for orgs not yet
  # migrated into a zone.
  def zone_supply_kw
    return @zone_supply_kw if defined?(@zone_supply_kw)
    @zone_supply_kw = main_meter&.supply_kw_for(monthly_period) ||
                      unit_config&.electricity_supply_kw
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

  # Tổn hao của pump_station = total_zone_loss × (kW pump ÷ B).
  # Pump pool phân bổ = consumption + pump_loss_share.
  def pump_loss_share(pump_station)
    return ZERO unless total_zone_loss.positive? && loss_pool_consumption_in_zone.positive?
    ps_consumption = pump_station_consumption(pump_station)
    return ZERO unless ps_consumption.positive?

    total_zone_loss * ps_consumption / loss_pool_consumption_in_zone
  end

  # --- Water pump actual (per CP) ------------------------------------------
  # 30/70 model (M6). Each pump station has assignments to "nhóm đối tượng"
  # — Organization (đơn vị cấp 2), ContactPoint (đầu mối đặc biệt), or
  # WorkGroup (nhóm công tác). An assignment may carry a
  # `fixed_pump_percentage` (e.g. 30) meaning that target takes that slice
  # off the top, regardless of personnel. Targets with NULL percentage share
  # the remaining pool by personnel ratio across all variable targets on
  # that pump.
  #
  # Within an Organization-level share (fixed or variable), the kW is split
  # across the org's contact points by personnel ratio. A ContactPoint share
  # lands on that single CP. A WorkGroup share is computed (so its personnel
  # counts toward the variable denominator) but NOT persisted here — WG
  # totals are reported via PumpAllocationCalculator (F10).
  #
  # NOTE: An assignable that overlaps the engine's own CPs receives share
  # from both routes. Example: a CP fixed 30% is ALSO counted inside its
  # parent Org's variable pool — CP personnel remain part of the Org
  # headcount, and the resulting share lands on the same CP. This stacking
  # is by design — admin chooses the assignments; the engine doesn't
  # de-duplicate.
  #
  # Backward compat: when every assignment is NULL, sum_fixed_pct = 0 →
  # variable_pct = 100 → behaves identically to the previous 100%-by-personnel
  # logic.
  def pump_allocations_by_cp
    @pump_allocations_by_cp ||= compute_pump_allocations
  end

  def pump_actual_for(cp_id)
    pump_allocations_by_cp[cp_id] || ZERO
  end

  def compute_pump_allocations
    allocations = Hash.new(ZERO)
    pump_stations = pump_stations_serving_unit
    return allocations if pump_stations.empty?

    pump_stations.each do |ps|
      # Pump pool absorbs the pump's share of zone loss so the inflated pool
      # is what gets distributed by personnel ratio.
      consumption = pump_station_consumption(ps) + pump_loss_share(ps)
      next unless consumption.positive?

      assignments = pump_station_assignments_for(ps)
      next if assignments.empty?

      fixed_assignments, variable_assignments = assignments.partition(&:fixed?)

      sum_fixed_pct = fixed_assignments.sum { |a| to_bd(a.fixed_pump_percentage) }
      sum_fixed_pct = bd_100 if sum_fixed_pct > bd_100

      fixed_assignments.each do |asg|
        share = consumption * to_bd(asg.fixed_pump_percentage) / bd_100
        apply_assignable_share(allocations, ps, asg.assignable, share)
      end

      variable_pct = bd_100 - sum_fixed_pct
      next unless variable_pct.positive?

      variable_pool_kw = consumption * variable_pct / bd_100
      head_by_asg     = variable_assignments.to_h { |a| [ a, headcount_for(a.assignable) ] }
      variable_total  = head_by_asg.values.sum
      next unless variable_total.positive?

      variable_total_bd = to_bd(variable_total)

      variable_assignments.each do |asg|
        head = head_by_asg[asg]
        next if head.zero?

        share = variable_pool_kw * to_bd(head) / variable_total_bd
        apply_assignable_share(allocations, ps, asg.assignable, share)
      end
    end

    allocations
  end

  # Headcount of a "nhóm đối tượng" — used both for the variable-pool
  # denominator and (for Organization) to split share down to CPs.
  def headcount_for(target)
    case target
    when Organization
      organization_personnel_total(target.id)
    when ContactPoint
      contact_point_personnel_total(target.id)
    when WorkGroup
      target.personnel_count.to_i
    else
      0
    end
  end

  # Route share to allocations. Engine is per-Organization → only writes
  # rows for CPs belonging to the current organization. WorkGroup shares
  # are computed by the loop above (to keep the denominator correct) but
  # not persisted here.
  def apply_assignable_share(allocations, pump_station, target, share)
    return unless share.positive?

    case target
    when Organization
      return unless target.id == organization.id

      distribute_within_org(allocations, pump_station, target.id, share)
    when ContactPoint
      return unless contact_point_ids.include?(target.id)

      allocations[target.id] += share
    when WorkGroup
      # F10 visibility handled by PumpAllocationCalculator.
    end
  end

  def organization_personnel_total(org_id)
    @organization_personnel_cache ||= {}
    @organization_personnel_cache[org_id] ||= Personnel
      .for_period(monthly_period.id)
      .joins(:contact_point)
      .where(contact_points: { organization_id: org_id })
      .sum("rank1_count + rank2_count + rank3_count + rank4_count + " \
           "rank5_count + rank6_count + rank7_count").to_i
  end

  def contact_point_personnel_total(cp_id)
    @contact_point_personnel_cache ||= {}
    @contact_point_personnel_cache[cp_id] ||= begin
      record = Personnel.for_period(monthly_period.id).for_contact_point(cp_id).first
      record ? record.total_count : 0
    end
  end

  # Distribute one org's slice (kW) across the org's CPs by personnel ratio.
  # Slice is lost when the org has 0 personnel (consistent with current
  # behaviour: CPs with personnel = 0 are skipped).
  def distribute_within_org(allocations, ps, org_id, org_share_kw)
    return unless org_share_kw.positive?

    cp_personnel = personnel_by_cp_for_org(ps, org_id)
    org_total    = cp_personnel.values.sum(0)
    return unless org_total.positive?

    org_total_bd = to_bd(org_total)
    cp_personnel.each do |cp_id, people|
      next if people.zero?
      next unless contact_point_ids.include?(cp_id)

      allocations[cp_id] += org_share_kw * to_bd(people) / org_total_bd
    end
  end

  # Pump stations serving the current engine's organization. A pump serves
  # the org when there is an assignment to either:
  #   - the Organization itself, or
  #   - any ContactPoint belonging to the Organization.
  # WorkGroup assignments alone do NOT pull a pump into the engine's view
  # (no CP to attach to).
  def pump_stations_serving_unit
    @pump_stations_serving_unit ||= begin
      cp_ids = contact_point_ids
      ps_ids = PumpStationAssignment.where(
        "(assignable_type = 'Organization' AND assignable_id = :org_id) OR " \
        "(assignable_type = 'ContactPoint' AND assignable_id IN (:cp_ids))",
        org_id: organization.id, cp_ids: cp_ids.presence || [ 0 ]
      ).pluck(:pump_station_id).uniq

      if ps_ids.empty?
        []
      else
        # Eager-load :meters so pump_station_consumption can read meter_ids
        # off the preloaded collection without firing a query per station.
        PumpStation.where(id: ps_ids).includes(:meters).select { |ps| ps.meters.any? }
      end
    end
  end

  def pump_station_consumption(pump_station)
    # Use .meters.map(&:id) (not .meter_ids) so we read straight from the
    # collection preloaded by `pump_stations_serving_unit` — no extra query.
    meter_ids = pump_station.meters.map(&:id)
    return ZERO if meter_ids.empty?

    to_bd(
      MeterReading.where(meter_id: meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  def pump_station_assignments_for(pump_station)
    @pump_station_assignments_for ||= {}
    @pump_station_assignments_for[pump_station.id] ||=
      PumpStationAssignment.for_pump_station(pump_station.id).to_a
  end

  # {cp_id => total_count} for CPs of one specific org in this period.
  def personnel_by_cp_for_org(pump_station, org_id)
    @personnel_by_cp_for_org ||= {}
    @personnel_by_cp_for_org[[ pump_station.id, org_id ]] ||=
      Personnel.for_period(monthly_period.id)
               .joins(:contact_point)
               .where(contact_points: { organization_id: org_id })
               .each_with_object({}) { |p, h| h[p.contact_point_id] = p.total_count }
  end

  def bd_100
    @bd_100 ||= BigDecimal("100")
  end

  # --- Misc -----------------------------------------------------------------
  def unit_price
    @unit_price ||= to_bd(monthly_period.unit_price)
  end

  # ================================================================ standards

  def build_standard_row(contact_point)
    personnel = personnel_by_cp[contact_point.id]
    rank_kws = {}
    (1..7).each do |i|
      count = personnel ? personnel.public_send(:"rank#{i}_count") : 0
      rank_kws[:"rank#{i}_kw"] = to_bd(count) * to_bd(rank_quotas[i])
    end

    total_personnel = personnel ? personnel.total_count : 0
    water_pump_standard = to_bd(total_personnel) * WATER_PUMP_RATE
    rank_total = rank_kws.values.sum(ZERO)
    total_standard = rank_total + water_pump_standard

    {
      contact_point: contact_point,
      contact_point_id: contact_point.id,
      monthly_period_id: monthly_period.id,
      total_personnel: total_personnel,
      **rank_kws,
      water_pump_standard_kw: water_pump_standard,
      total_standard_kw: total_standard
    }
  end

  # =================================================== deductions + usage + bill

  def apply_deductions_usage_and_billing(row)
    cp = row[:contact_point]
    total_standard = row[:total_standard_kw]
    personnel_count = to_bd(row[:total_personnel])

    # --- Số phải trừ ---
    savings = total_standard * savings_rate
    div_public = total_standard * division_public_rate
    unit_public = total_standard * unit_public_rate

    # Tổn hao phân bổ theo tỷ lệ kW công tơ của đầu mối / B (zone-wide
    # loss-pool denominator gồm normal + public_meter + pump). CP không có
    # công tơ → loss = 0. Pump nhận tổn hao qua pump_loss_share, không qua đây.
    cp_loss_pool = loss_pool_consumption_for(cp.id)
    loss =
      if loss_pool_consumption_in_zone.positive? && total_zone_loss.positive?
        total_zone_loss * cp_loss_pool / loss_pool_consumption_in_zone
      else
        ZERO
      end

    other = compute_other_deduction(cp, personnel_count)

    total_deduction = savings + loss + div_public + unit_public + other
    remaining_standard = total_standard - total_deduction

    # --- Sử dụng ---
    meter_usage = meter_usage_for(cp.id)
    pump_actual = pump_actual_for(cp.id)
    total_usage = meter_usage + pump_actual

    # --- So sánh + thành tiền ---
    over_under = total_usage - remaining_standard
    total_amount = over_under * unit_price

    row.merge!(
      savings_deduction_kw:          savings,
      loss_deduction_kw:             loss,
      division_public_deduction_kw:  div_public,
      unit_public_deduction_kw:      unit_public,
      other_deduction_kw:            other,
      total_deduction_kw:            total_deduction,
      remaining_standard_kw:         remaining_standard,
      meter_usage_kw:                meter_usage,
      water_pump_actual_kw:          pump_actual,
      total_usage_kw:                total_usage,
      over_under_kw:                 over_under,
      unit_price:                    unit_price,
      total_amount:                  total_amount
    )
  end

  def compute_other_deduction(contact_point, personnel_count)
    record = other_deductions_by_cp[contact_point.id]
    return ZERO unless record

    value = to_bd(record.other_value)
    case record.other_type
    when "fixed_kw" then value
    when "factor_per_person" then value * personnel_count
    else ZERO
    end
  end

  # ============================================================ config accessors

  def savings_rate
    @savings_rate ||= to_bd(unit_config&.savings_rate)
  end

  def division_public_rate
    @division_public_rate ||= to_bd(unit_config&.division_public_rate)
  end

  def unit_public_rate
    @unit_public_rate ||= to_bd(unit_config&.unit_public_rate)
  end

  # ===================================================================== persist

  def persist(row)
    calc = MonthlyCalculation.find_or_initialize_by(
      contact_point_id: row[:contact_point_id],
      monthly_period_id: row[:monthly_period_id]
    )
    calc.assign_attributes(row.except(:contact_point_id, :monthly_period_id))
    calc.save!
  end

  # =================================================================== utilities

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
