class CreateMainMeters < ActiveRecord::Migration[8.1]
  def change
    create_table :main_meters do |t|
      t.string :name, null: false
      t.references :zone, null: false, foreign_key: true
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :main_meters, :discarded_at
  end
end
