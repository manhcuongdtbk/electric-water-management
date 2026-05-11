class AddMainMeterIdToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :organizations, :main_meter, null: true, foreign_key: true, index: true
  end
end
