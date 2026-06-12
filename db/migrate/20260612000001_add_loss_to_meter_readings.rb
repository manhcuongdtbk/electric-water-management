class AddLossToMeterReadings < ActiveRecord::Migration[8.1]
  def change
    add_column :meter_readings, :loss, :decimal, null: true
  end
end
