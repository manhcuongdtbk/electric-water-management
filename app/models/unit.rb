class Unit < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :zone
  has_many :contact_points, dependent: :restrict_with_error
  has_many :blocks, dependent: :restrict_with_error
  has_many :groups, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :unit_configs
  has_many :pump_allocations
  has_many :managed_zones, class_name: "Zone", foreign_key: :manager_unit_id, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validate :immutable_zone_id, on: :update

  after_create :assign_as_zone_manager
  after_create :create_current_period_unit_config
  before_discard :ensure_no_kept_dependents
  before_discard :clear_zone_manager_if_self

  private

  def immutable_zone_id
    errors.add(:zone_id, :immutable) if zone_id_changed?
  end

  def create_current_period_unit_config
    period = Period.current
    return unless period
    unit_configs.create!(period: period, unit_public_rate: 0)
  end

  def assign_as_zone_manager
    if zone.manager_unit_id.nil? && zone.units.kept.count == 1
      zone.update_column(:manager_unit_id, id)
    end
  end

  def ensure_no_kept_dependents
    if contact_points.kept.exists?
      errors.add(:base, :has_kept_contact_points)
      throw(:abort)
    end
    if users.exists?
      errors.add(:base, :has_users)
      throw(:abort)
    end
  end

  def clear_zone_manager_if_self
    Zone.where(manager_unit_id: id).update_all(manager_unit_id: nil)
  end
end
