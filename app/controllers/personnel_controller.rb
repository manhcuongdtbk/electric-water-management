class PersonnelController < ApplicationController
  before_action :require_write_access!, only: [ :update ]
  before_action :set_contact_point
  before_action :set_period
  before_action :set_personnel_and_quotas

  def show; end

  def update
    if @period.nil?
      redirect_to contact_point_personnel_path(@contact_point),
                  alert: t("flash.personnel.no_period")
      return
    end

    if @personnel.update(personnel_params)
      redirect_to contact_point_personnel_path(@contact_point, period_id: @period.id),
                  notice: t("flash.personnel.saved")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def contact_points_scope
    if current_user.admin_level1?
      ContactPoint.all
    else
      current_user.organization.contact_points
    end
  end

  def set_contact_point
    @contact_point = contact_points_scope.includes(:organization).find(params[:contact_point_id])
  end

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def set_personnel_and_quotas
    return unless @period

    @personnel = @contact_point.personnel_records
                               .find_or_initialize_by(monthly_period: @period)
    date = Date.new(@period.year, @period.month, 1)
    @rank_quotas = RankQuota.current_quotas_for(date)
  end

  def personnel_params
    params.require(:personnel).permit(
      :rank1_count, :rank2_count, :rank3_count,
      :rank4_count, :rank5_count, :rank6_count, :rank7_count
    )
  end
end
