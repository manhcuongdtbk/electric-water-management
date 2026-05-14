class Organization < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :parent, class_name: "Organization", optional: true
  belongs_to :zone, optional: true
  has_many :children, class_name: "Organization", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :contact_points, dependent: :restrict_with_error
  has_many :meters, dependent: :restrict_with_error
  has_many :unit_configs, dependent: :destroy
  has_many :pump_station_assignments, as: :assignable, dependent: :destroy
  has_many :owned_work_groups, class_name: "WorkGroup",
           foreign_key: :owner_organization_id, dependent: :restrict_with_error
  has_many :contact_point_groups, dependent: :restrict_with_error

  # Enums
  enum :level, { division: 1, unit: 2 }, validate: true

  # Validations
  validates :name, presence: true,
                    uniqueness: { scope: :level, case_sensitive: true },
                    length: { maximum: 100 }
  validates :level, presence: true
  validate :parent_must_be_division, if: -> { level == "unit" && parent_id.present? }
  validate :division_has_no_parent, if: -> { level == "division" }
  validate :unit_must_have_zone

  # Callbacks
  before_destroy :prevent_destroy_division

  # Scopes
  scope :ordered, -> { order(:name) }
  scope :divisions, -> { where(level: :division) }
  scope :units, -> { where(level: :unit) }
  scope :by_parent, ->(parent_id) { where(parent_id: parent_id) }

  private

  def parent_must_be_division
    errors.add(:parent_id, :invalid) unless parent&.division?
  end

  def division_has_no_parent
    errors.add(:parent_id, :present) if parent_id.present?
  end

  def unit_must_have_zone
    errors.add(:zone, :blank) if unit? && zone.blank?
  end

  def prevent_destroy_division
    return if level == "unit"

    errors.add(:base, :cannot_destroy_division)
    throw(:abort)
  end
end
