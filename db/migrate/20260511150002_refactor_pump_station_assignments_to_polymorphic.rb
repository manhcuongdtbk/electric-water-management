# frozen_string_literal: true

# Switches `pump_station_assignments.organization_id` (FK) to a polymorphic
# `assignable` reference so a pump station can be assigned to any of:
# Organization (unit), ContactPoint (đầu mối đặc biệt), or WorkGroup
# (nhóm công tác).
#
# Existing rows are backfilled with assignable_type='Organization' so no data
# is lost. Rollback is allowed only when every row still points at an
# Organization (i.e. before any ContactPoint/WorkGroup assignment exists).
class RefactorPumpStationAssignmentsToPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_reference :pump_station_assignments, :assignable, polymorphic: true,
                  null: true, index: false

    execute <<~SQL
      UPDATE pump_station_assignments
         SET assignable_type = 'Organization',
             assignable_id   = organization_id
    SQL

    change_column_null :pump_station_assignments, :assignable_type, false
    change_column_null :pump_station_assignments, :assignable_id, false

    remove_index :pump_station_assignments, name: "idx_pump_assignments_on_station_and_org"
    remove_foreign_key :pump_station_assignments, :organizations
    remove_index :pump_station_assignments,
                 name: "index_pump_station_assignments_on_organization_id"
    remove_column :pump_station_assignments, :organization_id

    add_index :pump_station_assignments,
              %i[pump_station_id assignable_type assignable_id],
              unique: true,
              name: "idx_pump_assignments_on_station_and_assignable"
  end

  def down
    non_org = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM pump_station_assignments
       WHERE assignable_type <> 'Organization'
    SQL

    if non_org.positive?
      raise ActiveRecord::IrreversibleMigration,
            "Cannot roll back: #{non_org} pump_station_assignments rows " \
            "reference non-Organization assignables (ContactPoint/WorkGroup). " \
            "Delete those rows first or restore from backup."
    end

    add_reference :pump_station_assignments, :organization, foreign_key: true, null: true
    execute <<~SQL
      UPDATE pump_station_assignments
         SET organization_id = assignable_id
    SQL
    change_column_null :pump_station_assignments, :organization_id, false

    remove_index :pump_station_assignments,
                 name: "idx_pump_assignments_on_station_and_assignable"

    add_index :pump_station_assignments, %i[pump_station_id organization_id],
              unique: true, name: "idx_pump_assignments_on_station_and_org"

    remove_column :pump_station_assignments, :assignable_type
    remove_column :pump_station_assignments, :assignable_id
  end

  private

  def select_value(sql)
    connection.select_value(sql)
  end
end
