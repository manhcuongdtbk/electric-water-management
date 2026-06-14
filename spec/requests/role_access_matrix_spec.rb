# Chiều 2-3 — ma trận truy cập: mọi trang × 6 vai trò (200 hay redirect).
# "Ai vào được trang nào". Hành vi chi tiết per vai trò (data scoping, disabled
# input, ẩn/hiện cột) test ở spec riêng per trang — và độ phủ hành vi đó theo dõi
# ở #373; KHÔNG thuộc file này.
#
# Cả test access lẫn guardrail đủ-phủ (#359, ADR-056) sinh từ MỘT nguồn:
# RoleAccessMatrix::PAGES (spec/support/role_access_matrix.rb). Thêm một trang mà
# quên khai → block "completeness" đỏ; trang khai thiếu vai trò → cũng đỏ.
require "rails_helper"

RSpec.describe "Role access matrix (chiều 2-3)", type: :request do
  let!(:zone) { create(:zone, name: "Khu vực test") }
  let!(:unit_manager) { create(:unit, zone: zone, name: "Đơn vị quản lý") }
  let!(:unit_other) { create(:unit, zone: zone, name: "Đơn vị khác") }
  let!(:period) { create(:period, closed: false) }

  # unit_manager là đơn vị quản lý khu vực (UA-ZM/CMD-ZM); unit_other thì không.
  # Set tường minh thay vì dựa vào thứ tự auto-assign (AGENTS — quy ước test).
  before { zone.update!(manager_unit_id: unit_manager.id) }

  def build_user(role)
    case role
    when :sa     then create(:user, :system_admin)
    when :ua_zm  then create(:user, :unit_admin, unit: unit_manager)
    when :ua     then create(:user, :unit_admin, unit: unit_other)
    when :cmd_zm then create(:user, :commander, unit: unit_manager)
    when :cmd    then create(:user, :commander, unit: unit_other)
    when :tech   then create(:user, :technician)
    else raise ArgumentError, "Unknown role #{role.inspect}"
    end
  end

  def assert_access(role, path_helper, expected)
    label = RoleAccessMatrix::ROLE_LABELS[role]
    sign_in build_user(role)
    get public_send(path_helper)
    case expected
    when :ok
      expect(response).to have_http_status(:ok),
        "Expected 200 for #{label} on #{path_helper}, got #{response.status}"
    when :redirect
      expect(response).to have_http_status(:redirect),
        "Expected redirect for #{label} on #{path_helper}, got #{response.status}"
    end
  end

  # Sinh test: gom theo category cho dễ đọc output, mỗi trang 6 vai trò.
  RoleAccessMatrix::PAGES.group_by { |_slug, config| config[:category] }.each do |category, pages|
    describe category do
      pages.each do |slug, config|
        describe slug do
          RoleAccessMatrix::ROLES.each do |role|
            expected = config[:expect].fetch(role)
            it "#{RoleAccessMatrix::ROLE_LABELS[role]} → #{expected}" do
              assert_access(role, config[:path], expected)
            end
          end
        end
      end
    end
  end

  # --- Guardrail #359: ép đủ TRANG và đủ 6 VAI TRÒ -------------------------
  describe "completeness (guardrail #359)" do
    it "ma trận phủ mọi controller-trang (không thiếu, không stale)" do
      Rails.application.eager_load!
      # App page controllers = ApplicationController descendants, minus the Devise
      # auth infrastructure (Devise.parent_controller makes the whole Devise tree —
      # incl. Users::SessionsController — descend from ApplicationController). Those
      # are framework/auth controllers, not role-differentiated pages, so filter
      # them structurally rather than listing each Devise subclass.
      actual = ApplicationController.descendants
                                    .reject { |klass| klass <= DeviseController }
                                    .map(&:name)
      gaps = RoleAccessMatrix.coverage_gaps(actual)

      expect(gaps[:missing]).to be_empty,
        "Controller-trang chưa có trong ma trận: #{gaps[:missing].join(', ')}. " \
        "Thêm vào RoleAccessMatrix::PAGES (test đủ 6 vai trò) — hoặc nếu không phân vai trò, " \
        "thêm vào RoleAccessMatrix::EXCLUDED_CONTROLLERS kèm lý do."
      expect(gaps[:stale]).to be_empty,
        "Entry ma trận không còn controller tương ứng (đổi tên/xóa?): #{gaps[:stale].join(', ')}."
    end

    it "mỗi trang nêu kỳ vọng cho đủ 6 vai trò" do
      gaps = RoleAccessMatrix.role_gaps
      expect(gaps).to be_empty,
        "Trang thiếu vai trò: #{gaps.map { |slug, roles| "#{slug} (#{roles.join(', ')})" }.join('; ')}."
    end
  end
end
