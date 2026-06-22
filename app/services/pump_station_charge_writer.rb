# Persists the per-(recipient × pump station) breakdown computed by
# PumpAllocationCalculator into pump_station_charges so billing can show a per-station
# detail. Engine-only writer (mirrors LossSnapshotWriter): pump_station_charges is pure
# computed data with no callbacks. Idempotent recompute — deletes the (zone, period) rows
# and reinserts the current non-zero breakdown. Called inside the orchestrator transaction.
class PumpStationChargeWriter
  def initialize(zone:, period:, pump_results:)
    @zone = zone
    @period = period
    @pump_results = pump_results
  end

  def call
    PumpStationCharge.where(zone_id: @zone.id, period_id: @period.id).delete_all

    rows = []
    @pump_results.contact_point_station_allocations.each do |cp_id, by_station|
      by_station.each do |pump_cp_id, amount|
        next if amount.zero?

        rows << {
          period_id: @period.id,
          zone_id: @zone.id,
          contact_point_id: cp_id,
          pump_contact_point_id: pump_cp_id,
          amount: amount,
          created_at: now,
          updated_at: now
        }
      end
    end

    PumpStationCharge.insert_all(rows) if rows.any?
  end

  private

  def now
    @now ||= Time.current
  end
end
