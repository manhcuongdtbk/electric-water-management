class UsersController < ApplicationController
  include AuthorizeResource
  include ActionAuthKeyable
  include ZoneUnitFilterable
  include SettingsAccessGuard

  ACTION_AUTH_KEYS = { "show" => :read, "edit" => :update, "update" => :update, "destroy" => :destroy }.freeze

  before_action :require_account_manager!
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  SORT_COLUMNS = {
    username:     "users.username",
    display_name: "users.display_name",
    role:         "users.role",
    zone:         "zones.name",
    unit:         "units.name"
  }.freeze

  ROLES = %w[system_admin unit_admin commander division_commander technician].freeze

  def index
    scope = User.accessible_by(current_ability).includes(unit: :zone).left_joins(:unit)
    scope = scope.joins("LEFT JOIN zones ON zones.id = units.zone_id")

    @filter_role = params[:role] if ROLES.include?(params[:role])
    scope = scope.where(role: @filter_role) if @filter_role

    scope = apply_sa_zone_unit_filter(scope)

    scope = apply_search(scope, columns: %w[users.username users.display_name])
    scope = apply_sort(scope, allowed: SORT_COLUMNS, default: [:username, :asc])
    @total_count = scope.count
    @pagy, @users = pagy_with_per_page(scope)
  end

  def show
  end

  def new
    @user = User.new
    authorize!(:create, @user)
  end

  def create
    @user = User.new(create_user_params)
    authorize!(:create, @user)
    if @user.save
      redirect_to users_path,
        notice: t("flash.record_created", resource: t("resources.user"), name: @user.username)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @user.assign_attributes(update_user_params)
    # Vai trò KHÔNG đi qua mass assignment (xem update_user_params). Gán tường minh
    # rồi authorize! lại với vai trò mới để Ability (vd: system_admin không được tạo
    # technician) chặn được nâng quyền — set_user chỉ authorize trên vai trò cũ.
    @user.role = params[:user][:role] if params[:user].key?(:role)
    authorize!(:update, @user)
    if @user.save
      redirect_to users_path,
        notice: t("flash.record_updated", resource: t("resources.user"), name: @user.username)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: I18n.t("errors.cannot_destroy_self") and return
    end
    if @user.destroy
      redirect_to users_path,
        notice: t("flash.record_destroyed", resource: t("resources.user"), name: @user.username)
    else
      redirect_to users_path, alert: @user.errors.full_messages.join("\n")
    end
  end

  private

  def set_user
    @user = User.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @user)
  end


  def create_user_params
    params.require(:user).permit(:username, :display_name, :role, :unit_id, :password, :password_confirmation)
  end

  def update_user_params
    # :role bị loại khỏi permit (mass assignment) vì là thuộc tính nâng quyền —
    # nó được gán tường minh và authorize! lại trong #update.
    permitted = [:display_name, :unit_id]
    permitted += [:password, :password_confirmation] if params[:user][:password].present?
    attrs = params.require(:user).permit(*permitted)

    # T93: khi admin/technician reset password cho user khác,
    # set force_password_change để user phải đổi mật khẩu lần đăng nhập sau.
    if params[:user][:password].present? && @user != current_user
      attrs[:force_password_change] = true
    end

    attrs
  end
end
