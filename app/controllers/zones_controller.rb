class ZonesController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include ActionAuthKeyable
  include StructureChangeGuard
  include BusinessRoleRequired
  include SettingsAccessGuard

  ACTION_AUTH_KEYS = {
    "show" => :read, "edit" => :update, "update" => :update,
    "reassign_manager" => :manage, "destroy" => :destroy
  }.freeze

  before_action :require_system_admin!
  before_action :set_zone, only: [:show, :edit, :update, :destroy, :reassign_manager]
  before_action :require_open_period,
    only: [:create, :update, :destroy, :reassign_manager]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy, :reassign_manager]

  SORT_COLUMNS = {
    name:         "zones.name",
    manager_unit: "manager_units.name",
    units_count:  "(SELECT COUNT(*) FROM units WHERE units.zone_id = zones.id AND units.discarded_at IS NULL)",
    created_at:   "zones.created_at"
  }.freeze

  def index
    @period = current_period
    scope = load_collection(Zone).includes(:units, :main_meters, :manager_unit)
    if current_zone_manager?
      scope = scope.where(manager_unit_id: current_user.unit_id)
    end
    if params[:sort].to_s == "manager_unit"
      scope = scope.joins("LEFT JOIN units manager_units ON manager_units.id = zones.manager_unit_id")
    end
    scope = apply_search(scope, columns: "zones.name")
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:created_at, :desc])
    @total_count = scope.count
    @pagy, @zones = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @zone = Zone.new
    @zone.main_meters.build
    authorize!(:create, @zone)
  end

  def create
    @zone = Zone.new(zone_params)
    authorize!(:create, @zone)
    if @zone.save
      msg = t("flash.record_created", resource: t("resources.zone"), name: @zone.name)
      msg += " Cảnh báo: Khu vực chưa có đơn vị." if @zone.units.kept.empty?
      redirect_to zones_path, notice: msg
    else
      @zone.main_meters.build if @zone.main_meters.empty?
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @zone.update(zone_update_params)
      redirect_to zones_path,
        notice: t("flash.record_updated", resource: t("resources.zone"), name: @zone.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def reassign_manager
    new_manager_id = params[:manager_unit_id].presence
    new_manager = new_manager_id ? Unit.kept.accessible_by(current_ability).find(new_manager_id) : nil

    if new_manager && new_manager.zone_id != @zone.id
      redirect_to zones_path, alert: t("zones.flash.manager_must_belong_to_zone") and return
    end

    @zone.update_column(:manager_unit_id, new_manager&.id)
    msg = new_manager ? t("zones.flash.manager_reassigned", name: new_manager.name) :
                        t("zones.flash.manager_removed")
    redirect_to zones_path, notice: msg
  end

  def destroy
    if @zone.discard
      redirect_to zones_path,
        notice: t("flash.record_destroyed", resource: t("resources.zone"), name: @zone.name)
    else
      redirect_to zones_path, alert: @zone.errors.full_messages.join("\n")
    end
  end

  private

  def set_zone
    @zone = load_member(Zone, action: action_auth_key)
  end


  def zone_params
    params.require(:zone).permit(:name, main_meters_attributes: [:name])
  end

  def zone_update_params
    params.require(:zone).permit(:name, main_meters_attributes: [:id, :name])
  end
end
