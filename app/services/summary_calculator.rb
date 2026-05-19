class SummaryCalculator
  Result = Struct.new(:calculations, :warnings, keyword_init: true)

  def initialize(zone:, period:, loss_results:, pump_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
    @pump_results = pump_results
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    residentials = @query.residential_contact_points.includes(:meters, :unit).to_a
    @meter_usages = @query.meter_usages
    @unit_configs_by_unit_id = preload_unit_configs(residentials)
    @other_deductions_by_cp_id = preload_other_deductions(residentials)
    @personnel_by_cp_id = preload_personnel_entries(residentials)

    calculations = residentials.map { |cp| compute_and_persist(cp) }
    Result.new(calculations: calculations, warnings: [])
  end

  private

  def preload_unit_configs(residentials)
    unit_ids = residentials.map(&:unit_id).compact.uniq
    UnitConfig.where(unit_id: unit_ids, period_id: @period.id).index_by(&:unit_id)
  end

  def preload_other_deductions(residentials)
    OtherDeduction.where(contact_point_id: residentials.map(&:id), period_id: @period.id)
                  .index_by(&:contact_point_id)
  end

  def preload_personnel_entries(residentials)
    entries = PersonnelEntry.where(contact_point_id: residentials.map(&:id), period_id: @period.id)
                            .includes(:rank).to_a
    entries.group_by(&:contact_point_id)
  end

  def compute_and_persist(contact_point)
    personnel_entries = @personnel_by_cp_id[contact_point.id] || []
    total_personnel = personnel_entries.sum(&:count)
    residential_standard = personnel_entries.sum(BigDecimal("0")) do |entry|
      BigDecimal(entry.count.to_s) * BigDecimal(entry.rank.quota.to_s)
    end
    water_pump_standard = BigDecimal(total_personnel.to_s) * BigDecimal(@period.water_pump_standard.to_s)
    total_standard = residential_standard + water_pump_standard

    savings_deduction = BigDecimal(@period.savings_rate.to_s) * total_standard / BigDecimal("100")
    loss_deduction = @loss_results.contact_point_losses[contact_point.id] || BigDecimal("0")
    division_public_deduction = BigDecimal(@period.division_public_rate.to_s) * total_standard / BigDecimal("100")
    unit_public_deduction = compute_unit_public_deduction(contact_point, total_standard)
    other_deduction = compute_other_deduction(contact_point, total_personnel)

    total_deduction = savings_deduction + loss_deduction + division_public_deduction +
                      unit_public_deduction + other_deduction
    remaining_standard = total_standard - total_deduction

    residential_usage = contact_point.meters.with_discarded.sum(BigDecimal("0")) do |meter|
      @meter_usages[meter.id] || BigDecimal("0")
    end
    water_pump_usage = @pump_results.contact_point_allocations[contact_point.id] || BigDecimal("0")
    total_usage = residential_usage + water_pump_usage

    delta = total_usage - remaining_standard
    if delta > 0
      deficit = delta
      surplus = BigDecimal("0")
    else
      deficit = BigDecimal("0")
      surplus = -delta
    end

    unit_price = BigDecimal(@period.unit_price.to_s)
    deficit_amount = deficit * unit_price
    surplus_amount = surplus * unit_price

    calculation = Calculation.find_or_initialize_by(contact_point_id: contact_point.id, period_id: @period.id)
    calculation.assign_attributes(
      total_personnel: total_personnel,
      residential_standard: residential_standard,
      water_pump_standard: water_pump_standard,
      total_standard: total_standard,
      savings_deduction: savings_deduction,
      loss_deduction: loss_deduction,
      division_public_deduction: division_public_deduction,
      unit_public_deduction: unit_public_deduction,
      other_deduction: other_deduction,
      total_deduction: total_deduction,
      remaining_standard: remaining_standard,
      residential_usage: residential_usage,
      water_pump_usage: water_pump_usage,
      total_usage: total_usage,
      deficit: deficit,
      surplus: surplus,
      deficit_amount: deficit_amount,
      surplus_amount: surplus_amount,
      calculated_at: Time.current
    )
    calculation.save!
    calculation
  end

  def compute_unit_public_deduction(contact_point, total_standard)
    return BigDecimal("0") if contact_point.unit_id.nil?
    config = @unit_configs_by_unit_id[contact_point.unit_id]
    return BigDecimal("0") if config.nil?
    BigDecimal(config.unit_public_rate.to_s) * total_standard / BigDecimal("100")
  end

  def compute_other_deduction(contact_point, total_personnel)
    deduction = @other_deductions_by_cp_id[contact_point.id]
    return BigDecimal("0") if deduction.nil?

    case deduction.other_type
    when "fixed"
      BigDecimal(deduction.other_value.to_s)
    when "coefficient"
      BigDecimal(deduction.other_value.to_s) * BigDecimal(total_personnel.to_s)
    else
      BigDecimal("0")
    end
  end
end
