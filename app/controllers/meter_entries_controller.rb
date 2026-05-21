class MeterEntriesController < ApplicationController
  include MeterReadingEntry

  private

  def contact_point_type_condition
    { contact_points: { contact_point_type: %w[residential public] } }
  end

  def after_update_path
    meter_entries_path
  end
end
