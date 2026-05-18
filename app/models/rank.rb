class Rank < ApplicationRecord
  include Auditable

  belongs_to :period
  has_many :personnel_entries, dependent: :destroy

  validates :name, presence: true
  validates :quota, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :period_id }

  before_destroy :ensure_no_entries_with_personnel, prepend: true
  after_create :seed_personnel_entries_for_residentials

  private

  def ensure_no_entries_with_personnel
    if personnel_entries.where("count > 0").exists?
      errors.add(:base, :has_personnel_entries_in_use)
      throw(:abort)
    end
  end

  def seed_personnel_entries_for_residentials
    return unless period&.open?
    active_cp_ids = PersonnelEntry.where(period: period).distinct.pluck(:contact_point_id)
    return if active_cp_ids.empty?
    ContactPoint.kept.where(contact_point_type: "residential", id: active_cp_ids).find_each do |cp|
      PersonnelEntry.find_or_create_by!(period: period, rank: self, contact_point: cp) do |pe|
        pe.count = 0
      end
    end
  end
end
