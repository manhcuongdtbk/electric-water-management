class CreateUnitConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_configs do |t|
      t.references :unit, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.decimal :unit_public_rate, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :unit_configs, [:unit_id, :period_id], unique: true
  end
end
