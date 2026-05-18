class UsersController < ApplicationController
  include AuthorizeResource

  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index
    scope = User.accessible_by(current_ability).includes(:unit)
    if (q = params[:q]).present?
      scope = scope.where("users.username ILIKE ? OR users.display_name ILIKE ?",
                          "%#{q.strip}%", "%#{q.strip}%")
    end
    scope = scope.order(:username)
    @total_count = scope.count
    @pagy, @users = pagy(scope)
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
      redirect_to users_path, notice: "Đã tạo tài khoản \"#{@user.username}\"."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(update_user_params)
      redirect_to users_path, notice: "Đã cập nhật tài khoản \"#{@user.username}\"."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: I18n.t("errors.cannot_destroy_self") and return
    end
    if @user.destroy
      redirect_to users_path, notice: "Đã xóa tài khoản \"#{@user.username}\"."
    else
      redirect_to users_path, alert: @user.errors.full_messages.join("\n")
    end
  end

  private

  def set_user
    @user = User.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @user)
  end

  def action_auth_key
    case action_name
    when "show" then :read
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def create_user_params
    params.require(:user).permit(:username, :display_name, :role, :unit_id, :password, :password_confirmation)
  end

  def update_user_params
    permitted = [:display_name, :role, :unit_id]
    # Cho phép đổi password nếu cung cấp
    permitted += [:password, :password_confirmation] if params[:user][:password].present?
    params.require(:user).permit(*permitted)
  end
end
