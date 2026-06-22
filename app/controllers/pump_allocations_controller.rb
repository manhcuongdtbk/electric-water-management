class PumpAllocationsController < ApplicationController
  include PeriodGuard
  include AuthorizeResource
  include ActionAuthKeyable
  include BusinessRoleRequired
  include ZoneUnitFilterable
  include SettingsAccessGuard

  ACTION_AUTH_KEYS = { "edit" => :update, "update" => :update, "destroy" => :destroy }.freeze

  before_action :require_system_admin_or_zone_manager!
  before_action :set_allocation, only: [:edit, :update, :destroy]
  before_action :require_open_period, only: [:create, :update, :destroy]
  before_action :ensure_allocation_belongs_to_open_period, only: [:edit, :update, :destroy]

  def index
    @period = current_period
    # Trang này là view cấu hình NHÓM THEO TRẠM (một thẻ/trạm bơm), không phải
    # danh sách phẳng — cố ý KHÔNG dùng pagy/per_page và KHÔNG dùng sortable
    # header (dữ liệu nhỏ: vài trạm × vài đối tượng; sắp xếp/nhóm do view lo).
    # Đây là divergence có chủ đích so với quy ước "_list_toolbar per_page".
    scope = PumpAllocation.accessible_by(current_ability)
                          .includes(:zone, :unit, :block, :group, :contact_point, :pump_contact_point)
                          .joins(:zone)
                          .left_joins(:unit, :block, :group, :contact_point)
    scope = scope.where(period: @period) if @period
    scope = apply_sa_zone_filter(scope)
    @search_active = params[:q].present?
    scope = apply_pump_allocation_search(scope)
    @pump_allocations = scope.to_a
    @total_count = @pump_allocations.size

    @per_station = @period&.pump_allocation_per_station || false
    @station_groups = build_station_groups(@pump_allocations)
    @station_zone_shares = build_station_zone_shares
  end

  def new
    @pump_allocation = PumpAllocation.new(
      period: current_period,
      coefficient: 1,
      pump_contact_point_id: params[:pump_contact_point_id].presence
    )
    # Khi vào form qua "Thêm đối tượng vào trạm này" (prefill pump_contact_point_id),
    # set luôn zone của trạm đó để form mở ra nhất quán (zone + trạm khớp nhau) và
    # Stimulus refreshZoneScope không disable fieldset vì zone trống. Người dùng vẫn
    # có thể đổi zone sau (cascade tự reset trạm qua data-zone-id).
    if params[:pump_contact_point_id].present?
      station = ContactPoint.find_by(id: params[:pump_contact_point_id])
      @pump_allocation.zone = station.zone if station
    end
    if current_zone_manager?
      @pump_allocation.zone = Zone.kept.find_by(manager_unit_id: current_user.unit_id)
    end
    authorize!(:create, PumpAllocation)
  end

  def create
    @pump_allocation = PumpAllocation.new(allocation_params)
    @pump_allocation.period = current_period
    authorize!(:create, @pump_allocation)
    if @pump_allocation.save
      redirect_to pump_allocations_path,
        notice: t("flash.record_created", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @pump_allocation.update(allocation_params)
      redirect_to pump_allocations_path,
        notice: t("flash.record_updated", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @pump_allocation.destroy
    redirect_to pump_allocations_path,
      notice: t("flash.record_destroyed", resource: t("resources.pump_allocation"), name: @pump_allocation.zone.name)
  end

  private

  def set_allocation
    @pump_allocation = PumpAllocation.accessible_by(current_ability).find(params[:id])
    authorize!(action_auth_key, @pump_allocation)
  end

  # Vi phạm cách ly kỳ: chỉ cho sửa/xóa pump_allocation thuộc kỳ đang mở.
  # User có thể click link cũ trỏ tới allocation kỳ đã đóng → redirect kèm cảnh báo.
  def ensure_allocation_belongs_to_open_period
    return if @pump_allocation.period_id == Period.current&.id
    redirect_to pump_allocations_path,
                alert: I18n.t("pump_allocations.flash.belongs_to_closed_period")
  end

  # Tìm kiếm server-side trên tên đối tượng nhận + tên trạm bơm.
  # Join trạm bơm bằng alias tường minh (pump_station_cp) để không phụ thuộc
  # alias tự sinh của Rails khi contact_points xuất hiện hai lần.
  def apply_pump_allocation_search(scope)
    return scope if params[:q].blank?

    scope = scope.joins(
      "LEFT JOIN contact_points pump_station_cp " \
      "ON pump_station_cp.id = pump_allocations.pump_contact_point_id"
    )
    apply_search(
      scope,
      columns: %w[units.name blocks.name groups.name contact_points.name pump_station_cp.name]
    )
  end

  # Nhóm allocation theo trạm bơm cho view.
  #
  # Kỳ per-station: liệt kê MỌI trạm bơm (water_pump) accessible — kể cả trạm
  # chưa có đối tượng nào (hiện thẻ rỗng kèm cảnh báo). Khi đang tìm kiếm, ẩn
  # các trạm không có đối tượng khớp (không hiện thẻ rỗng/cảnh báo).
  # Kỳ cũ (legacy): mọi allocation có pump_contact_point_id = nil → gộp một thẻ.
  #
  # Trả về Array of Hash: { station:, allocations:, fixed_percentage_sum:, coefficient_count: }
  # station = nil cho thẻ "Gộp toàn khu vực (kỳ cũ)".
  def build_station_groups(allocations)
    by_station = allocations.group_by(&:pump_contact_point_id)

    unless @per_station
      allocs = (by_station[nil] || []).sort_by { |a| recipient_sort_key(a) }
      return [] if allocs.empty? && @search_active
      return [station_group(nil, allocs)]
    end

    stations = accessible_pump_stations
    stations = stations.select { |s| (by_station[s.id] || []).any? } if @search_active
    stations.sort_by { |s| [s.zone&.name.to_s, s.name.to_s] }.map do |station|
      allocs = (by_station[station.id] || []).sort_by { |a| recipient_sort_key(a) }
      station_group(station, allocs)
    end
  end

  # Phần trăm điện bơm nước mỗi trạm chiếm trong tổng điện bơm của khu vực, suy từ
  # CHỈ SỐ HIỆN TẠI (không cần đã tính toán/lưu). D_trạm = Σ (sử dụng + tổn hao) của
  # các công tơ bơm thuộc trạm; D_khu_vực = Σ toàn bộ công tơ bơm. Mirror cách
  # PumpAllocationCalculator dựng d_station: usage (ZoneQuery#meter_usages) + tổn hao
  # (LossCalculator#meter_losses) cộng theo công tơ, gộp theo trạm (contact_point_id).
  #
  # Trả Hash[station_contact_point_id => { percent: BigDecimal, kw: BigDecimal }].
  # Trạm nào không có công tơ bơm (hoặc D_khu_vực = 0, chưa nhập chỉ số) → không
  # có khóa → view hiện "—".
  def build_station_zone_shares
    return {} unless @period

    zones = @pump_allocations.map(&:zone).uniq.compact
    zones |= accessible_pump_stations.map(&:zone).compact if @per_station

    shares = {}
    zones.each do |zone|
      query = ZoneQuery.new(zone: zone, period: @period)
      pump_meters = query.pump_meters.to_a
      next if pump_meters.empty?

      usages = query.meter_usages
      losses = LossCalculator.new(zone: zone, period: @period).call.meter_losses
      d_by_meter = pump_meters.to_h do |meter|
        [meter.id, (usages[meter.id] || BigDecimal("0")) + (losses[meter.id] || BigDecimal("0"))]
      end
      d_zone = d_by_meter.values.sum(BigDecimal("0"))
      next if d_zone.zero?

      pump_meters.group_by(&:contact_point_id).each do |station_cp_id, station_meters|
        d_station = station_meters.sum(BigDecimal("0")) { |m| d_by_meter[m.id] || BigDecimal("0") }
        shares[station_cp_id] = {
          percent: d_station * BigDecimal("100") / d_zone,
          kw: d_station
        }
      end
    end
    shares
  end

  def station_group(station, allocs)
    {
      station: station,
      allocations: allocs,
      fixed_percentage_sum: allocs.filter_map(&:fixed_percentage).sum(BigDecimal("0")),
      coefficient_count: allocs.count { |a| a.fixed_percentage.blank? }
    }
  end

  def recipient_name(alloc)
    alloc.unit&.name || alloc.block&.name || alloc.group&.name || alloc.contact_point&.name
  end

  def recipient_sort_key(alloc)
    owning_unit = alloc.unit || alloc.block&.unit || alloc.group&.unit || alloc.contact_point&.unit
    [
      owning_unit&.name.to_s,
      (alloc.block || alloc.group&.block || alloc.contact_point&.block)&.name.to_s,
      (alloc.group || alloc.contact_point&.group)&.name.to_s,
      recipient_name(alloc).to_s
    ]
  end

  # Trạm bơm (water_pump) mà người dùng hiện tại được phép thấy, trong phạm vi
  # zone filter (nếu SA đã chọn khu vực). Dùng để hiện thẻ trạm chưa có đối tượng.
  def accessible_pump_stations
    scope = ContactPoint.kept.accessible_by(current_ability).includes(:zone).where(contact_point_type: "water_pump")
    scope = scope.where(zone_id: @zone.id) if @zone
    scope.order(:name).to_a
  end

  def action_auth_key
    case action_name
    when "edit", "update" then :update
    when "destroy" then :destroy
    end
  end

  def allocation_params
    params.require(:pump_allocation).permit(
      :zone_id, :pump_contact_point_id, :unit_id, :block_id, :group_id, :contact_point_id,
      :coefficient, :fixed_percentage, :lock_version
    )
  end
end
