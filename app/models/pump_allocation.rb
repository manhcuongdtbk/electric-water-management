class PumpAllocation < ApplicationRecord
  belongs_to :zone
  belongs_to :period
  belongs_to :unit, optional: true
  belongs_to :contact_point, optional: true

  validates :coefficient, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fixed_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }

  validate :validate_unit_or_contact_point_xor

  private

  def validate_unit_or_contact_point_xor
    if unit.present? == contact_point.present?
      errors.add(:base, :unit_or_contact_point_xor)
    end
  end
end
