module ApplicationHelper
  METER_TYPE_BADGE_CLASSES = {
    "normal"       => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800",
    "public_meter" => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700",
    "pump_station" => "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-cyan-100 text-cyan-800"
  }.freeze

  def meter_type_badge_class(type)
    METER_TYPE_BADGE_CLASSES.fetch(type.to_s, "inline-flex px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-700")
  end
end
