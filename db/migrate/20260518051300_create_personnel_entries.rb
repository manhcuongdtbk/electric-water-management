class CreatePersonnelEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :personnel_entries do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.references :rank, null: false, foreign_key: true
      t.integer :count, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :personnel_entries,
      [:contact_point_id, :period_id, :rank_id],
      unique: true,
      name: "idx_personnel_entries_unique"
  end
end
