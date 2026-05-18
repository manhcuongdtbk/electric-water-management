class ZoneQuery
  def initialize(zone:, period:)
    @zone = zone
    @period = period
  end

  def contact_points
    ContactPoint.kept.in_zone(@zone)
  end

  def meters
    Meter.kept.in_zone(@zone)
  end

  def meter_readings
    MeterReading.where(meter_id: meters.select(:id), period_id: @period.id)
  end

  def main_meter_readings
    MainMeterReading.joins(:main_meter)
                    .where(main_meters: { zone_id: @zone.id })
                    .where(period_id: @period.id)
                    .merge(MainMeter.kept)
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

  def residential_contact_points
    contact_points.where(contact_point_type: "residential")
  end

  def main_meter_total_usage
    main_meter_readings.sum(:usage).then { |v| BigDecimal(v.to_s) }
  end
end
