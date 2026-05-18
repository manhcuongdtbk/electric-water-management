class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.string :name, null: false
      t.references :unit, null: false, foreign_key: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :blocks, [:name, :unit_id], unique: true
    add_index :blocks, :discarded_at
  end
end
