class UnitsController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include StructureChangeGuard
  include BusinessRoleRequired

  before_action :set_unit, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period,
    only: [:create, :update, :destroy]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy]

  SORT_COLUMNS = {
    name:       "units.name",
    zone:       "zones.name",
    is_manager: "(SELECT COUNT(*) FROM zones WHERE zones.manager_unit_id = units.id)"
  }.freeze

  def index
    scope = load_collection(Unit).includes(:zone, :managed_zones)
    scope = scope.left_joins(:zone) if params[:sort].to_s == "zone"
    if (q = params[:q]).present?
      scope = scope.where("units.name ILIKE ?", "%#{q.strip}%")
    end
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:name, :asc])
    @total_count = scope.count
    @pagy, @units = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @unit = Unit.new
    authorize!(:create, @unit)
  end

  def create
    @unit = Unit.new(unit_params)
    authorize!(:create, @unit)
    if @unit.save
      redirect_to units_path,
        notice: t("flash.record_created", resource: t("resources.unit"), name: @unit.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @unit.update(unit_update_params)
      redirect_to units_path,
        notice: t("flash.record_updated", resource: t("resources.unit"), name: @unit.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Lấy danh sách zones bị ảnh hưởng TRƯỚC discard (before_discard
    # :clear_zone_manager_if_self sẽ set manager_unit_id = nil ngay sau đó)
    affected_zones = Zone.kept.where(manager_unit_id: @unit.id).pluck(:name)

    if @unit.discard
      msg = t("flash.record_destroyed", resource: t("resources.unit"), name: @unit.name)
      if affected_zones.any?
        msg += " Cảnh báo: khu vực #{affected_zones.join(', ')} hiện không còn đơn vị quản lý."
      end
      redirect_to units_path, notice: msg
    else
      redirect_to units_path, alert: @unit.errors.full_messages.join("\n")
    end
  end

  private

  def set_unit
    @unit = load_member(Unit, action: action_auth_key)
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def unit_params
    params.require(:unit).permit(:name, :zone_id)
  end

  def unit_update_params
    # T30: zone_id immutable
    params.require(:unit).permit(:name)
  end
end
