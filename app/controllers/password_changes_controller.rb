class PasswordChangesController < ApplicationController
  skip_before_action :restrict_tech_to_user_management!

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    attrs = password_change_params

    if @user.update(
      password: attrs[:password],
      password_confirmation: attrs[:password_confirmation],
      force_password_change: false
    )
      # Changing password invalidates the session (Devise rotates authenticatable_salt).
      # bypass_sign_in refreshes the session so the user stays logged in.
      bypass_sign_in(@user)
      redirect_to root_path, notice: t("flash.password_changes.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_change_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
