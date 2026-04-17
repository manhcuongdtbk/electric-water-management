class MonthlyPeriodsController < ApplicationController
  before_action :authorize_period_manage

  def create
    @period = MonthlyPeriod.new(period_params.merge(locked: false))

    if @period.save
      # Auto-lock the immediately preceding period
      previous_period = find_previous_period(@period)
      previous_period&.lock!(current_user)

      # Inherit personnel from previous period
      PeriodInheritanceService.new(@period).call

      redirect_to personnel_review_path(period_id: @period.id),
                  notice: t("flash.monthly_periods.created", label: @period.label)
    else
      redirect_to personnel_review_path,
                  alert: @period.errors.full_messages.to_sentence
    end
  end

  def unlock
    @period = MonthlyPeriod.find(params[:id])
    @period.unlock!
    redirect_to personnel_review_path(period_id: @period.id),
                notice: t("flash.monthly_periods.unlocked", label: @period.label)
  end

  private

  def authorize_period_manage
    authorize! :manage, MonthlyPeriod
  end

  def period_params
    params.require(:monthly_period).permit(:year, :month, :unit_price)
  end

  def find_previous_period(period)
    MonthlyPeriod
      .where("year * 12 + month < ?", period.year * 12 + period.month)
      .order(year: :desc, month: :desc)
      .first
  end
end
