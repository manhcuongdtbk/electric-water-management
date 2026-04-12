class ContactPointOtherDeduction < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :contact_point
  belongs_to :monthly_period

  # Enums
  # fixed_kw: nhập số kW cụ thể
  # factor_per_person: hệ số × số người của đầu mối đó
  enum :other_type, { fixed_kw: 0, factor_per_person: 1 }, validate: true

  # Validations
  validates :contact_point_id, uniqueness: { scope: :monthly_period_id }
  validates :other_value, numericality: { greater_than_or_equal_to: 0 }
end
