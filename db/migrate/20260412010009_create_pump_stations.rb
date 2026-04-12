# frozen_string_literal: true

class CreatePumpStations < ActiveRecord::Migration[8.1]
  def change
    create_table :pump_stations do |t|
      t.string :name, null: false
      t.references :organization, null: false, foreign_key: true # owner (division)
      t.references :meter, foreign_key: true # the pump station's electricity meter

      t.timestamps
    end

    # Join table: which organizations a pump station serves
    create_table :pump_station_assignments do |t|
      t.references :pump_station, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :pump_station_assignments, %i[pump_station_id organization_id], unique: true,
              name: "idx_pump_assignments_on_station_and_org"
  end
end
