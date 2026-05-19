class Group < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :unit
  belongs_to :block, optional: true
  has_many :contact_points, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :unit_id }

  validate :validate_block_unit_match

  after_discard do
    contact_points.kept.update_all(group_id: nil)
  end

  private

  def validate_block_unit_match
    return if block.blank? || unit_id.blank?
    errors.add(:block_id, :unit_mismatch) if block.unit_id != unit_id
  end
end
