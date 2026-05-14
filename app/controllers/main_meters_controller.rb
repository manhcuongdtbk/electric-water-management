class MainMetersController < ApplicationController
  before_action :load_zone
  before_action :set_main_meter, only: [ :edit, :update, :destroy ]

  def new
    authorize! :create, MainMeter
    @main_meter = @zone.main_meters.build
  end

  def create
    @main_meter = @zone.main_meters.build(main_meter_params)
    authorize! :create, @main_meter
    if @main_meter.save
      redirect_to zone_path(@zone), notice: t("flash.main_meters.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize! :update, @main_meter
  end

  def update
    authorize! :update, @main_meter
    if @main_meter.update(main_meter_params)
      redirect_to zone_path(@zone), notice: t("flash.main_meters.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @main_meter
    if @main_meter.main_meter_readings.exists?
      redirect_to zone_path(@zone), alert: t("flash.main_meters.cannot_destroy_with_readings")
    elsif @main_meter.destroy
      redirect_to zone_path(@zone), notice: t("flash.main_meters.destroyed")
    else
      redirect_to zone_path(@zone), alert: @main_meter.errors.full_messages.first
    end
  end

  private

  def load_zone
    @zone = Zone.accessible_by(current_ability).find(params[:zone_id])
  end

  def set_main_meter
    @main_meter = @zone.main_meters.find(params[:id])
  end

  def main_meter_params
    params.require(:main_meter).permit(:name)
  end
end
