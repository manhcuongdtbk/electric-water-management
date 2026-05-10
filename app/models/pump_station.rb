class PumpStation < ApplicationRecord
  has_paper_trail

  # Virtual attrs used only by the create form to atomically build the
  # first meter alongside the pump station (invariant: ≥ 1 meter).
  attr_accessor :first_meter_name, :first_meter_serial_number

  # Associations
  belongs_to :organization
  has_many :meters, dependent: :destroy
  has_many :pump_station_assignments, dependent: :destroy
  has_many :served_organizations, through: :pump_station_assignments, source: :organization

  # Validations
  validates :name, presence: true, length: { maximum: 100 }

  # Scopes
  scope :ordered, -> { order(:name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }

  def has_any_readings?
    MeterReading.where(meter_id: meters.select(:id)).exists?
  end
end
