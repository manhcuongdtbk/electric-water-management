class Meter < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :organization
  belongs_to :contact_point, optional: true
  has_many :meter_readings, dependent: :destroy
  has_one :pump_station, dependent: :nullify

  # Enums
  enum :meter_type, { normal: 0, public_meter: 1, pump_station: 2, no_loss: 3 }, validate: true

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :meter_type, presence: true
  validates :serial_number, uniqueness: true, allow_blank: true, length: { maximum: 50 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:position, :name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_type, ->(type) { where(meter_type: type) }
end
