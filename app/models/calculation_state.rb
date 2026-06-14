class CalculationState < ApplicationRecord
  belongs_to :zone
  belongs_to :period

  # Bump the input-changed timestamp for (zone, period) — idempotent, leaves
  # last_calculated_at untouched. upsert to avoid races + preserve created_at.
  def self.touch_inputs!(zone_id:, period_id:, at: Time.current)
    upsert_all(
      [{ zone_id: zone_id, period_id: period_id, inputs_changed_at: at,
         created_at: at, updated_at: at }],
      unique_by: %i[zone_id period_id],
      on_duplicate: Arel.sql("inputs_changed_at = EXCLUDED.inputs_changed_at, updated_at = EXCLUDED.updated_at")
    )
  end

  # Record the calculated-at timestamp for (zone, period). Called inside the
  # orchestrator transaction.
  def self.mark_calculated!(zone_id:, period_id:, at: Time.current)
    upsert_all(
      [{ zone_id: zone_id, period_id: period_id, last_calculated_at: at,
         created_at: at, updated_at: at }],
      unique_by: %i[zone_id period_id],
      on_duplicate: Arel.sql("last_calculated_at = EXCLUDED.last_calculated_at, updated_at = EXCLUDED.updated_at")
    )
  end

  def never_calculated?
    last_calculated_at.nil?
  end

  def stale?
    return false if last_calculated_at.nil?

    inputs_changed_at.present? && inputs_changed_at > last_calculated_at
  end

  def fresh?
    last_calculated_at.present? && !stale?
  end

  def status
    return :never_calculated if never_calculated?

    stale? ? :stale : :fresh
  end
end
