class CalculationOrchestrator
  Result = Struct.new(:loss_results, :pump_results, :summary_results, :warnings, keyword_init: true)

  def initialize(zone:, period:)
    @zone = zone
    @period = period
  end

  def call
    ActiveRecord::Base.transaction do
      loss = LossCalculator.new(zone: @zone, period: @period).call
      pump = PumpAllocationCalculator.new(zone: @zone, period: @period, loss_results: loss).call
      summary = SummaryCalculator.new(
        zone: @zone, period: @period, loss_results: loss, pump_results: pump
      ).call

      Result.new(
        loss_results: loss,
        pump_results: pump,
        summary_results: summary,
        warnings: loss.warnings + pump.warnings + summary.warnings
      )
    end
  end
end
