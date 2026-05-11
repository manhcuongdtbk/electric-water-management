class MainMeterReading < ApplicationRecord
  has_paper_trail

  belongs_to :main_meter
  belongs_to :monthly_period

  validates :electricity_supply_kw,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :main_meter_id, uniqueness: { scope: :monthly_period_id }

  scope :for_period, ->(period_id) { where(monthly_period_id: period_id) }
  scope :for_main_meter, ->(main_meter_id) { where(main_meter_id: main_meter_id) }
end
