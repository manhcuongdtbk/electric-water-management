class ElectricitySuppliesController < ApplicationController
  before_action :set_period
  before_action :set_target_main_meter

  def show
    authorize! :read, MainMeter
    set_reading
    @history = load_history
  end

  def update
    return redirect_to electricity_supply_path, alert: t("electricity_supplies.no_period") if @period.nil?
    return redirect_to electricity_supply_path, alert: t("electricity_supplies.no_main_meter") if @target_main_meter.nil?

    set_reading
    authorize! :update, @reading

    if @reading.update(electricity_supply_kw: supply_kw_param)
      redirect_to electricity_supply_path(period_id: @period.id, main_meter_id: effective_main_meter_id),
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

  def set_target_main_meter
    if current_user.admin_level1?
      @all_main_meters = MainMeter.ordered
      @target_main_meter = if params[:main_meter_id].present?
        @all_main_meters.find_by(id: params[:main_meter_id])
      else
        @all_main_meters.first
      end
    else
      @target_main_meter = current_user.organization&.zone&.main_meters&.ordered&.first
    end
  end

  def set_reading
    return unless @target_main_meter && @period

    @reading = MainMeterReading.find_or_initialize_by(
      main_meter: @target_main_meter,
      monthly_period: @period
    )
  end

  def load_history
    return [] unless @target_main_meter && @period

    scope = current_user.admin_level1? ? @all_main_meters : [ @target_main_meter ]

    MainMeterReading
      .includes(:monthly_period, :main_meter)
      .where(main_meter: scope)
      .where.not(monthly_period: @period)
      .joins(:monthly_period)
      .order("monthly_periods.year DESC, monthly_periods.month DESC")
  end

  # For admin_level1 defaulting to first main_meter (no main_meter_id param), preserve the
  # selected zone in the redirect so the form stays on the same zone after save.
  def effective_main_meter_id
    return nil unless current_user.admin_level1?

    params[:main_meter_id].presence || @target_main_meter&.id
  end

  def supply_kw_param
    raw = params.dig(:electricity_supply, :electricity_supply_kw)
    return nil if raw.blank?

    BigDecimal(raw.to_s)
  rescue ArgumentError, FloatDomainError
    nil
  end
end
