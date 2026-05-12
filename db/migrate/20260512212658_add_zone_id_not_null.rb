class AddZoneIdNotNull < ActiveRecord::Migration[8.1]
  def up
    change_column_null :main_meters,   :zone_id, false
    change_column_null :pump_stations, :zone_id, false
    # organizations.zone_id stays nullable: division-level orgs have no zone.
  end

  def down
    change_column_null :main_meters,   :zone_id, true
    change_column_null :pump_stations, :zone_id, true
  end
end
