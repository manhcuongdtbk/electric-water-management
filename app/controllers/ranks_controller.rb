class RanksController < ApplicationController
  include PeriodGuard
  include StructureChangeGuard
  include AuthorizeResource
  include BusinessRoleRequired
  include SettingsAccessGuard

  before_action :require_system_admin!
  before_action :set_rank, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy]
  before_action :ensure_rank_belongs_to_open_period, only: [:edit, :update, :destroy]

  SORT_COLUMNS = {
    position: "ranks.position",
    name:     "ranks.name",
    quota:    "ranks.quota"
  }.freeze

  def index
    @period = current_period || Period.order(year: :desc, month: :desc).first
    scope = @period ? @period.ranks : Rank.none
    authorize!(:read, Rank)
    scope = apply_search(scope, columns: "ranks.name") if @period
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:position, :asc]) if @period
    @total_count = scope.count
    @pagy, @ranks = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @period = current_period
    @rank = Rank.new(period: @period, position: next_position)
    authorize!(:create, @rank)
  end

  def create
    @period = current_period
    @rank = Rank.new(rank_params.merge(period: @period))
    authorize!(:create, @rank)
    if @rank.save
      redirect_to ranks_path,
        notice: t("flash.record_created", resource: t("resources.rank"), name: @rank.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @rank.update(rank_params)
      redirect_to ranks_path,
        notice: t("flash.record_updated", resource: t("resources.rank"), name: @rank.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @rank.destroy
      redirect_to ranks_path,
      notice: t("flash.record_destroyed", resource: t("resources.rank"), name: @rank.name)
    else
      redirect_to ranks_path, alert: @rank.errors.full_messages.join("\n")
    end
  end

  private

  def set_rank
    @rank = Rank.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @rank)
  end

  # Vi phạm cách ly kỳ: chỉ cho sửa/xóa rank thuộc kỳ đang mở.
  # User có thể click link cũ trỏ tới rank kỳ đã đóng → redirect kèm cảnh báo.
  def ensure_rank_belongs_to_open_period
    return if @rank.period_id == Period.current&.id
    redirect_to ranks_path, alert: I18n.t("ranks.flash.belongs_to_closed_period")
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def rank_params
    params.require(:rank).permit(:name, :quota, :position)
  end

  def next_position
    return 1 unless current_period
    (current_period.ranks.maximum(:position) || 0) + 1
  end
end
