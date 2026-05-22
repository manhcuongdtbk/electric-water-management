# Concern dùng chung cho các controller cần lọc theo khu vực và đơn vị.
#
# Hành vi:
#   - Chọn khu vực → dropdown đơn vị chỉ hiện đơn vị thuộc khu vực đó.
#   - Chọn đơn vị mà chưa chọn khu vực → tự chọn khu vực của đơn vị.
#   - Đổi khu vực → reset đơn vị (xử lý bên client bằng reset-child-select Stimulus controller).
#   - Đổi đơn vị sang "Tất cả" → giữ khu vực.
#
# Sử dụng cơ bản (resolve + available):
#   include ZoneUnitFilterable
#   @zone, @unit = resolve_zone_unit_filter
#   @available_zones = available_zones_for_filter(zone_ids: [...])
#   @available_units = available_units_for_filter(@zone, unit_ids: [...])
#
# Sử dụng nhanh (SA-only filter cho scope có unit_id):
#   scope = apply_sa_zone_unit_filter(scope)
#   # Tự set @zone, @unit, @available_zones, @available_units nếu SA.
#   # Non-SA: trả scope không đổi.
module ZoneUnitFilterable
  extend ActiveSupport::Concern

  private

  # Resolve zone và unit từ params.
  # Nếu unit được chọn mà zone chưa chọn → tự set zone = unit.zone.
  def resolve_zone_unit_filter(zone_scope: Zone.kept, unit_scope: Unit.kept)
    zone = params[:zone_id].present? ? zone_scope.find_by(id: params[:zone_id]) : nil
    unit = params[:unit_id].present? ? unit_scope.find_by(id: params[:unit_id]) : nil
    zone ||= unit&.zone if unit
    [zone, unit]
  end

  # SA-only: resolve zone/unit, compute available dropdowns, filter scope.
  # Non-SA: trả scope không đổi.
  #
  # Dùng cho scope có cột unit_id (groups, blocks, users, pump_allocations, units).
  # Contact_points override vì zone filter phức tạp hơn (zone_id trực tiếp + qua unit).
  #
  # Options:
  #   zone_column: SQL expression cho zone filter (mặc định "units.zone_id")
  #   unit_id_column: cột unit_id trên bảng chính (mặc định :unit_id)
  def apply_sa_zone_unit_filter(scope, zone_column: "units.zone_id", unit_id_column: :unit_id)
    return scope unless current_user.system_admin?

    @zone, @unit = resolve_zone_unit_filter
    all_unit_ids = scope.unscope(:order).where.not(unit_id_column => nil).distinct.pluck(unit_id_column)
    all_zone_ids = Unit.where(id: all_unit_ids).distinct.pluck(:zone_id)
    @available_zones = available_zones_for_filter(zone_ids: all_zone_ids)
    @available_units = available_units_for_filter(@zone, unit_ids: all_unit_ids)
    scope = scope.where(zone_column => @zone.id) if @zone
    scope = scope.where(unit_id_column => @unit.id) if @unit
    scope
  end

  # Danh sách khu vực cho dropdown filter.
  # Có thể giới hạn bằng zone_ids (chỉ khu vực có data trong scope).
  def available_zones_for_filter(zone_scope: Zone.kept, zone_ids: nil)
    scope = zone_scope.order(:name)
    scope = scope.where(id: zone_ids) if zone_ids
    scope
  end

  # Danh sách đơn vị cho dropdown filter.
  # Nếu zone được chọn → chỉ hiện đơn vị thuộc zone đó.
  # Có thể giới hạn bằng unit_ids (chỉ đơn vị có data trong scope).
  def available_units_for_filter(zone, unit_scope: Unit.kept, unit_ids: nil)
    scope = unit_scope.order(:name)
    scope = scope.where(zone_id: zone.id) if zone
    scope = scope.where(id: unit_ids) if unit_ids
    scope
  end
end
