class WorkGroup < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :owner_organization, class_name: "Organization"
  has_many :pump_station_assignments, as: :assignable, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, length: { maximum: 100 },
            uniqueness: { scope: :owner_organization_id }
  validates :personnel_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :owner_must_be_unit

  # Scopes
  scope :ordered, -> { order(:position, :name) }

  private

  def owner_must_be_unit
    return if owner_organization&.unit?

    errors.add(:owner_organization, :must_be_unit)
  end
end
