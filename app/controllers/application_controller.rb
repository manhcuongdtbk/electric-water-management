class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :restrict_tech_to_user_management!

  protected

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
