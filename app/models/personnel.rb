class Personnel < ApplicationRecord
  self.table_name = "personnel"

  has_paper_trail

  RANK_COLUMNS = (1..7).map { |i| :"rank#{i}_count" }.freeze
  WATER_PUMP_RATE = BigDecimal("9.45")

  # Associations
  belongs_to :contact_point
  belongs_to :monthly_period

  # Validations
  validates :contact_point_id, uniqueness: { scope: :monthly_period_id }
  validates :rank1_count, :rank2_count, :rank3_count, :rank4_count,
            :rank5_count, :rank6_count, :rank7_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_period, ->(period_id) { where(monthly_period_id: period_id) }
  scope :for_contact_point, ->(cp_id) { where(contact_point_id: cp_id) }
  scope :by_organization, ->(org_id) { joins(:contact_point).where(contact_points: { organization_id: org_id }) }

  def total_count
    RANK_COLUMNS.sum { |col| public_send(col) }
  end
end
