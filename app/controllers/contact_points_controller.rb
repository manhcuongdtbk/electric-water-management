class ContactPointsController < ApplicationController
  include Pagy::Method

  before_action :require_write_access!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_contact_point, only: [ :show, :edit, :update, :destroy ]

  def index
    @organizations = Organization.ordered if current_user.admin_level1?
    @q = contact_points_scope.ransack(params[:q])
    @pagy, @contact_points = pagy(
      @q.result.ordered.includes(:organization, :meters, :personnel_records),
      limit: 25
    )
  end

  def show; end

  def new
    @contact_point = ContactPoint.new
    @organizations = Organization.ordered if current_user.admin_level1?
  end

  def create
    @contact_point = build_contact_point
    if @contact_point.save
      redirect_to contact_points_path, notice: t("flash.contact_points.created")
    else
      @organizations = Organization.ordered if current_user.admin_level1?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.ordered if current_user.admin_level1?
  end

  def update
    if @contact_point.update(contact_point_params)
      redirect_to contact_points_path, notice: t("flash.contact_points.updated")
    else
      @organizations = Organization.ordered if current_user.admin_level1?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @contact_point.destroy
      redirect_to contact_points_path, notice: t("flash.contact_points.destroyed")
    else
      redirect_to contact_points_path, alert: @contact_point.errors.full_messages.to_sentence
    end
  end

  private

  def contact_points_scope
    if current_user.admin_level1?
      ContactPoint.all
    else
      current_user.organization.contact_points
    end
  end

  def set_contact_point
    @contact_point = contact_points_scope.find(params[:id])
  end

  def build_contact_point
    if current_user.admin_level1?
      ContactPoint.new(contact_point_params)
    else
      current_user.organization.contact_points.new(contact_point_params_for_unit)
    end
  end

  def contact_point_params
    params.require(:contact_point).permit(:name, :group_name, :position, :organization_id)
  end

  def contact_point_params_for_unit
    params.require(:contact_point).permit(:name, :group_name, :position)
  end
end
