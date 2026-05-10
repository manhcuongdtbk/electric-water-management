class PumpStationAssignmentsController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_pump_station
  before_action :set_assignment, only: [ :edit, :update, :destroy ]

  def new
    @assignment = @pump_station.pump_station_assignments.new
    @available_organizations = available_organizations
  end

  def create
    @assignment = @pump_station.pump_station_assignments.new(create_assignment_params)
    if @assignment.save
      redirect_to pump_stations_path, notice: t("flash.pump_station_assignments.created")
    else
      @available_organizations = available_organizations
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @assignment.update(update_assignment_params)
      redirect_to pump_stations_path, notice: t("flash.pump_station_assignments.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @assignment.destroy
      redirect_to pump_stations_path, notice: t("flash.pump_station_assignments.destroyed")
    else
      message = @assignment.errors.full_messages.first ||
                t("flash.pump_station_assignments.destroy_failed")
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

  def set_assignment
    @assignment = @pump_station.pump_station_assignments.find(params[:id])
  end

  def create_assignment_params
    params.require(:pump_station_assignment).permit(:organization_id, :fixed_pump_percentage)
  end

  def update_assignment_params
    params.require(:pump_station_assignment).permit(:fixed_pump_percentage)
  end

  def available_organizations
    assigned_org_ids = @pump_station.pump_station_assignments.pluck(:organization_id)
    Organization.units.ordered.where.not(id: assigned_org_ids)
  end
end
