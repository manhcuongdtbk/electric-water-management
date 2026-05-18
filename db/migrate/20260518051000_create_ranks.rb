class CreateRanks < ActiveRecord::Migration[8.1]
  def change
    create_table :ranks do |t|
      t.string :name, null: false
      t.decimal :quota, null: false
      t.integer :position, null: false
      t.references :period, null: false, foreign_key: true
      t.timestamps
    end
  end
end
