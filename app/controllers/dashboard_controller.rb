class DashboardController < ApplicationController
  include BusinessRoleRequired
  include FreshnessIndicatable

  def show
    @period = current_period
    if @period.nil?
      @no_period = true
      return
    end

    @summary = DashboardSummary.new(user: current_user,
                                    ability: current_ability,
                                    period: @period).call
    assign_freshness_states(@period)
  end
end
