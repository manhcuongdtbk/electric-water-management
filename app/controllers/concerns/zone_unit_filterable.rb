# Concern dùng chung cho các controller cần lọc theo khu vực và đơn vị.
#
# Hành vi:
#   - Chọn khu vực → dropdown đơn vị chỉ hiện đơn vị thuộc khu vực đó.
#   - Chọn đơn vị mà chưa chọn khu vực → tự chọn khu vực của đơn vị.
#   - Đổi khu vực → reset đơn vị (xử lý bên client bằng reset-child-select Stimulus controller).
#   - Đổi đơn vị sang "Tất cả" → giữ khu vực.
#   - Kỳ cũ mở lại → tự dùng with_discarded để hiện zone/unit đã xóa.
#
# Sử dụng nhanh:
#   scope = apply_sa_zone_unit_filter(scope)  # zone+unit cascade
#   scope = apply_sa_zone_filter(scope)       # zone-only
module ZoneUnitFilterable
  extend ActiveSupport::Concern

  private

  # Scope tự động: .kept khi kỳ bình thường, .with_discarded khi kỳ cũ mở lại.
  def zone_filter_scope
    respond_to?(:reopened_old_period?, true) && reopened_old_period? ? Zone.with_discarded : Zone.kept
  end

  def unit_filter_scope
    respond_to?(:reopened_old_period?, true) && reopened_old_period? ? Unit.with_discarded : Unit.kept
  end

  # Resolve zone và unit từ params.
  # Nếu unit được chọn mà zone chưa chọn → tự set zone = unit.zone.
  def resolve_zone_unit_filter(zone_scope: zone_filter_scope, unit_scope: unit_filter_scope)
    zone = params[:zone_id].present? ? zone_scope.find_by(id: params[:zone_id]) : nil
    unit = params[:unit_id].present? ? unit_scope.find_by(id: params[:unit_id]) : nil
    zone ||= unit&.zone if unit
    [zone, unit]
  end

  # SA-only: resolve zone/unit, compute available dropdowns, filter scope.
  # Non-SA: trả scope không đổi.
  #
  # Dùng cho scope có cột unit_id (groups, blocks, users).
  # Contact_points override vì zone filter phức tạp hơn.
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

  # SA-only: resolve zone, compute available zones, filter scope.
  # Non-SA: trả scope không đổi.
  #
  # Dùng cho scope có cột zone_id trực tiếp (units, pump_allocations).
  def apply_sa_zone_filter(scope, zone_id_column: :zone_id)
    return scope unless current_user.system_admin?

    zs = zone_filter_scope
    @zone = params[:zone_id].present? ? zs.find_by(id: params[:zone_id]) : nil
    @available_zones = available_zones_for_filter(
      zone_scope: zs,
      zone_ids: scope.unscope(:order).distinct.pluck(zone_id_column).compact
    )
    scope = scope.where(zone_id_column => @zone.id) if @zone
    scope
  end

  # SA-only: resolve zone/unit, compute available dropdowns, filter scope.
  # Non-SA: trả scope không đổi.
  #
  # Dùng cho scope joining contact_points mà contact_points có thể thuộc zone
  # trực tiếp (zone_id) hoặc gián tiếp qua unit (units.zone_id).
  # Zone filter dùng OR: contact_points.zone_id = :zid OR units.zone_id = :zid.
  #
  # Scope phải có sẵn join tới units và zones (LEFT JOIN) để SQL hoạt động.
  def apply_sa_zone_unit_filter_with_direct_zone(scope, zone_scope: zone_filter_scope, unit_scope: unit_filter_scope)
    return scope unless current_user.system_admin?

    @zone, @unit = resolve_zone_unit_filter(zone_scope: zone_scope, unit_scope: unit_scope)

    base = scope.unscope(:order)
    direct_zone_ids = base.where.not("contact_points.zone_id": nil)
                          .distinct.pluck("contact_points.zone_id")
    unit_ids = base.where.not("contact_points.unit_id": nil)
                   .distinct.pluck("contact_points.unit_id")
    unit_zone_ids = unit_ids.any? ? Unit.where(id: unit_ids).distinct.pluck(:zone_id) : []

    @available_zones = available_zones_for_filter(zone_scope: zone_scope,
                                                  zone_ids: (direct_zone_ids + unit_zone_ids).uniq)
    @available_units = available_units_for_filter(@zone, unit_scope: unit_scope, unit_ids: unit_ids)

    if @zone
      scope = scope.where(
        "contact_points.zone_id = :zone_id OR units.zone_id = :zone_id",
        zone_id: @zone.id
      )
    end
    scope = scope.where("contact_points.unit_id": @unit.id) if @unit
    scope
  end

  # Non-SA: resolve zone/unit dựa trên đơn vị và vai trò của current_user.
  # UA-ZM/CMD-ZM → [zone, nil] (thấy toàn khu vực, không filter đơn vị).
  # UA/CMD → [zone, unit] (chỉ thấy đơn vị mình).
  def resolve_current_user_zone_unit
    return [nil, nil] unless current_user&.unit_id
    unit = current_user.unit
    zone = unit&.zone
    if current_zone_manager?
      [zone, nil]
    else
      [zone, unit]
    end
  end

  # SA-only: derive available zones/units từ một data scope bất kỳ.
  # Dùng cho trang xem data lịch sử (billing) hoặc trang không dùng apply_sa_zone_filter.
  #
  # data_scope: scope chứa data cần derive (vd: Billing::Query.base_scope)
  # zone_id_sql: SQL expression cho zone_id (mặc định "zone_id")
  # unit_id_sql: SQL expression cho unit_id (mặc định "unit_id")
  def set_sa_available_filters_from(data_scope, zone_id_sql: "zone_id", unit_id_sql: "unit_id")
    return unless current_user.system_admin?

    zone_ids = data_scope.unscope(:order).pluck(Arel.sql(zone_id_sql)).compact.uniq
    @available_zones = available_zones_for_filter(zone_ids: zone_ids)

    unit_ids = data_scope.unscope(:order).pluck(Arel.sql(unit_id_sql)).compact.uniq
    @available_units = available_units_for_filter(@zone, unit_ids: unit_ids)
  end

  # Danh sách khu vực cho dropdown filter.
  # zone_ids suy từ dữ liệu (vd dòng billing): kỳ CHƯA tính → rỗng. Khu vực đang
  # chọn phải LUÔN nằm trong danh sách, nếu không dropdown rớt về "Tất cả" dù URL
  # có zone_id (bug filter billing kỳ rỗng). Nhét @zone&.id vào trước khi where.
  def available_zones_for_filter(zone_scope: zone_filter_scope, zone_ids: nil)
    scope = zone_scope.order(:name)
    scope = scope.where(id: (zone_ids + [@zone&.id]).compact.uniq) if zone_ids
    scope
  end

  # Danh sách đơn vị cho dropdown filter. Tương tự khu vực: đơn vị đang chọn phải
  # luôn có trong danh sách kể cả khi unit_ids (suy từ dữ liệu) rỗng.
  def available_units_for_filter(zone, unit_scope: unit_filter_scope, unit_ids: nil)
    scope = unit_scope.order(:name)
    scope = scope.where(zone_id: zone.id) if zone
    scope = scope.where(id: (unit_ids + [@unit&.id]).compact.uniq) if unit_ids
    scope
  end
end
