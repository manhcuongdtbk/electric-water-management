module StructureChangeGuard
  extend ActiveSupport::Concern

  private

  # Chặn thay đổi cấu trúc khi đang mở lại kỳ cũ (v2.3.0).
  # Cho phép khi:
  # - Không có kỳ mở (giai đoạn thiết lập ban đầu hoặc giữa các tháng)
  # - Có kỳ mở VÀ kỳ đó là kỳ mới nhất (theo year/month)
  def require_latest_period_when_open
    open_period = Period.open.first
    return if open_period.nil?
    latest_period = Period.order(year: :desc, month: :desc).first
    return if open_period.id == latest_period.id

    message = I18n.t("services.period_service.errors.structure_change_blocked_old_period")

    respond_to do |format|
      format.html do
        flash[:alert] = message
        redirect_back(fallback_location: "/", allow_other_host: false)
      end
      format.json { render json: { error: message }, status: :unprocessable_content }
    end
  end
end
