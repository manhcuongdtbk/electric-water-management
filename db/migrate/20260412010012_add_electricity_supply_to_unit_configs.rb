# frozen_string_literal: true

# F05: Store total electricity supplied by the power company to each unit per month.
# Used to calculate loss (tổn hao) = supply - sum of all meter readings.
class AddElectricitySupplyToUnitConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :unit_configs, :electricity_supply_kw, :decimal, precision: 12, scale: 2
  end
end
