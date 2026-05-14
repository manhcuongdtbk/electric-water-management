class PumpStation < ApplicationRecord
  has_paper_trail

  # Virtual attrs used only by the create form to atomically build the
  # first meter alongside the pump station (invariant: ≥ 1 meter).
  attr_accessor :first_meter_name

  # Associations
  belongs_to :zone
  has_many :meters, dependent: :destroy
  has_many :pump_station_assignments, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }

  # Scopes
  scope :ordered, -> { order(:name) }

  def has_any_readings?
    MeterReading.where(meter_id: meters.select(:id)).exists?
  end
end
