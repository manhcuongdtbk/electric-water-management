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
#   * Tổn hao toàn đơn vị = điện lực cung cấp − tổng công tơ (normal + public_meter)
#     trong đơn vị. Phân bổ cho từng đầu mối theo tỷ lệ
#     kW công tơ (normal + public_meter) đầu mối / kW công tơ toàn đơn vị.
#     (Đầu mối không có công tơ → loss = 0.)
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
  # (anything that is NOT a pump-station meter). Pump-station meters are
  # billed separately and don't participate in loss allocation.
  def loss_pool_consumption_by_cp
    @loss_pool_consumption_by_cp ||= MeterReading
                                     .for_period(monthly_period.id)
                                     .joins(:meter)
                                     .where(meters: { organization_id: organization.id })
                                     .where.not(meters: { meter_type: Meter.meter_types[:pump_station] })
                                     .group("meters.contact_point_id")
                                     .sum(:consumption)
                                     .transform_values { |v| to_bd(v) }
  end

  def loss_pool_consumption_for(cp_id)
    loss_pool_consumption_by_cp[cp_id] || ZERO
  end

  # --- Total loss (unit-wide) ----------------------------------------------
  # Σ(normal + public_meter) readings for meters belonging to this organization.
  # Pump-station meters are NOT in the loss pool (they're billed separately).
  def total_meter_consumption_in_unit
    @total_meter_consumption_in_unit ||= to_bd(
      MeterReading
        .for_period(monthly_period.id)
        .joins(:meter)
        .where(meters: { organization_id: organization.id })
        .where.not(meters: { meter_type: Meter.meter_types[:pump_station] })
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
        diff = to_bd(supply) - total_meter_consumption_in_unit
        diff.negative? ? ZERO : diff
      end
  end

  # --- Water pump actual (per CP) ------------------------------------------
  # For each pump station serving our unit, distribute its meter reading across
  # ALL contact points in ALL served organizations (by personnel ratio). Then
  # sum the shares that fall on our unit's contact points.
  #
  # A pump that serves one unit gives that unit 100% (same as the simple case).
  # A pump that serves two units with 3 and 7 people respectively gives the
  # first unit 3/10 × consumption, the second 7/10 × consumption — matches
  # Bảng II in docs/BANG_22_COT_ANALYSIS.md.
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

      served_personnel = served_personnel_map_for(ps)
      total_served = served_personnel.values.sum(0)
      next unless total_served.positive?

      total_served_bd = to_bd(total_served)
      contact_point_ids.each do |cp_id|
        people = served_personnel[cp_id]
        next if people.nil? || people.zero?

        allocations[cp_id] += consumption * to_bd(people) / total_served_bd
      end
    end

    allocations
  end

  def pump_stations_serving_unit
    @pump_stations_serving_unit ||= begin
      ps_ids = PumpStationAssignment.for_organization(organization.id).pluck(:pump_station_id)
      if ps_ids.empty?
        []
      else
        PumpStation.where(id: ps_ids).where.not(meter_id: nil).to_a
      end
    end
  end

  def pump_station_consumption(pump_station)
    reading = MeterReading.find_by(meter_id: pump_station.meter_id, monthly_period_id: monthly_period.id)
    to_bd(reading&.consumption)
  end

  # {cp_id => personnel_count} for all contact points in all organizations
  # served by this pump station (in this period).
  def served_personnel_map_for(pump_station)
    org_ids = PumpStationAssignment.for_pump_station(pump_station.id).pluck(:organization_id)
    return {} if org_ids.empty?

    Personnel.for_period(monthly_period.id)
             .joins(:contact_point)
             .where(contact_points: { organization_id: org_ids })
             .each_with_object({}) { |p, hash| hash[p.contact_point_id] = p.total_count }
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
