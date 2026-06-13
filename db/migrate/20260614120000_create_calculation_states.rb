class CreateCalculationStates < ActiveRecord::Migration[8.0]
  def change
    create_table :calculation_states do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.datetime :inputs_changed_at
      t.datetime :last_calculated_at
      t.timestamps
    end
    add_index :calculation_states, %i[zone_id period_id], unique: true,
      name: "idx_calculation_states_unique"
  end
end
