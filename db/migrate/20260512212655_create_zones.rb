class CreateZones < ActiveRecord::Migration[8.1]
  def change
    create_table :zones do |t|
      t.string :name, null: false
      t.bigint :manager_organization_id
      t.timestamps
    end

    add_index :zones, :name, unique: true
    add_index :zones, :manager_organization_id
    add_foreign_key :zones, :organizations, column: :manager_organization_id
  end
end
