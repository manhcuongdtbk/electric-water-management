class SeparateNoLossFromMeterType < ActiveRecord::Migration[8.1]
  def up
    add_column :meters, :no_loss, :boolean, default: false, null: false

    # Backfill: previously enum value 3 (`no_loss`) collapses into
    # meter_type = 0 (`normal`) with no_loss = true.
    Meter.where(meter_type: 3).update_all(meter_type: 0, no_loss: true)
  end

  def down
    Meter.where(no_loss: true).update_all(meter_type: 3)
    remove_column :meters, :no_loss
  end
end
