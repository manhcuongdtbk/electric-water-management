class AddManagerUnitToZones < ActiveRecord::Migration[8.1]
  def change
    add_reference :zones, :manager_unit, foreign_key: { to_table: :units }, null: true
  end
end
