module PeriodGuard
  extend ActiveSupport::Concern

  private

  def require_open_period
    return if Period.open.exists?
    message = I18n.t("services.period_service.errors.no_open_period")

    respond_to do |format|
      format.html do
        flash[:alert] = message
        redirect_back(fallback_location: "/", allow_other_host: false)
      end
      format.json { render json: { error: message }, status: :unprocessable_content }
    end
  end
end
