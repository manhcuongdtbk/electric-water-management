class LossSummary < ApplicationRecord
  belongs_to :zone
  belongs_to :period

  validates :zone_id, uniqueness: { scope: :period_id }
  validates :a, :b, :c, presence: true
end
