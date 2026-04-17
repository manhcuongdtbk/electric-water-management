class MetersController < ApplicationController
  before_action :set_contact_point
  before_action :authorize_contact_point_read
  before_action :set_meter, only: [ :edit, :update, :destroy ]

  def index
    @meters = @contact_point.meters.ordered
  end

  def new
    authorize! :create, Meter
    @meter = @contact_point.meters.new
  end

  def create
    @meter = @contact_point.meters.new(meter_params)
    @meter.organization = @contact_point.organization
    authorize! :create, @meter
    if @meter.save
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @meter
  end

  def update
    authorize! :update, @meter
    if @meter.update(meter_params)
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @meter
    if @meter.destroy
      redirect_to contact_point_meters_path(@contact_point), notice: t("flash.meters.destroyed")
    else
      redirect_to contact_point_meters_path(@contact_point), alert: @meter.errors.full_messages.to_sentence
    end
  end

  private

  def set_contact_point
    @contact_point = ContactPoint.includes(:organization).find(params[:contact_point_id])
  end

  def authorize_contact_point_read
    authorize! :read, @contact_point
  end

  def set_meter
    @meter = @contact_point.meters.find(params[:id])
  end

  def meter_params
    params.require(:meter).permit(:name, :meter_type, :serial_number, :notes, :position)
  end
end
