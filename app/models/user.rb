class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable,
         :trackable, :lockable, :timeoutable

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
  validate :password_complexity
  validate :prevent_locking_last_admin_level1, if: :will_save_change_to_locked_at?

  # Callbacks
  before_destroy :prevent_destroying_last_admin_level1

  # Scopes
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :admins, -> { where(role: [ :admin_level1, :admin_unit ]) }
  scope :ordered, -> { order(:full_name) }

  def last_active_admin_level1?
    admin_level1? && User.where(role: :admin_level1).where(locked_at: nil).where.not(id: id).count == 0
  end

  # Devise hook: log a high-severity warning when the last admin_level1 is auto-locked.
  # Auto-lock is not blocked because it may indicate a real attack.
  def lock_access!(opts = {})
    if last_active_admin_level1?
      Rails.logger.warn(
        "[SECURITY] Last active admin_level1 (id=#{id}, email=#{email}) " \
        "auto-locked due to failed login attempts. " \
        "Use `rails admin:reset_password[#{email}]` to recover."
      )
    end
    super
  end

  private

  def organization_must_be_unit
    return unless organization_id.present?
    return if Organization.where(id: organization_id, level: :unit).exists?

    errors.add(:organization, :invalid)
  end

  def password_complexity
    return if password.blank?
    return if password.match?(/\A(?=.*[A-Za-z])(?=.*\d).+\z/)

    errors.add(:password, :complexity)
  end

  def prevent_locking_last_admin_level1
    return if locked_at_was.present? # already locked before — this change is unrelated to locking
    return if locked_at.nil?         # unlocking
    return unless last_active_admin_level1?

    errors.add(:base, :last_admin_lock)
  end

  def prevent_destroying_last_admin_level1
    return unless last_active_admin_level1?

    errors.add(:base, :last_admin_destroy)
    throw(:abort)
  end
end
