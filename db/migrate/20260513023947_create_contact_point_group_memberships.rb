class CreateContactPointGroupMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_point_group_memberships do |t|
      t.references :contact_point_group, null: false, foreign_key: true
      t.references :contact_point, null: false, foreign_key: true
      t.timestamps
    end

    add_index :contact_point_group_memberships,
              [ :contact_point_group_id, :contact_point_id ],
              unique: true,
              name: "idx_cpg_memberships_on_group_and_cp"
  end
end
