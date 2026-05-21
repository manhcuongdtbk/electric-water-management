class Period < ApplicationRecord
  include Auditable

  has_many :ranks, dependent: :restrict_with_error
  has_many :meter_readings, dependent: :restrict_with_error
  has_many :main_meter_readings, dependent: :restrict_with_error
  has_many :personnel_entries, dependent: :restrict_with_error
  has_many :non_establishment_snapshots, dependent: :restrict_with_error
  has_many :unit_configs, dependent: :restrict_with_error
  has_many :other_deductions, dependent: :restrict_with_error
  has_many :calculations, dependent: :restrict_with_error
  has_many :pump_allocations, dependent: :restrict_with_error

  validates :year, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :month, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 },
    uniqueness: { scope: :year }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :savings_rate, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :division_public_rate, presence: true,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :water_pump_standard, presence: true, numericality: { greater_than: 0 }

  scope :open, -> { where(closed: false) }
  scope :closed, -> { where(closed: true) }

  def self.current
    open.first
  end

  def open?
    !closed
  end

  def latest?
    self.class.order(year: :desc, month: :desc).first&.id == id
  end
end
