class AddPerStationToPumpAllocationsAndPeriods < ActiveRecord::Migration[8.1]
  def change
    add_reference :pump_allocations, :pump_contact_point,
      foreign_key: { to_table: :contact_points }, null: true
    add_reference :pump_allocations, :block, foreign_key: true, null: true
    add_reference :pump_allocations, :group, foreign_key: true, null: true
    add_index :pump_allocations, [:zone_id, :period_id, :pump_contact_point_id],
      name: "index_pump_allocations_on_zone_period_station"

    add_column :periods, :pump_allocation_per_station, :boolean, null: false, default: false
  end
end
