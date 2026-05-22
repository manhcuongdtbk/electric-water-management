# Concern dùng chung cho các controller cần lọc theo khu vực và đơn vị.
#
# Hành vi:
#   - Chọn khu vực → dropdown đơn vị chỉ hiện đơn vị thuộc khu vực đó.
#   - Chọn đơn vị mà chưa chọn khu vực → tự chọn khu vực của đơn vị.
#   - Đổi khu vực → reset đơn vị (xử lý bên client bằng reset-child-select Stimulus controller).
#   - Đổi đơn vị sang "Tất cả" → giữ khu vực.
#
# Sử dụng:
#   include ZoneUnitFilterable
#
#   # Trong action index:
#   @zone, @unit = resolve_zone_unit_filter
#   # hoặc với scope tùy chỉnh (vd billing cần with_discarded):
#   @zone, @unit = resolve_zone_unit_filter(zone_scope: Zone.with_discarded, unit_scope: Unit.with_discarded)
#
#   @available_zones = available_zones_for_filter(zone_scope: Zone.kept)
#   @available_units = available_units_for_filter(@zone, unit_scope: Unit.kept)
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
