class UsersController < ApplicationController
  include Pagy::Method

  before_action :authorize_user_management
  before_action :set_user, only: [ :edit, :update, :lock, :unlock ]

  def index
    @q = User.accessible_by(current_ability)
              .includes(:organization)
              .ransack(params[:q])

    all_users = @q.result.to_a
    all_users = case params[:status]
    when "active" then all_users.reject(&:access_locked?)
    when "locked" then all_users.select(&:access_locked?)
    else all_users
    end
    all_users = apply_sort(all_users, params[:sort], params[:direction])

    @pagy, paged_users = pagy(all_users, limit: 50)
    @division_users = paged_users.select { |u| u.organization&.division? }
    unit_groups = paged_users.select { |u| u.organization&.unit? }
                             .group_by(&:organization)
                             .sort_by { |o, _| o&.name.to_s }
    unit_groups.reverse! if params[:sort] == "organization" && params[:direction] == "desc"
    @users_by_org = unit_groups
    @organizations = Organization.where(level: :unit).order(:name)
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

  def apply_sort(users, sort_col, direction)
    users.sort do |a, b|
      org_a = a.organization&.name.to_s
      org_b = b.organization&.name.to_s

      if sort_col == "organization"
        org_cmp = org_a <=> org_b
        primary = direction == "desc" ? -org_cmp : org_cmp
        next primary unless primary.zero?
        next a.full_name <=> b.full_name
      end

      org_cmp = org_a <=> org_b
      next org_cmp unless org_cmp.zero?

      col_cmp = case sort_col
      when "role" then User.roles[a.role] <=> User.roles[b.role]
      else             a.full_name <=> b.full_name
      end
      primary = direction == "desc" ? -col_cmp : col_cmp
      next primary unless primary.zero?

      a.full_name <=> b.full_name
    end
  end

  def user_create_params
    params.require(:user).permit(:email, :full_name, :password, :password_confirmation, :role, :organization_id)
  end

  def user_update_params
    attrs = params.require(:user).permit(:email, :full_name, :password, :password_confirmation, :role, :organization_id)
    attrs[:password].blank? ? attrs.except(:password, :password_confirmation) : attrs
  end
end
