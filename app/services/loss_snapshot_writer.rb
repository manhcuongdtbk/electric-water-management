# Persists the loss snapshot computed by LossCalculator so the entry pages and
# billing can display "kết quả từ lần tính gần nhất". Engine-only writer:
# uses update_all (no callbacks / lock_version bump) since loss is computed data.
# Called inside CalculationOrchestrator's transaction.
class LossSnapshotWriter
  def initialize(zone:, period:, loss_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
  end

  def call
    @loss_results.meter_losses.each do |meter_id, loss|
      MeterReading.where(meter_id: meter_id, period_id: @period.id).update_all(loss: loss)
    end

    summary = LossSummary.find_or_initialize_by(zone_id: @zone.id, period_id: @period.id)
    summary.update!(a: @loss_results.total_a, b: @loss_results.total_b, c: @loss_results.total_loss)
  end
end
