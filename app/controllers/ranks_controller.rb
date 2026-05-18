class RanksController < ApplicationController
  include AuthorizeResource

  before_action :set_rank, only: [:show, :edit, :update, :destroy]

  def index
    @period = current_period || Period.order(year: :desc, month: :desc).first
    scope = @period ? @period.ranks.order(:position) : Rank.none
    authorize!(:read, Rank)
    @total_count = scope.count
    @pagy, @ranks = pagy(scope)
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
      redirect_to ranks_path, notice: "Đã thêm nhóm cấp bậc \"#{@rank.name}\"."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @rank.update(rank_params)
      redirect_to ranks_path, notice: "Đã cập nhật nhóm cấp bậc \"#{@rank.name}\"."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @rank.destroy
      redirect_to ranks_path, notice: "Đã xóa nhóm cấp bậc \"#{@rank.name}\"."
    else
      redirect_to ranks_path, alert: @rank.errors.full_messages.join("\n")
    end
  end

  private

  def set_rank
    @rank = Rank.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @rank)
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
