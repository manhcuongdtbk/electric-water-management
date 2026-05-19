class ZoneWarningCollector
  def initialize(zone:, period:)
    @zone = zone
    @period = period
  end

  def call
    warnings = []
    warnings.concat(missing_main_meter_warnings)
    warnings.concat(missing_meter_reading_warnings)
    warnings.concat(loss_and_pump_warnings)
    warnings.uniq
  end

  private

  def query
    @query ||= ZoneQuery.new(zone: @zone, period: @period)
  end

  def missing_main_meter_warnings
    readings = query.main_meter_readings
    if readings.empty? || readings.sum(:usage).zero?
      ["Khu vực #{@zone.name}: chưa nhập số sử dụng công tơ tổng."]
    else
      []
    end
  end

  def missing_meter_reading_warnings
    rows = query.meter_readings
                .where(reading_end: nil, manual_usage: nil)
                .joins(meter: :contact_point)
                .pluck("contact_points.name",
                       "contact_points.contact_point_type",
                       "contact_points.unit_id")
    rows.map do |cp_name, cp_type, uid|
      if cp_type == "water_pump"
        "Khu vực #{@zone.name}: trạm bơm \"#{cp_name}\" chưa nhập số liệu."
      elsif uid
        unit = Unit.find_by(id: uid)
        "Đơn vị #{unit&.name}: đầu mối \"#{cp_name}\" chưa nhập chỉ số công tơ."
      else
        "Khu vực #{@zone.name}: đầu mối \"#{cp_name}\" chưa nhập chỉ số công tơ."
      end
    end.uniq
  end

  def loss_and_pump_warnings
    loss = LossCalculator.new(zone: @zone, period: @period).call
    pump = PumpAllocationCalculator.new(zone: @zone, period: @period, loss_results: loss).call
    loss.warnings + pump.warnings
  rescue StandardError => e
    Rails.logger.warn(
      "ZoneWarningCollector#loss_and_pump_warnings zone=#{@zone&.id} period=#{@period&.id}: #{e.class}: #{e.message}"
    )
    []
  end
end
