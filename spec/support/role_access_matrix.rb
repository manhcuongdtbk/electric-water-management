# Single source of truth for the role × page access matrix (guardrail #359, ADR-056).
#
# This module holds the canonical data (which page expects which HTTP outcome for
# each of the 6 real roles) AND the pure policy functions that the guardrail spec
# uses to detect coverage gaps. Keeping the policy as pure functions lets us test
# the guardrail itself with synthetic input (spec/lib/role_access_matrix_spec.rb),
# while spec/requests/role_access_matrix_spec.rb generates the real access tests
# and the completeness assertion from the same PAGES hash.
#
# Scope is access only (200 vs redirect / chiều 2-3). Detailed per-role behavior
# (data scoping, column visibility, commander read-only, zone-manager variants)
# is tracked separately in #373.
module RoleAccessMatrix
  # The 6 real roles (docs/V2_HANH_VI_HE_THONG.md mục 1). UA-ZM / CMD-ZM are the
  # zone-manager variants of unit_admin / commander. Defined once, here.
  ROLES = %i[sa ua_zm ua cmd_zm cmd tech].freeze

  # Human-facing labels for the 6 roles (test descriptions / failure messages).
  ROLE_LABELS = { sa: "SA", ua_zm: "UA-ZM", ua: "UA", cmd_zm: "CMD-ZM", cmd: "CMD", tech: "TECH" }.freeze

  # App page controllers that are intentionally NOT role-differentiated pages, so
  # they sit outside the access matrix:
  # - PasswordChangesController: self-service password change, every authenticated
  #   role may use it the same way (no role-specific access decision).
  # The Devise auth tree (Devise::*, DeviseController, Users::SessionsController)
  # also descends from ApplicationController (via Devise.parent_controller) but is
  # filtered STRUCTURALLY in the completeness spec (klass <= DeviseController), not
  # listed here. VersionController (ActionController::Base, public JSON) does not
  # descend from ApplicationController, so it never reaches the check.
  EXCLUDED_CONTROLLERS = %w[PasswordChangesController].freeze

  # slug => { category:, path:, expect: { role => :ok | :redirect } }
  # slug is the controller name in snake_case without the _controller suffix
  # (e.g. "contact_points" <-> ContactPointsController).
  PAGES = {
    # Xem kết quả — mọi vai trò nghiệp vụ xem được, TECH bị chặn (không thấy dữ liệu nghiệp vụ).
    "dashboard"          => { category: "Xem kết quả", path: :dashboard_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "billing"            => { category: "Xem kết quả", path: :billing_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "history"            => { category: "Xem kết quả", path: :history_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },

    # Nhập liệu — electricity_supply & pump_allocations chỉ đơn vị quản lý khu vực (UA-ZM/CMD-ZM).
    "electricity_supply" => { category: "Nhập liệu", path: :electricity_supply_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :redirect, cmd_zm: :ok, cmd: :redirect, tech: :redirect } },
    "meter_entries"      => { category: "Nhập liệu", path: :meter_entries_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "pump_entries"       => { category: "Nhập liệu", path: :pump_entries_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },

    # Khai báo — cấu trúc nghiệp vụ: mọi vai trò nghiệp vụ vào được, TECH chặn.
    "contact_points"     => { category: "Khai báo", path: :contact_points_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "blocks"             => { category: "Khai báo", path: :blocks_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "groups"             => { category: "Khai báo", path: :groups_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },
    "unit_config"        => { category: "Khai báo", path: :unit_config_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :ok, cmd_zm: :ok, cmd: :ok, tech: :redirect } },

    # Thiết lập — phần lớn chỉ SA; pump_allocations mở cho đơn vị quản lý khu vực.
    "zones"              => { category: "Thiết lập", path: :zones_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
    "units"              => { category: "Thiết lập", path: :units_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
    "pump_allocations"   => { category: "Thiết lập", path: :pump_allocations_path,
                             expect: { sa: :ok, ua_zm: :ok, ua: :redirect, cmd_zm: :ok, cmd: :redirect, tech: :redirect } },
    "pricing"            => { category: "Thiết lập", path: :pricing_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },
    "ranks"              => { category: "Thiết lập", path: :ranks_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :redirect } },

    # Hệ thống — tài khoản/nhật ký/sao lưu: SA và/hoặc TECH; backups chỉ TECH.
    "users"              => { category: "Hệ thống", path: :users_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } },
    "audit_logs"         => { category: "Hệ thống", path: :audit_logs_path,
                             expect: { sa: :ok, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } },
    "backups"            => { category: "Hệ thống", path: :backups_path,
                             expect: { sa: :redirect, ua_zm: :redirect, ua: :redirect, cmd_zm: :redirect, cmd: :redirect, tech: :ok } }
  }.freeze

  module_function

  # "contact_points" -> "ContactPointsController"
  def controller_name_for(slug)
    "#{slug.split('_').map(&:capitalize).join}Controller"
  end

  # Controller names declared by the matrix.
  def declared_controllers
    PAGES.keys.map { |slug| controller_name_for(slug) }
  end

  # Compare the real set of page-controller names against the matrix.
  # Returns { missing:, stale: }:
  #   missing — controllers that exist but have no matrix entry (a new page was
  #             forgotten); excluded controllers never count as missing.
  #   stale   — matrix entries whose controller no longer exists (renamed/deleted).
  def coverage_gaps(actual_controller_names)
    actual = actual_controller_names - EXCLUDED_CONTROLLERS
    declared = declared_controllers
    { missing: (actual - declared).sort, stale: (declared - actual).sort }
  end

  # Pages whose expectation hash does not cover all 6 roles.
  # Returns { slug => [missing_role, ...] } (empty when fully covered).
  def role_gaps
    PAGES.each_with_object({}) do |(slug, config), gaps|
      missing = ROLES - config.fetch(:expect).keys
      gaps[slug] = missing unless missing.empty?
    end
  end
end
