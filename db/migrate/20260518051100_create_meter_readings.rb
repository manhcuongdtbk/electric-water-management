class CreateMeterReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :meter_readings do |t|
      t.references :meter, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.decimal :reading_start, null: false, default: 0
      t.decimal :reading_end
      t.decimal :manual_usage
      t.text :manual_usage_note
      t.boolean :no_loss, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :meter_readings, [:meter_id, :period_id], unique: true
  end
end
