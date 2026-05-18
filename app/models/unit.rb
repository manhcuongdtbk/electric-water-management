class Unit < ApplicationRecord
  include Discard::Model

  belongs_to :zone
  has_many :contact_points, dependent: :restrict_with_error
  has_many :blocks, dependent: :restrict_with_error
  has_many :groups, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :unit_configs
  has_many :pump_allocations
  has_many :managed_zones, class_name: "Zone", foreign_key: :manager_unit_id, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  after_create :assign_as_zone_manager

  private

  def assign_as_zone_manager
    if zone.manager_unit_id.nil? && zone.units.kept.count == 1
      zone.update_column(:manager_unit_id, id)
    end
  end
end
