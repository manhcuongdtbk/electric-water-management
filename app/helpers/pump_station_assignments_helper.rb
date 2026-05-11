module PumpStationAssignmentsHelper
  # Compact label for an assignment row: target name + a small type badge,
  # plus the parent org name for a ContactPoint so admins can disambiguate
  # equally-named đầu mối across units.
  def pump_station_assignments_target_label(assignment)
    target = assignment.assignable
    return "" unless target

    type_key   = assignment.assignable_type.underscore
    type_label = t("pump_station_assignments.type_badge.#{type_key}")
    badge      = badge_for_assignable_type(assignment.assignable_type, type_label)

    main =
      if target.is_a?(ContactPoint) && target.organization
        "#{target.name} — #{target.organization.name}"
      else
        target.name
      end

    safe_join([ content_tag(:span, main, class: "text-gray-900"), " ".html_safe, badge ])
  end

  # Sort key — Organization first, then ContactPoint, then WorkGroup;
  # within each group, by the target's `position` when available, else 0,
  # then by name for stability.
  def pump_station_assignment_sort_key(assignment)
    type_order = { "Organization" => 0, "ContactPoint" => 1, "WorkGroup" => 2 }
                   .fetch(assignment.assignable_type, 99)
    target   = assignment.assignable
    position = target.respond_to?(:position) ? target.position.to_i : 0
    name     = target.respond_to?(:name) ? target.name.to_s : ""

    [ type_order, position, name ]
  end

  private

  def badge_for_assignable_type(type, label)
    color = case type
    when "Organization" then "bg-slate-100 text-slate-700"
    when "ContactPoint" then "bg-blue-100 text-blue-700"
    when "WorkGroup"    then "bg-emerald-100 text-emerald-700"
    else "bg-gray-100 text-gray-700"
    end

    content_tag(:span, label,
                class: "inline-block rounded-full px-2 py-0.5 text-xs font-medium #{color}")
  end
end
