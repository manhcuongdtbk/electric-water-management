class WorkGroupsController < ApplicationController
  before_action :authorize_work_groups
  before_action :set_work_group, only: [ :edit, :update, :destroy ]

  def index
    @work_groups = WorkGroup.ordered
  end

  def new
    @work_group = WorkGroup.new(position: next_position)
  end

  def create
    @work_group = WorkGroup.new(work_group_params)
    @work_group.owner_organization = division

    if @work_group.save
      redirect_to work_groups_path, notice: t("flash.work_groups.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @work_group.update(work_group_params)
      redirect_to work_groups_path, notice: t("flash.work_groups.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @work_group.destroy
      redirect_to work_groups_path, notice: t("flash.work_groups.destroyed")
    else
      message = @work_group.errors.full_messages.first ||
                t("flash.work_groups.destroy_failed")
      redirect_to work_groups_path, alert: message
    end
  end

  private

  def authorize_work_groups
    authorize! :manage, WorkGroup
  end

  def set_work_group
    @work_group = WorkGroup.find(params[:id])
  end

  def work_group_params
    params.require(:work_group).permit(:name, :personnel_count, :notes, :position)
  end

  def next_position
    (WorkGroup.maximum(:position) || -1) + 1
  end

  def division
    @division ||= Organization.divisions.first
  end
end
