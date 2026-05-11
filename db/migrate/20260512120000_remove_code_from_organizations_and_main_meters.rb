class RemoveCodeFromOrganizationsAndMainMeters < ActiveRecord::Migration[8.1]
  def up
    remove_index :organizations, :name
    remove_index :organizations, :code
    remove_column :organizations, :code
    add_index :organizations, [ :level, :name ], unique: true,
              name: "index_organizations_on_level_and_name"

    remove_index :main_meters, :code
    remove_column :main_meters, :code
  end

  def down
    add_column :main_meters, :code, :string
    add_index :main_meters, :code, unique: true

    remove_index :organizations, name: "index_organizations_on_level_and_name"
    add_column :organizations, :code, :string
    add_index :organizations, :code, unique: true
    add_index :organizations, :name, unique: true
  end
end
