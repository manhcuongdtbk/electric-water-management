class UnitConfigController < ApplicationController
  include PeriodGuard
  include AuthorizeResource

  before_action :require_open_period, only: [:update]

  def show
    @unit = load_unit
    @period = current_period
    @unit_config = @period && @unit ? UnitConfig.find_by(unit: @unit, period: @period) : nil
    @other_deductions = scope_other_deductions
  end

  def update
    @unit = load_unit
    @period = current_period
    @unit_config = UnitConfig.find_by(unit: @unit, period: @period)
    authorize!(:update, @unit_config) if @unit_config

    errors_collected = []
    ActiveRecord::Base.transaction do
      if @unit_config && params[:unit_config].present?
        attrs = params.require(:unit_config).permit(:unit_public_rate, :lock_version)
        unless @unit_config.update(attrs)
          errors_collected << { name: "Cấu hình đơn vị", msgs: @unit_config.errors.full_messages }
        end
      end

      (params[:other_deductions] || {}).each do |id, attrs|
        od = scope_other_deductions.find_by(id: id)
        next unless od
        authorize!(:update, od)
        permitted = attrs.permit(:other_type, :other_value, :lock_version)
        unless od.update(permitted)
          errors_collected << { name: od.contact_point.name, msgs: od.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors_collected.any?
    end

    if errors_collected.any?
      flash.now[:alert] = errors_collected.map { |e| "#{e[:name]}: #{e[:msgs].join(', ')}" }.join("\n")
      @unit_config = UnitConfig.find_by(unit: @unit, period: @period)
      @other_deductions = scope_other_deductions
      render :show, status: :unprocessable_entity
    else
      redirect_to unit_config_path(unit_id: @unit&.id), notice: "Đã lưu cấu hình đơn vị."
    end
  end

  private

  def load_unit
    if current_user.system_admin? && params[:unit_id].present?
      Unit.kept.accessible_by(current_ability).find(params[:unit_id])
    else
      current_user.unit
    end
  end

  def scope_other_deductions
    return OtherDeduction.none unless @period && @unit
    OtherDeduction.joins(:contact_point).includes(:contact_point)
                  .where(period: @period,
                         contact_points: { unit_id: @unit.id,
                                           contact_point_type: "residential" })
                  .accessible_by(current_ability)
                  .order("contact_points.name")
  end
end
