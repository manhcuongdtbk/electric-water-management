class CreateContactPointOtherDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_point_other_deductions do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true
      # 0 = fixed_kw (nhập số kW cụ thể), 1 = factor_per_person (hệ số × số người)
      t.integer :other_type, default: 0, null: false
      t.decimal :other_value, precision: 12, scale: 4, default: "0.0", null: false

      t.timestamps
    end

    add_index :contact_point_other_deductions,
              [ :contact_point_id, :monthly_period_id ],
              unique: true,
              name: "idx_cp_other_deductions_on_cp_and_period"
  end
end
