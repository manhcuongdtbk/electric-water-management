class PumpAllocationCalculator
  Result = Struct.new(:contact_point_allocations, :total_d, :warnings, keyword_init: true)

  def initialize(zone:, period:, loss_results:)
    @zone = zone
    @period = period
    @loss_results = loss_results
    @query = ZoneQuery.new(zone: zone, period: period)
  end

  def call
    warnings = []
    pump_meters = @query.pump_meters.to_a
    usages = @query.meter_usages

    if pump_meters.empty?
      warnings << I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter")
      return Result.new(contact_point_allocations: {}, total_d: BigDecimal("0"), warnings: warnings)
    end

    raw_pump_usage = pump_meters.sum(BigDecimal("0")) { |m| usages[m.id] || BigDecimal("0") }
    pump_loss = pump_meters.sum(BigDecimal("0")) { |m| @loss_results.meter_losses[m.id] || BigDecimal("0") }
    d = raw_pump_usage + pump_loss

    scope = @period.pump_allocations
                    .where(zone: @zone)
                    .left_joins(:unit, :contact_point)
                    .includes(:unit, :contact_point)
    unless @period.closed?
      scope = scope.where("units.discarded_at IS NULL OR units.id IS NULL")
                   .where("contact_points.discarded_at IS NULL OR contact_points.id IS NULL")
    end
    allocations = scope.to_a
    return Result.new(contact_point_allocations: {}, total_d: d, warnings: warnings) if allocations.empty?

    @personnel_cache = build_personnel_cache(allocations)

    fixed_allocations, coefficient_allocations = allocations.partition { |a| a.fixed_percentage.present? }

    object_amounts = {}
    fixed_allocations.each do |alloc|
      object_amounts[alloc] = d * BigDecimal(alloc.fixed_percentage.to_s) / BigDecimal("100")
    end

    remaining = d - object_amounts.values.sum(BigDecimal("0"))

    weighted = coefficient_allocations.map do |alloc|
      personnel = personnel_count_for(alloc)
      if personnel.zero?
        warnings << I18n.t("services.pump_allocation_calculator.warnings.zero_personnel")
        [alloc, BigDecimal("0")]
      else
        [alloc, BigDecimal(personnel.to_s) * BigDecimal(alloc.coefficient.to_s)]
      end
    end

    total_weighted = weighted.sum(BigDecimal("0")) { |_, w| w }

    if total_weighted > 0
      weighted.each do |alloc, weight|
        object_amounts[alloc] = remaining * weight / total_weighted
      end
    end

    contact_point_allocations = distribute_to_residential_contact_points(object_amounts)

    Result.new(contact_point_allocations: contact_point_allocations, total_d: d, warnings: warnings)
  end

  private

  def build_personnel_cache(allocations)
    cache = { unit: {}, contact_point: {}, residential_in_unit: {} }
    unit_ids = allocations.map(&:unit_id).compact.uniq
    cp_ids = allocations.map(&:contact_point_id).compact.uniq

    if unit_ids.any?
      contact_point_scope = @period.closed? ? ContactPoint.with_discarded : ContactPoint.kept
      contact_point_scope.where(unit_id: unit_ids, contact_point_type: "residential")
                  .each do |cp|
        cache[:residential_in_unit][cp.unit_id] ||= []
        cache[:residential_in_unit][cp.unit_id] << cp
      end

      counts_by_cp = PersonnelEntry.where(period_id: @period.id,
                                          contact_point_id: cache[:residential_in_unit].values.flatten.map(&:id))
                                   .group(:contact_point_id).sum(:count)

      unit_ids.each do |uid|
        cache[:unit][uid] = (cache[:residential_in_unit][uid] || []).sum(0) { |cp| counts_by_cp[cp.id] || 0 }
      end
      cache[:cp_counts] = counts_by_cp
    end

    if cp_ids.any?
      residential_counts = PersonnelEntry.where(period_id: @period.id, contact_point_id: cp_ids)
                                         .group(:contact_point_id).sum(:count)
      ne_counts = NonEstablishmentSnapshot.where(period_id: @period.id, contact_point_id: cp_ids)
                                          .pluck(:contact_point_id, :personnel_count).to_h

      allocations.each do |alloc|
        next unless alloc.contact_point_id
        cp = alloc.contact_point
        cache[:contact_point][alloc.contact_point_id] = case cp.contact_point_type
        when "residential" then residential_counts[cp.id] || 0
        when "non_establishment" then ne_counts[cp.id] || 0
        else 0
        end
      end
    end

    cache
  end

  def personnel_count_for(allocation)
    if allocation.unit_id
      @personnel_cache[:unit][allocation.unit_id] || 0
    elsif allocation.contact_point_id
      @personnel_cache[:contact_point][allocation.contact_point_id] || 0
    else
      0
    end
  end

  def distribute_to_residential_contact_points(object_amounts)
    cp_amounts = Hash.new { |h, k| h[k] = BigDecimal("0") }

    object_amounts.each do |alloc, amount|
      next if amount.zero?

      if alloc.unit_id
        residentials = @personnel_cache[:residential_in_unit][alloc.unit_id] || []
        unit_total = @personnel_cache[:unit][alloc.unit_id] || 0
        next if unit_total.zero?

        residentials.each do |cp|
          count = @personnel_cache[:cp_counts][cp.id] || 0
          next if count.zero?
          cp_amounts[cp.id] += amount * BigDecimal(count.to_s) / BigDecimal(unit_total.to_s)
        end
      elsif alloc.contact_point_id
        cp_amounts[alloc.contact_point_id] += amount
      end
    end

    cp_amounts
  end
end
