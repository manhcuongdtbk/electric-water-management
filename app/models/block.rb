class Block < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :unit
  has_many :groups, dependent: :nullify
  has_many :contact_points, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :unit_id }

  after_discard do
    groups.kept.update_all(block_id: nil)
    contact_points.kept.update_all(block_id: nil)
  end
end
