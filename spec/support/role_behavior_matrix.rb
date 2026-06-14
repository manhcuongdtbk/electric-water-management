# Single source of truth for the role × page × behavior-dimension matrix
# (guardrail #373, ADR-058). Sibling to RoleAccessMatrix (#359, access only).
#
# RoleAccessMatrix says WHO can open each page (200 vs redirect). This module
# says, for each page, which detailed per-role BEHAVIORS are tested:
#   - data_scoping        — non-SA sees only its unit/zone data
#   - zone_unit_columns   — SA sees Khu vực/Đơn vị columns, non-SA does not
#   - commander_readonly  — CMD/CMD-ZM: inputs disabled + Lưu hidden/disabled
#   - zone_manager_variant— UA-ZM/CMD-ZM behave differently once both are IN
#
# Each (page, dimension) is either { applies: {params} } or { na: "reason" }.
# The generated spec (spec/requests/role_behavior_matrix_spec.rb) runs the real
# assertions (in shared examples) for every `applies`, and asserts completeness:
# every access-matrix page declares all 4 dimensions, every `na` carries a
# reason, every `applies` names a scenario. Pure policy functions live here so
# the guardrail can be unit-tested with synthetic input (spec/lib/...).
module RoleBehaviorMatrix
  DIMENSIONS = %i[data_scoping zone_unit_columns commander_readonly zone_manager_variant].freeze

  # slug => { dimension => { applies: {scenario:, ...} } | { na: "reason" } }
  # slug uses the SAME vocabulary as RoleAccessMatrix::PAGES (single source).
  # Filled fully in Task 6; starts with one page so the functions have data.
  BEHAVIORS = {
    "blocks" => {
      data_scoping:         { applies: { scenario: :blocks } },
      zone_unit_columns:    { applies: { scenario: :blocks } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form new/edit; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "blocks không có hành vi riêng cho zone-manager — UA-ZM hành xử như UA." }
    }
  }.freeze

  module_function

  # Pages declared in the access matrix but missing from BEHAVIORS (forgot to
  # declare behavior for a new page), and stale BEHAVIORS entries with no
  # matching access page. access_slugs defaults to the real access matrix.
  def coverage_gaps(access_slugs = RoleAccessMatrix::PAGES.keys, behaviors = BEHAVIORS)
    declared = behaviors.keys
    { missing: (access_slugs - declared).sort, stale: (declared - access_slugs).sort }
  end

  # Pages whose entry does not declare all 4 dimensions.
  # Returns { slug => [missing_dimension, ...] } (empty when complete).
  def dimension_gaps(behaviors = BEHAVIORS)
    behaviors.each_with_object({}) do |(slug, dims), gaps|
      missing = DIMENSIONS - dims.keys
      gaps[slug] = missing unless missing.empty?
    end
  end

  # Entries that are malformed: neither a valid `applies` (Hash with :scenario)
  # nor a valid `na` (non-empty String reason). Returns { slug => [dimension] }.
  def invalid_entries(behaviors = BEHAVIORS)
    behaviors.each_with_object({}) do |(slug, dims), bad|
      dims.each do |dimension, entry|
        next if valid_applies?(entry) || valid_na?(entry)
        (bad[slug] ||= []) << dimension
      end
    end
  end

  def valid_applies?(entry)
    entry.is_a?(Hash) && entry.key?(:applies) &&
      entry[:applies].is_a?(Hash) && entry[:applies][:scenario].is_a?(Symbol)
  end

  def valid_na?(entry)
    entry.is_a?(Hash) && entry.key?(:na) &&
      entry[:na].is_a?(String) && !entry[:na].strip.empty?
  end
end
