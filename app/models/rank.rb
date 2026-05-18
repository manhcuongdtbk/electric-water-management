class Rank < ApplicationRecord
  belongs_to :period
  has_many :personnel_entries, dependent: :restrict_with_error

  validates :name, presence: true
  validates :quota, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true, numericality: { only_integer: true }
end
