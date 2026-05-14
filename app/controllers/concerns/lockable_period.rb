module LockablePeriod
  extend ActiveSupport::Concern

  private

  def block_write_if_period_locked
    return unless @period&.locked?

    redirect_back_or_to root_path, alert: t("flash.period_locked")
  end

  def block_write_if_latest_period_locked
    latest = MonthlyPeriod.ordered.first
    return unless latest&.locked?

    redirect_back_or_to root_path, alert: t("flash.period_locked")
  end
end
