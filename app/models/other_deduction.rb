class OtherDeduction < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  enum :other_type, { fixed: "fixed", coefficient: "coefficient", unit_coefficient: "unit_coefficient" },
    prefix: :other

  belongs_to :contact_point
  belongs_to :period

  validates :other_type, presence: true
  validates :other_value, presence: true, numericality: true
  validates :contact_point_id, uniqueness: { scope: :period_id }
  validate :validate_unit_coefficient_requires_unit

  private

  def calculation_state_targets
    [[contact_point&.effective_zone&.id, period_id]]
  end

  def validate_unit_coefficient_requires_unit
    return unless other_unit_coefficient?
    errors.add(:other_type, :unit_coefficient_requires_unit) if contact_point.unit_id.nil?
  end
end
