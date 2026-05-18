class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.references :unit, null: false, foreign_key: true
      t.references :block, foreign_key: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :groups, [:name, :unit_id], unique: true
    add_index :groups, :discarded_at
  end
end
