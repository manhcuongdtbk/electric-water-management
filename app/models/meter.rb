class Meter < ApplicationRecord
  has_paper_trail

  # Meter types that admin_unit can choose when creating a meter under a
  # contact point. `pump_station` is excluded — those meters belong to a
  # PumpStation (managed via the pump-station admin UI), not to a contact
  # point.
  CONTACT_POINT_FORM_TYPES = %w[normal public_meter no_loss].freeze

  # Associations
  belongs_to :organization
  belongs_to :contact_point, optional: true
  belongs_to :pump_station, optional: true
  has_many :meter_readings, dependent: :destroy

  # Enums
  enum :meter_type, { normal: 0, public_meter: 1, pump_station: 2, no_loss: 3 }, validate: true

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :meter_type, presence: true
  validates :serial_number, uniqueness: true, allow_blank: true, length: { maximum: 50 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :pump_station_assignment_consistency

  # Scopes
  scope :ordered, -> { order(:position, :name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_type, ->(type) { where(meter_type: type) }

  private

  def pump_station_assignment_consistency
    if pump_station?
      errors.add(:contact_point_id, :must_be_blank_for_pump_station) if contact_point_id.present?
      # Use the association object instead of the FK so validation passes during
      # nested creation (parent + child built together, parent has no id yet).
      errors.add(:pump_station_id, :required_for_pump_station) if pump_station.blank?
    elsif pump_station_id.present? || pump_station.present?
      errors.add(:pump_station_id, :only_for_pump_station_type)
    end
  end
end
