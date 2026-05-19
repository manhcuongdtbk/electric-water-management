class ContactPoint < ApplicationRecord
  include Discard::Model
  include Auditable

  enum :contact_point_type, {
    residential: "residential",
    public: "public",
    water_pump: "water_pump",
    non_establishment: "non_establishment"
  }, prefix: :type

  belongs_to :unit, optional: true
  belongs_to :zone, optional: true
  belongs_to :block, optional: true
  belongs_to :group, optional: true

  has_many :meters
  has_many :meter_readings, through: :meters

  accepts_nested_attributes_for :meters, allow_destroy: false,
    reject_if: ->(attrs) { attrs[:name].blank? }
  has_many :personnel_entries
  has_many :non_establishment_snapshots
  has_many :other_deductions
  has_many :calculations
  has_many :pump_allocations

  validates :name, presence: true,
    uniqueness: { scope: [:unit_id, :zone_id, :contact_point_type] }
  validates :contact_point_type, presence: true

  attr_accessor :initial_personnel_counts

  validate :validate_unit_zone_xor, if: -> { type_residential? || type_public? }
  validate :validate_block_group_unit_match, if: :type_residential?
  validate :validate_public_constraints, if: :type_public?
  validate :validate_water_pump_constraints, if: :type_water_pump?
  validate :validate_non_establishment_constraints, if: :type_non_establishment?
  validate :validate_residential_personnel_sum_on_create, on: :create,
    if: -> { type_residential? && initial_personnel_counts.present? }
  validate :validate_residential_personnel_sum_on_update, on: :update,
    if: :type_residential?
  validate :immutable_contact_point_type, on: :update

  after_create :create_current_period_snapshots
  after_update :propagate_personnel_count_to_current_snapshot,
    if: -> { type_non_establishment? && saved_change_to_personnel_count? }
  before_discard :discard_current_period_pump_allocations

  after_discard do
    meters.kept.find_each(&:discard)
  end

  scope :in_zone, ->(zone) {
    where(zone_id: zone.id).or(where(unit_id: zone.units.kept.select(:id)))
  }

  def effective_zone
    zone || unit&.zone
  end

  private

  def create_current_period_snapshots
    period = Period.current
    return unless period

    if type_residential?
      period.ranks.find_each do |rank|
        count = (initial_personnel_counts || {})[rank.id] || 0
        personnel_entries.create!(period: period, rank: rank, count: count)
      end
      other_deductions.create!(period: period, other_type: "fixed", other_value: 0)
    elsif type_non_establishment?
      non_establishment_snapshots.create!(period: period, personnel_count: personnel_count)
    end
  end

  # Cho residential/public: phải chọn ĐÚNG 1 trong 2 — đơn vị HOẶC khu vực.
  # Đầu mối sinh hoạt thuộc khu vực (vd "Chỉ huy khu vực") không thuộc đơn vị nào.
  # Tách 2 case lỗi để message dễ hiểu cho user:
  def validate_unit_zone_xor
    if unit.blank? && zone.blank?
      errors.add(:base, :assignment_required)
    elsif unit.present? && zone.present?
      errors.add(:base, :assignment_must_be_one)
    end
  end

  def validate_block_group_unit_match
    if block.present? && unit.present? && block.unit_id != unit.id
      errors.add(:block_id, :unit_mismatch)
    end
    if group.present? && unit.present? && group.unit_id != unit.id
      errors.add(:group_id, :unit_mismatch)
    end
    if block.present? && unit.blank?
      errors.add(:block_id, :must_be_blank)
    end
    if group.present? && unit.blank?
      errors.add(:group_id, :must_be_blank)
    end
  end

  def validate_public_constraints
    errors.add(:block_id, :must_be_blank) if block.present?
    errors.add(:group_id, :must_be_blank) if group.present?
    errors.add(:personnel_count, :must_be_blank) if personnel_count.present?
  end

  def validate_water_pump_constraints
    errors.add(:zone_id, :blank) if zone.blank?
    errors.add(:unit_id, :must_be_blank) if unit.present?
    errors.add(:block_id, :must_be_blank) if block.present?
    errors.add(:group_id, :must_be_blank) if group.present?
    errors.add(:personnel_count, :must_be_blank) if personnel_count.present?
  end

  def validate_non_establishment_constraints
    errors.add(:zone_id, :blank) if zone.blank?
    errors.add(:unit_id, :must_be_blank) if unit.present?
    errors.add(:block_id, :must_be_blank) if block.present?
    errors.add(:group_id, :must_be_blank) if group.present?
    if personnel_count.nil? || personnel_count < 1
      errors.add(:personnel_count, :greater_than_or_equal_to, count: 1)
    end
  end

  def validate_residential_personnel_sum_on_create
    total = (initial_personnel_counts || {}).values.sum(&:to_i)
    errors.add(:base, :residential_personnel_sum_too_low) if total < 1
  end

  def validate_residential_personnel_sum_on_update
    period = Period.current
    return unless period
    entries = personnel_entries.where(period: period)
    return if entries.empty?
    total = entries.sum(:count)
    errors.add(:base, :residential_personnel_sum_too_low) if total < 1
  end

  def immutable_contact_point_type
    errors.add(:contact_point_type, :immutable) if contact_point_type_changed?
  end

  def discard_current_period_pump_allocations
    period = Period.current
    return unless period
    PumpAllocation.where(contact_point_id: id, period_id: period.id).destroy_all
  end

  def propagate_personnel_count_to_current_snapshot
    period = Period.current
    return unless period
    non_establishment_snapshots.find_by(period: period)
      &.update_column(:personnel_count, personnel_count)
  end
end
