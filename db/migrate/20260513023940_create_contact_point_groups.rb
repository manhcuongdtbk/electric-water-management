class CreateContactPointGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_point_groups do |t|
      t.string :name, null: false
      t.references :organization, null: false, foreign_key: true
      t.timestamps
    end

    add_index :contact_point_groups, [ :organization_id, :name ], unique: true
  end
end
