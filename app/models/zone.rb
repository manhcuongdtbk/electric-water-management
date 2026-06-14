class Zone < ApplicationRecord
  include Discard::Model
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

  before_discard :ensure_no_kept_dependents
  before_discard :delete_current_period_main_meter_readings
  before_discard :discard_main_meters

  private

  def validate_has_at_least_one_main_meter
    if main_meters.empty?
      errors.add(:base, :must_have_at_least_one_main_meter)
    end
  end

  def ensure_no_kept_dependents
    if units.kept.exists?
      errors.add(:base, :has_kept_units)
      throw(:abort)
    end
    if contact_points.kept.exists?
      errors.add(:base, :has_kept_contact_points)
      throw(:abort)
    end
  end

  def discard_main_meters
    main_meters.kept.find_each(&:discard)
  end

  # Khi discard khu vực lúc đang mở kỳ: hard delete main_meter_readings kỳ đang mở của
  # mọi công tơ tổng thuộc khu vực. Dữ liệu kỳ cũ (đã đóng) giữ nguyên.
  # Uses destroy_all (not delete_all) so TouchesCalculationState fires and marks the zone stale on discard (#334).
  def delete_current_period_main_meter_readings
    period = Period.current
    return unless period
    MainMeterReading.where(main_meter_id: main_meters.select(:id),
                           period_id: period.id).destroy_all
  end
end
