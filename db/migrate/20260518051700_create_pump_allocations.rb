class CreatePumpAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :pump_allocations do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.references :unit, foreign_key: true
      t.references :contact_point, foreign_key: true
      t.decimal :fixed_percentage
      t.decimal :coefficient, null: false, default: 1
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
  end
end
