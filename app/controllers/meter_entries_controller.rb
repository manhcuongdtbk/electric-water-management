class MeterEntriesController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include BusinessRoleRequired

  before_action :require_open_period, only: [:update]

  def show
    @period = current_period
    @readings = load_readings
  end

  def update
    @period = current_period
    errors_collected = []

    ActiveRecord::Base.transaction do
      (params[:meter_readings] || {}).each do |id, attrs|
        reading = load_readings.find_by(id: id)
        next unless reading
        authorize!(:update, reading)
        permitted = attrs.permit(:reading_end, :manual_usage, :manual_usage_note, :lock_version)
        # Convert empty strings to nil
        cleaned = {
          reading_end: permitted[:reading_end].presence,
          manual_usage: permitted[:manual_usage].presence,
          manual_usage_note: permitted[:manual_usage_note].to_s.strip,
          lock_version: permitted[:lock_version].to_i
        }
        unless reading.update(cleaned)
          errors_collected << { name: reading.meter.name, msgs: reading.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors_collected.any?
    end

    if errors_collected.any?
      flash.now[:alert] = errors_collected.map { |e| "#{e[:name]}: #{e[:msgs].join(', ')}" }.join("\n")
      @readings = load_readings
      render :show, status: :unprocessable_entity
    else
      redirect_to meter_entries_path, notice: t("meter_entries.flash.saved")
    end
  end

  private

  def load_readings
    return MeterReading.none unless @period
    MeterReading.includes(meter: :contact_point)
                .where(period: @period)
                .accessible_by(current_ability)
                .joins(meter: :contact_point)
                .merge(Meter.kept)
                .merge(ContactPoint.kept)
                .where.not(contact_points: { contact_point_type: "water_pump" })
                .order("contact_points.name, meters.name")
  end
end
