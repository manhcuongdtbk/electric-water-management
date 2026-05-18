module PeriodHelper
  def period_label(period)
    return t("flash.no_open_period") unless period
    "Kỳ tháng #{period.month}/#{period.year}"
  end

  def no_open_period?
    current_period.nil?
  end
end
