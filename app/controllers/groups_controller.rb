class GroupsController < ApplicationController
  include PeriodGuard
  include StructureChangeGuard
  include AuthorizeResource
  include BusinessRoleRequired
  include ZoneUnitFilterable

  before_action :set_group, only: [:show, :edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :require_latest_period_when_open,
    only: [:new, :create, :edit, :update, :destroy]

  SORT_COLUMNS = {
    name:       "groups.name",
    zone:       "zones.name",
    block:      "blocks.name",
    unit:       "units.name",
    created_at: "groups.created_at"
  }.freeze

  def index
    @period = current_period
    scope = load_collection(Group).includes(:unit, :block)
                                  .joins(:unit).left_joins(:block)
    scope = scope.joins("INNER JOIN zones ON zones.id = units.zone_id")

    if current_user.role == "system_admin"
      @zone, @unit = resolve_zone_unit_filter
      # Tính available zones/units TRƯỚC khi filter để dropdown không bị giới hạn
      all_unit_ids = scope.unscope(:order).distinct.pluck(:unit_id)
      all_zone_ids = Unit.where(id: all_unit_ids).distinct.pluck(:zone_id)
      @available_zones = available_zones_for_filter(zone_ids: all_zone_ids)
      @available_units = available_units_for_filter(@zone, unit_ids: all_unit_ids)
      scope = scope.where(units: { zone_id: @zone.id }) if @zone
      scope = scope.where(unit_id: @unit.id) if @unit
    end

    if (q = params[:q]).present?
      scope = scope.where("groups.name ILIKE ?", "%#{q.strip}%")
    end
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:created_at, :desc])
    @total_count = scope.count
    @pagy, @groups = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @group = Group.new(unit_id: current_user.unit_id)
    authorize!(:create, @group)
  end

  def create
    @group = Group.new(create_params)
    @group.unit_id = current_user.unit_id if current_user.unit_id.present?
    authorize!(:create, @group)
    if @group.save
      redirect_to groups_path,
        notice: t("flash.record_created", resource: t("resources.group"), name: @group.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @group.update(update_params)
      redirect_to groups_path,
        notice: t("flash.record_updated", resource: t("resources.group"), name: @group.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @group.discard
      redirect_to groups_path,
        notice: "#{t("flash.record_destroyed", resource: t("resources.group"), name: @group.name)} Đầu mối trong nhóm đã chuyển về khối/đơn vị."
    else
      redirect_to groups_path, alert: @group.errors.full_messages.join("\n")
    end
  end

  private

  def set_group
    @group = load_member(Group, action: action_auth_key)
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def create_params
    params.require(:group).permit(:name, :unit_id, :block_id)
  end

  def update_params
    # unit_id immutable sau khi tạo; block_id vẫn cho đổi (di chuyển nhóm giữa các khối trong cùng đơn vị)
    params.require(:group).permit(:name, :block_id)
  end
end
