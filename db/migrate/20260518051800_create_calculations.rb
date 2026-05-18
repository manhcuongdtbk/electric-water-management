class CreateCalculations < ActiveRecord::Migration[8.1]
  def change
    create_table :calculations do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.integer :total_personnel, null: false
      t.decimal :residential_standard, null: false
      t.decimal :water_pump_standard, null: false
      t.decimal :total_standard, null: false
      t.decimal :savings_deduction, null: false
      t.decimal :loss_deduction, null: false
      t.decimal :division_public_deduction, null: false
      t.decimal :unit_public_deduction, null: false
      t.decimal :other_deduction, null: false
      t.decimal :total_deduction, null: false
      t.decimal :remaining_standard, null: false
      t.decimal :residential_usage, null: false
      t.decimal :water_pump_usage, null: false
      t.decimal :total_usage, null: false
      t.decimal :surplus, null: false, default: 0
      t.decimal :deficit, null: false, default: 0
      t.decimal :surplus_amount, null: false, default: 0
      t.decimal :deficit_amount, null: false, default: 0
      t.datetime :calculated_at, null: false
      t.timestamps
    end

    add_index :calculations, [:contact_point_id, :period_id], unique: true, name: "idx_calculations_unique"
  end
end
