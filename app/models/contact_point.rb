class ContactPoint < ApplicationRecord
  has_paper_trail

  # Associations
  belongs_to :organization
  has_many :meters, dependent: :restrict_with_error
  has_many :personnel_records, class_name: "Personnel", dependent: :destroy
  has_many :monthly_calculations, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 },
            uniqueness: { scope: :organization_id }
  validates :group_name, length: { maximum: 100 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:position, :name) }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_group, ->(group) { where(group_name: group) }
end
