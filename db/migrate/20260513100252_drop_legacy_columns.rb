class DropLegacyColumns < ActiveRecord::Migration[8.1]
  # Drops the two legacy ownership columns left in place by PR#90 as compat
  # shims while the controllers were rewritten to use zone_id directly:
  #   - organizations.main_meter_id   (replaced by organizations.zone_id)
  #   - pump_stations.organization_id (replaced by pump_stations.zone_id)
  #
  # Zone-based ownership has been wired through every controller, view, and
  # factory in earlier commits of this PR; no rows reference these columns
  # any more, so a column drop is sufficient — no data migration.
  def change
    remove_foreign_key :organizations, :main_meters
    remove_index :organizations, :main_meter_id
    remove_column :organizations, :main_meter_id, :bigint

    remove_foreign_key :pump_stations, :organizations
    remove_index :pump_stations, :organization_id
    remove_column :pump_stations, :organization_id, :bigint, null: false
  end
end
