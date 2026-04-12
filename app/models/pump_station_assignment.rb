class PumpStationAssignment < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :pump_station
  belongs_to :organization

  # Validations
  validates :pump_station_id, uniqueness: { scope: :organization_id }

  # Scopes
  scope :for_pump_station, ->(ps_id) { where(pump_station_id: ps_id) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
end
