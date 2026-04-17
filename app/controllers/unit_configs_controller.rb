class UnitConfigsController < ApplicationController
  before_action :set_period
  before_action :set_division
  before_action :set_configs

  def show
    authorize! :read, UnitConfig
  end

  def update
    case params[:section]
    when "division"
      authorize! :update, UnitConfig
      update_division_config
    when "unit"
      authorize! :update_unit_config, UnitConfig
      update_unit_config
    else
      redirect_to unit_config_path, alert: t("flash.unauthorized")
    end
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

  def set_division
    @division = Organization.divisions.first
    redirect_to root_path, alert: t("flash.unauthorized") unless @division
  end

  def set_configs
    return unless @period

    @division_config = UnitConfig.find_or_initialize_by(
      organization: @division,
      monthly_period: @period
    )

    if current_user.admin_unit? || current_user.commander?
      @unit_config = UnitConfig.find_or_initialize_by(
        organization: current_user.organization,
        monthly_period: @period
      )
      load_contact_point_deductions
    elsif current_user.admin_level1?
      # Load all unit configs for overview table — one query, no N+1
      unit_orgs = Organization.units.ordered
      existing = UnitConfig.where(organization: unit_orgs, monthly_period: @period)
                           .index_by(&:organization_id)
      @all_unit_configs = unit_orgs.map do |org|
        cfg = existing[org.id] || UnitConfig.new(organization: org, monthly_period: @period)
        [ org, cfg ]
      end
    end
  end

  def load_contact_point_deductions
    @contact_points = current_user.organization.contact_points.ordered

    # Personnel totals keyed by contact_point_id for the selected period
    @personnel_counts = Personnel.where(
      contact_point_id: @contact_points.map(&:id),
      monthly_period: @period
    ).index_by(&:contact_point_id).transform_values(&:total_count)

    # Existing deduction records keyed by contact_point_id
    @deductions = ContactPointOtherDeduction.where(
      contact_point_id: @contact_points.map(&:id),
      monthly_period: @period
    ).index_by(&:contact_point_id)
  end

  def update_division_config
    if @division_config.update(division_config_params)
      redirect_to unit_config_path(period_id: @period&.id),
                  notice: t("flash.unit_configs.division_updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_unit_config
    UnitConfig.transaction do
      @unit_config.assign_attributes(unit_config_params)
      @unit_config.save!
      upsert_contact_point_deductions
    end

    redirect_to unit_config_path(period_id: @period&.id),
                notice: t("flash.unit_configs.unit_updated")
  rescue ActiveRecord::RecordInvalid => e
    @errors = e.record.errors.full_messages
    load_contact_point_deductions
    render :show, status: :unprocessable_entity
  end

  def upsert_contact_point_deductions
    return unless params[:khac].present?

    allowed_cp_ids = current_user.organization.contact_points.pluck(:id).map(&:to_s)

    params[:khac].each do |cp_id, attrs|
      next unless allowed_cp_ids.include?(cp_id.to_s)

      record = ContactPointOtherDeduction.find_or_initialize_by(
        contact_point_id: cp_id.to_i,
        monthly_period: @period
      )
      record.update!(
        other_type: attrs[:other_type].presence || "fixed_kw",
        other_value: attrs[:other_value].presence || 0
      )
    end
  end

  # Params arrive as percentage (e.g. "5.00") — convert to decimal (0.0500) before save.
  # Convention per CLAUDE.md: DB stores 5.0 meaning 5%; engine divides by 100 in M2.
  # The UI shows/edits in %, so we divide here.
  def division_config_params
    raw = params.require(:division_config).permit(:savings_rate, :division_public_rate)
    {
      savings_rate: percent_to_decimal(raw[:savings_rate]),
      division_public_rate: percent_to_decimal(raw[:division_public_rate])
    }.compact
  end

  def unit_config_params
    raw = params.require(:unit_config).permit(:unit_public_rate)
    { unit_public_rate: percent_to_decimal(raw[:unit_public_rate]) }.compact
  end

  def percent_to_decimal(value)
    return nil if value.blank?

    BigDecimal(value.to_s) / 100
  rescue ArgumentError
    nil
  end
end
