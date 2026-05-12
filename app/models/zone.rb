class Zone < ApplicationRecord
  has_paper_trail

  belongs_to :manager_organization, class_name: "Organization", optional: true
  has_many :main_meters,   dependent: :restrict_with_error
  has_many :organizations, dependent: :restrict_with_error
  has_many :pump_stations, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { case_sensitive: true },
                   length: { maximum: 100 }

  scope :ordered, -> { order(:name) }
end
