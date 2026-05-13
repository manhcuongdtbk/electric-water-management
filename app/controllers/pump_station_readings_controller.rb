class PumpStationReadingsController < ApplicationController
  before_action :authorize_pump_stations
  before_action :set_period

  def show
    set_grouped_readings
  end

  def update
    if @period.nil?
      return redirect_to pump_station_readings_path,
                         alert: t("pump_station_readings.no_period")
    end

    if @period.locked?
      return redirect_to pump_station_readings_path(period_id: @period.id),
                         alert: t("flash.pump_station_readings.period_locked")
    end

    if batch_save_readings
      redirect_to pump_station_readings_path(period_id: @period.id),
                  notice: t("flash.pump_station_readings.saved")
    else
      set_grouped_readings
      render :show, status: :unprocessable_entity
    end
  end

  private

  def authorize_pump_stations
    authorize! :manage, PumpStation
  end

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def previous_period
    return nil unless @period

    MonthlyPeriod
      .where("year * 12 + month < ?", @period.year * 12 + @period.month)
      .order(year: :desc, month: :desc)
      .first
  end

  def pump_station_meters
    @pump_station_meters ||= Meter
                               .joins(:pump_station)
                               .merge(PumpStation.accessible_by(current_ability))
                               .where(meter_type: Meter.meter_types[:pump_station])
                               .includes(:pump_station)
                               .order("pump_stations.name", :position, :name)
  end

  # Build @grouped_readings: { PumpStation => [[Meter, MeterReading], ...] }
  def set_grouped_readings
    return unless @period

    meters = pump_station_meters
    meter_ids = meters.map(&:id)

    existing = MeterReading.for_period(@period.id)
                           .where(meter_id: meter_ids)
                           .index_by(&:meter_id)

    prev_period = previous_period
    prev_readings = if prev_period
      MeterReading.for_period(prev_period.id)
                  .where(meter_id: meter_ids)
                  .index_by(&:meter_id)
    else
      {}
    end

    @grouped_readings = meters.group_by(&:pump_station).transform_values do |group_meters|
      group_meters.map do |meter|
        reading = if @readings_by_meter_id&.key?(meter.id)
          @readings_by_meter_id[meter.id]
        elsif existing[meter.id]
          existing[meter.id]
        else
          r = MeterReading.new(meter: meter, monthly_period: @period)
          r.reading_start = prev_readings[meter.id]&.reading_end
          r
        end
        [ meter, reading ]
      end
    end
  end

  def batch_save_readings
    @readings_by_meter_id = {}
    @errors_by_meter_id = {}
    all_valid = true
    allowed_meter_ids = pump_station_meters.map(&:id).to_set

    ActiveRecord::Base.transaction do
      (params[:readings] || {}).each do |meter_id_str, values|
        meter_id = meter_id_str.to_i
        next unless allowed_meter_ids.include?(meter_id)

        reading_start_raw = values[:reading_start]
        reading_end_raw   = values[:reading_end]

        # Skip meter nếu cả đầu kỳ và cuối kỳ đều trống — user chưa nhập, không
        # tạo row rỗng (tránh consumption=0 giả khi engine đọc).
        next if reading_start_raw.blank? && reading_end_raw.blank?

        reading = MeterReading.find_or_initialize_by(
          meter_id: meter_id,
          monthly_period_id: @period.id
        )
        reading.reading_start = reading_start_raw.presence
        reading.reading_end   = reading_end_raw.presence

        @readings_by_meter_id[meter_id] = reading

        unless reading.save
          all_valid = false
          @errors_by_meter_id[meter_id] = reading.errors.full_messages
        end
      end

      raise ActiveRecord::Rollback unless all_valid
    end

    all_valid
  end
end
