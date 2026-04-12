# frozen_string_literal: true

class CreatePersonnel < ActiveRecord::Migration[8.1]
  def change
    create_table :personnel do |t|
      t.references :contact_point, null: false, foreign_key: true
      t.references :monthly_period, null: false, foreign_key: true

      # 7 rank groups — number of people in each
      t.integer :rank1_count, null: false, default: 0 # 570 kW - Command
      t.integer :rank2_count, null: false, default: 0 # 440 kW - Brigade/Regiment command
      t.integer :rank3_count, null: false, default: 0 # 305 kW - Battalion command
      t.integer :rank4_count, null: false, default: 0 # 130 kW - Company/Platoon command
      t.integer :rank5_count, null: false, default: 0 # 210 kW - Agency/Headquarters
      t.integer :rank6_count, null: false, default: 0 # 110 kW - Battalion/Company
      t.integer :rank7_count, null: false, default: 0 #  24 kW - NCOs/Soldiers/Students

      t.timestamps
    end

    add_index :personnel, %i[contact_point_id monthly_period_id], unique: true,
              name: "idx_personnel_on_contact_point_and_period"
  end
end
