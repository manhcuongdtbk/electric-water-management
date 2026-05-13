class PumpStationMetersController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_pump_station
  before_action :set_meter, only: [ :edit, :update, :destroy ]

  def new
    @meter = @pump_station.meters.new
  end

  def create
    @meter = @pump_station.meters.new(meter_params)
    @meter.meter_type   = :pump_station
    @meter.contact_point = nil
    @meter.organization = division

    if @meter.save
      redirect_to pump_stations_path, notice: t("flash.pump_station_meters.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @meter.update(meter_params)
      redirect_to pump_stations_path, notice: t("flash.pump_station_meters.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @meter.meter_readings.exists?
      redirect_to pump_stations_path,
                  alert: t("flash.pump_station_meters.cannot_destroy_with_readings")
    elsif @pump_station.meters.count <= 1
      redirect_to pump_stations_path,
                  alert: t("flash.pump_station_meters.cannot_destroy_last_meter")
    elsif @meter.destroy
      redirect_to pump_stations_path, notice: t("flash.pump_station_meters.destroyed")
    else
      message = @meter.errors.full_messages.first ||
                t("flash.pump_station_meters.destroy_failed")
      redirect_to pump_stations_path, alert: message
    end
  end

  private

  def authorize_pump_stations
    authorize! :manage, PumpStation
  end

  def set_pump_station
    @pump_station = PumpStation.find(params[:pump_station_id])
  end

  def set_meter
    @meter = @pump_station.meters.find(params[:id])
  end

  def meter_params
    params.require(:meter).permit(:name, :serial_number, :notes, :position)
  end

  def division
    @division ||= Organization.divisions.first
  end
end
