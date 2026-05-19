class ZoneQuery
  def initialize(zone:, period:)
    @zone = zone
    @period = period
  end

  def contact_points
    ContactPoint.with_discarded.in_zone(@zone)
  end

  # v2.4.0: chỉ trả công tơ CÓ meter_reading cho kỳ đang tính. Công tơ không có reading
  # kỳ đó (đầu mối đã discard ở kỳ đang mở → reading đã bị cleanup) → engine skip hoàn toàn.
  # Kỳ cũ: reading vẫn còn → công tơ đã discard vẫn được tính (đúng cho kỳ cũ).
  def meters
    Meter.with_discarded.in_zone(@zone)
         .where(id: MeterReading.where(period_id: @period.id).select(:meter_id))
  end

  def meter_readings
    MeterReading.where(meter_id: meters.select(:id), period_id: @period.id)
  end

  def main_meter_readings
    MainMeterReading.joins(:main_meter)
                    .where(main_meters: { zone_id: @zone.id })
                    .where(period_id: @period.id)
                    .merge(MainMeter.with_discarded)
  end

  def meter_usages
    meter_readings.each_with_object({}) do |reading, hash|
      usage = reading.usage
      hash[reading.meter_id] = usage.nil? ? BigDecimal("0") : BigDecimal(usage.to_s)
    end
  end

  def pump_meters
    meters.joins(:contact_point).where(contact_points: { contact_point_type: "water_pump" })
  end

  # v2.4.0: chỉ trả đầu mối sinh hoạt CÓ công tơ với meter_reading kỳ đang tính (qua
  # #meters đã lọc) → SummaryCalculator không tạo lại Calculation cho đầu mối đã discard.
  def residential_contact_points
    contact_points.where(contact_point_type: "residential")
                  .where(id: meters.select(:contact_point_id))
  end

  def main_meter_total_usage
    main_meter_readings.sum(:usage).then { |v| BigDecimal(v.to_s) }
  end
end
