# frozen_string_literal: true

# paper_trail versions table for audit trail
class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.jsonb    :object          # stores the old state
      t.jsonb    :object_changes  # stores the diff
      t.datetime :created_at
    end

    add_index :versions, %i[item_type item_id]
    add_index :versions, :whodunnit
    add_index :versions, :created_at
  end
end
