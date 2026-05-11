# frozen_string_literal: true

class CreateWorkGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :work_groups do |t|
      t.string  :name, null: false
      t.integer :personnel_count, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.text    :notes
      t.references :owner_organization, null: false,
                   foreign_key: { to_table: :organizations }

      t.timestamps
    end

    add_index :work_groups, %i[owner_organization_id name], unique: true,
              name: "idx_work_groups_on_owner_and_name"
  end
end
