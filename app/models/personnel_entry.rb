class PersonnelEntry < ApplicationRecord
  include Auditable

  belongs_to :contact_point
  belongs_to :period
  belongs_to :rank

  validates :count, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :contact_point_id, uniqueness: { scope: [:period_id, :rank_id] }
end
