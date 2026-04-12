class AddNotesToMeters < ActiveRecord::Migration[8.1]
  def change
    add_column :meters, :notes, :text
  end
end
