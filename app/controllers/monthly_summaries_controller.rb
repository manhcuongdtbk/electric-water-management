# frozen_string_literal: true

# F11 — Bảng tổng hợp theo tháng (bảng 22 cột)
# Hiển thị kết quả tính toán từ CalculationEngine cho một đơn vị và một kỳ tháng.
# Nếu chưa có dữ liệu → tự động chạy engine. Nút "Tính lại" cho admin.
class MonthlySummariesController < ApplicationController
  before_action :set_period
  before_action :set_target_org

  def show
    authorize! :read, MonthlyCalculation
    load_or_calculate if @period && @target_org

    respond_to do |format|
      format.html
      format.csv do
        return head(:not_found) unless @calculations&.any?

        send_data monthly_summary_csv,
                  type: "text/csv; charset=utf-8",
                  filename: "bao_cao_tong_hop_#{@period.month}_#{@period.year}.csv"
      end
    end
  end

  def recalculate
    authorize! :recalculate, MonthlyCalculation

    if @period.nil?
      return redirect_to monthly_summary_path, alert: t("monthly_summary.no_period")
    end

    if @target_org.nil?
      return redirect_to monthly_summary_path, alert: t("monthly_summary.no_org")
    end

    begin
      CalculationEngine.new(organization: @target_org, monthly_period: @period).call
    rescue => e
      return redirect_to monthly_summary_path(period_id: @period.id, org_id: effective_org_id),
                         alert: t("flash.monthly_summary.recalculate_failed", error: e.message)
    end

    redirect_to monthly_summary_path(period_id: @period.id, org_id: effective_org_id),
                notice: t("flash.monthly_summary.recalculated")
  end

  private

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = if params[:org_id].present?
        @all_orgs.find_by(id: params[:org_id])
      else
        @all_orgs.first
      end
    else
      @target_org = current_user.organization
    end
  end

  def effective_org_id
    current_user.admin_level1? ? @target_org&.id : nil
  end

  def load_or_calculate
    @calculations = fetch_calculations

    if @calculations.empty?
      begin
        CalculationEngine.new(organization: @target_org, monthly_period: @period).call
        @calculations = fetch_calculations
      rescue => e
        @calculation_error = e.message
      end
    end

    @totals = build_totals(@calculations) if @calculations.any?
  end

  def fetch_calculations
    MonthlyCalculation
      .by_organization(@target_org.id)
      .for_period(@period.id)
      .ordered
      .includes(:contact_point)
  end

  def build_totals(calculations)
    kw_cols = %i[
      rank1_kw rank2_kw rank3_kw rank4_kw rank5_kw rank6_kw rank7_kw
      water_pump_standard_kw total_standard_kw
      savings_deduction_kw loss_deduction_kw division_public_deduction_kw
      unit_public_deduction_kw other_deduction_kw total_deduction_kw
      remaining_standard_kw meter_usage_kw water_pump_actual_kw total_usage_kw
      over_under_kw total_amount
    ]
    totals = { total_personnel: calculations.sum(&:total_personnel) }
    kw_cols.each { |col| totals[col] = calculations.sum { |c| c.public_send(col) } }
    totals[:living_standard_kw] = MonthlyCalculation::RANK_KW_COLUMNS.sum { |col| totals[col] }
    totals
  end

  CSV_DATA_COLS = %i[
    total_personnel living_standard_kw water_pump_standard_kw total_standard_kw
    savings_deduction_kw loss_deduction_kw division_public_deduction_kw
    unit_public_deduction_kw other_deduction_kw total_deduction_kw
    remaining_standard_kw meter_usage_kw water_pump_actual_kw total_usage_kw
    over_under_kw total_amount
  ].freeze

  def monthly_summary_csv
    rank_headers = (1..7).map { |i| helpers.history_column_label(:"rank#{i}_kw") }
    non_rank_headers = CSV_DATA_COLS.map { |col| t("monthly_summary.columns.#{col}") }
    headers = [
      t("monthly_summary.columns.stt"),
      t("monthly_summary.columns.contact_point"),
      *rank_headers,
      *non_rank_headers
    ]

    bom = +"\xEF\xBB\xBF"
    bom + CSV.generate(encoding: "UTF-8") do |csv|
      csv << headers

      @calculations.each_with_index do |calc, idx|
        rank_values = (1..7).map { |i| calc.public_send(:"rank#{i}_kw").to_f }
        non_rank_values = [
          calc.total_personnel,
          calc.rank_standard_total_kw.to_f,
          calc.water_pump_standard_kw.to_f,
          calc.total_standard_kw.to_f,
          calc.savings_deduction_kw.to_f,
          calc.loss_deduction_kw.to_f,
          calc.division_public_deduction_kw.to_f,
          calc.unit_public_deduction_kw.to_f,
          calc.other_deduction_kw.to_f,
          calc.total_deduction_kw.to_f,
          calc.remaining_standard_kw.to_f,
          calc.meter_usage_kw.to_f,
          calc.water_pump_actual_kw.to_f,
          calc.total_usage_kw.to_f,
          calc.over_under_kw.to_f,
          calc.total_amount.to_f
        ]
        csv << [ idx + 1, calc.contact_point.name, *rank_values, *non_rank_values ]
      end

      if @totals
        totals_rank = (1..7).map { |i| @totals[:"rank#{i}_kw"].to_f }
        totals_non_rank = [
          @totals[:total_personnel],
          @totals[:living_standard_kw].to_f,
          @totals[:water_pump_standard_kw].to_f,
          @totals[:total_standard_kw].to_f,
          @totals[:savings_deduction_kw].to_f,
          @totals[:loss_deduction_kw].to_f,
          @totals[:division_public_deduction_kw].to_f,
          @totals[:unit_public_deduction_kw].to_f,
          @totals[:other_deduction_kw].to_f,
          @totals[:total_deduction_kw].to_f,
          @totals[:remaining_standard_kw].to_f,
          @totals[:meter_usage_kw].to_f,
          @totals[:water_pump_actual_kw].to_f,
          @totals[:total_usage_kw].to_f,
          @totals[:over_under_kw].to_f,
          @totals[:total_amount].to_f
        ]
        csv << [ t("monthly_summary.total_row"), "", *totals_rank, *totals_non_rank ]
      end
    end
  end
end
