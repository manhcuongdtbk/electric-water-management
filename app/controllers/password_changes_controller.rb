class PasswordChangesController < ApplicationController
  skip_before_action :enforce_password_change

  def edit
    @force_change = current_user.force_password_change?
  end

  def update
    @force_change = current_user.force_password_change?

    if !@force_change && !valid_current_password?
      current_user.errors.add(:current_password, I18n.t("password_changes.errors.current_password_invalid"))
      render :edit, status: :unprocessable_content and return
    end

    if current_user.update(password_params.merge(force_password_change: false))
      bypass_sign_in(current_user)
      redirect_to root_path, notice: I18n.t("flash.password_changed")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def valid_current_password?
    current_password = params.dig(:user, :current_password).to_s
    return false if current_password.blank?
    current_user.valid_password?(current_password)
  end
end
