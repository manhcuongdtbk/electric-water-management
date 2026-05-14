class MainMeter < ApplicationRecord
  has_paper_trail

  belongs_to :zone
  # Required by Ability rules (`can :read, MainMeter, organizations: { id: ... }`)
  # which walk this hash association at authorization time.
  has_many :organizations, through: :zone
  has_many :main_meter_readings, dependent: :destroy
  has_many :monthly_periods, through: :main_meter_readings

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }

  scope :ordered, -> { order(:name) }

  def reading_for(monthly_period)
    main_meter_readings.find_by(monthly_period: monthly_period)
  end

  def supply_kw_for(monthly_period)
    reading_for(monthly_period)&.electricity_supply_kw
  end
end
