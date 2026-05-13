class PumpStationAssignmentsController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_pump_station
  before_action :set_assignment, only: [ :edit, :update, :destroy ]

  def new
    @assignment = @pump_station.pump_station_assignments.new
    @available_assignables = available_assignables
  end

  def create
    @assignment = @pump_station.pump_station_assignments.new(create_assignment_params)
    if @assignment.save
      redirect_to pump_stations_path, notice: t("flash.pump_station_assignments.created")
    else
      @available_assignables = available_assignables
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
    params.require(:pump_station_assignment)
          .permit(:assignable_type, :assignable_id, :fixed_pump_percentage)
  end

  def update_assignment_params
    params.require(:pump_station_assignment).permit(:fixed_pump_percentage)
  end

  # Build available pickers for each assignable type, excluding records
  # already assigned to this pump station.
  def available_assignables
    taken_ids_by_type = @pump_station.pump_station_assignments
      .pluck(:assignable_type, :assignable_id)
      .group_by(&:first)
      .transform_values { |arr| arr.map(&:last) }

    {
      organizations: Organization.units.ordered
                                 .where.not(id: taken_ids_by_type["Organization"] || []),
      contact_points: ContactPoint
                        .joins(:organization)
                        .where(organizations: { level: Organization.levels[:unit] })
                        .order("organizations.position, contact_points.position, contact_points.name")
                        .where.not(id: taken_ids_by_type["ContactPoint"] || []),
      work_groups: WorkGroup.ordered.where.not(id: taken_ids_by_type["WorkGroup"] || []),
      contact_point_groups: ContactPointGroup
        .where(organization_id: @pump_station.zone.organizations.pluck(:id))
        .ordered
        .where.not(id: taken_ids_by_type["ContactPointGroup"] || [])
    }
  end
end
