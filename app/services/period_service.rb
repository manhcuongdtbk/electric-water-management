class PeriodService
  Error = Class.new(StandardError)

  OpenResult = Struct.new(:period, :warnings, keyword_init: true)
  CloseResult = Struct.new(:period, :warnings, keyword_init: true)

  DEFAULT_RANKS = [
    { name: "Chỉ huy Sư đoàn; sĩ quan có trần quân hàm là Đại tá", quota: BigDecimal("570"), position: 1 },
    { name: "Chỉ huy Trung đoàn; sĩ quan có trần quân hàm là Thượng tá", quota: BigDecimal("440"), position: 2 },
    { name: "Chỉ huy Tiểu đoàn; sĩ quan có trần quân hàm là Trung tá, Thiếu tá", quota: BigDecimal("305"), position: 3 },
    { name: "Chỉ huy Đại đội, Trung đội; sĩ quan có trần quân hàm là cấp Úy", quota: BigDecimal("130"), position: 4 },
    { name: "Cơ quan Sư đoàn, Trung đoàn", quota: BigDecimal("210"), position: 5 },
    { name: "Tiểu đoàn, Đại đội", quota: BigDecimal("110"), position: 6 },
    { name: "Hạ sĩ quan, binh sĩ", quota: BigDecimal("24"), position: 7 }
  ].freeze

  DEFAULT_SAVINGS_RATE = BigDecimal("5")
  DEFAULT_DIVISION_PUBLIC_RATE = BigDecimal("10")
  DEFAULT_WATER_PUMP_STANDARD = BigDecimal("9.45")
  DEFAULT_UNIT_PUBLIC_RATE = BigDecimal("0")

  def open_new_period(year: nil, month: nil, unit_price: nil)
    if (open_period = Period.open.first)
      raise Error, I18n.t("services.period_service.errors.has_open_period",
                          year: open_period.year, month: open_period.month)
    end

    previous = Period.order(:year, :month).last

    ActiveRecord::Base.transaction do
      attrs = build_period_attributes(previous: previous, year: year, month: month, unit_price: unit_price)
      period = Period.create!(attrs)

      if previous
        copy_ranks_from(previous, period)
        copy_pump_allocations_from(previous, period)
      else
        seed_default_ranks(period)
      end

      snapshot_existing_entities(period, previous)

      OpenResult.new(period: period, warnings: [])
    end
  end

  def close_period(period)
    period.update!(closed: true)
    CloseResult.new(period: period, warnings: mismatch_warnings_with_next_period(period))
  end

  def reopen_period(period)
    if (other_open = Period.open.where.not(id: period.id).first)
      raise Error, I18n.t("services.period_service.errors.reopen_blocked_by_open_period",
                          year: other_open.year, month: other_open.month)
    end
    period.update!(closed: false)
    period
  end

  private

  def build_period_attributes(previous:, year:, month:, unit_price:)
    if previous
      next_yr, next_mo = next_year_month(previous.year, previous.month)
      {
        year: next_yr,
        month: next_mo,
        closed: false,
        unit_price: previous.unit_price,
        savings_rate: previous.savings_rate,
        division_public_rate: previous.division_public_rate,
        water_pump_standard: previous.water_pump_standard
      }
    else
      if year.nil? || month.nil? || unit_price.nil?
        raise Error, I18n.t("services.period_service.errors.first_period_requires_year_month")
      end
      {
        year: year,
        month: month,
        closed: false,
        unit_price: BigDecimal(unit_price.to_s),
        savings_rate: DEFAULT_SAVINGS_RATE,
        division_public_rate: DEFAULT_DIVISION_PUBLIC_RATE,
        water_pump_standard: DEFAULT_WATER_PUMP_STANDARD
      }
    end
  end

  def next_year_month(current_year, current_month)
    return [current_year + 1, 1] if current_month == 12
    [current_year, current_month + 1]
  end

  def seed_default_ranks(period)
    DEFAULT_RANKS.each { |attrs| period.ranks.create!(attrs) }
  end

  def copy_ranks_from(previous, new_period)
    previous.ranks.order(:position).each do |rank|
      new_period.ranks.create!(name: rank.name, quota: rank.quota, position: rank.position)
    end
  end

  def copy_pump_allocations_from(previous, new_period)
    previous.pump_allocations.find_each do |allocation|
      new_period.pump_allocations.create!(
        zone_id: allocation.zone_id,
        unit_id: allocation.unit_id,
        contact_point_id: allocation.contact_point_id,
        coefficient: allocation.coefficient,
        fixed_percentage: allocation.fixed_percentage
      )
    end
  end

  # Snapshot các entity đã tồn tại từ trước:
  # - Khi mở kỳ ĐẦU TIÊN: các unit/contact_point/meter đã được tạo trước khi mở kỳ
  #   (không có callback để tạo snapshot tự động). Method này tạo snapshot mặc định cho chúng.
  # - Khi mở kỳ KẾ TIẾP: các entity tạo giữa kỳ trước đã có snapshot cho kỳ trước.
  #   Method này tạo snapshot cho kỳ MỚI bằng cách kế thừa từ kỳ trước (count, no_loss, reading_end → reading_start...).
  # Dùng `where.not(id: existing)` để không duplicate với callback after_create
  # (callback sẽ chạy nếu entity tạo SAU khi period đã open).
  def snapshot_existing_entities(period, previous)
    snapshot_units(period, previous)
    snapshot_residential_contact_points(period, previous)
    snapshot_non_establishment_contact_points(period, previous)
    snapshot_meters(period, previous)
  end

  def snapshot_units(period, previous)
    existing_unit_ids = period.unit_configs.select(:unit_id)
    Unit.kept.where.not(id: existing_unit_ids).find_each do |unit|
      previous_config = previous&.unit_configs&.find_by(unit: unit)
      unit.unit_configs.create!(
        period: period,
        unit_public_rate: previous_config&.unit_public_rate || DEFAULT_UNIT_PUBLIC_RATE
      )
    end
  end

  def snapshot_residential_contact_points(period, previous)
    residentials = ContactPoint.kept.where(contact_point_type: "residential")
    existing_pe_cp_ids = period.personnel_entries.select(:contact_point_id)
    residentials.where.not(id: existing_pe_cp_ids).find_each do |cp|
      period.ranks.find_each do |rank|
        count = if previous
          previous_rank = previous.ranks.find_by(position: rank.position)
          previous_entry = previous_rank && PersonnelEntry.find_by(contact_point: cp, period: previous, rank: previous_rank)
          previous_entry&.count || 0
        else
          0
        end
        cp.personnel_entries.create!(period: period, rank: rank, count: count)
      end
    end

    existing_od_cp_ids = period.other_deductions.select(:contact_point_id)
    residentials.where.not(id: existing_od_cp_ids).find_each do |cp|
      previous_deduction = previous && OtherDeduction.find_by(contact_point: cp, period: previous)
      cp.other_deductions.create!(
        period: period,
        other_type: previous_deduction&.other_type || "fixed",
        other_value: previous_deduction&.other_value || 0
      )
    end
  end

  def snapshot_non_establishment_contact_points(period, previous)
    non_establishments = ContactPoint.kept.where(contact_point_type: "non_establishment")
    existing_nes_cp_ids = period.non_establishment_snapshots.select(:contact_point_id)
    non_establishments.where.not(id: existing_nes_cp_ids).find_each do |cp|
      previous_snapshot = previous && NonEstablishmentSnapshot.find_by(contact_point: cp, period: previous)
      personnel = previous_snapshot&.personnel_count || cp.personnel_count
      cp.non_establishment_snapshots.create!(period: period, personnel_count: personnel)
    end
  end

  def snapshot_meters(period, previous)
    existing_meter_ids = period.meter_readings.select(:meter_id)
    Meter.kept.where.not(id: existing_meter_ids).find_each do |meter|
      previous_reading = previous && MeterReading.find_by(meter: meter, period: previous)
      reading_start = previous_reading&.reading_end || BigDecimal("0")
      meter.meter_readings.create!(
        period: period,
        reading_start: reading_start,
        reading_end: nil,
        no_loss: meter.no_loss
      )
    end
  end

  def mismatch_warnings_with_next_period(period)
    next_period = Period.where("(year * 100 + month) > ?", period.year * 100 + period.month)
                        .order(:year, :month).first
    return [] unless next_period

    warnings = []
    period.meter_readings.includes(:meter).find_each do |reading|
      next if reading.reading_end.nil?
      next_reading = MeterReading.find_by(meter_id: reading.meter_id, period: next_period)
      next if next_reading.nil?
      next if BigDecimal(reading.reading_end.to_s) == BigDecimal(next_reading.reading_start.to_s)

      warnings << I18n.t("services.period_service.warnings.meter_reading_mismatch",
                         meter: reading.meter.name,
                         period_month: period.month,
                         period_year: period.year,
                         reading_end: reading.reading_end,
                         next_month: next_period.month,
                         next_year: next_period.year,
                         reading_start: next_reading.reading_start)
    end
    warnings
  end
end
