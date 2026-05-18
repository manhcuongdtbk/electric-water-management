class BlocksController < ApplicationController
  include PeriodGuard
  include AuthorizeResource

  before_action :set_block, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]

  def index
    scope = load_collection(Block).includes(:unit)
    if (q = params[:q]).present?
      scope = scope.where("blocks.name ILIKE ?", "%#{q.strip}%")
    end
    scope = scope.order(:name)
    @total_count = scope.count
    @pagy, @blocks = pagy(scope)
  end

  def show
  end

  def new
    @block = Block.new
    authorize!(:create, @block)
  end

  def create
    @block = Block.new(create_params)
    authorize!(:create, @block)
    if @block.save
      redirect_to blocks_path, notice: "Đã tạo khối \"#{@block.name}\"."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @block.update(update_params)
      redirect_to blocks_path, notice: "Đã cập nhật khối \"#{@block.name}\"."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @block.discard
      redirect_to blocks_path, notice: "Đã xóa khối \"#{@block.name}\". Các nhóm và đầu mối trong khối đã chuyển về trực tiếp thuộc đơn vị."
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
