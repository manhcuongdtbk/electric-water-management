class PumpStationsController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_pump_station, only: [ :edit, :update, :destroy ]

  def index
    @pump_stations = PumpStation
                       .includes(:organization, :meters,
                                 pump_station_assignments: :assignable)
                       .ordered
  end

  def new
    @pump_station = PumpStation.new
  end

  def create
    @pump_station = PumpStation.new(pump_station_params)
    @pump_station.organization = division
    @pump_station.first_meter_name          = first_meter_name_param
    @pump_station.first_meter_serial_number = first_meter_serial_param

    @first_meter = @pump_station.meters.build(
      name: first_meter_name_param,
      serial_number: first_meter_serial_param,
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
    @pump_station = PumpStation.find(params[:id])
  end

  def pump_station_params
    params.require(:pump_station).permit(:name)
  end

  def first_meter_name_param
    params.dig(:pump_station, :first_meter_name).to_s.strip
  end

  def first_meter_serial_param
    raw = params.dig(:pump_station, :first_meter_serial_number)
    raw.present? ? raw.to_s.strip : nil
  end

  def copy_first_meter_errors
    return unless @first_meter

    @first_meter.errors[:name].each do |msg|
      @pump_station.errors.add(:first_meter_name, msg)
    end
    @first_meter.errors[:serial_number].each do |msg|
      @pump_station.errors.add(:first_meter_serial_number, msg)
    end
  end

  def division
    @division ||= Organization.divisions.first
  end
end
