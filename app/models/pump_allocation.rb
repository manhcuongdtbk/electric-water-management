class PumpAllocation < ApplicationRecord
  belongs_to :zone
  belongs_to :period
  belongs_to :unit, optional: true
  belongs_to :contact_point, optional: true

  validates :coefficient, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fixed_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }

  validate :validate_unit_or_contact_point_xor
  validate :validate_fixed_percentage_sum_within_limit

  private

  def validate_unit_or_contact_point_xor
    if unit.present? == contact_point.present?
      errors.add(:base, :unit_or_contact_point_xor)
    end
  end

  def validate_fixed_percentage_sum_within_limit
    return if fixed_percentage.blank?
    return if zone_id.blank? || period_id.blank?

    scope = PumpAllocation.where(zone_id: zone_id, period_id: period_id)
                          .where.not(fixed_percentage: nil)
    scope = scope.where.not(id: id) if persisted?
    existing_sum = BigDecimal(scope.sum(:fixed_percentage).to_s)
    total = existing_sum + BigDecimal(fixed_percentage.to_s)

    if total > 100
      errors.add(:base, :fixed_percentage_sum_exceeds_one_hundred)
    end
  end
end
