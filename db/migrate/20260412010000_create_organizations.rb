# frozen_string_literal: true

class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.integer :level, null: false, default: 2 # 1 = division, 2 = subordinate unit
      t.references :parent, foreign_key: { to_table: :organizations }
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :organizations, :code, unique: true
    add_index :organizations, :level
  end
end
