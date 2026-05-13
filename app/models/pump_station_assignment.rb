class PumpStationAssignment < ApplicationRecord
  has_paper_trail

  ALLOWED_ASSIGNABLE_TYPES = %w[Organization ContactPoint WorkGroup ContactPointGroup].freeze

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
  validate :total_fixed_percentage_within_zone_limit

  # Scopes
  scope :for_pump_station, ->(ps_id) { where(pump_station_id: ps_id) }
  scope :for_assignable, ->(type, id) { where(assignable_type: type, assignable_id: id) }
  scope :for_organizations, ->(org_ids) { where(assignable_type: "Organization", assignable_id: org_ids) }

  def fixed?
    fixed_pump_percentage.present?
  end

  private

  def total_fixed_percentage_within_zone_limit
    return unless pump_station&.zone && fixed_pump_percentage.present? && fixed_pump_percentage > 0

    zone = pump_station.zone
    other_total = PumpStationAssignment
      .joins(:pump_station)
      .where(pump_stations: { zone_id: zone.id })
      .where.not(fixed_pump_percentage: nil)
      .where.not(id: id)
      .sum(:fixed_pump_percentage)

    new_total = other_total + fixed_pump_percentage
    if new_total > BigDecimal("100")
      errors.add(
        :fixed_pump_percentage,
        "tổng tỷ lệ cố định trong khu vực vượt quá 100% (hiện tại: #{other_total}%, thêm: #{fixed_pump_percentage}%)"
      )
    end
  end

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
