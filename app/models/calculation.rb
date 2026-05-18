class Calculation < ApplicationRecord
  belongs_to :contact_point
  belongs_to :period

  validates :contact_point_id, uniqueness: { scope: :period_id }
end
