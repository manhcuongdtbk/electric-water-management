# frozen_string_literal: true

# Zone-wide pump allocation calculator (F08 + F10).
#
# Resolves how each pump station's inflated pool — consumption plus the
# station's share of zone loss — is split across its assignments
# (Organization, ContactPoint, ContactPointGroup, WorkGroup), and then
# drilled down to contact points for billing.
#
# 30/70 model (M6). An assignment may carry a `fixed_pump_percentage`, in
# which case it takes that slice of the pool off the top regardless of
# personnel. Remaining assignments (NULL percentage) share the rest by
# personnel ratio. fixed_pump_percentage = 0 → that assignment gets 0 and
# does NOT participate in the variable pool. sum_fixed_percentage > 100 is
# clamped to 100 → variable assignments collapse to 0.
#
# Within an Organization or ContactPointGroup share, kW is split across
# member contact points by personnel ratio. A ContactPoint share lands
# on that single CP. A WorkGroup share counts toward the variable
# denominator but yields no CP allocation — it only appears in
# `allocations_by_assignment` (the F10 breakdown).
#
# Zone-wide: every pump station in the zone is processed, and every
# member CP receives its drill-down share regardless of which
# organization owns it. SummaryCalculator reads `allocations_by_cp[cp_id]`
# for only the CPs it cares about.
#
# Interface:
#
#   pac = PumpAllocationCalculator.new(
#     zone: zone, monthly_period: period,
#     loss_calculator: optional_shared_instance
#   )
#   pac.call # =>
#   {
#     allocations_by_cp:         { cp_id => BigDecimal },
#     allocations_by_assignment: [
#       { assignable_type:, assignable_id:, name:, personnel:,
#         fixed_pump_percentage:, kw: }, ...
#     ],
#     total_pool_kw: BigDecimal
#   }
#
# Instance is one-shot — caches are built on first access. Pass in a
# shared LossCalculator so its memoized loss math is reused across
# calculators.
class PumpAllocationCalculator
  ZERO = BigDecimal("0")

  attr_reader :zone, :monthly_period

  def initialize(zone:, monthly_period:, loss_calculator: nil)
    @zone = zone
    @monthly_period = monthly_period
    @loss_calculator = loss_calculator
  end

  def call
    return empty_result if zone.nil?

    allocations_by_cp = Hash.new(ZERO)
    allocations_by_assignment = []
    total_pool_kw = ZERO

    pump_stations.each do |ps|
      pool = pump_station_consumption(ps) + loss_calculator.pump_loss_share(ps)
      next unless pool.positive?

      total_pool_kw += pool

      assignments = pump_station_assignments_for(ps)
      next if assignments.empty?

      allocate_station(allocations_by_cp, allocations_by_assignment, pool, assignments)
    end

    {
      allocations_by_cp:         allocations_by_cp,
      allocations_by_assignment: allocations_by_assignment,
      total_pool_kw:             total_pool_kw
    }
  end

  private

  def empty_result
    { allocations_by_cp: {}, allocations_by_assignment: [], total_pool_kw: ZERO }
  end

  def loss_calculator
    @loss_calculator ||= LossCalculator.new(zone: zone, monthly_period: monthly_period)
  end

  # ============================================================ pump stations

  def pump_stations
    @pump_stations ||= PumpStation.where(zone: zone)
                                  .includes(:meters)
                                  .select { |ps| ps.meters.any? }
  end

  def pump_station_consumption(pump_station)
    meter_ids = pump_station.meters.map(&:id)
    return ZERO if meter_ids.empty?

    to_bd(
      MeterReading.where(meter_id: meter_ids,
                         monthly_period_id: monthly_period.id).sum(:consumption)
    )
  end

  def pump_station_assignments_for(pump_station)
    @pump_station_assignments_cache ||= {}
    @pump_station_assignments_cache[pump_station.id] ||=
      PumpStationAssignment.for_pump_station(pump_station.id)
                           .includes(:assignable)
                           .to_a
  end

  # ============================================================ allocation

  def allocate_station(allocations_by_cp, allocations_by_assignment, pool, assignments)
    fixed, variable = assignments.partition(&:fixed?)

    sum_fixed_pct = fixed.sum { |a| to_bd(a.fixed_pump_percentage) }
    sum_fixed_pct = bd_100 if sum_fixed_pct > bd_100

    fixed.each do |asg|
      share = pool * to_bd(asg.fixed_pump_percentage) / bd_100
      apply_share(allocations_by_cp, allocations_by_assignment, asg, share)
    end

    variable_pct = bd_100 - sum_fixed_pct
    if variable_pct.positive?
      variable_pool_kw = pool * variable_pct / bd_100
      head_by_asg = variable.to_h { |a| [ a, headcount_for(a.assignable) ] }
      variable_total = head_by_asg.values.sum

      variable.each do |asg|
        head = head_by_asg[asg]
        share =
          if variable_total.positive? && head.positive?
            variable_pool_kw * to_bd(head) / to_bd(variable_total)
          else
            ZERO
          end
        apply_share(allocations_by_cp, allocations_by_assignment, asg, share)
      end
    else
      variable.each do |asg|
        apply_share(allocations_by_cp, allocations_by_assignment, asg, ZERO)
      end
    end
  end

  def apply_share(allocations_by_cp, allocations_by_assignment, assignment, share)
    target = assignment.assignable

    case target
    when Organization
      distribute_within_org(allocations_by_cp, target.id, share)
    when ContactPoint
      allocations_by_cp[target.id] += share if share.positive?
    when ContactPointGroup
      distribute_within_contact_point_group(allocations_by_cp, target, share)
    when WorkGroup
      # No CP routing — WorkGroup only surfaces in allocations_by_assignment.
    end

    allocations_by_assignment << build_assignment_row(assignment, share)
  end

  def build_assignment_row(assignment, share)
    target = assignment.assignable
    {
      assignable_type:       assignment.assignable_type,
      assignable_id:         assignment.assignable_id,
      name:                  target.respond_to?(:name) ? target.name : nil,
      personnel:             headcount_for(target),
      fixed_pump_percentage: assignment.fixed_pump_percentage,
      kw:                    share
    }
  end

  # ============================================================ drill-down

  def distribute_within_org(allocations_by_cp, org_id, org_share_kw)
    return unless org_share_kw.positive?

    cp_personnel = personnel_by_cp_for_org(org_id)
    org_total = cp_personnel.values.sum(0)
    return unless org_total.positive?

    org_total_bd = to_bd(org_total)
    cp_personnel.each do |cp_id, people|
      next if people.zero?

      allocations_by_cp[cp_id] += org_share_kw * to_bd(people) / org_total_bd
    end
  end

  def distribute_within_contact_point_group(allocations_by_cp, group, group_share_kw)
    return unless group_share_kw.positive?

    member_cp_ids = group.contact_points.pluck(:id)
    return if member_cp_ids.empty?

    cp_personnel = personnel_by_cp_for_group(group.id)
    group_total = member_cp_ids.sum { |cp_id| cp_personnel[cp_id].to_i }
    return unless group_total.positive?

    group_total_bd = to_bd(group_total)
    member_cp_ids.each do |cp_id|
      people = cp_personnel[cp_id].to_i
      next if people.zero?

      allocations_by_cp[cp_id] += group_share_kw * to_bd(people) / group_total_bd
    end
  end

  # ============================================================ headcount

  def headcount_for(target)
    case target
    when Organization
      organization_personnel_total(target.id)
    when ContactPoint
      contact_point_personnel_total(target.id)
    when ContactPointGroup
      contact_point_group_personnel_total(target.id)
    when WorkGroup
      target.personnel_count.to_i
    else
      0
    end
  end

  def organization_personnel_total(org_id)
    @organization_personnel_cache ||= {}
    @organization_personnel_cache[org_id] ||= Personnel
      .for_period(monthly_period.id)
      .joins(:contact_point)
      .where(contact_points: { organization_id: org_id })
      .sum("rank1_count + rank2_count + rank3_count + rank4_count + " \
           "rank5_count + rank6_count + rank7_count").to_i
  end

  def contact_point_personnel_total(cp_id)
    @contact_point_personnel_cache ||= {}
    @contact_point_personnel_cache[cp_id] ||= begin
      record = Personnel.for_period(monthly_period.id).for_contact_point(cp_id).first
      record ? record.total_count : 0
    end
  end

  def contact_point_group_personnel_total(group_id)
    @contact_point_group_personnel_cache ||= {}
    @contact_point_group_personnel_cache[group_id] ||= Personnel
      .for_period(monthly_period.id)
      .joins(contact_point: :contact_point_group_memberships)
      .where(contact_point_group_memberships: { contact_point_group_id: group_id })
      .sum("rank1_count + rank2_count + rank3_count + rank4_count + " \
           "rank5_count + rank6_count + rank7_count").to_i
  end

  def personnel_by_cp_for_org(org_id)
    @personnel_by_cp_for_org_cache ||= {}
    @personnel_by_cp_for_org_cache[org_id] ||=
      Personnel.for_period(monthly_period.id)
               .joins(:contact_point)
               .where(contact_points: { organization_id: org_id })
               .each_with_object({}) { |p, h| h[p.contact_point_id] = p.total_count }
  end

  def personnel_by_cp_for_group(group_id)
    @personnel_by_cp_for_group_cache ||= {}
    @personnel_by_cp_for_group_cache[group_id] ||=
      Personnel.for_period(monthly_period.id)
               .joins(contact_point: :contact_point_group_memberships)
               .where(contact_point_group_memberships: { contact_point_group_id: group_id })
               .each_with_object({}) { |p, h| h[p.contact_point_id] = p.total_count }
  end

  # ============================================================ misc

  def bd_100
    @bd_100 ||= BigDecimal("100")
  end

  def to_bd(value)
    case value
    when BigDecimal then value
    when nil then ZERO
    else BigDecimal(value.to_s)
    end
  end
end
