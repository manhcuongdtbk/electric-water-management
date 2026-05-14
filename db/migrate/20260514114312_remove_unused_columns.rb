class RemoveUnusedColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :main_meters,          :notes,         :text
    remove_column :main_meters,          :position,      :integer
    remove_column :meters,               :notes,         :text
    remove_column :meters,               :serial_number, :string
    remove_column :meters,               :position,      :integer
    remove_column :work_groups,          :notes,         :text
    remove_column :work_groups,          :position,      :integer
    remove_column :organizations,        :position,      :integer
    remove_column :contact_points,       :position,      :integer
    remove_column :monthly_calculations, :notes,         :text
  end
end
