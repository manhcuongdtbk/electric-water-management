# Shared logic giữa MeterEntriesController (sinh hoạt + công cộng)
# và PumpEntriesController (bơm nước).
# 2 controller chỉ khác filter loại công tơ và redirect path.
module MeterReadingEntry
  extend ActiveSupport::Concern

  included do
    include PeriodGuard
    include AuthorizeResource
    include BusinessRoleRequired
    include ZoneUnitFilterable
    include FreshnessIndicatable

    before_action :require_open_period, only: [:update]
  end

  def show
    @period = current_period
    @readings = load_readings
    @show_zone_unit = current_user.system_wide_scope?
    assign_freshness_states(@period)
  end

  def update
    @period = current_period
    errors_collected = []

    ActiveRecord::Base.transaction do
      (params[:meter_readings] || {}).each do |id, attrs|
        reading = load_readings.find_by(id: id)
        next unless reading
        authorize!(:update, reading)
        permitted = attrs.permit(:reading_start, :reading_end, :manual_usage, :manual_usage_note, :lock_version)
        cleaned = {
          reading_start: permitted[:reading_start].presence || 0,
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
      render :show, status: :unprocessable_content
    else
      redirect_to after_update_path, notice: t("#{controller_name}.flash.saved")
    end
  end

  private

  def load_readings
    return MeterReading.none unless @period
    scope = MeterReading.includes(meter: { contact_point: [{ unit: :zone }, :zone] })
                .where(period: @period)
                .accessible_by(current_ability)
                .joins(meter: :contact_point)
                .joins("LEFT JOIN units ON units.id = contact_points.unit_id")
                .where(contact_point_type_condition)

    scope = apply_sa_zone_unit_filter_with_direct_zone(scope)
    scope = apply_search(scope, columns: "contact_points.name")
    scope.order("contact_points.name, meters.name")
  end

  # Override in subclass: filter loại công tơ
  def contact_point_type_condition
    raise NotImplementedError
  end

  # Override in subclass: redirect path sau update
  def after_update_path
    raise NotImplementedError
  end
end
