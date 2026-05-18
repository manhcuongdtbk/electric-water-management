class Group < ApplicationRecord
  include Discard::Model

  belongs_to :unit
  belongs_to :block, optional: true
  has_many :contact_points, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :unit_id }
end
