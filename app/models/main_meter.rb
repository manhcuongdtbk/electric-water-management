class MainMeter < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :zone
  has_many :main_meter_readings

  validates :name, presence: true

  before_discard :delete_current_period_main_meter_readings

  private

  # Khi discard công tơ tổng lúc đang mở kỳ: hard delete main_meter_readings kỳ đang mở.
  # Khác Meter: không cần guard bỏ qua cascade — Zone đã xóa readings trước khi cascade
  # discard (Zone#delete_current_period_main_meter_readings), callback này khi đó là no-op.
  # Uses destroy_all (not delete_all) so TouchesCalculationState fires and marks the zone stale on discard (#334).
  def delete_current_period_main_meter_readings
    period = Period.current
    return unless period
    main_meter_readings.where(period: period).destroy_all
  end
end
