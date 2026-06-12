class CreateLossSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :loss_summaries do |t|
      t.references :zone, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true
      t.decimal :a, null: false
      t.decimal :b, null: false
      t.decimal :c, null: false
      t.timestamps
    end
    add_index :loss_summaries, [:zone_id, :period_id], unique: true
  end
end
