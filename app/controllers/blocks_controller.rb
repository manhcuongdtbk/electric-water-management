class BlocksController < ApplicationController
  include PeriodGuard
  include StructureChangeGuard
  include AuthorizeResource

  before_action :set_block, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy]

  SORT_COLUMNS = {
    name: "blocks.name",
    unit: "units.name"
  }.freeze

  def index
    scope = load_collection(Block).includes(:unit)
    scope = scope.left_joins(:unit) if params[:sort].to_s == "unit"
    if (q = params[:q]).present?
      scope = scope.where("blocks.name ILIKE ?", "%#{q.strip}%")
    end
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:name, :asc])
    @total_count = scope.count
    @pagy, @blocks = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @block = Block.new(unit_id: current_user.unit_id)
    authorize!(:create, @block)
  end

  def create
    @block = Block.new(create_params)
    @block.unit_id = current_user.unit_id if current_user.unit_id.present?
    authorize!(:create, @block)
    if @block.save
      redirect_to blocks_path,
        notice: t("flash.record_created", resource: t("resources.block"), name: @block.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @block.update(update_params)
      redirect_to blocks_path,
        notice: t("flash.record_updated", resource: t("resources.block"), name: @block.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @block.discard
      redirect_to blocks_path,
        notice: "#{t("flash.record_destroyed", resource: t("resources.block"), name: @block.name)} Các nhóm và đầu mối trong khối đã chuyển về trực tiếp thuộc đơn vị."
    else
      redirect_to blocks_path, alert: @block.errors.full_messages.join("\n")
    end
  end

  private

  def set_block
    @block = load_member(Block, action: action_auth_key)
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def create_params
    params.require(:block).permit(:name, :unit_id)
  end

  def update_params
    # unit_id immutable sau khi tạo
    params.require(:block).permit(:name)
  end
end
