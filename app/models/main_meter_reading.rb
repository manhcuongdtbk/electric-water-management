class MainMeterReading < ApplicationRecord
  belongs_to :main_meter
  belongs_to :period

  validates :usage, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :main_meter_id, uniqueness: { scope: :period_id }
end
