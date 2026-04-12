# frozen_string_literal: true

class CreateUnitConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_configs do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true

      # Savings rate — set by admin_level1, applied to all units (5-10%)
      t.decimal :savings_rate, precision: 5, scale: 4 # e.g. 0.0500 = 5%

      # Division public rate — set by admin_level1 (5-10%)
      t.decimal :division_public_rate, precision: 5, scale: 4

      # Unit public rate — set by each unit's admin (10-20%)
      t.decimal :unit_public_rate, precision: 5, scale: 4

      # "Other" deduction — either fixed kW or coefficient × number of people
      t.integer :other_deduction_type, default: 0 # 0=fixed_kw, 1=per_person_coefficient
      t.decimal :other_deduction_value, precision: 12, scale: 4, default: 0

      t.timestamps
    end

    add_index :unit_configs, %i[organization_id monthly_period_id], unique: true,
              name: "idx_unit_configs_on_org_and_period"
  end
end
