class CleanPumpStationMeterData < ActiveRecord::Migration[8.1]
  PUMP_STATION_TYPE = 2 # Meter.meter_types[:pump_station]

  def up
    pump_type_meters = Meter.where(meter_type: PUMP_STATION_TYPE)

    cleared_contact_points = pump_type_meters.where.not(contact_point_id: nil).update_all(contact_point_id: nil)
    say "Cleared contact_point_id on #{cleared_contact_points} pump_station meter(s)" if cleared_contact_points.positive?

    orphans = pump_type_meters.where(pump_station_id: nil).pluck(:id, :name)
    if orphans.any?
      say "WARNING: #{orphans.size} pump_station meter(s) have no pump_station and are orphaned. Manual review required:"
      orphans.each { |id, name| say "  meter id=#{id} name=#{name.inspect}" }
    end

    cleared_pump_stations = Meter.where.not(meter_type: PUMP_STATION_TYPE)
                                 .where.not(pump_station_id: nil)
                                 .update_all(pump_station_id: nil)
    say "Cleared pump_station_id on #{cleared_pump_stations} non-pump_station meter(s)" if cleared_pump_stations.positive?
  end

  def down
    # Defensive cleanup — no inverse needed.
  end
end
