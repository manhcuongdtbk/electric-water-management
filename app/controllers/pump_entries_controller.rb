class PumpEntriesController < ApplicationController
  include MeterReadingEntry

  private

  def contact_point_type_condition
    { contact_points: { contact_point_type: "water_pump" } }
  end

  def after_update_path
    pump_entries_path
  end
end
