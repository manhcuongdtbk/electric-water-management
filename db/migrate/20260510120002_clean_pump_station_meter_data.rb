class CleanPumpStationMeterData < ActiveRecord::Migration[8.1]
  PUMP_STATION_TYPE = 2 # Meter.meter_types[:pump_station]

  def up
    cleared_contact_points = connection.update(<<~SQL.squish)
      UPDATE meters
      SET contact_point_id = NULL
      WHERE meter_type = #{PUMP_STATION_TYPE}
        AND contact_point_id IS NOT NULL
    SQL
    say "Cleared contact_point_id on #{cleared_contact_points} pump_station meter(s)" if cleared_contact_points.positive?

    orphans = connection.select_rows(<<~SQL.squish)
      SELECT id, name FROM meters
      WHERE meter_type = #{PUMP_STATION_TYPE}
        AND pump_station_id IS NULL
    SQL
    if orphans.any?
      say "WARNING: #{orphans.size} pump_station meter(s) have no pump_station and are orphaned. Manual review required:"
      orphans.each { |id, name| say "  meter id=#{id} name=#{name.inspect}" }
    end

    cleared_pump_stations = connection.update(<<~SQL.squish)
      UPDATE meters
      SET pump_station_id = NULL
      WHERE meter_type <> #{PUMP_STATION_TYPE}
        AND pump_station_id IS NOT NULL
    SQL
    say "Cleared pump_station_id on #{cleared_pump_stations} non-pump_station meter(s)" if cleared_pump_stations.positive?
  end

  def down
    # Defensive cleanup — no inverse needed.
  end
end
