# frozen_string_literal: true

class CreateMeterReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :meter_readings do |t|
      t.references :meter, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true
      t.decimal :reading_start, precision: 12, scale: 2 # beginning of period
      t.decimal :reading_end, precision: 12, scale: 2   # end of period
      t.decimal :consumption, precision: 12, scale: 2   # auto-calculated: end - start

      t.timestamps
    end

    add_index :meter_readings, %i[meter_id monthly_period_id], unique: true,
              name: "idx_meter_readings_on_meter_and_period"
  end
end
