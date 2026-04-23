module AuditLogsHelper
  EXCLUDED_FIELDS = %w[id created_at updated_at].freeze

  def humanize_changes(version)
    changes = version.object_changes
    return nil if changes.blank?

    model_key = version.item_type.underscore
    changes.except(*EXCLUDED_FIELDS).filter_map do |field, (old_val, new_val)|
      field_label = I18n.t("activerecord.attributes.#{model_key}.#{field}", default: field.humanize)
      old_str = format_change_value(old_val)
      new_str = format_change_value(new_val)
      "#{field_label}: #{old_str} → #{new_str}"
    end
  end

  def event_badge(event)
    label = I18n.t("audit_log.events.#{event}", default: event.humanize)
    content_tag(:span, label, class: "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{event_badge_classes(event)}")
  end

  def item_type_label(item_type)
    I18n.t("audit_log.item_types.#{item_type}", default: item_type.humanize)
  end

  private

  def event_badge_classes(event)
    case event
    when "create"  then "bg-green-100 text-green-800"
    when "update"  then "bg-amber-100 text-amber-800"
    when "destroy" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-700"
    end
  end

  def format_change_value(val)
    return "(trống)" if val.nil?
    return val.to_s if val.is_a?(TrueClass) || val.is_a?(FalseClass)

    val.to_s.truncate(60)
  end
end
