class PumpAllocationsController < ApplicationController
  include PeriodGuard
  include AuthorizeResource

  before_action :set_allocation, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :ensure_allocation_belongs_to_open_period, only: [:edit, :update, :destroy]

  SORT_COLUMNS = {
    zone:        "zones.name",
    target:      "COALESCE(units.name, contact_points.name)",
    percentage:  "pump_allocations.fixed_percentage",
    coefficient: "pump_allocations.coefficient"
  }.freeze

  def index
    @period = current_period
    scope = PumpAllocation.accessible_by(current_ability)
                          .includes(:zone, :unit, :contact_point)
                          .joins(:zone)
                          .left_joins(:unit, :contact_point)
    scope = scope.where(period: @period) if @period
    if (q = params[:q]).present?
      like = "%#{q.strip}%"
      scope = scope.where("zones.name ILIKE :q OR units.name ILIKE :q OR contact_points.name ILIKE :q", q: like)
    end
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:zone, :asc])
    @total_count = scope.count
    @pagy, @pump_allocations = pagy_with_per_page(scope)
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
      redirect_to pump_allocations_path,
        notice: t("flash.record_created", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pump_allocation.update(allocation_params)
      redirect_to pump_allocations_path,
        notice: t("flash.record_updated", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pump_allocation.destroy
    redirect_to pump_allocations_path,
      notice: t("flash.record_destroyed", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
  end

  private

  def set_allocation
    @pump_allocation = PumpAllocation.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @pump_allocation)
  end

  # Vi phạm cách ly kỳ: chỉ cho sửa/xóa pump_allocation thuộc kỳ đang mở.
  # User có thể click link cũ trỏ tới allocation kỳ đã đóng → redirect kèm cảnh báo.
  def ensure_allocation_belongs_to_open_period
    return if @pump_allocation.period_id == Period.current&.id
    redirect_to pump_allocations_path,
                alert: I18n.t("pump_allocations.flash.belongs_to_closed_period")
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
