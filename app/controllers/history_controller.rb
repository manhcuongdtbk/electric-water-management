# frozen_string_literal: true

class HistoryController < ApplicationController
  DETAIL_COLUMNS = %i[
    total_personnel
    rank1_kw rank2_kw rank3_kw rank4_kw rank5_kw rank6_kw rank7_kw
    water_pump_standard_kw water_pump_actual_kw
    total_standard_kw total_usage_kw
    total_deduction_kw savings_deduction_kw loss_deduction_kw
    division_public_deduction_kw unit_public_deduction_kw other_deduction_kw
    meter_usage_kw over_under_kw unit_price total_amount
  ].freeze

  # Columns where a lower value is better (decrease = improvement)
  # over_under_kw = usage - remaining_standard: positive means over quota (deficit), negative means under (surplus)
  LOWER_IS_BETTER_COLUMNS = %i[
    total_usage_kw total_deduction_kw savings_deduction_kw loss_deduction_kw
    division_public_deduction_kw unit_public_deduction_kw other_deduction_kw
    meter_usage_kw total_amount
  ].freeze

  before_action :check_access
  before_action :set_orgs_for_admin
  before_action :set_contact_points
  before_action :set_year_month

  def show
    if @contact_point.nil? || @period.nil?
      respond_to do |f|
        f.html
        f.csv { head :not_found }
      end
      return
    end

    @current_calc = MonthlyCalculation
      .for_period(@period.id)
      .for_contact_point(@contact_point.id)
      .first

    prior_period = MonthlyPeriod.find_by(year: @selected_year - 1, month: @selected_month)
    @prior_calc = prior_period &&
      MonthlyCalculation.for_period(prior_period.id).for_contact_point(@contact_point.id).first

    respond_to do |format|
      format.html
      format.csv do
        return head(:not_found) unless @current_calc

        send_data history_csv,
                  type: "text/csv; charset=utf-8",
                  filename: "bao_cao_lich_su_#{@selected_month}_#{@selected_year}.csv"
      end
    end
  end

  private

  def check_access
    return redirect_to(users_path, alert: t("flash.access_denied")) if current_user.tech?

    authorize! :read, MonthlyCalculation
  end

  def set_orgs_for_admin
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = @all_orgs.find_by(id: params[:org_id]) || @all_orgs.first
      @selected_org_id = @target_org&.id
    else
      @target_org = current_user.organization
    end
  end

  def set_contact_points
    return unless @target_org

    @contact_points = ContactPoint.by_organization(@target_org.id).ordered
    @contact_point = @contact_points.find_by(id: params[:contact_point_id]) || @contact_points.first
  end

  def set_year_month
    @available_years = MonthlyPeriod.order(year: :desc).distinct.pluck(:year)
    @selected_year   = params[:year].presence&.to_i || @available_years.first
    @selected_month  = params[:month].presence&.to_i || Time.current.month
    @period          = MonthlyPeriod.find_by(year: @selected_year, month: @selected_month)
  end

  def history_csv
    current_period_label = "#{@selected_year}/#{@selected_month.to_s.rjust(2, '0')}"
    prior_period_label   = "#{@selected_year - 1}/#{@selected_month.to_s.rjust(2, '0')}"

    headers = [
      t("history.comparison_table.field"),
      t("history.comparison_table.current", period: current_period_label),
      t("history.comparison_table.prior",   period: prior_period_label),
      t("history.comparison_table.delta")
    ]

    bom = +"\xEF\xBB\xBF"
    bom + CSV.generate(encoding: "UTF-8") do |csv|
      csv << headers

      DETAIL_COLUMNS.each do |col|
        label       = helpers.history_column_label(col)
        current_val = @current_calc.public_send(col)
        prior_val   = @prior_calc&.public_send(col)

        delta = if prior_val.nil?
          ""
        else
          diff = current_val.to_d - prior_val.to_d
          if diff.zero? then "="
          elsif diff > 0 then "▲"
          else "▼"
          end
        end

        csv << [ label, current_val, prior_val || "", delta ]
      end
    end
  end
end
