class Users::SessionsController < Devise::SessionsController
  protected

  def after_sign_in_path_for(resource)
    period = Period.current
    if period.present?
      existing = flash[:notice]
      message = I18n.t("flash.period_now_open", month: period.month, year: period.year)
      flash[:notice] = [existing, message].compact.join(" ")
    end
    super
  end
end
