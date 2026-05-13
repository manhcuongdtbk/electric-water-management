class ZonesController < ApplicationController
  before_action :set_zone, only: [ :edit, :update, :destroy ]

  def index
    authorize! :read, Zone
    @zones = Zone.accessible_by(current_ability).ordered.includes(:manager_organization, :main_meters, :organizations)
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

  def edit
    authorize! :update, @zone
  end

  def update
    authorize! :update, @zone
    if @zone.update(zone_params)
      redirect_to zones_path, notice: t("flash.zones.updated")
    else
      render :edit, status: :unprocessable_entity
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

  def zone_params
    params.require(:zone).permit(:name, :manager_organization_id)
  end

  def unit_options
    Organization.units.ordered.map { |o| [ o.name, o.id ] }
  end
  helper_method :unit_options
end
