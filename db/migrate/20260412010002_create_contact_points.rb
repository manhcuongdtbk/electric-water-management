# frozen_string_literal: true

class CreateContactPoints < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_points do |t|
      t.string :name, null: false
      t.references :organization, null: false, foreign_key: true
      t.integer :position, default: 0
      t.string :group_name # e.g. "Ban Tham muu", "Ban Chinh tri", "Ban HCKT"

      t.timestamps
    end

    add_index :contact_points, %i[organization_id name], unique: true
  end
end
