class WorkGroupsController < ApplicationController
  before_action :set_work_group, only: [ :edit, :update, :destroy ]

  def index
    authorize! :read, WorkGroup
    @work_groups = WorkGroup.accessible_by(current_ability).ordered
  end

  def new
    owner = current_user.admin_level1? ? nil : current_user.organization
    @work_group = WorkGroup.new(owner_organization: owner)
    authorize! :create, @work_group
  end

  def create
    @work_group = WorkGroup.new(work_group_params)
    @work_group.owner_organization = current_user.organization unless current_user.admin_level1?
    authorize! :create, @work_group

    if @work_group.save
      redirect_to work_groups_path, notice: t("flash.work_groups.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @work_group
  end

  def update
    authorize! :update, @work_group

    if @work_group.update(work_group_params)
      redirect_to work_groups_path, notice: t("flash.work_groups.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @work_group

    if @work_group.destroy
      redirect_to work_groups_path, notice: t("flash.work_groups.destroyed")
    else
      message = @work_group.errors.full_messages.first ||
                t("flash.work_groups.destroy_failed")
      redirect_to work_groups_path, alert: message
    end
  end

  private

  def set_work_group
    @work_group = WorkGroup.accessible_by(current_ability).find(params[:id])
  end

  def work_group_params
    permitted = params.require(:work_group).permit(:name, :personnel_count)
    if current_user.admin_level1? && params[:work_group][:owner_organization_id].present?
      permitted[:owner_organization_id] = params[:work_group][:owner_organization_id]
    end
    permitted
  end
end
