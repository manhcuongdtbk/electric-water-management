# Provides Ability-aligned zones + assigns @freshness_states for the view.
# Shared by the five pages that show/edit data related to derived data (#334).
module FreshnessIndicatable
  extend ActiveSupport::Concern

  private

  # Zones the current user sees for this period (Ability-aligned). selected_zone (if
  # present) narrows to one zone (SA zone filter).
  def freshness_zones(period, selected_zone: nil)
    return Zone.with_discarded.where(id: selected_zone.id).order(:name) if selected_zone

    if current_user.system_wide_scope?
      Zone.with_discarded.order(:name)
    else
      zone_ids = [current_user.unit&.zone_id].compact
      if current_user.unit_id
        zone_ids += Zone.kept.where(manager_unit_id: current_user.unit_id).pluck(:id)
      end
      Zone.with_discarded.where(id: zone_ids.uniq).order(:name)
    end
  end

  # Closed period = frozen (no input edits) → no stale → []. Only compute freshness
  # for an open period.
  def assign_freshness_states(period, selected_zone: nil)
    if period.nil? || period.closed?
      @freshness_states = []
      return @freshness_states
    end
    @freshness_states = CalculationFreshness.new(
      period: period, zones: freshness_zones(period, selected_zone: selected_zone)
    ).call
  end
end
