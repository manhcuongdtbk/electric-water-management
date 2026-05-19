class ZonesController < ApplicationController
  include AuthorizeResource
  include StructureChangeGuard

  before_action :set_zone, only: [:show, :edit, :update, :destroy, :reassign_manager]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy, :reassign_manager]

  SORT_COLUMNS = {
    name:         "zones.name",
    manager_unit: "manager_units.name",
    units_count:  "(SELECT COUNT(*) FROM units WHERE units.zone_id = zones.id AND units.discarded_at IS NULL)"
  }.freeze

  def index
    scope = load_collection(Zone).includes(:units, :main_meters, :manager_unit)
    if params[:sort].to_s == "manager_unit"
      scope = scope.joins("LEFT JOIN units manager_units ON manager_units.id = zones.manager_unit_id")
    end
    if (q = params[:q]).present?
      scope = scope.where("zones.name ILIKE ?", "%#{q.strip}%")
    end
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:name, :asc])
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
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @zone.update(zone_update_params)
      redirect_to zones_path,
        notice: t("flash.record_updated", resource: t("resources.zone"), name: @zone.name)
    else
      render :edit, status: :unprocessable_entity
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

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update", "reassign_manager" then :update
    when "destroy" then :destroy
    end
  end

  def zone_params
    params.require(:zone).permit(:name, main_meters_attributes: [:name])
  end

  def zone_update_params
    # Bỏ main_meters_attributes ở update (quản lý riêng nếu cần)
    params.require(:zone).permit(:name)
  end
end
