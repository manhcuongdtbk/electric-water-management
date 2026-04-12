class MonthlyPeriod < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :locked_by, class_name: "User", optional: true
  has_many :meter_readings, dependent: :destroy
  has_many :personnel_records, class_name: "Personnel", dependent: :destroy
  has_many :unit_configs, dependent: :destroy
  has_many :monthly_calculations, dependent: :destroy

  # Validations
  validates :year, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 },
            uniqueness: { scope: :year }
  validates :unit_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :locked, inclusion: { in: [ true, false ] }
  validate :locked_by_required_when_locked

  # Scopes
  scope :ordered, -> { order(year: :desc, month: :desc) }
  scope :unlocked, -> { where(locked: false) }
  scope :locked, -> { where(locked: true) }
  scope :for_year, ->(year) { where(year: year) }

  def label
    format("%04d/%02d", year, month)
  end

  def lock!(user)
    update!(locked: true, locked_at: Time.current, locked_by: user)
  end

  def unlock!
    update!(locked: false, locked_at: nil, locked_by: nil)
  end

  private

  def locked_by_required_when_locked
    errors.add(:locked_by, :blank) if locked? && locked_by_id.nil?
  end
end
