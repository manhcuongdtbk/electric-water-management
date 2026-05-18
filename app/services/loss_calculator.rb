class LossCalculator
  Result = Struct.new(:meter_losses, :contact_point_losses, :total_loss, :total_b, :warnings, keyword_init: true)

  def initialize(zone:, period:)
    @zone = zone
    @period = period
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    warnings = []

    meters_in_zone = @query.meters.to_a
    if meters_in_zone.empty?
      warnings << I18n.t("services.loss_calculator.warnings.zone_empty")
      return Result.new(meter_losses: {}, contact_point_losses: {}, total_loss: BigDecimal("0"),
                        total_b: BigDecimal("0"), warnings: warnings)
    end

    usages = @query.meter_usages
    readings_by_meter_id = @query.meter_readings.index_by(&:meter_id)

    no_loss_meters, loss_bearing_meters = meters_in_zone.partition do |meter|
      reading = readings_by_meter_id[meter.id]
      reading && reading.no_loss
    end

    main_total = @query.main_meter_total_usage
    no_loss_total = no_loss_meters.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") }
    a = main_total - no_loss_total
    b = loss_bearing_meters.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") }

    if b.zero?
      warnings << I18n.t("services.loss_calculator.warnings.no_loss_bearing_meters")
      return Result.new(meter_losses: zero_losses(meters_in_zone), contact_point_losses: {},
                        total_loss: BigDecimal("0"), total_b: BigDecimal("0"), warnings: warnings)
    end

    c_raw = a - b
    if c_raw < 0
      warnings << I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main")
      c = BigDecimal("0")
    else
      c = c_raw
    end

    meter_losses = {}
    meters_in_zone.each do |meter|
      reading = readings_by_meter_id[meter.id]
      if reading && reading.no_loss
        meter_losses[meter.id] = BigDecimal("0")
      else
        usage = usages[meter.id] || BigDecimal("0")
        meter_losses[meter.id] = c.zero? ? BigDecimal("0") : usage * c / b
      end
    end

    contact_point_losses = group_losses_by_contact_point(meters_in_zone, meter_losses)

    Result.new(
      meter_losses: meter_losses,
      contact_point_losses: contact_point_losses,
      total_loss: c,
      total_b: b,
      warnings: warnings
    )
  end

  private

  def zero_losses(meters)
    meters.each_with_object({}) { |m, h| h[m.id] = BigDecimal("0") }
  end

  def group_losses_by_contact_point(meters, meter_losses)
    meters.group_by(&:contact_point_id).transform_values do |meters_in_cp|
      meters_in_cp.sum(BigDecimal("0")) { |m| meter_losses[m.id] || BigDecimal("0") }
    end
  end
end
