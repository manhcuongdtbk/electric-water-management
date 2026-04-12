class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  protected

  def require_write_access!
    return if current_user.admin_level1? || current_user.admin_unit?

    redirect_to root_path, alert: t("flash.unauthorized")
  end
end
