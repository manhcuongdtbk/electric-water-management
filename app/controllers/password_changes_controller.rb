class PasswordChangesController < ApplicationController
  skip_before_action :enforce_password_change

  def edit
  end

  def update
    if current_user.update(password_params.merge(force_password_change: false))
      bypass_sign_in(current_user)
      redirect_to root_path, notice: I18n.t("flash.password_changed")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
