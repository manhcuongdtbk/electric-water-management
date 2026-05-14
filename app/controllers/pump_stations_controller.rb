class PumpStationsController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_pump_station, only: [ :edit, :update, :destroy ]
  before_action :load_available_zones, only: [ :new, :create, :edit, :update ]

  def index
    @pump_stations = PumpStation
                       .accessible_by(current_ability)
                       .includes(:zone, :meters,
                                 pump_station_assignments: :assignable)
                       .ordered
  end

  def new
    @pump_station = PumpStation.new
  end

  def create
    @pump_station = PumpStation.new(pump_station_params)
    @pump_station.first_meter_name = first_meter_name_param

    @first_meter = @pump_station.meters.build(
      name: first_meter_name_param,
      meter_type: :pump_station,
      organization: division
    )

    if @pump_station.save
      redirect_to pump_stations_path, notice: t("flash.pump_stations.created")
    else
      copy_first_meter_errors
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pump_station.update(pump_station_params)
      redirect_to pump_stations_path, notice: t("flash.pump_stations.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @pump_station.has_any_readings?
      redirect_to pump_stations_path,
                  alert: t("flash.pump_stations.cannot_destroy_with_readings")
    elsif @pump_station.destroy
      redirect_to pump_stations_path, notice: t("flash.pump_stations.destroyed")
    else
      message = @pump_station.errors.full_messages.first ||
                t("flash.pump_stations.destroy_failed")
      redirect_to pump_stations_path, alert: message
    end
  end

  private

  def authorize_pump_stations
    authorize! :manage, PumpStation
  end

  def set_pump_station
    @pump_station = PumpStation.accessible_by(current_ability).find(params[:id])
  end

  def pump_station_params
    params.require(:pump_station).permit(:name, :zone_id)
  end

  # Zone scope shown in the create/edit form. admin_level1 sees every zone;
  # an admin_unit zone-manager only sees the zones they manage (matching the
  # ability rule `can :manage, PumpStation, zone_id: managed_zone_ids`).
  def load_available_zones
    @available_zones = if current_user.admin_level1?
      Zone.ordered
    else
      Zone.where(manager_organization_id: current_user.organization_id).ordered
    end
  end

  def first_meter_name_param
    params.dig(:pump_station, :first_meter_name).to_s.strip
  end

  def copy_first_meter_errors
    return unless @first_meter

    @first_meter.errors[:name].each do |msg|
      @pump_station.errors.add(:first_meter_name, msg)
    end
  end

  def division
    @division ||= Organization.divisions.first
  end
end
