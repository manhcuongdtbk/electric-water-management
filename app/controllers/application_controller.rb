class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  include OptimisticLockingGuard
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit
  before_action :enforce_password_change

  rescue_from CanCan::AccessDenied do |_exception|
    flash[:alert] = I18n.t("errors.access_denied")
    redirect_to(user_signed_in? ? root_path : new_user_session_path)
  end

  helper_method :current_zone_manager?, :current_period

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  protected

  def current_period
    @current_period ||= Period.current
  end

  def current_zone_manager?
    return false unless current_user&.unit_id
    Zone.exists?(manager_unit_id: current_user.unit_id)
  end

  private

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = current_user&.id
  end

  def enforce_password_change
    return unless user_signed_in?
    return unless current_user.force_password_change?
    return if devise_controller?
    return if controller_name == "password_changes"
    redirect_to edit_password_change_path
  end
end
