class BillingController < ApplicationController
  include AuthorizeResource
  include BusinessRoleRequired
  include ZoneUnitFilterable

  def show
    @available_periods = Period.order(year: :desc, month: :desc)
    @period = resolve_period
    return redirect_to pricing_path, alert: t("flash.no_periods_yet") unless @period

    @ranks = @period.ranks.order(:position).to_a
    @base_scope = Billing::Query.base_scope(@period, current_ability)

    if current_user.system_admin?
      scope = apply_sa_zone_unit_filter_with_direct_zone(@base_scope,
                zone_scope: Zone.with_discarded, unit_scope: Unit.with_discarded)
    else
      @zone, @unit = resolve_current_user_zone_unit
      scope = Billing::Query.apply_zone_unit_filter(@base_scope, zone: @zone, unit: @unit)
      @available_zones = [current_user.unit&.zone].compact
    end
    scope = Billing::Query.apply_search(scope, q: params[:q])
                          .order(Arel.sql(Billing::Query::SORT_ORDER))

    @show_zone_column = @zone.nil?
    @show_unit_column = @unit.nil?
    @total_count = scope.count
    @summary = Billing::Query.summary(scope, period: @period)
    @warnings = collect_warnings_for_zones(zones_in_scope(@period))
    @loss_summaries = LossSummary.where(period_id: @period.id, zone_id: zones_in_scope(@period).select(:id))
                                 .includes(:zone).to_a.sort_by { |s| s.zone&.name.to_s }

    respond_to do |format|
      format.html do
        @pagy, @calculations = pagy(scope, items: (params[:per_page] || 50).to_i)
        preload_personnel(@calculations)
      end
      format.xlsx do
        @calculations = scope.to_a
        preload_personnel(@calculations)
        response.headers["Content-Disposition"] =
          %(attachment; filename="bang-tinh-tien-#{@period.month}-#{@period.year}.xlsx")
      end
    end
  end

  def recalculate
    @period = resolve_period
    return redirect_to pricing_path, alert: t("flash.no_periods_yet") unless @period
    return redirect_to billing_path(period_id: @period.id), alert: t("billing.flash.period_closed") unless @period.open?
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
      current_period || Period.order(year: :desc, month: :desc).first
    end
  end

  def resolve_filter
    if current_user.system_admin?
      resolve_zone_unit_filter(zone_scope: Zone.with_discarded, unit_scope: Unit.with_discarded)
    else
      resolve_current_user_zone_unit
    end
  end

  def preload_personnel(calculations)
    cp_ids = calculations.map(&:contact_point_id)
    entries = PersonnelEntry
                .where(period_id: @period.id, contact_point_id: cp_ids)
                .includes(:rank)
    @personnel_by_cp_id = Hash.new { |h, k| h[k] = {} }
    entries.each { |e| @personnel_by_cp_id[e.contact_point_id][e.rank_id] = e.count }
  end

  def collect_warnings_for_zones(zones)
    zones.flat_map { |z| ZoneWarningCollector.new(zone: z, period: @period).call }
  end

  # Dùng cho recalculate + warnings. Luôn dùng .with_discarded vì:
  # - Engine cần zone đã xóa để tính kỳ cũ (data còn)
  # - ZoneWarningCollector tự skip zone không có data cho kỳ đó (zone_has_data_for_period?)
  def zones_in_scope(period)
    return Zone.with_discarded.where(id: @zone.id) if @zone

    if current_user.system_admin?
      Zone.with_discarded.order(:name)
    else
      zone_ids = [current_user.unit&.zone_id].compact
      zone_ids += Zone.kept.where(manager_unit_id: current_user.unit_id).pluck(:id) if current_user.unit_id
      Zone.with_discarded.where(id: zone_ids.uniq)
    end
  end

  def redirect_filter_params
    result = params.permit(:period_id, :zone_id, :unit_id, :q).to_h.compact_blank
    # Khi auto-select zone từ unit, zone_id không có trong params gốc → thêm vào
    result[:zone_id] ||= @zone&.id&.to_s if @zone
    result.compact_blank
  end
end
