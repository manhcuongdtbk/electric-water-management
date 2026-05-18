class Meter < ApplicationRecord
  include Discard::Model

  belongs_to :contact_point
  has_many :meter_readings

  delegate :contact_point_type, to: :contact_point

  validates :name, presence: true, uniqueness: { scope: :contact_point_id }

  scope :in_zone, ->(zone) { joins(:contact_point).merge(ContactPoint.in_zone(zone)) }
end
