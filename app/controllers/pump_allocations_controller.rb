class PumpAllocationsController < ApplicationController
  include PeriodGuard
  include AuthorizeResource

  before_action :set_allocation, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]

  def index
    @period = current_period
    scope = PumpAllocation.accessible_by(current_ability).includes(:zone, :unit, :contact_point)
    scope = scope.where(period: @period) if @period
    scope = scope.order("zones.name", :fixed_percentage)
                 .joins(:zone)
    @total_count = scope.count
    @pagy, @pump_allocations = pagy(scope)
  end

  def show
  end

  def new
    @pump_allocation = PumpAllocation.new(period: current_period, coefficient: 1)
    authorize!(:create, @pump_allocation)
  end

  def create
    @pump_allocation = PumpAllocation.new(allocation_params)
    @pump_allocation.period = current_period
    authorize!(:create, @pump_allocation)
    if @pump_allocation.save
      redirect_to pump_allocations_path, notice: "Đã tạo phân bổ bơm nước."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pump_allocation.update(allocation_params)
      redirect_to pump_allocations_path, notice: "Đã cập nhật phân bổ bơm nước."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pump_allocation.destroy
    redirect_to pump_allocations_path, notice: "Đã xóa phân bổ bơm nước."
  end

  private

  def set_allocation
    @pump_allocation = PumpAllocation.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @pump_allocation)
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def allocation_params
    params.require(:pump_allocation).permit(
      :zone_id, :unit_id, :contact_point_id, :coefficient, :fixed_percentage, :lock_version
    )
  end
end
