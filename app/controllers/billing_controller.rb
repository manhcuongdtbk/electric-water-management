class BillingController < ApplicationController
  include AuthorizeResource
  include BusinessRoleRequired
  include ZoneUnitFilterable
  include FreshnessIndicatable

  def show
    @available_periods = Period.order(year: :desc, month: :desc)
    @period = resolve_period
    return redirect_to pricing_path, alert: t("flash.no_periods_yet") unless @period

    @ranks = @period.ranks.order(:position).to_a
    @base_scope = Billing::Query.base_scope(@period, current_ability)
    @zone = @unit = nil

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
    assign_freshness_states(@period, selected_zone: @zone)
    @warnings = collect_warnings_for_zones(zones_in_scope(@period))
    @loss_summaries = LossSummary.where(period_id: @period.id, zone_id: zones_in_scope(@period).select(:id))
                                 .includes(:zone).to_a.sort_by { |s| s.zone&.name.to_s }
    @loss_breakdowns = @loss_summaries.each_with_object({}) do |summary, hash|
      next unless summary.zone
      hash[summary.zone_id] = LossBreakdown.new(zone: summary.zone, period: @period, summary: summary).call
    end
    @pump_station_matrices = build_pump_station_matrices(zones_in_scope(@period))

    respond_to do |format|
      format.html do
        @pagy, @calculations = pagy(scope, items: (params[:per_page] || 50).to_i)
        preload_personnel(@calculations)
      end
      format.xlsx do
        # Layer 2 guard: refuse to generate a file from stale derived data unless the
        # caller explicitly acknowledged (defends against direct-URL bypass of the JS
        # confirm). @export_stale is reused by the in-file warning stamp (Layer 3).
        @export_stale = @period.open? && CalculationFreshness.new(
          period: @period, zones: freshness_zones(@period, selected_zone: @zone)
        ).any_stale?
        if @export_stale && params[:acknowledged_stale].blank?
          next redirect_to(billing_path(redirect_filter_params),
                           alert: t("billing.export.stale_blocked"))
        end
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
    begin
      ActiveRecord::Base.transaction do
        zones_in_scope(@period).find_each do |zone|
          result = CalculationOrchestrator.new(zone: zone, period: @period).call
          warnings += result.warnings.map { |w| "#{zone.name}: #{w}" }
        end
      end
    rescue PumpAllocationCalculator::IncompleteStationConfig => e
      # Cấu hình trạm chưa đủ → transaction đã rollback, không persist gì. Báo lỗi rõ.
      flash[:alert] = e.message
      return redirect_to billing_path(redirect_filter_params)
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

  # Build, per displayed zone, the recipient × station matrix of pump-water
  # electricity (PumpStationCharge). Only zones with ≥1 charge row appear (legacy/gộp
  # periods store no rows → no section). Stations are columns A→Z, recipients rows A→Z;
  # cells missing a charge row mean 0 (only non-zero contributions are persisted).
  def build_pump_station_matrices(zones)
    charges = PumpStationCharge
                .where(period_id: @period.id, zone_id: zones.select(:id))
                .includes(contact_point: [:unit, :block, :group], pump_contact_point: [])
                .to_a
    zones_by_id = zones.index_by(&:id)
    charges.group_by(&:zone_id).transform_values do |zone_charges|
      stations = zone_charges.map(&:pump_contact_point).uniq.sort_by { |s| s.name.to_s }
      recipients = zone_charges.map(&:contact_point).uniq.sort_by do |r|
        [r.unit&.name.to_s, r.block&.name.to_s, r.group&.name.to_s, r.name.to_s]
      end
      amounts = zone_charges.each_with_object({}) do |charge, hash|
        hash[[charge.contact_point_id, charge.pump_contact_point_id]] = charge.amount
      end
      PumpStationMatrix.new(zone: zones_by_id[zone_charges.first.zone_id],
                            stations: stations, recipients: recipients, amounts: amounts)
    end
  end

  # Lightweight value object the partial renders: zone (for the caption), stations
  # (columns), recipients (rows), per-cell amount lookup (0 default), per-station column
  # totals, and grand total.
  PumpStationMatrix = Struct.new(:zone, :stations, :recipients, :amounts, keyword_init: true) do
    def amount_for(recipient, station)
      amounts.fetch([recipient.id, station.id], BigDecimal("0"))
    end

    def station_total(station)
      recipients.sum { |recipient| amount_for(recipient, station) }
    end

    def grand_total
      stations.sum { |station| station_total(station) }
    end
  end

  # Dùng cho recalculate + warnings. Delegates to FreshnessIndicatable#freshness_zones
  # so both share one Ability-aligned zone set (with_discarded vì engine cần zone đã
  # xóa để tính kỳ cũ; ZoneWarningCollector tự skip zone không có data cho kỳ đó).
  def zones_in_scope(period)
    freshness_zones(period, selected_zone: @zone)
  end

  def redirect_filter_params
    result = params.permit(:period_id, :zone_id, :unit_id, :q).to_h.compact_blank
    # Khi auto-select zone từ unit, zone_id không có trong params gốc → thêm vào
    result[:zone_id] ||= @zone&.id&.to_s if @zone
    result.compact_blank
  end
end
