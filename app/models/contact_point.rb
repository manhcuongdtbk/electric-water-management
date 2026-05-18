class ContactPoint < ApplicationRecord
  include Discard::Model

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
  validate :validate_water_pump_constraints, if: :type_water_pump?
  validate :validate_non_establishment_constraints, if: :type_non_establishment?

  after_create :create_current_period_snapshots

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


  def validate_unit_zone_xor
    if unit.present? == zone.present?
      errors.add(:base, :unit_zone_xor)
    end
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
end
