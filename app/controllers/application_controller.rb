class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :check_force_password_change!
  before_action :restrict_tech_to_user_management!

  protected

  def after_sign_in_path_for(resource)
    if resource.force_password_change?
      edit_password_change_path
    elsif resource.tech?
      users_path
    else
      stored_location_for(resource) || root_path
    end
  end

  def check_force_password_change!
    return unless current_user&.force_password_change?
    return if controller_name == "password_changes"

    redirect_to edit_password_change_path, alert: t("flash.password_changes.required")
  end

  def require_write_access!
    return if current_user.admin_level1? || current_user.admin_unit?

    redirect_to root_path, alert: t("flash.unauthorized")
  end

  def restrict_tech_to_user_management!
    return unless current_user&.tech?
    return if controller_name == "users"

    redirect_to users_path, alert: t("flash.unauthorized")
  end
end
