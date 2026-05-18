class CreateOtherDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :other_deductions do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.column :other_type, :other_deduction_type, null: false, default: "fixed"
      t.decimal :other_value, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :other_deductions, [:contact_point_id, :period_id], unique: true, name: "idx_other_deductions_unique"
  end
end
