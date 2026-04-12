# frozen_string_literal: true

class CreateMeters < ActiveRecord::Migration[8.1]
  def change
    create_table :meters do |t|
      t.string :name, null: false
      t.string :serial_number
      t.integer :meter_type, null: false, default: 0 # 0=normal, 1=public, 2=pump_station
      t.references :contact_point, foreign_key: true # nullable for pump station meters
      t.references :organization, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :meters, :meter_type
    add_index :meters, :serial_number
  end
end
