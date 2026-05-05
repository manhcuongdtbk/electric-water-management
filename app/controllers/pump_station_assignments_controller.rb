class PumpStationAssignmentsController < ApplicationController
  before_action :set_pump_station
  before_action :set_assignment

  def edit
    authorize! :update, @assignment
  end

  def update
    authorize! :update, @assignment
    if @assignment.update(assignment_params)
      redirect_to pump_stations_path, notice: t("flash.pump_station_assignments.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_pump_station
    @pump_station = PumpStation.find(params[:pump_station_id])
  end

  def set_assignment
    @assignment = @pump_station.pump_station_assignments.find(params[:id])
  end

  def assignment_params
    params.require(:pump_station_assignment).permit(:fixed_pump_percentage)
  end
end
