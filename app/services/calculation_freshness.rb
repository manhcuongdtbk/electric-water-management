# Per-zone derived-data freshness for a period (#334, ADR-049). Returns only zones
# that have a calculation_states row (others: empty data is self-evident).
class CalculationFreshness
  Entry = Struct.new(:zone, :status, keyword_init: true)

  def initialize(period:, zones:)
    @period = period
    @zones = zones
  end

  def call
    return [] if @period.nil?

    states = CalculationState
             .where(period_id: @period.id, zone_id: @zones.map(&:id))
             .index_by(&:zone_id)
    @zones.filter_map do |zone|
      state = states[zone.id]
      next if state.nil?

      Entry.new(zone: zone, status: state.status)
    end
  end

  def any_stale?
    call.any? { |entry| entry.status == :stale }
  end
end
