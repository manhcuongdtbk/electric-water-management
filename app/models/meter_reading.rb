class MeterReading < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :meter
  belongs_to :monthly_period

  # Validations
  validates :meter_id, uniqueness: { scope: :monthly_period_id }
  validates :reading_start, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reading_end, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :consumption, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :reading_end_not_less_than_start

  # Scopes
  scope :for_period, ->(period_id) { where(monthly_period_id: period_id) }
  scope :for_meter, ->(meter_id) { where(meter_id: meter_id) }
  scope :by_organization, ->(org_id) { joins(:meter).where(meters: { organization_id: org_id }) }

  before_save :calculate_consumption

  private

  def calculate_consumption
    return unless reading_start.present? && reading_end.present?

    self.consumption = reading_end - reading_start
  end

  def reading_end_not_less_than_start
    return unless reading_start.present? && reading_end.present?

    errors.add(:reading_end, :greater_than_or_equal_to, count: reading_start) if reading_end < reading_start
  end
end
