class CreateMeters < ActiveRecord::Migration[8.1]
  def change
    create_table :meters do |t|
      t.string :name, null: false
      t.references :contact_point, null: false, foreign_key: true
      t.boolean :no_loss, null: false, default: false
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :meters, [:name, :contact_point_id], unique: true
    add_index :meters, :discarded_at
  end
end
