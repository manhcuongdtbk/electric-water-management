class PersonnelController < ApplicationController
  before_action :load_and_authorize_contact_point
  before_action :set_period
  before_action :set_personnel_and_quotas

  def show
  end

  def update
    authorize! :update, @contact_point

    if @period.nil?
      redirect_to contact_point_personnel_path(@contact_point),
                  alert: t("flash.personnel.no_period")
      return
    end

    if @period.locked?
      redirect_to contact_point_personnel_path(@contact_point, period_id: @period.id),
                  alert: t("flash.personnel.period_locked")
      return
    end

    if @personnel.update(personnel_params)
      redirect_to contact_point_personnel_path(@contact_point, period_id: @period.id),
                  notice: t("flash.personnel.saved")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def toggle_review
    authorize! :update, @contact_point

    if @period.nil?
      redirect_to personnel_review_path, alert: t("flash.personnel.no_period")
      return
    end

    if @period.locked?
      redirect_to personnel_review_path(period_id: @period.id),
                  alert: t("flash.personnel.period_locked")
      return
    end

    record = @contact_point.personnel_records.find_by(monthly_period: @period)
    if record.nil?
      redirect_to personnel_review_path(period_id: @period.id),
                  alert: t("flash.personnel.no_record")
      return
    end

    if record.reviewed?
      record.unmark_reviewed!
      notice = t("flash.personnel.review_unmarked")
    else
      record.mark_reviewed!
      notice = t("flash.personnel.review_marked")
    end

    redirect_back_or_to personnel_review_path(period_id: @period.id), notice: notice
  end

  private

  # Scopes the parent lookup through `accessible_by(current_ability)` so
  # that non-existent and cross-org contact_point ids both produce the same
  # redirect + access_denied flash. See MetersController for rationale.
  def load_and_authorize_contact_point
    @contact_point = ContactPoint
                       .accessible_by(current_ability)
                       .includes(:organization)
                       .find_by(id: params[:contact_point_id])
    raise CanCan::AccessDenied unless @contact_point
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
