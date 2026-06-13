class NonEstablishmentSnapshot < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  belongs_to :contact_point
  belongs_to :period

  validates :personnel_count, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :contact_point_id, uniqueness: { scope: :period_id }

  private

  def calculation_state_targets
    [[contact_point&.effective_zone&.id, period_id]]
  end
end
