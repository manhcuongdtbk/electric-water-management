class PeriodComparison
  Row = Struct.new(:contact_point, :calc_a, :calc_b, :diff, :note, keyword_init: true)

  COMPARE_ATTRS = %i[
    total_personnel residential_standard water_pump_standard total_standard
    total_deduction remaining_standard residential_usage water_pump_usage total_usage
    deficit surplus deficit_amount surplus_amount
  ].freeze

  def initialize(ability:, period_a:, period_b:)
    @ability = ability
    @period_a = period_a
    @period_b = period_b
  end

  def call
    scope_a = Calculation.accessible_by(@ability).where(period_id: @period_a.id)
    scope_b = Calculation.accessible_by(@ability).where(period_id: @period_b.id)
    ids_a = scope_a.pluck(:contact_point_id)
    ids_b = scope_b.pluck(:contact_point_id)
    cp_ids = (ids_a + ids_b).uniq
    return [] if cp_ids.empty?

    cps = ContactPoint.where(id: cp_ids)
                      .includes(:unit, :zone, :block, :group)
                      .index_by(&:id)
    calcs_a = scope_a.where(contact_point_id: cp_ids).index_by(&:contact_point_id)
    calcs_b = scope_b.where(contact_point_id: cp_ids).index_by(&:contact_point_id)

    rows = cp_ids.map do |id|
      a = calcs_a[id]
      b = calcs_b[id]
      note = if a && b
               nil
             elsif a
               "chỉ có ở kỳ #{label(@period_a)}"
             else
               "mới ở kỳ #{label(@period_b)}"
             end
      Row.new(
        contact_point: cps[id],
        calc_a: a,
        calc_b: b,
        diff: (a && b) ? diff_struct(a, b) : nil,
        note: note
      )
    end
    sort_rows(rows)
  end

  private

  def diff_struct(a, b)
    COMPARE_ATTRS.each_with_object({}) do |attr, h|
      av = a.send(attr) || 0
      bv = b.send(attr) || 0
      h[attr] = bv - av
    end
  end

  def sort_rows(rows)
    rows.sort_by do |r|
      cp = r.contact_point
      [
        cp&.effective_zone&.name.to_s,
        cp&.unit&.name.to_s,
        cp&.block&.name.to_s,
        cp&.group&.name.to_s,
        cp&.name.to_s
      ]
    end
  end

  def label(period)
    "#{period.month}/#{period.year}"
  end
end
