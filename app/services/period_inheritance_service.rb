class PeriodInheritanceService
  attr_reader :new_period

  def initialize(new_period)
    @new_period = new_period
  end

  # Copies all personnel records from the immediately preceding period into new_period.
  # Skips contact points that already have a record for new_period.
  # Returns the number of records inherited (0 if no previous period exists).
  def call
    previous = previous_period
    return 0 unless previous

    inherited = 0

    Personnel.for_period(previous.id).find_each do |prev|
      Personnel.find_or_create_by!(
        contact_point_id: prev.contact_point_id,
        monthly_period_id: new_period.id
      ) do |p|
        Personnel::RANK_COLUMNS.each { |col| p[col] = prev.public_send(col) }
        # reviewed_at intentionally left nil — inherited records start as unreviewed
      end
      inherited += 1
    end

    inherited
  end

  private

  def previous_period
    MonthlyPeriod
      .where("year * 12 + month < ?", new_period.year * 12 + new_period.month)
      .order(year: :desc, month: :desc)
      .first
  end
end
