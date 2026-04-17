class ElectricitySuppliesController < ApplicationController
  before_action :set_period
  before_action :set_target_org

  def show
    authorize! :read, UnitConfig
    set_config
    @history = load_history
  end

  def update
    authorize! :update_unit_config, UnitConfig

    return redirect_to electricity_supply_path, alert: t("electricity_supplies.no_period") if @period.nil?
    return redirect_to electricity_supply_path, alert: t("electricity_supplies.no_org") if @target_org.nil?

    set_config

    if @config.update(electricity_supply_kw: supply_kw_param)
      redirect_to electricity_supply_path(period_id: @period.id, org_id: effective_org_id),
                  notice: t("flash.electricity_supplies.updated")
    else
      @history = load_history
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = if params[:org_id].present?
        @all_orgs.find_by(id: params[:org_id])
      else
        @all_orgs.first
      end
    else
      @target_org = current_user.organization
    end
  end

  def set_config
    return unless @target_org && @period

    @config = UnitConfig.find_or_initialize_by(
      organization: @target_org,
      monthly_period: @period
    )
  end

  def load_history
    return [] unless @target_org && @period

    org_ids = current_user.admin_level1? ? @all_orgs.map(&:id) : [ @target_org.id ]

    UnitConfig
      .includes(:monthly_period, :organization)
      .where(organization_id: org_ids)
      .where.not(electricity_supply_kw: nil)
      .where.not(monthly_period: @period)
      .joins(:monthly_period)
      .order("monthly_periods.year DESC, monthly_periods.month DESC")
  end

  # For admin_level1 defaulting to first org (no org_id param), preserve the
  # selected org in the redirect so the form stays on the same org after save.
  def effective_org_id
    return nil unless current_user.admin_level1?

    params[:org_id].presence || @target_org&.id
  end

  def supply_kw_param
    raw = params.dig(:electricity_supply, :electricity_supply_kw)
    return nil if raw.blank?

    BigDecimal(raw.to_s)
  rescue ArgumentError, FloatDomainError
    nil
  end
end
