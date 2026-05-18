class CreateContactPoints < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_points do |t|
      t.string :name, null: false
      t.column :contact_point_type, :contact_point_type, null: false
      t.references :unit, foreign_key: true
      t.references :zone, foreign_key: true
      t.references :block, foreign_key: true
      t.references :group, foreign_key: true
      t.integer :personnel_count
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :contact_points,
      [:name, :unit_id, :zone_id, :contact_point_type],
      unique: true,
      name: "idx_contact_points_name_unique"
    add_index :contact_points, :discarded_at
  end
end
