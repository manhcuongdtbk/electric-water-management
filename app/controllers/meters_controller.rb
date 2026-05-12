class MetersController < ApplicationController
  before_action :load_and_authorize_contact_point
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

  # Scopes the parent lookup through `accessible_by(current_ability)` so that
  # non-existent IDs and cross-org IDs both produce identical responses
  # (redirect + access_denied flash). Without this, an attacker could
  # distinguish "record does not exist" (404) from "record exists but you
  # can't reach it" (302) and enumerate cross-org contact_points.
  def load_and_authorize_contact_point
    @contact_point = ContactPoint
                       .accessible_by(current_ability)
                       .includes(:organization)
                       .find_by(id: params[:contact_point_id])
    raise CanCan::AccessDenied unless @contact_point
  end

  def set_meter
    @meter = @contact_point.meters.find(params[:id])
  end

  def meter_params
    attrs = params.require(:meter).permit(:name, :meter_type, :no_loss, :serial_number, :notes, :position)
    # Pump-station meters belong to a PumpStation, not a contact point. Null out
    # any meter_type not on the contact-point form whitelist — covers the form's
    # "pump_station" string, the JSON API's integer 2, and any future enum
    # surprises. Missing key is left untouched so partial updates still work.
    if attrs.key?(:meter_type) && !Meter::CONTACT_POINT_FORM_TYPES.include?(attrs[:meter_type].to_s)
      attrs[:meter_type] = nil
    end
    attrs
  end
end
