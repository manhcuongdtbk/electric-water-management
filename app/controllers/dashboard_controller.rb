# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    return redirect_to(users_path, alert: t("flash.access_denied")) if current_user.tech?

    authorize! :read, MonthlyCalculation

    @view_type = params[:view_type].presence_in(%w[month quarter year]) || "month"
    set_target_org

    case @view_type
    when "month"   then setup_month_view
    when "quarter" then setup_quarter_view
    when "year"    then setup_year_view
    end

    respond_to do |format|
      format.html
      format.csv do
        return head(:not_found) unless @table_rows&.any?

        send_data dashboard_csv,
                  type: "text/csv; charset=utf-8",
                  filename: dashboard_csv_filename
      end
    end
  end

  private

  # ---------------------------------------------------------------------------
  # Org selection (shared across all view types)
  # ---------------------------------------------------------------------------

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @selected_org_id = params[:org_id].presence || "all"
      @target_org = (@selected_org_id != "all") ? @all_orgs.find_by(id: @selected_org_id) : nil
    else
      @target_org = current_user.organization
    end
  end

  # ---------------------------------------------------------------------------
  # Month view
  # ---------------------------------------------------------------------------

  def setup_month_view
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      recent_id = MonthlyCalculation
        .joins(:monthly_period)
        .order("monthly_periods.year DESC, monthly_periods.month DESC")
        .pick(:monthly_period_id)
      recent_id ? @periods.find_by(id: recent_id) : @periods.first
    end

    load_month_data if @period
  end

  def load_month_data
    @calculations = fetch_calculations_for_period(@period.id)
    build_month_metrics
    build_month_chart_data
    build_month_table_data
  end

  def fetch_calculations_for_period(period_id)
    scope = MonthlyCalculation.for_period(period_id).ordered.preload(:contact_point)
    apply_org_scope(scope)
  end

  def apply_org_scope(scope)
    if @target_org
      scope.by_organization(@target_org.id)
    else
      unit_ids = Organization.where(parent_id: current_user.organization.id).pluck(:id)
      scope.where(contact_points: { organization_id: unit_ids })
    end
  end

  def build_month_metrics
    @total_standard = @calculations.sum(&:total_standard_kw)
    @total_usage    = @calculations.sum(&:total_usage_kw)
    @difference     = @total_standard - @total_usage
    @over_count     = @calculations.count { |c| c.total_usage_kw > c.total_standard_kw }
  end

  def build_month_chart_data
    labels        = @calculations.map { |c| c.contact_point.name }
    standard_vals = @calculations.to_h { |c| [ c.contact_point.name, c.total_standard_kw.to_f ] }
    usage_vals    = @calculations.to_h { |c| [ c.contact_point.name, c.total_usage_kw.to_f ] }

    @chart_data = [
      { name: t("dashboard.chart.standard"), data: standard_vals },
      { name: t("dashboard.chart.usage"),    data: usage_vals }
    ]

    @usage_colors = labels.map do |lbl|
      (usage_vals[lbl] || 0) > (standard_vals[lbl] || 0) ? "rgba(239,68,68,0.85)" : "rgba(34,197,94,0.85)"
    end
  end

  def build_month_table_data
    @table_rows = @calculations.map do |c|
      {
        name:     c.contact_point.name,
        standard: c.total_standard_kw,
        usage:    c.total_usage_kw,
        diff:     c.total_standard_kw - c.total_usage_kw,
        over:     c.total_usage_kw > c.total_standard_kw
      }
    end.sort_by { |r| r[:diff] }
  end

  # ---------------------------------------------------------------------------
  # Quarter view
  # ---------------------------------------------------------------------------

  def setup_quarter_view
    @available_years = calc_years_for_scope
    return if @available_years.empty?

    @selected_year    = (params[:year].presence || @available_years.first)&.to_i
    @selected_quarter = (params[:quarter].presence || default_quarter(@selected_year))&.to_i
    months = quarter_months(@selected_quarter)

    periods = MonthlyPeriod.for_year(@selected_year).where(month: months)
    @calculations_by_month = periods_to_calcs(periods)
    @calculations = @calculations_by_month.values.flatten

    return unless @calculations.any?

    build_table_data_aggregate
    build_metrics_aggregate
    build_quarter_chart_data
  end

  def build_quarter_chart_data
    datasets = []
    @calculations_by_month.each do |month, calcs|
      label    = "T#{month}"
      std_data = calcs.to_h { |c| [ c.contact_point.name, c.total_standard_kw.to_f ] }
      use_data = calcs.to_h { |c| [ c.contact_point.name, c.total_usage_kw.to_f ] }
      datasets << { name: "#{label} - #{t('dashboard.chart.standard')}", data: std_data }
      datasets << { name: "#{label} - #{t('dashboard.chart.usage')}",    data: use_data }
    end
    @chart_data = datasets
  end

  # ---------------------------------------------------------------------------
  # Year view
  # ---------------------------------------------------------------------------

  def setup_year_view
    @available_years = calc_years_for_scope
    return if @available_years.empty?

    @selected_year = (params[:year].presence || @available_years.first)&.to_i

    periods = MonthlyPeriod.for_year(@selected_year)
    @calculations_by_month = periods_to_calcs(periods)
    @calculations = @calculations_by_month.values.flatten

    return unless @calculations.any?

    build_table_data_aggregate
    build_metrics_aggregate
    build_year_chart_data
  end

  def build_year_chart_data
    std_by_month = {}
    use_by_month = {}
    @calculations_by_month.each do |month, calcs|
      label              = t("dashboard.month_label", month: month)
      std_by_month[label] = calcs.sum(&:total_standard_kw).to_f
      use_by_month[label] = calcs.sum(&:total_usage_kw).to_f
    end
    @chart_data = [
      { name: t("dashboard.chart.standard"), data: std_by_month },
      { name: t("dashboard.chart.usage"),    data: use_by_month }
    ]
  end

  # ---------------------------------------------------------------------------
  # Shared aggregate helpers (quarter + year)
  # ---------------------------------------------------------------------------

  def build_table_data_aggregate
    aggregated = Hash.new { |h, k| h[k] = { name: k, standard: BigDecimal("0"), usage: BigDecimal("0") } }
    @calculations.each do |c|
      name = c.contact_point.name
      aggregated[name][:standard] += c.total_standard_kw
      aggregated[name][:usage]    += c.total_usage_kw
    end
    @table_rows = aggregated.values
      .map { |r| r.merge(diff: r[:standard] - r[:usage], over: r[:usage] > r[:standard]) }
      .sort_by { |r| r[:diff] }
  end

  def build_metrics_aggregate
    @total_standard = @table_rows.sum { |r| r[:standard] }
    @total_usage    = @table_rows.sum { |r| r[:usage] }
    @difference     = @total_standard - @total_usage
    @over_count     = @table_rows.count { |r| r[:over] }
  end

  def calc_years_for_scope
    base = MonthlyCalculation.joins(:monthly_period, :contact_point)
    scoped = if @target_org
      base.where(contact_points: { organization_id: @target_org.id })
    else
      unit_ids = Organization.where(parent_id: current_user.organization.id).pluck(:id)
      base.where(contact_points: { organization_id: unit_ids })
    end
    scoped.distinct.pluck("monthly_periods.year").sort.reverse
  end

  def periods_to_calcs(periods)
    result = {}
    periods.each do |period|
      calcs = fetch_calculations_for_period(period.id).to_a
      result[period.month] = calcs if calcs.any?
    end
    result
  end

  def quarter_months(quarter)
    case quarter
    when 1 then [ 1, 2, 3 ]
    when 2 then [ 4, 5, 6 ]
    when 3 then [ 7, 8, 9 ]
    when 4 then [ 10, 11, 12 ]
    else        [ 1, 2, 3 ]
    end
  end

  def default_quarter(year)
    return 1 if year.nil?
    month = MonthlyPeriod
      .joins(:monthly_calculations)
      .where(year: year)
      .order(month: :desc)
      .pick(:month)
    month ? ((month - 1) / 3) + 1 : 1
  end

  # ---------------------------------------------------------------------------
  # CSV export
  # ---------------------------------------------------------------------------

  def dashboard_csv
    headers = [
      t("dashboard.table.name"),
      t("dashboard.table.standard"),
      t("dashboard.table.usage"),
      t("dashboard.table.difference")
    ]

    bom = +"\xEF\xBB\xBF"
    bom + CSV.generate(encoding: "UTF-8") do |csv|
      csv << headers
      @table_rows.each do |row|
        csv << [ row[:name], row[:standard].to_f, row[:usage].to_f, row[:diff].to_f ]
      end
    end
  end

  def dashboard_csv_filename
    case @view_type
    when "month"
      "bao_cao_dashboard_thang_#{@period.month}_#{@period.year}.csv"
    when "quarter"
      "bao_cao_dashboard_quy_#{@selected_quarter}_#{@selected_year}.csv"
    when "year"
      "bao_cao_dashboard_nam_#{@selected_year}.csv"
    end
  end
end
