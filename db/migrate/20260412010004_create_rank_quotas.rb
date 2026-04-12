# frozen_string_literal: true

class CreateRankQuotas < ActiveRecord::Migration[8.1]
  def change
    create_table :rank_quotas do |t|
      t.integer :rank_group, null: false # 1..7
      t.string :rank_name, null: false
      t.decimal :quota_kw, precision: 10, scale: 2, null: false
      t.date :effective_from, null: false

      t.timestamps
    end

    add_index :rank_quotas, %i[rank_group effective_from], unique: true
  end
end
