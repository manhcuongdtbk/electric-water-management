class HistoryController < ApplicationController
  include BusinessRoleRequired

  MODES = %w[compare range].freeze

  def show
    @mode = MODES.include?(params[:mode]) ? params[:mode] : "compare"
    @available_periods = Period.order(year: :desc, month: :desc)

    case @mode
    when "compare" then load_compare
    when "range"   then load_range
    end
  end

  private

  def load_compare
    @period_a = @available_periods.find_by(id: params[:period_a])
    @period_b = @available_periods.find_by(id: params[:period_b])
    return unless @period_a && @period_b

    @comparison = PeriodComparison.new(
      ability: current_ability,
      period_a: @period_a,
      period_b: @period_b
    ).call
  end

  def load_range
    @from_period = @available_periods.find_by(id: params[:from_period_id]) || @available_periods.last
    @to_period = @available_periods.find_by(id: params[:to_period_id]) || @available_periods.first

    # Auto-swap nếu from > to
    if @from_period && @to_period
      @from_period, @to_period = @to_period, @from_period if period_key(@from_period) > period_key(@to_period)
    end

    @periods = @available_periods.select do |p|
      key = period_key(p)
      key >= period_key(@from_period) && key <= period_key(@to_period)
    end

    @total_count = @periods.size
    @period_summaries = @periods.map do |p|
      [p, DashboardSummary.new(user: current_user, ability: current_ability, period: p).call]
    end
  end

  def period_key(period)
    period.year * 12 + period.month
  end
end
