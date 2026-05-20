class User < ApplicationRecord
  # KHÔNG include Auditable: cần ignore encrypted_password trong PaperTrail
  # tránh leak bcrypt hash qua audit_logs view (system_admin + technician xem được).
  has_paper_trail ignore: [:encrypted_password]

  devise :database_authenticatable, :timeoutable

  enum :role, {
    technician: "technician",
    system_admin: "system_admin",
    unit_admin: "unit_admin",
    commander: "commander"
  }

  belongs_to :unit, optional: true

  validates :username, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :role, presence: true
  validates :unit_id, presence: true, if: -> { unit_admin? || commander? }
  validates :password, presence: true, on: :create
  validates :password, confirmation: true
  validates :password_confirmation, presence: true, if: :password_required?
  validate :password_complexity, if: :password_required?

  before_validation :clear_unit_for_non_unit_scoped_roles
  before_destroy :prevent_default_account_destroy

  def self.find_for_database_authentication(warden_conditions)
    where(username: warden_conditions[:username]).first
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end

  def will_save_change_to_email?
    false
  end

  def timeout_in
    2.hours
  end

  private

  def clear_unit_for_non_unit_scoped_roles
    self.unit_id = nil if technician? || system_admin?
  end

  def password_complexity
    return if password.blank?
    return if password.length >= 8 &&
              password.match?(/[A-Z]/) &&
              password.match?(/[a-z]/) &&
              password.match?(/\d/) &&
              password.match?(/[^A-Za-z0-9]/)

    errors.add(:password, :complexity)
  end

  def password_required?
    new_record? || password.present?
  end

  def prevent_default_account_destroy
    if default_account?
      errors.add(:base, :cannot_delete_default_account)
      throw(:abort)
    end
  end
end
