class MainMeter < ApplicationRecord
  has_paper_trail

  has_many :organizations
  has_many :main_meter_readings, dependent: :destroy
  has_many :monthly_periods, through: :main_meter_readings

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  # Detach linked organizations through `update!` so paper_trail records the FK
  # change on each Organization. `dependent: :nullify` would issue a bulk UPDATE
  # that bypasses Rails callbacks, leaving F19 audit log blind to the change.
  before_destroy :detach_organizations

  scope :ordered, -> { order(:position, :name) }

  def reading_for(monthly_period)
    main_meter_readings.find_by(monthly_period: monthly_period)
  end

  def supply_kw_for(monthly_period)
    reading_for(monthly_period)&.electricity_supply_kw
  end

  private

  def detach_organizations
    organizations.each { |org| org.update!(main_meter_id: nil) }
  end
end
