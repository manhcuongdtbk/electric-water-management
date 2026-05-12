class AddZoneIdToTables < ActiveRecord::Migration[8.1]
  def change
    add_reference :main_meters,   :zone, foreign_key: true, null: true, index: true
    add_reference :organizations, :zone, foreign_key: true, null: true, index: true
    add_reference :pump_stations, :zone, foreign_key: true, null: true, index: true
  end
end
