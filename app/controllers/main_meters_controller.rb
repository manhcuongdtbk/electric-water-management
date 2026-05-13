class MainMetersController < ApplicationController
  before_action :authorize_main_meter_management
  before_action :set_main_meter, only: [ :edit, :update, :destroy ]

  def index
    @main_meters = MainMeter.ordered.includes(:organizations)
  end

  def new
    @main_meter = MainMeter.new(position: next_position)
    @available_organizations = Organization.units.ordered
  end

  def create
    @main_meter = MainMeter.new(main_meter_params)
    Organization.transaction do
      # The MainMeter form does not yet expose a zone picker (Zone CRUD is a
      # follow-up). For the current 1:1 main_meter-to-zone reality, derive the
      # zone from the meter's name.
      assign_default_zone(@main_meter)
      if @main_meter.save
        assign_organizations(@main_meter, organization_ids_param)
        redirect_to main_meters_path, notice: t("flash.main_meters.created")
      else
        @available_organizations = Organization.units.ordered
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    @available_organizations = Organization.units.ordered
  end

  def update
    Organization.transaction do
      if @main_meter.update(main_meter_params)
        assign_organizations(@main_meter, organization_ids_param)
        redirect_to main_meters_path, notice: t("flash.main_meters.updated")
      else
        @available_organizations = Organization.units.ordered
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    if @main_meter.main_meter_readings.exists?
      redirect_to main_meters_path, alert: t("flash.main_meters.cannot_destroy_with_readings")
    elsif @main_meter.destroy
      redirect_to main_meters_path, notice: t("flash.main_meters.destroyed")
    else
      redirect_to main_meters_path, alert: @main_meter.errors.full_messages.first
    end
  end

  private

  def authorize_main_meter_management
    authorize! :manage, MainMeter
  end

  def set_main_meter
    @main_meter = MainMeter.find(params[:id])
  end

  def next_position
    (MainMeter.maximum(:position) || 0) + 1
  end

  def main_meter_params
    params.require(:main_meter).permit(:name, :notes, :position)
  end

  def organization_ids_param
    Array(params.dig(:main_meter, :organization_ids)).reject(&:blank?).map(&:to_i)
  end

  def assign_default_zone(main_meter)
    return if main_meter.zone.present?
    return if main_meter.name.blank?

    main_meter.zone = Zone.find_or_create_by!(name: main_meter.name)
  end

  # Re-assign the units linked to this main meter via its zone: any unit
  # previously in the zone but not in the new selection is detached
  # (zone_id => nil), and any newly selected unit is attached. Stealing a
  # unit from another zone is allowed — admin_level1 is trusted to manage
  # zone membership.
  #
  # Uses `update!` per record (not `update_all`) so paper_trail logs the FK
  # change on each Organization — F19 audit log must see who moved which unit
  # into which zone. paper_trail no-ops when the value is unchanged, so calling
  # update! on an already-linked org is safe and produces no spurious version.
  def assign_organizations(main_meter, requested_ids)
    zone_id = main_meter.zone_id
    Organization.where(zone_id: zone_id).where.not(id: requested_ids).each do |org|
      org.update!(zone_id: nil)
    end
    Organization.units.where(id: requested_ids).each do |org|
      org.update!(zone_id: zone_id)
    end
  end
end
