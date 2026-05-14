class ZonesController < ApplicationController
  include Pagy::Method

  before_action :set_zone, only: [ :show, :update, :destroy ]

  def index
    authorize! :read, Zone
    @q = Zone.accessible_by(current_ability)
              .includes(:manager_organization, :main_meters, :organizations)
              .ransack(params[:q])
    all_zones = @q.result.to_a
    all_zones = apply_sort(all_zones, params[:sort], params[:direction])
    @pagy, @zones = pagy(all_zones, limit: 25)
  end

  def show
    authorize! :read, @zone
    @main_meters = @zone.main_meters.ordered
    @organizations = @zone.organizations.ordered
  end

  def new
    authorize! :create, Zone
    @zone = Zone.new
  end

  def create
    @zone = Zone.new(zone_params)
    authorize! :create, @zone
    if @zone.save
      redirect_to zones_path, notice: t("flash.zones.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! :update, @zone
    if @zone.update(zone_params)
      redirect_to zones_path, notice: t("flash.zones.updated")
    else
      @main_meters = @zone.main_meters.ordered
      @organizations = @zone.organizations.ordered
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @zone
    if @zone.destroy
      redirect_to zones_path, notice: t("flash.zones.destroyed")
    else
      message = @zone.errors.full_messages.first || t("flash.zones.destroy_failed")
      redirect_to zones_path, alert: message
    end
  end

  private

  def set_zone
    @zone = Zone.accessible_by(current_ability).find(params[:id])
  end

  def apply_sort(zones, sort_col, direction)
    zones.sort do |a, b|
      col_cmp = case sort_col
      when "manager_organization"
        a.manager_organization&.name.to_s <=> b.manager_organization&.name.to_s
      when "main_meters"
        a.main_meters.size <=> b.main_meters.size
      when "organizations"
        a.organizations.size <=> b.organizations.size
      else
        a.name <=> b.name
      end
      primary = direction == "desc" ? -col_cmp : col_cmp
      next primary unless primary.zero?
      a.name <=> b.name
    end
  end

  def zone_params
    params.require(:zone).permit(:name, :manager_organization_id)
  end

  def manager_options(zone)
    zone.organizations.units.ordered.map { |o| [ o.name, o.id ] }
  end
  helper_method :manager_options
end
