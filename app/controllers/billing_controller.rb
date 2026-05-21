class BillingController < ApplicationController
  include AuthorizeResource
  include BusinessRoleRequired

  def show
    @period = resolve_period
    return redirect_to root_path, alert: t("flash.no_open_period") unless @period

    @zone, @unit = resolve_filter
    @show_zone_column = @zone.nil?
    @show_unit_column = @unit.nil?

    @ranks = @period.ranks.order(:position).to_a
    scope = build_calculations_scope
    @total_count = scope.count
    @summary = Billing::Query.summary(scope, period: @period)
    @warnings = collect_warnings

    respond_to do |format|
      format.html do
        @pagy, @calculations = pagy(scope, items: (params[:per_page] || 50).to_i)
        preload_dependencies(@calculations)
        @available_zones = available_zones_for_filter
        @available_units = available_units_for_filter(@zone)
      end
      format.xlsx do
        @calculations = scope.to_a
        preload_dependencies(@calculations)
        response.headers["Content-Disposition"] =
          %(attachment; filename="bang-tinh-tien-#{@period.month}-#{@period.year}.xlsx")
      end
    end
  end

  def recalculate
    @period = resolve_period
    return redirect_to root_path, alert: t("flash.no_open_period") unless @period
    raise CanCan::AccessDenied if @period.closed?
    authorize!(:recalculate, Calculation)

    @zone, @unit = resolve_filter
    warnings = []
    ActiveRecord::Base.transaction do
      zones_in_scope(@period).find_each do |zone|
        result = CalculationOrchestrator.new(zone: zone, period: @period).call
        warnings += result.warnings.map { |w| "#{zone.name}: #{w}" }
      end
    end

    flash[:notice] = t("billing.flash.recalculated")
    flash[:alert] = warnings.join(" — ") if warnings.any?
    redirect_to billing_path(redirect_filter_params)
  end

  private

  def resolve_period
    if params[:period_id].present?
      Period.find_by(id: params[:period_id])
    else
      current_period
    end
  end

  def resolve_filter
    if current_user.role == "system_admin"
      zone = params[:zone_id].present? ? Zone.with_discarded.find_by(id: params[:zone_id]) : nil
      unit = params[:unit_id].present? ? Unit.with_discarded.find_by(id: params[:unit_id]) : nil
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

  def build_calculations_scope
    scope = Billing::Query.base_scope(@period, current_ability)
    scope = Billing::Query.apply_filters(scope, zone: @zone, unit: @unit, q: params[:q])
    scope.order(Arel.sql(Billing::Query::SORT_ORDER))
  end

  def preload_dependencies(calcs)
    cp_ids = calcs.map(&:contact_point_id)
    entries = PersonnelEntry
                .where(period_id: @period.id, contact_point_id: cp_ids)
                .includes(:rank)
    @personnel_by_cp_id = Hash.new { |h, k| h[k] = {} }
    entries.each { |e| @personnel_by_cp_id[e.contact_point_id][e.rank_id] = e.count }
  end

  def collect_warnings
    zones_in_scope(@period).flat_map do |zone|
      ZoneWarningCollector.new(zone: zone, period: @period).call
    end
  end

  # Dùng cho recalculate + warnings. Luôn dùng .with_discarded vì:
  # - Engine cần zone đã xóa để tính kỳ cũ (data còn)
  # - ZoneWarningCollector tự skip zone không có data cho kỳ đó
  def zones_in_scope(period)
    return Zone.with_discarded.where(id: @zone.id) if @zone

    if current_user.role == "system_admin"
      Zone.with_discarded.order(:name)
    else
      zone_ids = [current_user.unit&.zone_id].compact
      zone_ids += Zone.where(manager_unit_id: current_user.unit_id).pluck(:id) if current_user.unit_id
      Zone.with_discarded.where(id: zone_ids.uniq)
    end
  end

  def redirect_filter_params
    params.permit(:period_id, :zone_id, :unit_id, :q).to_h.compact_blank
  end

  def available_zones_for_filter
    if current_user.role == "system_admin"
      Zone.with_discarded.order(:name)
    else
      [current_user.unit&.zone].compact
    end
  end

  def available_units_for_filter(zone)
    base = Unit.with_discarded.order(:name)
    base = base.where(zone_id: zone.id) if zone
    base.order(:name)
  end
end
