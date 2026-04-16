class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :lockable

  has_paper_trail

  # Associations
  belongs_to :organization
  has_many :locked_monthly_periods, class_name: "MonthlyPeriod", foreign_key: :locked_by_id, dependent: :nullify

  # Enums
  enum :role, { admin_level1: 0, admin_unit: 1, commander: 2, tech: 3 }, validate: true

  # Validations
  validates :full_name, presence: true, length: { maximum: 100 }
  validates :role, presence: true
  validates :organization_id, presence: true
  validate :organization_must_be_unit, if: -> { admin_unit? || commander? }

  # Scopes
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :admins, -> { where(role: [ :admin_level1, :admin_unit ]) }
  scope :ordered, -> { order(:full_name) }

  private

  def organization_must_be_unit
    return unless organization_id.present?
    return if Organization.where(id: organization_id, level: :unit).exists?

    errors.add(:organization, :invalid)
  end
end
