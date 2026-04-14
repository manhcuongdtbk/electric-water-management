class MeterReadingsController < ApplicationController
  before_action :require_access!
  before_action :set_period
  before_action :set_target_org

  def show
    set_grouped_readings
  end

  def update
    unless current_user.admin_level1? || current_user.admin_unit?
      return redirect_to root_path, alert: t("flash.unauthorized")
    end

    if @period.nil?
      return redirect_to meter_readings_path, alert: t("meter_readings.no_period")
    end

    if @target_org.nil?
      return redirect_to meter_readings_path, alert: t("meter_readings.no_org")
    end

    if @period.locked?
      return redirect_to meter_readings_path(period_id: @period.id, org_id: effective_org_id),
                         alert: t("meter_readings.period_locked")
    end

    if batch_save_readings
      redirect_to meter_readings_path(period_id: @period.id, org_id: effective_org_id),
                  notice: t("flash.meter_readings.saved")
    else
      set_grouped_readings
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_access!
    return if current_user.admin_level1? || current_user.admin_unit? || current_user.commander?

    redirect_to root_path, alert: t("flash.unauthorized")
  end

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = if params[:org_id].present?
        @all_orgs.find_by(id: params[:org_id])
      else
        @all_orgs.first
      end
    else
      @target_org = current_user.organization
    end
  end

  def effective_org_id
    current_user.admin_level1? ? @target_org&.id : nil
  end

  def previous_period
    return nil unless @period

    MonthlyPeriod
      .where("year * 12 + month < ?", @period.year * 12 + @period.month)
      .order(year: :desc, month: :desc)
      .first
  end

  # Build @grouped_readings: { ContactPoint|nil => [[Meter, MeterReading], ...] }
  # Merges DB records, submitted values (on re-render after errors), and
  # inherited start readings from the previous period.
  def set_grouped_readings
    return unless @target_org && @period

    meters = @target_org.meters.includes(:contact_point).ordered
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

    @grouped_readings = meters.group_by(&:contact_point).transform_values do |group_meters|
      group_meters.map do |meter|
        reading = if @readings_by_meter_id&.key?(meter.id)
          # Re-render after failed save: use the submitted object (carries errors)
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

  # Saves all submitted readings in a single transaction.
  # Returns true on full success, false if any reading fails validation.
  # Populates @readings_by_meter_id and @errors_by_meter_id on failure.
  def batch_save_readings
    @readings_by_meter_id = {}
    @errors_by_meter_id = {}
    all_valid = true

    ActiveRecord::Base.transaction do
      (params[:readings] || {}).each do |meter_id_str, values|
        meter = @target_org.meters.find_by(id: meter_id_str.to_i)
        next unless meter

        reading = MeterReading.find_or_initialize_by(
          meter_id: meter.id,
          monthly_period_id: @period.id
        )
        reading.reading_start = values[:reading_start].presence
        reading.reading_end   = values[:reading_end].presence

        @readings_by_meter_id[meter.id] = reading

        unless reading.save
          all_valid = false
          @errors_by_meter_id[meter.id] = reading.errors.full_messages
        end
      end

      raise ActiveRecord::Rollback unless all_valid
    end

    all_valid
  end
end
