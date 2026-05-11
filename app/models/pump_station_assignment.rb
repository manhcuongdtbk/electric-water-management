class PumpStationAssignment < ApplicationRecord
  has_paper_trail

  ALLOWED_ASSIGNABLE_TYPES = %w[Organization ContactPoint WorkGroup].freeze

  # Associations
  belongs_to :pump_station
  belongs_to :assignable, polymorphic: true

  # Validations
  validates :assignable_type, inclusion: { in: ALLOWED_ASSIGNABLE_TYPES }
  validates :assignable_id,
            uniqueness: { scope: %i[pump_station_id assignable_type] }
  validates :fixed_pump_percentage,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 100
            },
            allow_nil: true
  validate :assignable_scope_is_valid

  # Scopes
  scope :for_pump_station, ->(ps_id) { where(pump_station_id: ps_id) }
  scope :for_assignable, ->(type, id) { where(assignable_type: type, assignable_id: id) }
  scope :for_organizations, ->(org_ids) { where(assignable_type: "Organization", assignable_id: org_ids) }

  def fixed?
    fixed_pump_percentage.present?
  end

  private

  # Reject assignments to a division-level Organization (only units may be
  # gán bơm) or to a ContactPoint whose org is not a unit. WorkGroup owner
  # is already constrained on WorkGroup itself.
  def assignable_scope_is_valid
    case assignable
    when Organization
      errors.add(:assignable, :must_be_unit_level) unless assignable.unit?
    when ContactPoint
      org = assignable.organization
      errors.add(:assignable, :must_be_in_unit_org) unless org&.unit?
    end
  end
end
