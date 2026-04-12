class MetersController < ApplicationController
  before_action :require_write_access!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_contact_point
  before_action :set_meter, only: [ :edit, :update, :destroy ]

  def index
    @meters = @contact_point.meters.ordered
  end

  def new
    @meter = @contact_point.meters.new
  end

  def create
    @meter = @contact_point.meters.new(meter_params)
    @meter.organization = @contact_point.organization
    if @meter.save
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @meter.update(meter_params)
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @meter.destroy
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.destroyed")
    else
      redirect_to contact_point_meters_path(@contact_point), alert: @meter.errors.full_messages.to_sentence
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
    @contact_point = contact_points_scope.includes(:organization).find(params[:contact_point_id])
  end

  def set_meter
    @meter = @contact_point.meters.find(params[:id])
  end

  def meter_params
    params.require(:meter).permit(:name, :meter_type, :serial_number, :notes, :position)
  end
end
