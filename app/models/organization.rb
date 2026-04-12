class Organization < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :parent, class_name: "Organization", optional: true
  has_many :children, class_name: "Organization", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :contact_points, dependent: :restrict_with_error
  has_many :meters, dependent: :restrict_with_error
  has_many :unit_configs, dependent: :destroy
  has_many :pump_stations, dependent: :restrict_with_error
  has_many :pump_station_assignments, dependent: :destroy
  has_many :served_by_pump_stations, through: :pump_station_assignments, source: :pump_station

  # Enums
  enum :level, { division: 1, unit: 2 }, validate: true

  # Validations
  validates :code, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :level, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_must_be_division, if: -> { level == "unit" && parent_id.present? }
  validate :division_has_no_parent, if: -> { level == "division" }

  # Scopes
  scope :ordered, -> { order(:position, :name) }
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
end
