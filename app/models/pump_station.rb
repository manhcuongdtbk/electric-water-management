class PumpStation < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :organization
  belongs_to :meter, optional: true
  has_many :pump_station_assignments, dependent: :destroy
  has_many :served_organizations, through: :pump_station_assignments, source: :organization

  # Validations
  validates :name, presence: true, length: { maximum: 100 }

  # Scopes
  scope :ordered, -> { order(:name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
end
