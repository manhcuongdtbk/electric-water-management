# frozen_string_literal: true

class CreateMonthlyCalculations < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_calculations do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true

      # === Personnel snapshot (copied at calculation time) ===
      t.integer :total_personnel, null: false, default: 0

      # === Standard (tiêu chuẩn) — 7 rank kW values ===
      t.decimal :rank1_kw, precision: 12, scale: 2, default: 0 # 570 kW group
      t.decimal :rank2_kw, precision: 12, scale: 2, default: 0 # 440 kW group
      t.decimal :rank3_kw, precision: 12, scale: 2, default: 0 # 305 kW group
      t.decimal :rank4_kw, precision: 12, scale: 2, default: 0 # 130 kW group
      t.decimal :rank5_kw, precision: 12, scale: 2, default: 0 # 210 kW group
      t.decimal :rank6_kw, precision: 12, scale: 2, default: 0 # 110 kW group
      t.decimal :rank7_kw, precision: 12, scale: 2, default: 0 #  24 kW group

      # Water pump standard: 9.45 kW × total_personnel
      t.decimal :water_pump_standard_kw, precision: 12, scale: 2, default: 0

      # Total standard before deductions (sum of rank kW + water pump standard)
      t.decimal :total_standard_kw, precision: 12, scale: 2, default: 0

      # === Deductions (số phải trừ) ===
      t.decimal :savings_deduction_kw, precision: 12, scale: 2, default: 0       # tiết kiệm (%)
      t.decimal :loss_deduction_kw, precision: 12, scale: 2, default: 0           # tổn hao (allocated by kW ratio)
      t.decimal :division_public_deduction_kw, precision: 12, scale: 2, default: 0 # công cộng Sư đoàn
      t.decimal :unit_public_deduction_kw, precision: 12, scale: 2, default: 0     # công cộng đơn vị
      t.decimal :other_deduction_kw, precision: 12, scale: 2, default: 0           # khác
      t.decimal :total_deduction_kw, precision: 12, scale: 2, default: 0

      # === Remaining standard (còn được hưởng) ===
      t.decimal :remaining_standard_kw, precision: 12, scale: 2, default: 0

      # === Usage (sử dụng) ===
      t.decimal :meter_usage_kw, precision: 12, scale: 2, default: 0        # from meter readings
      t.decimal :water_pump_actual_kw, precision: 12, scale: 2, default: 0  # allocated from pump stations
      t.decimal :total_usage_kw, precision: 12, scale: 2, default: 0        # meter + water pump actual

      # === Comparison & billing ===
      t.decimal :over_under_kw, precision: 12, scale: 2, default: 0   # total_usage - remaining_standard
      t.decimal :unit_price, precision: 12, scale: 2, default: 0      # snapshot from monthly_period
      t.decimal :total_amount, precision: 12, scale: 2, default: 0    # over_under × unit_price

      t.text :notes

      t.timestamps
    end

    add_index :monthly_calculations, %i[contact_point_id monthly_period_id], unique: true,
              name: "idx_monthly_calcs_on_contact_point_and_period"
  end
end
