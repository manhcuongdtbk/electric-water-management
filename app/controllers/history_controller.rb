class HistoryController < ApplicationController
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

    @zone, @unit = resolve_filter_for_history
    @show_zone_column = @zone.nil?
    @show_unit_column = @unit.nil?
    @ranks = @period.ranks.order(:position).to_a

    scope = Billing::Query.base_scope(@period, current_ability)
    scope = Billing::Query.apply_filters(scope, zone: @zone, unit: @unit, q: params[:q])
    scope = scope.order(Arel.sql(Billing::Query::SORT_ORDER))

    @total_count = scope.count
    @summary = Billing::Query.summary(scope, period: @period)
    @warnings = collect_warnings_for_zones(zones_in_scope_for_history)
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
    @from = parse_year_month(params[:from]) || default_range_start
    @to   = parse_year_month(params[:to])   || default_range_end

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

  def resolve_filter_for_history
    if current_user.role == "system_admin"
      zone = params[:zone_id].present? ? Zone.find_by(id: params[:zone_id]) : nil
      unit = params[:unit_id].present? ? Unit.kept.find_by(id: params[:unit_id]) : nil
      [zone, unit]
    else
      unit = current_user.unit
      zone = unit&.zone
      if zone && Zone.exists?(id: zone.id, manager_unit_id: unit.id)
        [zone, nil]
      else
        [zone, unit]
      end
    end
  end

  def preload_personnel(calcs)
    cp_ids = calcs.map(&:contact_point_id)
    entries = PersonnelEntry.where(period_id: @period.id, contact_point_id: cp_ids).includes(:rank)
    @personnel_by_cp_id = Hash.new { |h, k| h[k] = {} }
    entries.each { |e| @personnel_by_cp_id[e.contact_point_id][e.rank_id] = e.count }
  end

  def collect_warnings_for_zones(zones)
    zones.flat_map { |z| ZoneWarningCollector.new(zone: z, period: @period).call }
  end

  def zones_in_scope_for_history
    return Zone.where(id: @zone.id) if @zone

    if current_user.role == "system_admin"
      Zone.all
    else
      zone_ids = [current_user.unit&.zone_id].compact
      zone_ids += Zone.where(manager_unit_id: current_user.unit_id).pluck(:id) if current_user.unit_id
      Zone.where(id: zone_ids.uniq)
    end
  end

  def available_zones_for_filter
    if current_user.role == "system_admin"
      Zone.order(:name)
    else
      [current_user.unit&.zone].compact
    end
  end

  def available_units_for_filter(zone)
    base = Unit.kept.accessible_by(current_ability)
    base = base.where(zone_id: zone.id) if zone
    base.order(:name)
  end

  def parse_year_month(value)
    return nil if value.blank?
    Date.strptime(value, "%Y-%m")
  rescue ArgumentError
    nil
  end

  def default_range_start
    (Date.current - 2.months).beginning_of_month
  end

  def default_range_end
    Date.current.end_of_month
  end
end
