class AddFixedPumpPercentageToPumpStationAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :pump_station_assignments, :fixed_pump_percentage,
               :decimal, precision: 5, scale: 2
  end
end
