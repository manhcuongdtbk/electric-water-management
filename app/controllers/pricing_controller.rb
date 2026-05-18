class PricingController < ApplicationController
  include AuthorizeResource

  def show
    @current_period = Period.current
    @all_periods = Period.order(year: :desc, month: :desc)
    authorize!(:read, Period)
  end

  def update
    @period = Period.current
    return redirect_to(pricing_path, alert: "Không có kỳ đang mở.") unless @period
    authorize!(:update, @period)
    if @period.update(period_params)
      redirect_to pricing_path, notice: "Đã cập nhật đơn giá và các thông số kỳ."
    else
      @current_period = @period
      @all_periods = Period.order(year: :desc, month: :desc)
      render :show, status: :unprocessable_entity
    end
  end

  def open_period
    authorize!(:create, Period)
    begin
      result = PeriodService.new.open_new_period(
        year: params[:year]&.to_i,
        month: params[:month]&.to_i,
        unit_price: params[:unit_price]
      )
      msg = "Đã mở kỳ tháng #{result.period.month}/#{result.period.year}."
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
    msg = "Đã đóng kỳ tháng #{result.period.month}/#{result.period.year}."
    msg += " Cảnh báo: #{result.warnings.join('; ')}" if result.warnings.any?
    redirect_to pricing_path, notice: msg
  end

  def reopen_period
    period = Period.accessible_by(current_ability).find(params[:period_id])
    authorize!(:update, period)
    PeriodService.new.reopen_period(period)
    redirect_to pricing_path, notice: "Đã mở lại kỳ tháng #{period.month}/#{period.year}."
  rescue PeriodService::Error => e
    redirect_to pricing_path, alert: e.message
  end

  private

  def period_params
    params.require(:period).permit(:unit_price, :savings_rate, :division_public_rate, :water_pump_standard)
  end
end
