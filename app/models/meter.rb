class Meter < ApplicationRecord
  include Discard::Model

  belongs_to :contact_point
  has_many :meter_readings

  delegate :contact_point_type, to: :contact_point

  validates :name, presence: true, uniqueness: { scope: :contact_point_id }

  scope :in_zone, ->(zone) { joins(:contact_point).merge(ContactPoint.in_zone(zone)) }

  after_create :create_current_period_reading

  private

  def create_current_period_reading
    period = Period.current
    return unless period
    meter_readings.create!(period: period, reading_start: 0, reading_end: nil, no_loss: no_loss)
  end
end
