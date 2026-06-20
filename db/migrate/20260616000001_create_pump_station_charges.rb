class CreatePumpStationCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :pump_station_charges do |t|
      t.references :period, null: false, foreign_key: true
      t.references :zone, null: false, foreign_key: true
      t.references :contact_point, null: false, foreign_key: true
      t.references :pump_contact_point, null: false,
                   foreign_key: { to_table: :contact_points }
      t.decimal :amount, null: false
      t.timestamps
    end
    add_index :pump_station_charges, [:zone_id, :period_id]
    add_index :pump_station_charges, [:period_id, :contact_point_id]
  end
end
