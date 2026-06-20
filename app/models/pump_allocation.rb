class PumpAllocation < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  RECIPIENT_KEYS = %i[unit_id block_id group_id contact_point_id].freeze

  belongs_to :zone
  belongs_to :period
  belongs_to :unit, optional: true
  belongs_to :block, optional: true
  belongs_to :group, optional: true
  belongs_to :contact_point, optional: true
  belongs_to :pump_contact_point, class_name: "ContactPoint", optional: true

  validates :coefficient, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :fixed_percentage,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }

  validates :unit_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :block_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :group_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }
  validates :contact_point_id, uniqueness: { scope: [:zone_id, :period_id, :pump_contact_point_id], allow_nil: true }

  validate :validate_exactly_one_recipient
  validate :validate_recipient_belongs_to_zone
  validate :validate_station_for_period_mode
  validate :validate_fixed_percentage_sum_within_limit
  validate :validate_no_overlap, if: -> { period&.pump_allocation_per_station }
  validate :validate_no_split, if: -> { period&.pump_allocation_per_station }
  validate :validate_recipient_has_residential_contact_points

  protected

  def resolved_residential_cp_ids
    if unit_id.present?
      ContactPoint.where(unit_id: unit_id, contact_point_type: "residential").pluck(:id)
    elsif block_id.present?
      ContactPoint.where(block_id: block_id, contact_point_type: "residential").pluck(:id)
    elsif group_id.present?
      ContactPoint.where(group_id: group_id, contact_point_type: "residential").pluck(:id)
    elsif contact_point_id.present? && contact_point&.contact_point_type == "residential"
      [contact_point_id]
    else
      []
    end
  end

  def owning_unit_id
    if unit_id.present?
      unit_id
    elsif block_id.present?
      block&.unit_id
    elsif group_id.present?
      group&.unit_id
    elsif contact_point_id.present?
      contact_point&.unit_id
    end
  end

  private

  def calculation_state_targets
    [[zone_id, period_id]]
  end

  def recipient_count
    RECIPIENT_KEYS.count { |k| public_send(k).present? }
  end

  def validate_exactly_one_recipient
    case recipient_count
    when 0 then errors.add(:base, :recipient_required)
    when 1 then nil
    else errors.add(:base, :recipient_must_be_one)
    end
  end

  def validate_recipient_belongs_to_zone
    return if zone_id.blank?

    if unit.present? && unit.zone_id != zone_id
      errors.add(:unit_id, :zone_mismatch)
    end
    if block.present? && block.unit&.zone_id != zone_id
      errors.add(:block_id, :zone_mismatch)
    end
    if group.present? && group.unit&.zone_id != zone_id
      errors.add(:group_id, :zone_mismatch)
    end
    if contact_point.present?
      cp_zone_id = contact_point.zone_id || contact_point.unit&.zone_id
      errors.add(:contact_point_id, :zone_mismatch) if cp_zone_id != zone_id
    end
  end

  def validate_station_for_period_mode
    return if period.blank?

    if period.pump_allocation_per_station
      if pump_contact_point_id.blank?
        errors.add(:pump_contact_point_id, :required_for_station)
      elsif pump_contact_point.present?
        if pump_contact_point.contact_point_type != "water_pump" ||
           pump_contact_point.zone_id != zone_id
          errors.add(:pump_contact_point_id, :must_be_water_pump)
        end
      end
    elsif pump_contact_point_id.present?
      errors.add(:pump_contact_point_id, :not_allowed_legacy)
    end
  end

  def validate_recipient_has_residential_contact_points
    return if recipient_count != 1

    if unit_id.present?
      errors.add(:unit_id, :no_residential_contact_points) unless ContactPoint.where(unit_id: unit_id, contact_point_type: "residential").exists?
    elsif block_id.present?
      errors.add(:block_id, :no_residential_contact_points) unless ContactPoint.where(block_id: block_id, contact_point_type: "residential").exists?
    elsif group_id.present?
      errors.add(:group_id, :no_residential_contact_points) unless ContactPoint.where(group_id: group_id, contact_point_type: "residential").exists?
    end
  end

  def validate_no_overlap
    return if zone_id.blank? || period_id.blank?

    my_cp_ids = resolved_residential_cp_ids
    return if my_cp_ids.empty?

    siblings = PumpAllocation.where(zone_id: zone_id, period_id: period_id)
    siblings = siblings.where.not(id: id) if persisted?

    siblings.find_each do |other|
      overlap = my_cp_ids & other.resolved_residential_cp_ids
      next if overlap.empty?
      errors.add(:base, :overlapping_recipients)
      break
    end
  end

  def validate_no_split
    return if zone_id.blank? || period_id.blank?
    return unless pump_contact_point_id.present?

    my_unit_id = owning_unit_id
    return if my_unit_id.nil?

    different_station = PumpAllocation
      .where(zone_id: zone_id, period_id: period_id)
      .where.not(pump_contact_point_id: pump_contact_point_id)
    different_station = different_station.where.not(id: id) if persisted?

    different_station.find_each do |other|
      if other.owning_unit_id == my_unit_id
        errors.add(:base, :split_across_stations)
        break
      end
    end
  end

  def validate_fixed_percentage_sum_within_limit
    return if fixed_percentage.blank?
    return if zone_id.blank? || period_id.blank?

    scope = PumpAllocation.where(zone_id: zone_id, period_id: period_id,
                                 pump_contact_point_id: pump_contact_point_id)
                          .where.not(fixed_percentage: nil)
    scope = scope.where.not(id: id) if persisted?
    existing_sum = BigDecimal(scope.sum(:fixed_percentage).to_s)
    total = existing_sum + BigDecimal(fixed_percentage.to_s)

    errors.add(:base, :fixed_percentage_sum_exceeds_one_hundred) if total > 100
  end
end
