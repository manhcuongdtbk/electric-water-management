class CreateMainMeterReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :main_meter_readings do |t|
      t.references :main_meter, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.decimal :usage, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :main_meter_readings, [:main_meter_id, :period_id], unique: true
  end
end
