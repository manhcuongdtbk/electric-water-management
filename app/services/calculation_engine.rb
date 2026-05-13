# frozen_string_literal: true

# F08 + F09 + F10 — Engine tính toán bảng 22 cột cho một đơn vị (organization)
# trong một chu kỳ tháng (monthly_period).
#
# Tuân thủ nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html):
#
#   * 7 nhóm cấp bậc, lấy định mức từ RankQuota (1 row per rank_group).
#   * Tiêu chuẩn bơm nước = 9.45 kW/người/tháng (Personnel::WATER_PUMP_RATE).
#   * "Số phải trừ" gồm: Tiết kiệm, Tổn hao, Công cộng Sư đoàn, Công cộng đơn vị, Khác.
#     Tổn hao TRỪ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng.
#   * Tổn hao + bơm nước được tính TOÀN KHU VỰC bởi các service tách rời:
#       - LossCalculator (zone:, monthly_period:) — tổn hao zone, per-CP + per-pump.
#       - PumpAllocationCalculator (zone:, monthly_period:, loss_calculator:) —
#         phân bổ pump pool (consumption + pump_loss_share) theo mô hình 30/70
#         (M6) cho mọi assignment trong zone, drill xuống tới CP.
#     Khi org chưa được gán Zone, zone = nil → cả hai service short-circuit về 0.
#   * Engine orchestration: tổng hợp standard + deductions + usage + billing
#     per CP, đọc per-CP loss/pump từ 2 service trên qua memoized accessors.
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

  # Division-level UnitConfig holds savings_rate + division_public_rate (set
  # by admin_level1 on /unit_configs). Unit-level row holds unit_public_rate
  # + other_deduction_*. Engine runs per-Unit, so reach up to the parent.
  def division_organization
    @division_organization ||= organization.unit? ? organization.parent : organization
  end

  def division_config
    return @division_config if defined?(@division_config)

    @division_config = division_organization &&
                       UnitConfig.find_by(organization: division_organization,
                                          monthly_period: monthly_period)
  end

  def personnel_by_cp
    @personnel_by_cp ||= Personnel.for_period(monthly_period.id)
                                  .where(contact_point_id: contact_point_ids)
                                  .index_by(&:contact_point_id)
  end

  def rank_quotas
    @rank_quotas ||= RankQuota::RANK_GROUPS.each_with_object({}) do |group, hash|
      quota = RankQuota.for_rank(group).first
      hash[group] = quota&.quota_kw || ZERO
    end
  end

  def other_deductions_by_cp
    @other_deductions_by_cp ||= ContactPointOtherDeduction
                                .where(monthly_period: monthly_period,
                                       contact_point_id: contact_point_ids)
                                .index_by(&:contact_point_id)
  end

  # --- Meter usage (per CP) — DB-side group + sum ---------------------------
  # Only `normal` meters bill into the CP usage column. `no_loss` is now an
  # orthogonal boolean (not a separate meter_type), so this filter naturally
  # includes both lossy and non-lossy residential meters — they all belong to
  # đầu mối sinh hoạt and their kW is billed. The no_loss flag only changes
  # whether a meter participates in the loss pool, not whether it's billed.
  def meter_usage_by_cp
    @meter_usage_by_cp ||= MeterReading
                           .for_period(monthly_period.id)
                           .joins(:meter)
                           .where(meters: {
                             organization_id: organization.id,
                             meter_type: Meter.meter_types[:normal]
                           })
                           .group("meters.contact_point_id")
                           .sum(:consumption)
                           .transform_values { |v| to_bd(v) }
  end

  def meter_usage_for(cp_id)
    meter_usage_by_cp[cp_id] || ZERO
  end

  # --- Zone resolution -----------------------------------------------------
  # Org belongs to a Zone (multiple orgs can share a zone). If the org has no
  # zone (e.g. seed/spec data), zone is nil and downstream calculators short-
  # circuit to zero.
  def zone
    @zone ||= organization.zone
  end

  # --- Loss phase (zone-wide tổn hao) — delegated to LossCalculator -------
  # Loss values (C, B, per-CP numerators, supply) live in LossCalculator.
  # Engine memoizes the instance + the call() hash so per-CP / per-pump
  # access stays cheap inside compute().
  def loss_calculator
    @loss_calculator ||= LossCalculator.new(zone: zone, monthly_period: monthly_period)
  end

  def loss_results
    @loss_results ||= loss_calculator.call
  end

  # --- Pump phase (zone-wide bơm nước) — delegated to PumpAllocationCalculator
  # PAC processes every pump station in the zone, partitions each pool by
  # the 30/70 model (fixed slots first, remaining split by personnel), and
  # drills Organization / ContactPointGroup shares down to CPs. Engine
  # only reads per-CP kW for the CPs it persists.
  def pump_calculator
    @pump_calculator ||= PumpAllocationCalculator.new(
      zone:            zone,
      monthly_period:  monthly_period,
      loss_calculator: loss_calculator
    )
  end

  def pump_results
    @pump_results ||= pump_calculator.call
  end

  def pump_allocations_by_cp
    pump_results[:allocations_by_cp]
  end

  def pump_actual_for(cp_id)
    pump_allocations_by_cp[cp_id] || ZERO
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
    cp_loss_pool = loss_results[:loss_pool_consumption_by_cp][cp.id] || ZERO
    b = loss_results[:loss_pool_consumption_in_zone]
    c = loss_results[:total_zone_loss]
    loss =
      if b.positive? && c.positive?
        c * cp_loss_pool / b
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
    @savings_rate ||= to_bd(division_config&.savings_rate)
  end

  def division_public_rate
    @division_public_rate ||= to_bd(division_config&.division_public_rate)
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
