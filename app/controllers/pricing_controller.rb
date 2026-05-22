class PricingController < ApplicationController
  include AuthorizeResource
  include BusinessRoleRequired
  include ListSortable

  def show
    @current_period = Period.current
    all_periods = Period.order(year: :desc, month: :desc)
    @latest_period = all_periods.first
    @next_year, @next_month = compute_next_year_month(@latest_period)
    @pagy, @all_periods = pagy_with_per_page(all_periods, default: 10)
    authorize!(:read, Period)
  end

  def update
    @period = Period.current
    return redirect_to(pricing_path, alert: t("flash.no_open_period")) unless @period
    authorize!(:update, @period)
    if @period.update(period_params)
      redirect_to pricing_path, notice: t("pricing.flash.updated")
    else
      @current_period = @period
      all_periods = Period.order(year: :desc, month: :desc)
      @pagy, @all_periods = pagy_with_per_page(all_periods, default: 10)
      render :show, status: :unprocessable_entity
    end
  end

  def open_period
    authorize!(:create, Period)
    begin
      result = PeriodService.new.open_new_period(
        year: params[:year].presence&.to_i,
        month: params[:month].presence&.to_i,
        unit_price: params[:unit_price].presence
      )
      msg = t("pricing.flash.opened", month: result.period.month, year: result.period.year)
      msg += " Cảnh báo: #{result.warnings.join('; ')}" if result.warnings.any?
      redirect_to pricing_path, notice: msg
    rescue PeriodService::Error => e
      redirect_to pricing_path, alert: e.message
    end
  end

  def close_period
    period = Period.accessible_by(current_ability).find(params[:period_id])
    authorize!(:update, period)
    result = PeriodService.new.close_period(period)
    msg = t("pricing.flash.closed", month: result.period.month, year: result.period.year)
    msg += " Cảnh báo: #{result.warnings.join('; ')}" if result.warnings.any?
    redirect_to pricing_path, notice: msg
  end

  def reopen_period
    period = Period.accessible_by(current_ability).find(params[:period_id])
    authorize!(:update, period)
    PeriodService.new.reopen_period(period)
    redirect_to pricing_path, notice: t("pricing.flash.reopened", month: period.month, year: period.year)
  rescue PeriodService::Error => e
    redirect_to pricing_path, alert: e.message
  end

  private

  def period_params
    params.require(:period).permit(:unit_price, :savings_rate, :division_public_rate, :water_pump_standard)
  end

  # Tính (year, month) của kỳ kế tiếp dựa trên kỳ mới nhất.
  # Nếu chưa có kỳ nào (lần đầu cài đặt) → trả [nil, nil] để view hiển thị form đầy đủ.
  def compute_next_year_month(latest)
    return [nil, nil] unless latest
    return [latest.year + 1, 1] if latest.month == 12
    [latest.year, latest.month + 1]
  end
end
