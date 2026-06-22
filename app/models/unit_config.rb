class UnitConfig < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  belongs_to :unit
  belongs_to :period

  validates :unit_public_rate, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :unit_id, uniqueness: { scope: :period_id }

  private

  def calculation_state_targets
    [[unit&.zone_id, period_id]]
  end
end
