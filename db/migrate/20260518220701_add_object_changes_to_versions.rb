class AddObjectChangesToVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :versions, :object_changes, :text
    add_index  :versions, :event
    add_index  :versions, :whodunnit
    add_index  :versions, :created_at
  end
end
