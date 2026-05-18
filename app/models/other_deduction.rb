class OtherDeduction < ApplicationRecord
  enum :other_type, { fixed: "fixed", coefficient: "coefficient" }, prefix: :other

  belongs_to :contact_point
  belongs_to :period

  validates :other_type, presence: true
  validates :other_value, presence: true, numericality: true
  validates :contact_point_id, uniqueness: { scope: :period_id }
end
