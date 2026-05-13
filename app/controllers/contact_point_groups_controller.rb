class ContactPointGroupsController < ApplicationController
  before_action :set_target_org
  before_action :set_contact_point_group, only: [ :edit, :update, :destroy ]

  def index
    authorize! :read, ContactPointGroup
    @contact_point_groups = ContactPointGroup
      .accessible_by(current_ability)
      .where(target_org_condition)
      .ordered
      .includes(:contact_points)
  end

  def new
    authorize! :create, ContactPointGroup
    @contact_point_group = ContactPointGroup.new
    @available_contact_points = available_residential_contact_points
  end

  def create
    @contact_point_group = build_contact_point_group
    authorize! :create, @contact_point_group
    if @contact_point_group.save
      redirect_to contact_point_groups_path, notice: t("flash.contact_point_groups.created")
    else
      @available_contact_points = available_residential_contact_points
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @contact_point_group
    @available_contact_points = available_residential_contact_points
  end

  def update
    authorize! :update, @contact_point_group
    if @contact_point_group.update(contact_point_group_params)
      redirect_to contact_point_groups_path, notice: t("flash.contact_point_groups.updated")
    else
      @available_contact_points = available_residential_contact_points
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @contact_point_group
    if @contact_point_group.destroy
      redirect_to contact_point_groups_path, notice: t("flash.contact_point_groups.destroyed")
    else
      message = @contact_point_group.errors.full_messages.first ||
                t("flash.contact_point_groups.destroy_failed")
      redirect_to contact_point_groups_path, alert: message
    end
  end

  private

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = if params[:org_id].present?
        @all_orgs.find_by(id: params[:org_id])
      else
        @all_orgs.first
      end
    else
      @target_org = current_user.organization
    end
  end

  def set_contact_point_group
    @contact_point_group = ContactPointGroup
      .accessible_by(current_ability)
      .find_by(id: params[:id])
    raise CanCan::AccessDenied unless @contact_point_group
  end

  def build_contact_point_group
    if current_user.admin_level1?
      ContactPointGroup.new(contact_point_group_params.merge(organization: @target_org))
    else
      current_user.organization.contact_point_groups.new(contact_point_group_params)
    end
  end

  def available_residential_contact_points
    org = @target_org || current_user.organization
    org&.contact_points&.residential&.ordered || ContactPoint.none
  end

  def target_org_condition
    @target_org ? { organization_id: @target_org.id } : {}
  end

  def contact_point_group_params
    params.require(:contact_point_group).permit(:name, contact_point_ids: [])
  end
end
