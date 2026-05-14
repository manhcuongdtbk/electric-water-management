class OrganizationsController < ApplicationController
  include Pagy::Method

  before_action :authorize_organization_management
  before_action :set_organization, only: [ :edit, :update, :destroy ]

  def index
    @q = Organization.units.accessible_by(current_ability)
                     .includes(:zone, :users, :contact_points)
                     .ransack(params[:q])

    all_orgs = @q.result.to_a
    all_orgs = apply_sort(all_orgs, params[:sort], params[:direction])

    @pagy, paged_orgs = pagy(all_orgs, limit: 25)
    @organizations_by_zone = paged_orgs.group_by(&:zone)
                                       .sort_by { |z, _| z&.name.to_s }
    @zones = Zone.order(:name)
  end

  def new
    @organization = Organization.new(level: :unit)
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
    @organization = Organization.units.accessible_by(current_ability).find(params[:id])
  end

  def related_data_exists?
    @organization.users.exists? ||
      @organization.contact_points.exists? ||
      @organization.meters.exists? ||
      @organization.unit_configs.exists? ||
      @organization.pump_station_assignments.exists?
  end

  def apply_sort(orgs, sort_col, direction)
    orgs.sort do |a, b|
      zone_a = a.zone&.name.to_s
      zone_b = b.zone&.name.to_s

      if sort_col == "zone"
        zone_cmp = zone_a <=> zone_b
        primary  = direction == "desc" ? -zone_cmp : zone_cmp
        next primary unless primary.zero?
        next a.name <=> b.name
      end

      zone_cmp = zone_a <=> zone_b
      next zone_cmp unless zone_cmp.zero?

      col_cmp = case sort_col
                when "contact_points" then a.contact_points.size <=> b.contact_points.size
                when "users"          then a.users.size <=> b.users.size
                else                       a.name <=> b.name
                end
      primary = direction == "desc" ? -col_cmp : col_cmp
      next primary unless primary.zero?

      a.name <=> b.name
    end
  end

  def organization_params
    params.require(:organization).permit(:name, :zone_id)
  end
end
