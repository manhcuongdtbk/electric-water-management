class UnitConfigController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include BusinessRoleRequired
  include ZoneUnitFilterable

  before_action :require_open_period, only: [:update]

  def show
    @period = current_period
    if current_user.system_admin?
      @zone, @unit = resolve_zone_unit_filter
      @unit ||= @zone ? nil : load_unit_fallback
      set_sa_filter_dropdowns
    else
      @unit = current_user.unit
    end
    @unit_config = find_or_create_unit_config
    @other_deductions = scope_other_deductions
    @zone_other_deductions = scope_zone_other_deductions
  end

  def update
    @unit = resolve_unit_for_update
    @period = current_period
    @unit_config = find_or_create_unit_config
    if @unit_config
      authorize!(:update, @unit_config)
    else
      authorize!(:update, UnitConfig.new(unit: @unit, period: @period))
    end

    errors_collected = []
    ActiveRecord::Base.transaction do
      if @unit_config && params[:unit_config].present?
        attrs = params.require(:unit_config).permit(:unit_public_rate, :lock_version)
        unless @unit_config.update(attrs)
          errors_collected << { name: "Cấu hình đơn vị", msgs: @unit_config.errors.full_messages }
        end
      end

      all_editable_ods = scope_other_deductions.or(scope_zone_other_deductions)
      (params[:other_deductions] || {}).each do |id, attrs|
        od = all_editable_ods.find_by(id: id)
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
      @zone_other_deductions = scope_zone_other_deductions
      # View show.html.erb đọc @available_zones/@available_units vô điều kiện cho SA → phải set lại khi re-render.
      @zone = @unit&.zone if current_user.system_admin?
      set_sa_filter_dropdowns
      render :show, status: :unprocessable_content
    else
      redirect_to unit_config_path(unit_id: @unit&.id), notice: t("unit_config.flash.saved")
    end
  end

  private

  # SA-only: danh sách khu vực/đơn vị cho dropdown filter ở show.html.erb.
  # Dùng chung giữa #show và nhánh re-render lỗi của #update.
  def set_sa_filter_dropdowns
    return unless current_user.system_admin?
    @available_zones = available_zones_for_filter
    us = unit_filter_scope
    us = us.where(id: UnitConfig.where(period: @period).pluck(:unit_id)) if reopened_old_period?
    @available_units = available_units_for_filter(@zone, unit_scope: us)
  end

  # Safety net cho data cũ: units tạo trước khi có after_create callback (PR #156)
  # có thể thiếu UnitConfig. Lazy create với default 0% khi truy cập trang.
  def find_or_create_unit_config
    return nil unless @period && @unit
    UnitConfig.find_or_create_by!(unit: @unit, period: @period)
  end

  def load_unit_fallback
    current_user.unit
  end

  def resolve_unit_for_update
    if current_user.system_admin? && params[:unit_id].present?
      scope = reopened_old_period? ? Unit.with_discarded : Unit.kept
      scope.find(params[:unit_id])
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

  def scope_zone_other_deductions
    return OtherDeduction.none unless @period
    zone_ids = zone_other_deduction_zone_ids
    return OtherDeduction.none if zone_ids.empty?
    OtherDeduction.joins(:contact_point).includes(:contact_point)
                  .where(period: @period,
                         contact_points: { zone_id: zone_ids,
                                           unit_id: nil,
                                           contact_point_type: "residential" })
                  .accessible_by(current_ability)
                  .order("contact_points.name")
  end

  # Nguồn zone_ids cho khoản trừ "Khác" của đầu mối zone-direct:
  # - @unit có → các khu vực do đơn vị này quản lý (đường manager-unit, gồm non-SA).
  # - @unit nil & @zone có & SA → đúng khu vực đang chọn (ngữ cảnh khu vực, ADR-034).
  def zone_other_deduction_zone_ids
    if @unit
      Zone.kept.where(manager_unit_id: @unit.id).pluck(:id)
    elsif @zone && current_user.system_admin?
      [@zone.id]
    else
      []
    end
  end
end
