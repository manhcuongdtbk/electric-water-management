class UnitConfig < ApplicationRecord
  belongs_to :unit
  belongs_to :period

  validates :unit_public_rate, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :unit_id, uniqueness: { scope: :period_id }
end
