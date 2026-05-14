class Zone < ApplicationRecord
  has_paper_trail

  belongs_to :manager_organization, class_name: "Organization", optional: true
  has_many :main_meters,   dependent: :restrict_with_error
  has_many :organizations, dependent: :restrict_with_error
  has_many :pump_stations, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { case_sensitive: true },
                   length: { maximum: 100 }
  validate :manager_must_belong_to_zone

  scope :ordered, -> { order(:name) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name]
  end

  private

  def manager_must_belong_to_zone
    return if manager_organization.blank?

    errors.add(:manager_organization, :not_in_zone) if manager_organization.zone_id != id
  end
end
