class ZonesController < ApplicationController
  include AuthorizeResource

  before_action :set_zone, only: [:show, :edit, :update, :destroy, :reassign_manager]

  def index
    scope = load_collection(Zone).includes(:units, :main_meters, :manager_unit)
    if (q = params[:q]).present?
      scope = scope.where("zones.name ILIKE ?", "%#{q.strip}%")
    end
    scope = scope.order(:name)
    @total_count = scope.count
    @pagy, @zones = pagy(scope)
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
      redirect_to zones_path, notice: "Đã tạo khu vực \"#{@zone.name}\". " +
        (@zone.units.kept.any? ? "" : "Cảnh báo: Khu vực chưa có đơn vị.")
    else
      @zone.main_meters.build if @zone.main_meters.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @zone.update(zone_update_params)
      redirect_to zones_path, notice: "Đã cập nhật khu vực \"#{@zone.name}\"."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def reassign_manager
    new_manager_id = params[:manager_unit_id].presence
    new_manager = new_manager_id ? Unit.kept.accessible_by(current_ability).find(new_manager_id) : nil

    if new_manager && new_manager.zone_id != @zone.id
      redirect_to zones_path, alert: "Đơn vị mới phải thuộc khu vực này." and return
    end

    @zone.update_column(:manager_unit_id, new_manager&.id)
    msg = new_manager ? "Đã chuyển đơn vị quản lý sang \"#{new_manager.name}\"." :
                        "Đã xóa đơn vị quản lý."
    redirect_to zones_path, notice: msg
  end

  def destroy
    if @zone.destroy
      redirect_to zones_path, notice: "Đã xóa khu vực \"#{@zone.name}\"."
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
