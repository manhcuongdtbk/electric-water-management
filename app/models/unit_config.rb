class UnitConfig < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :organization
  belongs_to :monthly_period

  # Enums
  enum :other_deduction_type, { fixed_kw: 0, percent: 1 }, validate: true

  # Validations
  validates :organization_id, uniqueness: { scope: :monthly_period_id }
  validates :savings_rate,
            numericality: { greater_than_or_equal_to: 0, less_than: 1 },
            allow_nil: true
  validates :division_public_rate,
            numericality: { greater_than_or_equal_to: 0, less_than: 1 },
            allow_nil: true
  validates :unit_public_rate,
            numericality: { greater_than_or_equal_to: 0, less_than: 1 },
            allow_nil: true
  validates :other_deduction_value,
            numericality: { greater_than_or_equal_to: 0 }
  validates :electricity_supply_kw,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  # Scopes
  scope :for_period, ->(period_id) { where(monthly_period_id: period_id) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
end
