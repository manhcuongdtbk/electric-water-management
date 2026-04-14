# frozen_string_literal: true

# F08 + F09 + F10 — Engine tính toán bảng 22 cột cho một đơn vị (organization)
# trong một chu kỳ tháng (monthly_period).
#
# Tuân thủ nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html):
#
#   * 7 nhóm cấp bậc, lấy định mức từ RankQuota (effective_at period start).
#   * Tiêu chuẩn bơm nước = 9.45 kW/người/tháng (cố định; Personnel::WATER_PUMP_RATE).
#   * "Số phải trừ" gồm: Tiết kiệm, Tổn hao, Công cộng Sư đoàn, Công cộng đơn vị, Khác.
#     Tổn hao TRỪ khỏi tiêu chuẩn, KHÔNG cộng vào sử dụng.
#   * Tổn hao toàn đơn vị = điện lực cung cấp − tổng công tơ (normal + public_meter)
#     trong đơn vị. Phân bổ cho từng đầu mối theo tỷ lệ
#     tiêu chuẩn đầu mối / tổng tiêu chuẩn đơn vị.
#   * Bơm nước thực tế = phân bổ từ các trạm bơm phục vụ đơn vị
#     (pump_station_assignments) theo tỷ lệ quân số đầu mối / tổng quân số đơn vị.
#   * Mọi phép tính dùng BigDecimal. KHÔNG làm tròn ở bước trung gian.
#
# Interface:
#
#   engine = CalculationEngine.new(organization:, monthly_period:)
#   engine.compute  # → Array<Hash> (full-precision BigDecimal, not persisted)
#   engine.call     # → persists MonthlyCalculation rows (upsert), returns results
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
    # Step 1: compute per-contact-point "standards" first (needed for loss allocation).
    standards = contact_points.map do |cp|
      build_standard_row(cp)
    end

    sum_total_standard = standards.sum { |row| row[:total_standard_kw] } || ZERO

    # Step 2: layer deductions + usage + billing on top.
    standards.map do |row|
      apply_deductions_usage_and_billing(row, sum_total_standard)
      row.except(:contact_point)
    end
  end

  # Compute and persist results to monthly_calculations (upsert per contact point).
  def call
    results = compute
    ActiveRecord::Base.transaction do
      results.each { |row| persist(row) }
    end
    results
  end

  private

  # --------------------------------------------------------------------- data

  def contact_points
    @contact_points ||= organization.contact_points.ordered.to_a
  end

  def unit_config
    @unit_config ||= UnitConfig.find_by(organization: organization, monthly_period: monthly_period)
  end

  def personnel_by_cp
    @personnel_by_cp ||= Personnel.for_period(monthly_period.id)
                                  .where(contact_point_id: contact_points.map(&:id))
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

  def meter_usage_by_cp
    @meter_usage_by_cp ||= begin
      readings = MeterReading.for_period(monthly_period.id)
                             .joins(:meter)
                             .where(meters: { organization_id: organization.id,
                                              meter_type: Meter.meter_types[:normal] })
      # sum consumption per contact_point
      readings.each_with_object(Hash.new(ZERO)) do |r, hash|
        cp_id = r.meter.contact_point_id
        next unless cp_id

        hash[cp_id] += to_bd(r.consumption)
      end
    end
  end

  # Sum of consumption for ALL meters in this organization that contribute to
  # the loss pool (normal + public_meter; NOT pump_station meters).
  def total_meter_consumption_in_unit
    @total_meter_consumption_in_unit ||= begin
      readings = MeterReading.for_period(monthly_period.id)
                             .joins(:meter)
                             .where(meters: { organization_id: organization.id })
                             .where.not(meters: { meter_type: Meter.meter_types[:pump_station] })
      readings.sum { |r| to_bd(r.consumption) }
    end
  end

  def total_unit_loss
    @total_unit_loss ||= begin
      supply = unit_config&.electricity_supply_kw
      if supply.blank?
        ZERO
      else
        diff = to_bd(supply) - total_meter_consumption_in_unit
        diff.negative? ? ZERO : diff
      end
    end
  end

  # Bơm nước thực tế = tổng công tơ pump_station cho các trạm phục vụ đơn vị này.
  # PumpStation được gán tới organization qua pump_station_assignments.
  def total_pump_energy_for_unit
    @total_pump_energy_for_unit ||= begin
      station_ids = PumpStationAssignment.for_organization(organization.id).pluck(:pump_station_id)
      return ZERO if station_ids.empty?

      meter_ids = PumpStation.where(id: station_ids).where.not(meter_id: nil).pluck(:meter_id)
      return ZERO if meter_ids.empty?

      readings = MeterReading.for_period(monthly_period.id).where(meter_id: meter_ids)
      readings.sum { |r| to_bd(r.consumption) }
    end
  end

  def total_org_personnel
    @total_org_personnel ||= personnel_by_cp.values.sum(0) { |p| p.total_count }
  end

  def other_deductions_by_cp
    @other_deductions_by_cp ||= ContactPointOtherDeduction
                                .where(monthly_period: monthly_period,
                                       contact_point_id: contact_points.map(&:id))
                                .index_by(&:contact_point_id)
  end

  def unit_price
    @unit_price ||= to_bd(monthly_period.unit_price)
  end

  # ---------------------------------------------------------------- standards

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

  # ------------------------------------------------- deductions + usage + bill

  def apply_deductions_usage_and_billing(row, sum_total_standard)
    cp = row[:contact_point]
    total_standard = row[:total_standard_kw]
    personnel_count = to_bd(row[:total_personnel])

    # --- Số phải trừ ---
    savings = total_standard * savings_rate
    div_public = total_standard * division_public_rate
    unit_public = total_standard * unit_public_rate

    loss =
      if sum_total_standard.positive? && total_unit_loss.positive?
        total_unit_loss * total_standard / sum_total_standard
      else
        ZERO
      end

    other = compute_other_deduction(cp, personnel_count)

    total_deduction = savings + loss + div_public + unit_public + other
    remaining_standard = total_standard - total_deduction

    # --- Sử dụng ---
    meter_usage = meter_usage_by_cp[cp.id] || ZERO
    pump_actual =
      if total_org_personnel.positive?
        total_pump_energy_for_unit * personnel_count / to_bd(total_org_personnel)
      else
        ZERO
      end
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

  # ---------------------------------------------------------- config accessors

  def savings_rate
    @savings_rate ||= to_bd(unit_config&.savings_rate)
  end

  def division_public_rate
    @division_public_rate ||= to_bd(unit_config&.division_public_rate)
  end

  def unit_public_rate
    @unit_public_rate ||= to_bd(unit_config&.unit_public_rate)
  end

  # ------------------------------------------------------------------ persist

  def persist(row)
    calc = MonthlyCalculation.find_or_initialize_by(
      contact_point_id: row[:contact_point_id],
      monthly_period_id: row[:monthly_period_id]
    )
    calc.assign_attributes(row.except(:contact_point_id, :monthly_period_id))
    calc.save!
  end

  # ---------------------------------------------------------------- utilities

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
