class PumpStation < ApplicationRecord
  has_paper_trail

  # Virtual attrs used only by the create form to atomically build the
  # first meter alongside the pump station (invariant: ≥ 1 meter).
  attr_accessor :first_meter_name, :first_meter_serial_number

  # Associations
  belongs_to :zone
  belongs_to :organization, optional: true
  has_many :meters, dependent: :destroy
  has_many :pump_station_assignments, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }

  # Temporary compat shim until the form learns about zones: when an owner
  # organization is set, derive zone from it so legacy create flows continue
  # to work. Drop alongside `organization_id` in the controller-refactor PR.
  before_validation :ensure_zone_from_organization, on: :create

  # Scopes
  scope :ordered, -> { order(:name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }

  def has_any_readings?
    MeterReading.where(meter_id: meters.select(:id)).exists?
  end

  private

  def ensure_zone_from_organization
    return if zone.present?
    return if name.blank?

    self.zone = organization&.zone
    return if zone.present?

    # No owner zone available — fall back to a solo zone named after the pump
    # station. Truncate to 100 to keep within Zone's length limit so the
    # pump_station's own name-length validation still surfaces normally.
    zone_name = "Khu vực #{name}".first(100)
    self.zone = Zone.find_or_create_by!(name: zone_name)
  end
end
