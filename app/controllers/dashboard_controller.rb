# frozen_string_literal: true

# Dashboard — trang chủ tổng quan theo tháng (M4).
# Hiển thị metric cards, biểu đồ Chartkick, và bảng đầu mối cho kỳ tháng được chọn.
class DashboardController < ApplicationController
  def show
    if current_user.tech?
      return redirect_to(users_path, alert: t("flash.access_denied"))
    end

    authorize! :read, MonthlyCalculation

    set_period
    set_target_org
    load_dashboard_data if @period
  end

  private

  def set_period
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
  end

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @selected_org_id = params[:org_id].presence || "all"
      @target_org = (@selected_org_id != "all") ? @all_orgs.find_by(id: @selected_org_id) : nil
    else
      @target_org = current_user.organization
    end
  end

  def load_dashboard_data
    @calculations = fetch_calculations
    build_metrics
    build_chart_data
    build_table_data
  end

  def fetch_calculations
    scope = MonthlyCalculation.for_period(@period.id).ordered.includes(:contact_point)
    if @target_org
      scope.by_organization(@target_org.id)
    else
      # admin_level1 "Tất cả": all contact points across all units under division
      scope.joins(contact_point: :organization)
           .where(organizations: { parent_id: current_user.organization.id })
    end
  end

  def build_metrics
    @total_standard  = @calculations.sum(&:total_standard_kw)
    @total_usage     = @calculations.sum(&:total_usage_kw)
    @difference      = @total_standard - @total_usage
    @over_count      = @calculations.count { |c| c.total_usage_kw > c.total_standard_kw }
  end

  def build_chart_data
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

  def build_table_data
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
end
