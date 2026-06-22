# Single source of truth for the role × page × behavior-dimension matrix
# (guardrail #373, ADR-058). Sibling to RoleAccessMatrix (#359, access only).
#
# RoleAccessMatrix says WHO can open each page (200 vs redirect). This module
# says, for each page, which detailed per-role BEHAVIORS are tested:
#   - data_scoping        — non-SA sees only its unit/zone data
#   - zone_unit_columns   — SA sees Khu vực/Đơn vị columns, non-SA does not
#   - commander_readonly  — CMD/CMD-ZM/DC: inputs disabled + Lưu hidden/disabled
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
  BEHAVIORS = {
    "dashboard" => {
      data_scoping:         { na: "Dashboard render partial khác hẳn theo vai trò (_system_admin vs đơn vị), không phải bảng cùng-trang để scope; phủ ở dashboard_spec + access #359." },
      zone_unit_columns:    { na: "Cột theo partial-riêng-mỗi-vai-trò, không phải ẩn/hiện cột cùng bảng." },
      commander_readonly:   { na: "Trang chỉ xem — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem tổng hợp như UA — không có biến thể riêng." }
    },
    "blocks" => {
      data_scoping:         { applies: { scenario: :blocks } },
      zone_unit_columns:    { applies: { scenario: :blocks } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form new/edit; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "Khác biệt UA-ZM (đọc Block toàn khu vực quản lý, Task 8b #319) vs UA (chỉ đơn vị mình) là thuần read-scope — đã ép ở data_scoping. Không có biến thể UI riêng (cột/filter) chỉ cho zone-manager." }
    },
    "groups" => {
      data_scoping:         { applies: { scenario: :groups } },
      zone_unit_columns:    { applies: { scenario: :groups } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form; index không có input nội dòng; nút Sửa/Thêm bị ẩn." },
      zone_manager_variant: { na: "Khác biệt UA-ZM (đọc Group toàn khu vực quản lý, Task 8b #319) vs UA (chỉ đơn vị mình) là thuần read-scope — đã ép ở data_scoping. Không có biến thể UI riêng (cột/filter) chỉ cho zone-manager." }
    },
    "contact_points" => {
      data_scoping:         { applies: { scenario: :contact_points_index } },
      zone_unit_columns:    { applies: { scenario: :contact_points_index } },
      commander_readonly:   { na: "Commander chỉ :read — không vào được form; index không có input nội dòng; nút Sửa/Thêm ẩn." },
      zone_manager_variant: { applies: { scenario: :contact_points } }
    },
    "meter_entries" => {
      data_scoping:         { applies: { scenario: :meter_entries_data } },
      zone_unit_columns:    { applies: { scenario: :meter_entries_data } },
      commander_readonly:   { applies: { scenario: :meter_entries } },
      zone_manager_variant: { na: "UA-ZM nhập liệu như UA — không có biến thể riêng." }
    },
    "billing" => {
      data_scoping:         { applies: { scenario: :billing } },
      zone_unit_columns:    { applies: { scenario: :billing } },
      commander_readonly:   { na: "Trang chỉ xem kết quả — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem bảng tính như UA — không có biến thể riêng." }
    },
    "history" => {
      data_scoping:         { na: "History range mode chỉ render dòng tổng hợp cấp kỳ (không tên đầu mối/đơn vị để phân biệt scope ở request-level); scoping non-SA của history đã được kiểm ở spec/requests/dimension_coverage_spec.rb (UA xem compare/range)." },
      zone_unit_columns:    { na: "History LUÔN hiện cả cột Khu vực + Đơn vị mọi vai trò (so sánh kỳ cần context đầy đủ) — không ẩn theo vai trò." },
      commander_readonly:   { na: "Trang chỉ xem — không có input nghiệp vụ để disable." },
      zone_manager_variant: { na: "UA-ZM xem lịch sử như UA — không có biến thể riêng." }
    },
    "electricity_supply" => {
      data_scoping:         { applies: { scenario: :electricity_supply_data } },
      zone_unit_columns:    { na: "Cột Khu vực hiện cho mọi vai trò có quyền (UA-ZM/CMD-ZM), không gated theo SA." },
      commander_readonly:   { applies: { scenario: :electricity_supply } },
      zone_manager_variant: { na: "Khác biệt UA-ZM vs UA là thuần access (UA bị redirect) — đã ép ở #359." }
    },
    "pump_entries" => {
      data_scoping:         { applies: { scenario: :pump_entries_data } },
      zone_unit_columns:    { applies: { scenario: :pump_entries_data } },
      commander_readonly:   { applies: { scenario: :pump_entries_commander } },
      zone_manager_variant: { na: "UA-ZM nhập liệu như UA — không có biến thể riêng." }
    },
    "pump_allocations" => {
      data_scoping:         { applies: { scenario: :pump_allocations_data } },
      zone_unit_columns:    { na: "Cột Khu vực hiện cho mọi vai trò có quyền (UA-ZM/CMD-ZM), không gated theo SA." },
      commander_readonly:   { na: "CMD-ZM xem danh sách read-only (nút Sửa/Xóa ẩn), không có input nội dòng; form không truy cập được." },
      zone_manager_variant: { na: "Khác biệt UA-ZM vs UA là thuần access (UA bị redirect) — đã ép ở #359." }
    },
    "unit_config" => {
      data_scoping:         { na: "SA unit_config shows one unit at a time (dropdown pick); no single request renders all units' CP names simultaneously, so the SA-sees-all precondition in the shared example cannot be satisfied. Per-unit scoping is already covered in unit_config_spec.rb." },
      zone_unit_columns:    { na: "Trang cấu hình một đơn vị, không có bảng cross-zone/unit để ẩn cột." },
      commander_readonly:   { applies: { scenario: :unit_config_commander } },
      zone_manager_variant: { applies: { scenario: :unit_config_zm } }
    },
    "zones" => {
      data_scoping:         { na: "Chỉ SA/DC truy cập (access #359) — cả hai có scope toàn cục, không scope theo đơn vị." },
      zone_unit_columns:    { na: "Chỉ SA/DC truy cập — không có unit-scoped role để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359). DC read-only nhưng trang CRUD không có input nội dòng." },
      zone_manager_variant: { na: "Chỉ SA/DC — không có biến thể ZM." }
    },
    "units" => {
      data_scoping:         { na: "Chỉ SA/DC truy cập — cả hai có scope toàn cục, không scope theo đơn vị." },
      zone_unit_columns:    { na: "Chỉ SA/DC truy cập — không có unit-scoped role để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359). DC read-only nhưng trang CRUD không có input nội dòng." },
      zone_manager_variant: { na: "Chỉ SA/DC — không có biến thể ZM." }
    },
    "pricing" => {
      data_scoping:         { na: "Chỉ SA/DC truy cập — cả hai có scope toàn cục, không scope theo đơn vị." },
      zone_unit_columns:    { na: "Chỉ SA/DC truy cập — không có unit-scoped role để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359). DC read-only nhưng trang CRUD không có input nội dòng." },
      zone_manager_variant: { na: "Chỉ SA/DC — không có biến thể ZM." }
    },
    "ranks" => {
      data_scoping:         { na: "Chỉ SA/DC truy cập — cả hai có scope toàn cục, không scope theo đơn vị." },
      zone_unit_columns:    { na: "Chỉ SA/DC truy cập — không có unit-scoped role để so cột." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359). DC read-only nhưng trang CRUD không có input nội dòng." },
      zone_manager_variant: { na: "Chỉ SA/DC — không có biến thể ZM." }
    },
    "users" => {
      data_scoping:         { na: "Quản trị tài khoản SA/TECH toàn cục — không scope theo đơn vị nghiệp vụ. DC không truy cập." },
      zone_unit_columns:    { na: "Bảng người dùng không có cột Khu vực/Đơn vị gated theo SA." },
      commander_readonly:   { na: "Commander và DC không truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Không có biến thể ZM cho quản trị tài khoản." }
    },
    "audit_logs" => {
      data_scoping:         { na: "Nhật ký hệ thống SA/DC/TECH toàn cục — không scope theo đơn vị nghiệp vụ." },
      zone_unit_columns:    { na: "Bảng nhật ký không có cột Khu vực/Đơn vị gated theo SA." },
      commander_readonly:   { na: "Commander không truy cập (redirect ở access #359). DC read-only nhưng trang chỉ xem — không có input." },
      zone_manager_variant: { na: "Không có biến thể ZM cho nhật ký." }
    },
    "backups" => {
      data_scoping:         { na: "Chỉ TECH truy cập — không scope dữ liệu nghiệp vụ." },
      zone_unit_columns:    { na: "Không có bảng dữ liệu nghiệp vụ với cột Khu vực/Đơn vị." },
      commander_readonly:   { na: "Chỉ TECH truy cập (redirect ở access #359)." },
      zone_manager_variant: { na: "Không có biến thể ZM cho sao lưu." }
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
