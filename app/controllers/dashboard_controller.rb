class DashboardController < ApplicationController
  include BusinessRoleRequired

  def show
    @period = current_period
    if @period.nil?
      @no_period = true
      return
    end

    @summary = DashboardSummary.new(user: current_user,
                                    ability: current_ability,
                                    period: @period).call
  end
end
