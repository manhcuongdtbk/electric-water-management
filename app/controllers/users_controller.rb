class UsersController < ApplicationController
  before_action :authorize_user_management
  before_action :set_user, only: [ :edit, :update, :lock, :unlock ]

  def index
    @users = User.ordered.includes(:organization)
  end

  def new
    @user = User.new
    @unit_organizations = unit_organizations
  end

  def create
    @user = User.new(user_create_params)
    auto_assign_organization!
    if @user.save
      redirect_to users_path, notice: t("flash.users.created")
    else
      @unit_organizations = unit_organizations
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @unit_organizations = unit_organizations
  end

  def update
    @user.assign_attributes(user_update_params)
    auto_assign_organization!
    # When admin provides a new password for another user, force them to change it on next login
    if @user != current_user && params.dig(:user, :password).present?
      @user.force_password_change = true
    end
    if @user.save
      # If admin changed their own password, Devise rotates authenticatable_salt,
      # invalidating the current session. bypass_sign_in refreshes it.
      bypass_sign_in(@user) if @user == current_user && params.dig(:user, :password).present?
      redirect_to users_path, notice: t("flash.users.updated")
    else
      @unit_organizations = unit_organizations
      render :edit, status: :unprocessable_entity
    end
  end

  def lock
    if @user == current_user
      redirect_to users_path, alert: t("flash.users.cannot_lock_self")
    elsif @user.last_active_admin_level1?
      redirect_to users_path, alert: t("flash.users.cannot_lock_last_admin")
    else
      @user.lock_access!(send_instructions: false)
      redirect_to users_path, notice: t("flash.users.locked")
    end
  end

  def unlock
    @user.unlock_access!
    redirect_to users_path, notice: t("flash.users.unlocked")
  end

  private

  def authorize_user_management
    authorize! :manage, User
  end

  def set_user
    @user = User.accessible_by(current_ability).find(params[:id])
  end

  def unit_organizations
    Organization.where(level: :unit).ordered
  end

  def auto_assign_organization!
    return if @user.admin_unit? || @user.commander?

    @user.organization = Organization.find_by(level: :division)
  end

  def user_create_params
    params.require(:user).permit(:email, :full_name, :password, :password_confirmation, :role, :organization_id)
  end

  def user_update_params
    attrs = params.require(:user).permit(:email, :full_name, :password, :password_confirmation, :role, :organization_id)
    attrs[:password].blank? ? attrs.except(:password, :password_confirmation) : attrs
  end
end
