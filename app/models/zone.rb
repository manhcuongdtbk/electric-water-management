class Zone < ApplicationRecord
  include Auditable

  has_many :units
  has_many :contact_points, dependent: :restrict_with_error
  has_many :main_meters, dependent: :restrict_with_error
  has_many :pump_allocations, dependent: :restrict_with_error
  belongs_to :manager_unit, class_name: "Unit", optional: true

  accepts_nested_attributes_for :main_meters, allow_destroy: false,
    reject_if: ->(attrs) { attrs[:name].blank? }

  validates :name, presence: true, uniqueness: true
  validate :validate_has_at_least_one_main_meter, on: :create

  before_destroy :ensure_no_kept_units, prepend: true

  private

  def validate_has_at_least_one_main_meter
    if main_meters.empty?
      errors.add(:base, :must_have_at_least_one_main_meter)
    end
  end

  def ensure_no_kept_units
    if units.kept.exists?
      errors.add(:base, :has_kept_units)
      throw(:abort)
    end
  end
end
