class CreateMainMeterReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :main_meter_readings do |t|
      t.references :main_meter, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true
      t.decimal :electricity_supply_kw, precision: 12, scale: 2, null: false

      t.timestamps
    end

    add_index :main_meter_readings,
              [ :main_meter_id, :monthly_period_id ],
              unique: true,
              name: "idx_main_meter_readings_on_meter_and_period"
  end
end
