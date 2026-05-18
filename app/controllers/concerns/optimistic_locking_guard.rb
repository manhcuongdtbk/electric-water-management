module OptimisticLockingGuard
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::StaleObjectError, with: :handle_stale_object
  end

  private

  def handle_stale_object(_exception)
    flash[:alert] = I18n.t("errors.stale_object")
    redirect_back(fallback_location: root_path, allow_other_host: false)
  end
end
