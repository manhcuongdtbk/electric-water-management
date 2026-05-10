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
#   * Tổn hao toàn đơn vị = điện lực cung cấp − kW công tơ no_loss
#     − tổng công tơ (normal + public_meter) trong đơn vị.
#     Phân bổ cho từng đầu mối theo tỷ lệ
#     kW công tơ (normal + public_meter) đầu mối / kW công tơ toàn đơn vị.
#     (Đầu mối không có công tơ thường → loss = 0; công tơ no_loss không tham gia.)
#   * Bơm nước thực tế: mỗi trạm bơm phục vụ đơn vị (qua pump_station_assignments)
#     phân bổ công tơ pump của trạm cho từng đầu mối theo tỷ lệ
#     quân số đầu mối / tổng quân số trên TẤT CẢ các đơn vị mà trạm bơm phục vụ.
#     (Trạm bơm phục vụ nhiều đơn vị được chia công bằng theo quân số.)
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

  # --- Loss-pool consumption (per CP) — DB-side group + sum ----------------
  # Used as the numerator for loss allocation. Includes normal + public_meter
  # only. Pump-station meters are billed separately. No-loss meters are
  # behind the substation (no internal-line loss) and are subtracted from
  # supply directly — neither participate in loss allocation.
  def loss_pool_consumption_by_cp
    @loss_pool_consumption_by_cp ||= MeterReading
                                     .for_period(monthly_period.id)
                                     .joins(:meter)
                                     .where(meters: { organization_id: organization.id })
                                     .where.not(meters: { meter_type: [
                                       Meter.meter_types[:pump_station],
                                       Meter.meter_types[:no_loss]
                                     ] })
                                     .group("meters.contact_point_id")
                                     .sum(:consumption)
                                     .transform_values { |v| to_bd(v) }
  end

  def loss_pool_consumption_for(cp_id)
    loss_pool_consumption_by_cp[cp_id] || ZERO
  end

  # --- Total loss (unit-wide) ----------------------------------------------
  # Σ(normal + public_meter) readings for meters belonging to this organization.
  # Pump-station and no_loss meters are NOT in the loss pool — kept consistent
  # with loss_pool_consumption_by_cp so that the per-CP map sums to this total.
  def total_meter_consumption_in_unit
    @total_meter_consumption_in_unit ||= to_bd(
      MeterReading
        .for_period(monthly_period.id)
        .joins(:meter)
        .where(meters: { organization_id: organization.id })
        .where.not(meters: { meter_type: [
          Meter.meter_types[:pump_station],
          Meter.meter_types[:no_loss]
        ] })
        .sum(:consumption)
    )
  end

  # Σ(no_loss) readings — meters at the substation that don't go through
  # internal lines, so their kW must be removed from supply BEFORE computing
  # internal-line loss (they don't contribute to the loss pool).
  def no_loss_consumption_in_unit
    @no_loss_consumption_in_unit ||= to_bd(
      MeterReading
        .for_period(monthly_period.id)
        .joins(:meter)
        .where(meters: { organization_id: organization.id,
                         meter_type: Meter.meter_types[:no_loss] })
        .sum(:consumption)
    )
  end

  def total_unit_loss
    return @total_unit_loss if defined?(@total_unit_loss)

    supply = unit_config&.electricity_supply_kw
    @total_unit_loss =
      if supply.blank?
        ZERO
      else
        diff = to_bd(supply) - no_loss_consumption_in_unit - total_meter_consumption_in_unit
        diff.negative? ? ZERO : diff
      end
  end

  # --- Water pump actual (per CP) ------------------------------------------
  # 30/70 model (M6). Each pump station has assignments to organizations; an
  # assignment may carry a `fixed_pump_percentage` (e.g. 30) meaning that org
  # takes that slice off the top, regardless of personnel. Orgs with NULL
  # percentage share the remaining pool by personnel ratio. Within an org
  # (fixed or variable), the share is split across the org's contact points
  # by personnel ratio (CPs with 0 personnel receive nothing — slice is lost
  # if the whole org has 0 personnel).
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
      consumption = pump_station_consumption(ps)
      next unless consumption.positive?

      assignments = pump_station_assignments_for(ps)
      next if assignments.empty?

      fixed_assignments    = assignments.select(&:fixed?)
      variable_assignments = assignments - fixed_assignments

      sum_fixed_pct = fixed_assignments.sum { |a| to_bd(a.fixed_pump_percentage) }
      sum_fixed_pct = bd_100 if sum_fixed_pct > bd_100

      fixed_assignments.each do |asg|
        next unless asg.organization_id == organization.id

        org_pct      = to_bd(asg.fixed_pump_percentage)
        org_share_kw = consumption * org_pct / bd_100
        distribute_within_org(allocations, ps, asg.organization_id, org_share_kw)
      end

      variable_pct = bd_100 - sum_fixed_pct
      next unless variable_pct.positive?

      variable_pool_kw = consumption * variable_pct / bd_100
      org_personnel    = personnel_by_org_for(ps)
      variable_org_ids = variable_assignments.map(&:organization_id)
      variable_total   = variable_org_ids.sum { |oid| org_personnel[oid].to_i }
      next unless variable_total.positive?

      variable_total_bd = to_bd(variable_total)

      variable_assignments.each do |asg|
        next unless asg.organization_id == organization.id

        personnel_by_cp_for_org(ps, asg.organization_id).each do |cp_id, people|
          next if people.zero?
          next unless contact_point_ids.include?(cp_id)

          allocations[cp_id] += variable_pool_kw * to_bd(people) / variable_total_bd
        end
      end
    end

    allocations
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

  def pump_stations_serving_unit
    @pump_stations_serving_unit ||= begin
      ps_ids = PumpStationAssignment.for_organization(organization.id).pluck(:pump_station_id)
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
    to_bd(
      MeterReading.where(meter_id: pump_station.meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  def pump_station_assignments_for(pump_station)
    @pump_station_assignments_for ||= {}
    @pump_station_assignments_for[pump_station.id] ||=
      PumpStationAssignment.for_pump_station(pump_station.id).to_a
  end

  # {org_id => total_personnel} across CPs of every org assigned to this pump
  # in this period — used to compute the variable-pool denominator.
  def personnel_by_org_for(pump_station)
    @personnel_by_org_for ||= {}
    @personnel_by_org_for[pump_station.id] ||= begin
      org_ids = pump_station_assignments_for(pump_station).map(&:organization_id)
      if org_ids.empty?
        {}
      else
        Personnel.for_period(monthly_period.id)
                 .joins(:contact_point)
                 .where(contact_points: { organization_id: org_ids })
                 .group("contact_points.organization_id")
                 .sum("rank1_count + rank2_count + rank3_count + rank4_count + " \
                      "rank5_count + rank6_count + rank7_count")
      end
    end
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

    # Tổn hao phân bổ theo tỷ lệ kW công tơ (normal + public_meter)
    # đầu mối / tổng kW công tơ đơn vị. Đầu mối không có công tơ → loss = 0.
    cp_loss_pool = loss_pool_consumption_for(cp.id)
    total_loss_pool = total_meter_consumption_in_unit
    loss =
      if total_loss_pool.positive? && total_unit_loss.positive?
        total_unit_loss * cp_loss_pool / total_loss_pool
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
