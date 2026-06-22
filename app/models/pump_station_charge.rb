# Per-(recipient contact point × pump station) electricity charge for pump water,
# computed by PumpAllocationCalculator and persisted by PumpStationChargeWriter so the
# billing page can show a per-station breakdown. Pure computed data (mirrors LossSummary:
# no Auditable, no back-reference in the dependency graph). Only non-zero contributions
# are stored — a missing (cp, station) pair means 0.
class PumpStationCharge < ApplicationRecord
  belongs_to :period
  belongs_to :zone
  belongs_to :contact_point
  belongs_to :pump_contact_point, class_name: "ContactPoint"

  validates :amount, presence: true
end
