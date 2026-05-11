class CreateMainMeters < ActiveRecord::Migration[8.1]
  def change
    create_table :main_meters do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :notes
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :main_meters, :name, unique: true
    add_index :main_meters, :code, unique: true
  end
end
