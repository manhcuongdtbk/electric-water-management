# frozen_string_literal: true

# SummaryCalculator — phase 3 of engine tách 3.
#
# Per-CP tổng hợp bảng 22 cột: tiêu chuẩn (rank1..7_kw + water_pump_standard)
# + các khoản trừ (savings, loss, division_public, unit_public, other)
# + sử dụng (meter + pump) + so sánh + thành tiền.
#
# Standalone service: DB lookups (personnel, rank quotas, configs, other
# deductions, meter usage) đều tự lo. Loss và pump không tính lại — đọc qua
# injected `loss_results` + `pump_results` từ CalculationOrchestrator.
#
# Interface:
#
#   summary = SummaryCalculator.new(
#     organization:   org,
#     monthly_period: period,
#     loss_results:   loss_calculator.call,
#     pump_results:   pump_calculator.call
#   )
#   summary.compute(contact_points)  # → Array<Hash> (full-precision BigDecimal)
#
# Row Hash chứa cả `contact_point:` (CP object) — orchestrator strip trước khi
# persist. Mọi phép tính dùng BigDecimal, KHÔNG làm tròn trung gian.
class SummaryCalculator
  ZERO = BigDecimal("0")
  WATER_PUMP_RATE = Personnel::WATER_PUMP_RATE

  attr_reader :organization, :monthly_period, :loss_results, :pump_results

  def initialize(organization:, monthly_period:, loss_results:, pump_results:)
    @organization   = organization
    @monthly_period = monthly_period
    @loss_results   = loss_results
    @pump_results   = pump_results
  end

  def compute(contact_points)
    @contact_points = contact_points
    contact_points.map do |cp|
      row = build_standard_row(cp)
      apply_deductions_usage_and_billing(row)
      row
    end
  end

  private

  # ============================================================ data caching

  def contact_point_ids
    @contact_point_ids ||= @contact_points.map(&:id)
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
  # Only `normal` meters bill into the CP usage column. `no_loss` is an
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

  # ============================================================ result readers

  def pump_actual_for(cp_id)
    pump_results[:allocations_by_cp][cp_id] || ZERO
  end

  def loss_deduction_for(cp_id)
    loss_pool_by_cp = loss_results[:loss_pool_consumption_by_cp]
    loss_pool_total = loss_results[:loss_pool_consumption_in_zone]
    total_loss      = loss_results[:total_zone_loss]

    return ZERO unless total_loss&.positive? && loss_pool_total&.positive?

    cp_consumption = loss_pool_by_cp[cp_id] || ZERO
    return ZERO unless cp_consumption.positive?

    total_loss * cp_consumption / loss_pool_total
  end

  # ============================================================ config accessors

  def unit_price
    @unit_price ||= to_bd(monthly_period.unit_price)
  end

  def savings_rate
    @savings_rate ||= to_bd(division_config&.savings_rate)
  end

  def division_public_rate
    @division_public_rate ||= to_bd(division_config&.division_public_rate)
  end

  def unit_public_rate
    @unit_public_rate ||= to_bd(unit_config&.unit_public_rate)
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
    savings     = total_standard * savings_rate
    div_public  = total_standard * division_public_rate
    unit_public = total_standard * unit_public_rate
    loss        = loss_deduction_for(cp.id)
    other       = compute_other_deduction(cp, personnel_count)

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

  # =================================================================== utilities

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
