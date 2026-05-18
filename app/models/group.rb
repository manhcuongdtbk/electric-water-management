class Group < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :unit
  belongs_to :block, optional: true
  has_many :contact_points, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :unit_id }

  after_discard do
    contact_points.kept.update_all(group_id: nil)
  end
end
