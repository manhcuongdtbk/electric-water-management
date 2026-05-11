# frozen_string_literal: true

# Replaced by MainMeterReading.electricity_supply_kw (per-zone supply via shared
# main meter) since PR1/PR2 of M6. Engine no longer falls back to this column.
class DropElectricitySupplyFromUnitConfigs < ActiveRecord::Migration[8.1]
  def change
    remove_column :unit_configs, :electricity_supply_kw, :decimal, precision: 12, scale: 2
  end
end
