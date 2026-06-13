# Read-only derivation of the per-contact-point-type loss/usage reconciliation
# table shown under the A/B/C block on the billing page (ADR-054, #332). Returns
# RAW BigDecimal values (no rounding) so reconciliation tests assert on the true
# figures; the view rounds per cell at display time. Anchored on the LossSummary
# snapshot (a/b/c) so the "Cộng" row matches A/B/C exactly. Returns nil when loss
# has not been computed for this zone+period (no LossSummary) — caller hides the
# table, matching the "kết quả từ lần tính gần nhất" semantics of ADR-027.
class LossBreakdown
  TYPE_ORDER = %w[residential public water_pump non_establishment].freeze

  Row = Struct.new(:type, :usage, :loss, :actual, keyword_init: true)
  Result = Struct.new(:rows, :loss_bearing_total, :no_loss_total, :grand_total, :no_loss_by_type,
                      keyword_init: true)

  def initialize(zone:, period:)
    @zone = zone
    @period = period
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    summary = LossSummary.find_by(zone_id: @zone.id, period_id: @period.id)
    return nil unless summary

    meters = @query.meters.includes(:contact_point).to_a
    usages = @query.meter_usages
    readings = @query.meter_readings.index_by(&:meter_id)

    no_loss, loss_bearing = meters.partition do |meter|
      reading = readings[meter.id]
      reading && reading.no_loss
    end

    rows = loss_bearing
      .group_by { |meter| meter.contact_point.contact_point_type }
      .map do |type, group|
        usage = group.sum(BigDecimal("0")) { |meter| usages[meter.id] || BigDecimal("0") }
        loss  = group.sum(BigDecimal("0")) { |meter| readings[meter.id]&.loss || BigDecimal("0") }
        Row.new(type: type, usage: usage, loss: loss, actual: usage + loss)
      end
      .sort_by { |row| TYPE_ORDER.index(row.type) || TYPE_ORDER.size }

    no_loss_usage = no_loss.sum(BigDecimal("0")) { |meter| usages[meter.id] || BigDecimal("0") }
    no_loss_by_type = no_loss
      .group_by { |meter| meter.contact_point.contact_point_type }
      .transform_values { |group| group.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") } }

    Result.new(
      rows: rows,
      loss_bearing_total: Row.new(type: nil, usage: summary.b, loss: summary.c, actual: summary.a),
      no_loss_total: Row.new(type: nil, usage: no_loss_usage, loss: BigDecimal("0"),
                             actual: no_loss_usage),
      grand_total: Row.new(type: nil, usage: summary.b + no_loss_usage, loss: summary.c,
                           actual: @query.main_meter_total_usage),
      no_loss_by_type: no_loss_by_type
    )
  end
end
