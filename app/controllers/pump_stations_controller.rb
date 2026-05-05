class PumpStationsController < ApplicationController
  def index
    authorize! :read, PumpStation
    @pump_stations = PumpStation
                       .includes(pump_station_assignments: :organization)
                       .ordered
  end
end
