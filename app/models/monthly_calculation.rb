class MonthlyCalculation < ApplicationRecord
  has_paper_trail

  RANK_KW_COLUMNS = (1..7).map { |i| :"rank#{i}_kw" }.freeze

  # Associations
  belongs_to :contact_point
  belongs_to :monthly_period

  # Validations
  validates :contact_point_id, uniqueness: { scope: :monthly_period_id }
  validates :total_personnel, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rank1_kw, :rank2_kw, :rank3_kw, :rank4_kw,
            :rank5_kw, :rank6_kw, :rank7_kw,
            :water_pump_standard_kw, :water_pump_actual_kw,
            :total_standard_kw, :total_usage_kw, :total_deduction_kw,
            :remaining_standard_kw, :meter_usage_kw, :over_under_kw,
            :savings_deduction_kw, :loss_deduction_kw,
            :division_public_deduction_kw, :unit_public_deduction_kw,
            :other_deduction_kw, :unit_price, :total_amount,
            numericality: true

  # Scopes
  scope :for_period, ->(period_id) { where(monthly_period_id: period_id) }
  scope :for_contact_point, ->(cp_id) { where(contact_point_id: cp_id) }
  scope :by_organization, ->(org_id) { joins(:contact_point).where(contact_points: { organization_id: org_id }) }
  scope :ordered, -> { joins(:contact_point).order("contact_points.position", "contact_points.name") }

  def rank_standard_total_kw
    RANK_KW_COLUMNS.sum { |col| public_send(col) }
  end
end
