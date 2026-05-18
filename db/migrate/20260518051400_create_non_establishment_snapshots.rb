class CreateNonEstablishmentSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :non_establishment_snapshots do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.integer :personnel_count, null: false
      t.timestamps
    end

    add_index :non_establishment_snapshots,
      [:contact_point_id, :period_id],
      unique: true,
      name: "idx_non_establishment_snapshots_unique"
  end
end
