class OrganizationsController < ApplicationController
  before_action :authorize_organization_management
  before_action :set_organization, only: [ :edit, :update, :destroy ]

  def index
    @organizations = Organization.units.ordered.includes(:users, :contact_points)
  end

  def new
    @organization = Organization.new(level: :unit, position: next_position)
  end

  def create
    @organization = Organization.new(organization_params)
    @organization.level  = :unit
    @organization.parent = Organization.divisions.first
    if @organization.save
      redirect_to organizations_path, notice: t("flash.organizations.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: t("flash.organizations.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if related_data_exists?
      redirect_to organizations_path, alert: t("flash.organizations.cannot_destroy_with_data")
    elsif @organization.destroy
      redirect_to organizations_path, notice: t("flash.organizations.destroyed")
    else
      message = @organization.errors.full_messages.first || t("flash.organizations.destroy_failed")
      redirect_to organizations_path, alert: message
    end
  end

  private

  def authorize_organization_management
    authorize! :manage, Organization
  end

  def set_organization
    # Controller scope is intentionally limited to level-2 units. The division
    # is managed by seeds and is not editable / destroyable here, even by
    # admin_level1.
    @organization = Organization.units.find(params[:id])
  end

  def next_position
    (Organization.units.maximum(:position) || 0) + 1
  end

  def related_data_exists?
    @organization.users.exists? ||
      @organization.contact_points.exists? ||
      @organization.meters.exists? ||
      @organization.pump_stations.exists? ||
      @organization.unit_configs.exists? ||
      @organization.pump_station_assignments.exists?
  end

  def organization_params
    params.require(:organization).permit(:name, :position)
  end
end
