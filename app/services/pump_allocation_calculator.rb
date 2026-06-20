class PumpAllocationCalculator
  Result = Struct.new(:contact_point_allocations, :contact_point_station_allocations,
                      :total_d, :warnings, keyword_init: true)

  # Domain error: một trạm bơm (hoặc nhánh gộp toàn khu vực) còn điện thừa
  # (remaining > 0) nhưng KHÔNG có đối tượng nhận theo hệ số có trọng số dương
  # (total_weighted == 0) → điện sẽ bị bỏ rơi âm thầm, bảng tính tiền sẽ nói dối
  # (tổng trạm < điện thật của trạm). Nghiệp vụ mục 9.6 = chặn, không tính.
  class IncompleteStationConfig < StandardError; end

  def initialize(zone:, period:, loss_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    @warnings = []
    # Hash[contact_point_id => Hash[pump_contact_point_id => BigDecimal]]: how much each
    # recipient CP got from each station. Filled only by the per-station branch; the
    # legacy zone-wide branch leaves it empty (no per-station detail).
    @station_allocations = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = BigDecimal("0") } }
    pump_meters = @query.pump_meters.to_a

    if pump_meters.empty?
      @warnings << I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter")
      return Result.new(contact_point_allocations: {}, contact_point_station_allocations: {},
                        total_d: BigDecimal("0"), warnings: @warnings)
    end

    usages = @query.meter_usages
    @meter_d = pump_meters.each_with_object({}) do |m, h|
      raw = usages[m.id] || BigDecimal("0")
      loss = @loss_results.meter_losses[m.id] || BigDecimal("0")
      h[m.id] = raw + loss
    end
    total_d = @meter_d.values.sum(BigDecimal("0"))

    allocations = load_allocations
    cp_amounts = if @period.pump_allocation_per_station
      allocate_per_station(pump_meters, allocations)
    else
      allocate_zone_wide(total_d, allocations)
    end

    Result.new(contact_point_allocations: cp_amounts,
               contact_point_station_allocations: materialize_station_allocations,
               total_d: total_d, warnings: @warnings)
  end

  private

  # Convert the default-block nested hash into plain hashes so callers (writer/specs)
  # don't accidentally autovivify keys. Empty for the legacy zone-wide branch.
  def materialize_station_allocations
    @station_allocations.each_with_object({}) do |(cp_id, by_station), out|
      out[cp_id] = by_station.to_h
    end
  end

  def load_allocations
    scope = @period.pump_allocations
                    .where(zone: @zone)
                    .left_joins(:unit, :block, :group, :contact_point, :pump_contact_point)
                    .includes(:unit, :block, :group, :contact_point, :pump_contact_point)
    unless @period.closed?
      scope = scope.where("units.discarded_at IS NULL OR units.id IS NULL")
                   .where("blocks.discarded_at IS NULL OR blocks.id IS NULL")
                   .where("groups.discarded_at IS NULL OR groups.id IS NULL")
                   .where("contact_points.discarded_at IS NULL OR contact_points.id IS NULL")
                   .where("pump_contact_points_pump_allocations.discarded_at IS NULL OR pump_contact_points_pump_allocations.id IS NULL")
    end
    scope.to_a
  end

  def allocate_zone_wide(d, allocations)
    return {} if allocations.empty?
    @personnel_cache = build_personnel_cache(allocations)
    object_amounts = allocate_within(d, allocations, station_label: @zone.name)
    distribute_to_recipients(object_amounts)
  end

  def allocate_per_station(pump_meters, allocations)
    @personnel_cache = build_personnel_cache(allocations)
    by_station = allocations.group_by(&:pump_contact_point_id)
    meters_by_station = pump_meters.group_by { |m| m.contact_point_id }

    cp_amounts = Hash.new { |h, k| h[k] = BigDecimal("0") }
    meters_by_station.each do |station_cp_id, station_meters|
      d_station = station_meters.sum(BigDecimal("0")) { |m| @meter_d[m.id] || BigDecimal("0") }
      station_allocs = by_station[station_cp_id] || []
      if station_allocs.empty?
        @warnings << I18n.t("services.pump_allocation_calculator.warnings.station_without_recipient",
                            station: station_name(station_cp_id))
        next
      end
      object_amounts = allocate_within(d_station, station_allocs, station_label: station_name(station_cp_id))
      distribute_to_recipients(object_amounts).each do |cp_id, amt|
        cp_amounts[cp_id] += amt
        @station_allocations[cp_id][station_cp_id] += amt
      end
    end
    cp_amounts
  end

  def station_name(cp_id)
    ContactPoint.with_discarded.find_by(id: cp_id)&.name.to_s
  end

  def allocate_within(d, allocations, station_label:)
    fixed, coefficient = allocations.partition { |a| a.fixed_percentage.present? }
    object_amounts = {}
    fixed.each { |a| object_amounts[a] = d * BigDecimal(a.fixed_percentage.to_s) / BigDecimal("100") }
    remaining = d - object_amounts.values.sum(BigDecimal("0"))

    weighted = coefficient.map do |a|
      personnel = personnel_count_for(a)
      if personnel.zero?
        @warnings << I18n.t("services.pump_allocation_calculator.warnings.zero_personnel")
        [a, BigDecimal("0")]
      else
        [a, BigDecimal(personnel.to_s) * BigDecimal(a.coefficient.to_s)]
      end
    end
    total_weighted = weighted.sum(BigDecimal("0")) { |_, w| w }
    # Còn điện thừa nhưng không có đối tượng hệ số trọng số dương → điện sẽ bị bỏ rơi.
    # Chặn ngay tại lúc tính (mục 9.6), không tạo kết quả nói dối.
    if remaining > 0 && total_weighted.zero?
      raise IncompleteStationConfig,
            I18n.t("services.pump_allocation_calculator.errors.incomplete_station_config",
                   station: station_label)
    end
    if total_weighted > 0
      weighted.each { |a, w| object_amounts[a] = remaining * w / total_weighted }
    end
    object_amounts
  end

  def build_personnel_cache(allocations)
    cache = { unit: {}, block: {}, group: {}, contact_point: {}, residential: {} }
    unit_ids  = allocations.map(&:unit_id).compact.uniq
    block_ids = allocations.map(&:block_id).compact.uniq
    group_ids = allocations.map(&:group_id).compact.uniq
    cp_ids    = allocations.map(&:contact_point_id).compact.uniq

    residential_scope = @period.closed? ? ContactPoint.with_discarded : ContactPoint.kept

    register = lambda do |bucket_key, owner_id, residentials|
      cache[bucket_key][owner_id] = residentials.map(&:id)
      residentials.each { |cp| cache[:residential][cp.id] = cp }
    end

    if unit_ids.any?
      residential_scope.where(unit_id: unit_ids, contact_point_type: "residential")
                       .group_by(&:unit_id).each { |uid, cps| register.call(:unit, uid, cps) }
    end
    if block_ids.any?
      residential_scope.where(block_id: block_ids, contact_point_type: "residential")
                       .group_by(&:block_id).each { |bid, cps| register.call(:block, bid, cps) }
    end
    if group_ids.any?
      residential_scope.where(group_id: group_ids, contact_point_type: "residential")
                       .group_by(&:group_id).each { |gid, cps| register.call(:group, gid, cps) }
    end

    all_residential_ids = cache[:residential].keys
    cache[:cp_counts] = if all_residential_ids.any?
      PersonnelEntry.where(period_id: @period.id, contact_point_id: all_residential_ids)
                    .group(:contact_point_id).sum(:count)
    else
      {}
    end

    if cp_ids.any?
      residential_counts = PersonnelEntry.where(period_id: @period.id, contact_point_id: cp_ids)
                                         .group(:contact_point_id).sum(:count)
      ne_counts = NonEstablishmentSnapshot.where(period_id: @period.id, contact_point_id: cp_ids)
                                          .pluck(:contact_point_id, :personnel_count).to_h
      allocations.each do |a|
        next unless a.contact_point_id
        cp = a.contact_point
        cache[:contact_point][a.contact_point_id] = case cp.contact_point_type
        when "residential" then residential_counts[cp.id] || 0
        when "non_establishment" then ne_counts[cp.id] || 0
        else 0
        end
      end
    end
    cache
  end

  def group_total(bucket_key, owner_id)
    (@personnel_cache[bucket_key][owner_id] || []).sum(0) { |cp_id| @personnel_cache[:cp_counts][cp_id] || 0 }
  end

  def personnel_count_for(a)
    if a.unit_id then group_total(:unit, a.unit_id)
    elsif a.block_id then group_total(:block, a.block_id)
    elsif a.group_id then group_total(:group, a.group_id)
    elsif a.contact_point_id then @personnel_cache[:contact_point][a.contact_point_id] || 0
    else 0
    end
  end

  def distribute_to_recipients(object_amounts)
    cp_amounts = Hash.new { |h, k| h[k] = BigDecimal("0") }
    object_amounts.each do |a, amount|
      next if amount.zero?
      if a.contact_point_id
        cp_amounts[a.contact_point_id] += amount
      else
        bucket_key = a.unit_id ? :unit : (a.block_id ? :block : :group)
        owner_id   = a.unit_id || a.block_id || a.group_id
        total = group_total(bucket_key, owner_id)
        if total.zero?
          recipient_name = (a.unit || a.block || a.group)&.name
          @warnings << I18n.t("services.pump_allocation_calculator.warnings.empty_recipient",
                              name: recipient_name)
          next
        end
        (@personnel_cache[bucket_key][owner_id] || []).each do |cp_id|
          count = @personnel_cache[:cp_counts][cp_id] || 0
          next if count.zero?
          cp_amounts[cp_id] += amount * BigDecimal(count.to_s) / BigDecimal(total.to_s)
        end
      end
    end
    cp_amounts
  end
end
