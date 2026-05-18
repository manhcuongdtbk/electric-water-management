class Zone < ApplicationRecord
  has_many :units, dependent: :restrict_with_error
  has_many :contact_points, dependent: :restrict_with_error
  has_many :main_meters, dependent: :restrict_with_error
  has_many :pump_allocations, dependent: :restrict_with_error
  belongs_to :manager_unit, class_name: "Unit", optional: true

  validates :name, presence: true, uniqueness: true
end
