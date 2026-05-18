class CreatePeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :periods do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :unit_price, null: false
      t.boolean :closed, null: false, default: true
      t.decimal :savings_rate, null: false, default: 5
      t.decimal :division_public_rate, null: false, default: 10
      t.decimal :water_pump_standard, null: false, default: 9.45
      t.timestamps
    end

    add_index :periods, [:year, :month], unique: true

    execute <<~SQL
      CREATE UNIQUE INDEX idx_periods_only_one_open ON periods ((true)) WHERE closed = false;
    SQL
  end
end
