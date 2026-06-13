class MeterReading < ApplicationRecord
  include Auditable
  include TouchesCalculationState

  belongs_to :meter
  belongs_to :period

  validates :reading_start, presence: true,
    numericality: { greater_than_or_equal_to: 0 }
  validates :reading_end,
    numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :manual_usage,
    numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :meter_id, uniqueness: { scope: :period_id }

  def usage
    return manual_usage if manual_usage.present?
    return nil if reading_end.nil?
    reading_end - reading_start
  end

  def actual_usage
    return nil if loss.nil?
    usage_value = usage
    return nil if usage_value.nil?
    usage_value + loss
  end

  private

  def calculation_state_targets
    [[meter&.contact_point&.effective_zone&.id, period_id]]
  end
end
