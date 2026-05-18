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
  end

  def ensure_not_last_meter
    return if contact_point.discarded?
    return if contact_point.type_non_establishment?
    return if contact_point.meters.kept.where.not(id: id).exists?
    errors.add(:base, :last_meter_cannot_be_destroyed)
    throw(:abort)
  end
end
