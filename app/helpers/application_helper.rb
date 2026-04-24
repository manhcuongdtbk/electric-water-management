module ApplicationHelper
  HISTORY_INTEGER_COLS = %i[total_personnel unit_price total_amount].freeze

  def format_history_value(calc, col)
    val = calc.public_send(col)
    if HISTORY_INTEGER_COLS.include?(col)
      number_with_precision(val, precision: 0, delimiter: ",")
    else
      number_with_precision(val, precision: 2, delimiter: ",")
    end
  end

  def rank_names
    @rank_names ||= RankQuota.current_names
  end

  def history_column_label(col)
    if (m = col.to_s.match(/\Arank(\d)_kw\z/))
      "#{rank_names[m[1].to_i]} (kW)"
    else
      t("history.columns.#{col}")
    end
  end

  METER_TYPE_BADGE_CLASSES = {
    "normal"       => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800",
    "public_meter" => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700",
    "pump_station" => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-cyan-100 text-cyan-800"
  }.freeze

  def meter_type_badge_class(type)
    METER_TYPE_BADGE_CLASSES.fetch(type.to_s, "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700")
  end
end
