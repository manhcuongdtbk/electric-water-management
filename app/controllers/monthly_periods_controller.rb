class MonthlyPeriodsController < ApplicationController
  def index
    authorize! :read, MonthlyPeriod
    @monthly_periods = MonthlyPeriod.ordered
  end

  def edit
    authorize! :manage, MonthlyPeriod
    @monthly_period = MonthlyPeriod.accessible_by(current_ability).find_by(id: params[:id])
    raise CanCan::AccessDenied unless @monthly_period
  end

  def update
    authorize! :manage, MonthlyPeriod
    @monthly_period = MonthlyPeriod.accessible_by(current_ability).find_by(id: params[:id])
    raise CanCan::AccessDenied unless @monthly_period
    if @monthly_period.update(unit_price_params)
      redirect_to monthly_periods_path, notice: t("flash.monthly_periods.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    authorize! :manage, MonthlyPeriod
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
    authorize! :manage, MonthlyPeriod
    @period = MonthlyPeriod.accessible_by(current_ability).find_by(id: params[:id])
    raise CanCan::AccessDenied unless @period
    @period.unlock!
    redirect_to personnel_review_path(period_id: @period.id),
                notice: t("flash.monthly_periods.unlocked", label: @period.label)
  end

  private

  def unit_price_params
    params.require(:monthly_period).permit(:unit_price)
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
