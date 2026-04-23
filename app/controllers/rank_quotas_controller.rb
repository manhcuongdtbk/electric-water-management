class RankQuotasController < ApplicationController
  before_action :set_rank_quota, only: [ :edit, :update ]

  def index
    authorize! :read, RankQuota
    @rank_quotas = RankQuota.ordered
  end

  def edit
    authorize! :manage, RankQuota
  end

  def update
    authorize! :manage, RankQuota
    if @rank_quota.update(rank_quota_params)
      redirect_to rank_quotas_path, notice: t("flash.rank_quotas.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_rank_quota
    @rank_quota = RankQuota.accessible_by(current_ability).find_by(id: params[:id])
    raise CanCan::AccessDenied unless @rank_quota
  end

  def rank_quota_params
    params.require(:rank_quota).permit(:rank_name, :quota_kw)
  end
end
