# Bumps CalculationState#inputs_changed_at whenever an input model changes
# (create/update/destroy), so the derived-data freshness indicator (#334, ADR-049)
# can detect "derived data is now stale". Each including model defines
# #calculation_state_targets returning [[zone_id, period_id], ...] (usually one).
# Runs at after_commit so it sees the final state, including destroys. The recalc
# engine does not write these tables via callbacks, so there is no false-fire race.
module TouchesCalculationState
  extend ActiveSupport::Concern

  included do
    after_commit :bump_calculation_state, on: %i[create update destroy]
  end

  private

  def bump_calculation_state
    calculation_state_targets.each do |zone_id, period_id|
      next if zone_id.nil? || period_id.nil?
      CalculationState.touch_inputs!(zone_id: zone_id, period_id: period_id)
    end
  end

  def calculation_state_targets
    []
  end
end
