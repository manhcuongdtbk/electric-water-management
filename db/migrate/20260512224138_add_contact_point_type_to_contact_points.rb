class AddContactPointTypeToContactPoints < ActiveRecord::Migration[8.1]
  def up
    add_column :contact_points, :contact_point_type, :integer, default: 0, null: false
    add_index :contact_points, :contact_point_type

    # Backfill: a CP whose meters are ALL public_meter (1) maps to `communal` (1).
    # Default 0 (`residential`) covers everything else, including CPs with no meters.
    public_t = 1 # Meter.meter_types[:public_meter]
    communal_cp_ids = Meter
                      .where.not(contact_point_id: nil)
                      .group(:contact_point_id)
                      .having("MIN(meter_type) = ? AND MAX(meter_type) = ?", public_t, public_t)
                      .pluck(:contact_point_id)
    ContactPoint.where(id: communal_cp_ids).update_all(contact_point_type: 1)
  end

  def down
    remove_index :contact_points, :contact_point_type
    remove_column :contact_points, :contact_point_type
  end
end
