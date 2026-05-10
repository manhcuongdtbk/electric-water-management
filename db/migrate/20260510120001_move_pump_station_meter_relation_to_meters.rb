class MovePumpStationMeterRelationToMeters < ActiveRecord::Migration[8.1]
  def up
    add_reference :meters, :pump_station, null: true, foreign_key: true, index: true

    execute <<~SQL.squish
      UPDATE meters
      SET pump_station_id = pump_stations.id
      FROM pump_stations
      WHERE pump_stations.meter_id = meters.id
    SQL

    remove_foreign_key :pump_stations, :meters
    remove_index :pump_stations, :meter_id if index_exists?(:pump_stations, :meter_id)
    remove_column :pump_stations, :meter_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "PumpStation→Meter is now 1-many; reversing would lose data when a station has more than one meter"
  end
end
