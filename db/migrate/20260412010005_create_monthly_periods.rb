# frozen_string_literal: true

class CreateMonthlyPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_periods do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :unit_price, precision: 12, scale: 2 # VND per kW, changes monthly
      t.boolean :locked, null: false, default: false
      t.references :locked_by, foreign_key: { to_table: :users }
      t.datetime :locked_at

      t.timestamps
    end

    add_index :monthly_periods, %i[year month], unique: true
  end
end
