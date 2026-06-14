class Meter < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :contact_point
  has_many :meter_readings

  delegate :contact_point_type, to: :contact_point

  validates :name, presence: true, uniqueness: { scope: :contact_point_id }

  scope :in_zone, ->(zone) { joins(:contact_point).merge(ContactPoint.in_zone(zone)) }

  after_create :create_current_period_reading
  after_update :propagate_no_loss_to_current_period_reading, if: :saved_change_to_no_loss?
  before_discard :ensure_not_last_meter
  before_discard :delete_current_period_meter_readings

  private

  def create_current_period_reading
    period = Period.current
    return unless period
    meter_readings.create!(period: period, reading_start: 0, reading_end: nil, no_loss: no_loss)
  end

  def propagate_no_loss_to_current_period_reading
    period = Period.current
    return unless period
    meter_readings.find_by(period: period)&.update_column(:no_loss, no_loss)
    zone_id = contact_point&.effective_zone&.id
    CalculationState.touch_inputs!(zone_id: zone_id, period_id: period.id) if zone_id
  end

  def ensure_not_last_meter
    return if contact_point.discarded?
    return if contact_point.type_non_establishment?
    return if contact_point.meters.kept.where.not(id: id).exists?
    errors.add(:base, :last_meter_cannot_be_destroyed)
    throw(:abort)
  end

  # Khi discard công tơ đơn lẻ lúc đang mở kỳ: hard delete meter_readings kỳ đang mở.
  # Bỏ qua khi discard cascade từ contact_point (ContactPoint#delete_current_period_records
  # đã xóa hết) — lúc đó contact_point đã discarded.
  # Uses destroy_all (not delete_all) so TouchesCalculationState fires and marks the zone stale on discard (#334).
  def delete_current_period_meter_readings
    return if contact_point.discarded?
    period = Period.current
    return unless period
    meter_readings.where(period: period).destroy_all
  end
end
