class Block < ApplicationRecord
  include Discard::Model

  belongs_to :unit
  has_many :groups, dependent: :nullify
  has_many :contact_points, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :unit_id }
end
