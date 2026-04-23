class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit
  before_action :check_force_password_change!

  rescue_from CanCan::AccessDenied do |_exception|
    if current_user&.tech?
      # Tech users work in /users; silently bounce them back instead of showing
      # a scary "không có quyền" flash when they hit a business URL.
      redirect_to users_path
    else
      redirect_to root_path, alert: t("flash.access_denied")
    end
  end

  helper_method :session_expires_at

  protected

  def user_for_paper_trail
    current_user&.id
  end

  def session_expires_at
    return nil unless user_signed_in?

    last_request = warden.session(:user)["last_request_at"]
    return nil unless last_request

    Time.at(last_request).utc + Devise.timeout_in
  end

  def after_sign_in_path_for(resource)
    post_sign_in_destination_for(resource)
  end

  def post_sign_in_destination_for(user)
    if user.force_password_change?
      edit_password_change_path
    elsif user.tech?
      users_path
    else
      stored_location_for(user) || root_path
    end
  end

  def check_force_password_change!
    return unless current_user&.force_password_change?
    return if controller_name == "password_changes"

    redirect_to edit_password_change_path, alert: t("flash.password_changes.required")
  end
end
