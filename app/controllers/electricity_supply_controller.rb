class ElectricitySupplyController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include BusinessRoleRequired

  before_action :require_open_period, only: [:update]

  def show
    @period = current_period
    @readings = load_readings
    authorize_or_redirect
  end

  def update
    @period = current_period
    errors_collected = []

    ActiveRecord::Base.transaction do
      (params[:main_meter_readings] || {}).each do |id, attrs|
        reading = load_readings.find_by(id: id)
        next unless reading
        authorize!(:update, reading)
        permitted = attrs.permit(:usage, :lock_version)
        next if permitted[:usage].to_s.empty?
        unless reading.update(permitted)
          errors_collected << { name: reading.main_meter.name, msgs: reading.errors.full_messages }
        end
      end

      # Tạo mới cho main_meter chưa có reading
      (params[:new_main_meter_readings] || {}).each do |main_meter_id, attrs|
        permitted = attrs.permit(:usage)
        next if permitted[:usage].to_s.empty?
        mm = accessible_main_meters.find_by(id: main_meter_id)
        next unless mm
        reading = mm.main_meter_readings.build(period: @period, usage: permitted[:usage])
        authorize!(:create, reading)
        unless reading.save
          errors_collected << { name: mm.name, msgs: reading.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors_collected.any?
    end

    if errors_collected.any?
      flash.now[:alert] = errors_collected.map { |e| "#{e[:name]}: #{e[:msgs].join(', ')}" }.join("\n")
      @readings = load_readings
      render :show, status: :unprocessable_entity
    else
      redirect_to electricity_supply_path, notice: t("electricity_supply.flash.saved")
    end
  end

  private

  def authorize_or_redirect
    return if accessible_main_meters.exists? || current_user.system_admin?
    redirect_to root_path, alert: I18n.t("errors.access_denied")
  end

  def accessible_main_meters
    MainMeter.kept.accessible_by(current_ability)
  end

  def load_readings
    return MainMeterReading.none unless @period
    MainMeterReading.includes(main_meter: :zone)
                    .where(period: @period)
                    .where(main_meter_id: accessible_main_meters.select(:id))
                    .order("main_meters.name")
  end
end
