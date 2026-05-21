module Billing
  class Query
    SORT_ORDER = <<~SQL.squish.freeze
      COALESCE(unit_zones.name, cp_zones.name) ASC,
      units.name ASC NULLS LAST,
      blocks.name ASC NULLS LAST,
      groups.name ASC NULLS LAST,
      contact_points.name ASC
    SQL

    SUMMARY_ATTRS = %i[
      total_personnel residential_standard water_pump_standard total_standard
      savings_deduction loss_deduction division_public_deduction unit_public_deduction
      other_deduction total_deduction remaining_standard residential_usage
      water_pump_usage total_usage surplus deficit surplus_amount deficit_amount
    ].freeze

    def self.base_scope(period, ability)
      Calculation.where(period_id: period.id)
        .joins(:contact_point)
        .joins("LEFT JOIN units ON units.id = contact_points.unit_id")
        .joins("LEFT JOIN blocks ON blocks.id = contact_points.block_id")
        .joins("LEFT JOIN groups ON groups.id = contact_points.group_id")
        .joins("LEFT JOIN zones unit_zones ON unit_zones.id = units.zone_id")
        .joins("LEFT JOIN zones cp_zones ON cp_zones.id = contact_points.zone_id")
        .where(contact_points: { contact_point_type: "residential" })
        .merge(ContactPoint.kept)
        .accessible_by(ability)
        .includes(contact_point: [:block, :group, :zone, { unit: :zone }])
    end

    def self.apply_filters(scope, zone:, unit:, q: nil)
      if zone
        scope = scope.where(
          "contact_points.zone_id = :zid OR units.zone_id = :zid",
          zid: zone.id
        )
      end
      scope = scope.where("contact_points.unit_id = ?", unit.id) if unit
      if q.present?
        sanitized = ActiveRecord::Base.sanitize_sql_like(q.strip)
        scope = scope.where("contact_points.name ILIKE ?", "%#{sanitized}%")
      end
      scope
    end

    def self.summary(scope, period:)
      bare = scope.unscope(:order, :limit, :offset, :includes, :select)
      select_sql = SUMMARY_ATTRS.map { |a| "COALESCE(SUM(calculations.#{a}), 0) AS #{a}" }.join(", ")
      relation = bare.select(select_sql)
      row = ActiveRecord::Base.connection.exec_query(relation.to_sql).first || {}

      summary = SUMMARY_ATTRS.each_with_object({}) do |attr, h|
        h[attr] = row[attr.to_s] || 0
      end

      cp_ids = bare.pluck(:contact_point_id)
      rank_totals = PersonnelEntry
                      .where(period_id: period.id, contact_point_id: cp_ids)
                      .group(:rank_id)
                      .sum(:count)
      summary[:personnel_by_rank] = Hash.new(0).merge(rank_totals)
      summary
    end
  end
end
