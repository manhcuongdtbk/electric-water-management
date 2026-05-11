class ContactPoint < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :organization
  has_many :meters, dependent: :restrict_with_error
  has_many :personnel_records, class_name: "Personnel", dependent: :destroy
  has_many :monthly_calculations, dependent: :destroy
  has_many :other_deductions, class_name: "ContactPointOtherDeduction", dependent: :destroy
  has_many :pump_station_assignments, as: :assignable, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 },
            uniqueness: { scope: :organization_id }
  validates :group_name, length: { maximum: 100 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:position, :name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_group, ->(group) { where(group_name: group) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name group_name organization_id position created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[organization]
  end
end
