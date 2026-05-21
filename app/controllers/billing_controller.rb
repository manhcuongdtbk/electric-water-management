class BillingController < ApplicationController
  include AuthorizeResource
  include BusinessRoleRequired
  include BillingShared

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
    @warnings = collect_warnings_for_zones(zones_in_scope(@period))

    respond_to do |format|
      format.html do
        @pagy, @calculations = pagy(scope, items: (params[:per_page] || 50).to_i)
        preload_personnel(@calculations)
        @available_zones = available_zones_for_filter
        @available_units = available_units_for_filter(@zone)
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

  def redirect_filter_params
    params.permit(:period_id, :zone_id, :unit_id, :q).to_h.compact_blank
  end
end
