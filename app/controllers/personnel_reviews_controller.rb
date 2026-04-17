class PersonnelReviewsController < ApplicationController
  before_action :set_period
  before_action :set_target_org

  def show
    authorize! :read, Personnel
    set_personnel_rows if @period && @target_org
  end

  private

  def set_period
    @periods = MonthlyPeriod.ordered
    @period = if params[:period_id].present?
      @periods.find_by(id: params[:period_id])
    else
      @periods.first
    end
  end

  def set_target_org
    if current_user.admin_level1?
      @all_orgs = Organization.units.ordered
      @target_org = if params[:org_id].present?
        @all_orgs.find_by(id: params[:org_id])
      else
        @all_orgs.first
      end
    else
      @target_org = current_user.organization
    end
  end

  def previous_period(period)
    MonthlyPeriod
      .where("year * 12 + month < ?", period.year * 12 + period.month)
      .order(year: :desc, month: :desc)
      .first
  end

  # Builds @personnel_rows: array of hashes with:
  #   contact_point:, personnel:, prev_personnel:, changed:
  def set_personnel_rows
    contact_points = @target_org.contact_points.ordered

    prev_period = previous_period(@period)

    prev_map = if prev_period
      Personnel
        .for_period(prev_period.id)
        .by_organization(@target_org.id)
        .index_by(&:contact_point_id)
    else
      {}
    end

    current_map = Personnel
      .for_period(@period.id)
      .by_organization(@target_org.id)
      .index_by(&:contact_point_id)

    @personnel_rows = contact_points.map do |cp|
      current  = current_map[cp.id]
      prev     = prev_map[cp.id]

      changed = if current && prev
        Personnel::RANK_COLUMNS.any? { |col| current.public_send(col) != prev.public_send(col) }
      else
        false
      end

      { contact_point: cp, personnel: current, prev_personnel: prev, changed: changed }
    end
  end
end
