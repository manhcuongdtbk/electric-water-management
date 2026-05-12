class MainMeter < ApplicationRecord
  has_paper_trail

  belongs_to :zone
  has_many :organizations, through: :zone
  has_many :main_meter_readings, dependent: :destroy
  has_many :monthly_periods, through: :main_meter_readings

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  # Temporary compat shim until the controller refactor adds an explicit zone
  # picker: when a MainMeter is created without one, auto-create a same-named
  # Zone. Matches the current 1:1 MainMeter↔Zone reality from migration.
  before_validation :ensure_zone, on: :create

  # The `organizations.main_meter_id` FK still exists this PR; without an
  # explicit nullify, destroying a MainMeter that has orgs pointing at it via
  # that legacy column raises PG::ForeignKeyViolation. Drop along with the
  # column in the controller-refactor PR.
  before_destroy :detach_legacy_organizations

  scope :ordered, -> { order(:position, :name) }

  def reading_for(monthly_period)
    main_meter_readings.find_by(monthly_period: monthly_period)
  end

  def supply_kw_for(monthly_period)
    reading_for(monthly_period)&.electricity_supply_kw
  end

  private

  def ensure_zone
    return if zone.present?
    return if name.blank?

    self.zone = Zone.find_or_create_by!(name: name)
  end

  def detach_legacy_organizations
    Organization.where(main_meter_id: id).find_each do |org|
      org.update!(main_meter_id: nil)
    end
  end
end
