class HistoryController < ApplicationController
  include BusinessRoleRequired
  include BillingShared

  MODES = %w[single compare range].freeze

  def show
    @mode = MODES.include?(params[:mode]) ? params[:mode] : "single"
    @available_periods = Period.order(year: :desc, month: :desc)

    case @mode
    when "single"  then load_single
    when "compare" then load_compare
    when "range"   then load_range
    end
  end

  private

  def load_single
    @period = @available_periods.find_by(id: params[:period_id]) || @available_periods.first
    return unless @period

    @zone, @unit = resolve_filter
    @show_zone_column = @zone.nil?
    @show_unit_column = @unit.nil?
    @ranks = @period.ranks.order(:position).to_a

    scope = build_calculations_scope
    @total_count = scope.count
    @summary = Billing::Query.summary(scope, period: @period)
    @warnings = collect_warnings_for_zones(zones_in_scope(@period))
    @pagy, @calculations = pagy(scope, items: (params[:per_page] || 50).to_i)
    preload_personnel(@calculations)

    @dashboard_summary = DashboardSummary.new(user: current_user,
                                              ability: current_ability,
                                              period: @period).call
    @available_zones = available_zones_for_filter
    @available_units = available_units_for_filter(@zone)
  end

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
    @from = parse_month_year(params[:from_month], params[:from_year]) ||
            parse_year_month(params[:from]) ||
            default_range_start
    @to = parse_month_year(params[:to_month], params[:to_year], end_of_month: true) ||
          parse_year_month(params[:to]) ||
          default_range_end

    from_key = @from.year * 12 + @from.month
    to_key   = @to.year * 12 + @to.month

    @periods = @available_periods.select do |p|
      key = p.year * 12 + p.month
      key >= from_key && key <= to_key
    end

    @period_summaries = @periods.map do |p|
      [p, DashboardSummary.new(user: current_user, ability: current_ability, period: p).call]
    end
  end

  def parse_year_month(value)
    return nil if value.blank?
    Date.strptime(value, "%Y-%m")
  rescue ArgumentError
    nil
  end

  def parse_month_year(month, year, end_of_month: false)
    return nil if month.blank? || year.blank?
    m = month.to_i
    y = year.to_i
    return nil unless m.between?(1, 12) && y.between?(2000, 2100)
    date = Date.new(y, m, 1)
    end_of_month ? date.end_of_month : date
  rescue ArgumentError, Date::Error
    nil
  end

  def default_range_start
    (Date.current - 2.months).beginning_of_month
  end

  def default_range_end
    Date.current.end_of_month
  end
end
