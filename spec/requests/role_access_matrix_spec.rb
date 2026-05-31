# Chiều 2 — kiểm thử vai trò: mọi trang × 6 role.
# File này cover "ai vào được trang nào" theo ma trận trong V2_CHIEU_TEST.md chiều 3.
# Behavior cụ thể per role (data scoping, disabled inputs) test ở spec riêng per page.
require "rails_helper"

RSpec.describe "Role access matrix (chiều 2)", type: :request do
  let!(:zone) { create(:zone, name: "Khu vực test") }
  let!(:unit_manager) { create(:unit, zone: zone, name: "Đơn vị quản lý") }
  let!(:unit_other) { create(:unit, zone: zone, name: "Đơn vị khác") }
  let!(:period) { create(:period, closed: false) }

  let(:sa) { create(:user, :system_admin) }
  let(:ua_zm) { create(:user, :unit_admin, unit: unit_manager) }
  let(:ua) { create(:user, :unit_admin, unit: unit_other) }
  let(:cmd_zm) { create(:user, :commander, unit: unit_manager) }
  let(:cmd) { create(:user, :commander, unit: unit_other) }
  let(:tech) { create(:user, :technician) }

  # zone auto-assigns manager to unit_manager (first unit in zone).
  # unit_other is NOT zone-manager.

  # Helper: test rằng role truy cập trang trả về 200 (hoặc redirect nếu expected)
  def expect_access(user, path, expected_status)
    sign_in user
    get path
    case expected_status
    when :ok
      expect(response).to have_http_status(:ok),
        "Expected 200 for #{user.role}#{' (zone-manager)' if Zone.kept.exists?(manager_unit_id: user.unit_id)} on #{path}, got #{response.status}"
    when :redirect
      expect(response).to have_http_status(:redirect),
        "Expected redirect for #{user.role} on #{path}, got #{response.status}"
    end
    reset!  # clear session between roles
  end

  describe "Xem kết quả" do
    describe "dashboard" do
      let(:path) { dashboard_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "billing" do
      let(:path) { billing_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "history" do
      let(:path) { history_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end
  end

  describe "Nhập liệu" do
    describe "electricity_supply" do
      let(:path) { electricity_supply_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → redirect")  { expect_access(ua, path, :redirect) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → redirect") { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "meter_entries" do
      let(:path) { meter_entries_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "pump_entries" do
      let(:path) { pump_entries_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end
  end

  describe "Khai báo" do
    describe "contact_points" do
      let(:path) { contact_points_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "blocks" do
      let(:path) { blocks_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "groups" do
      let(:path) { groups_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "unit_config" do
      let(:path) { unit_config_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → 200")      { expect_access(ua, path, :ok) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → 200")     { expect_access(cmd, path, :ok) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end
  end

  describe "Thiết lập" do
    describe "zones" do
      let(:path) { zones_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200 (xem khu vực mình quản lý)") { expect_access(ua_zm, path, :ok) }
      it("UA → redirect (không quản lý khu vực)") { expect_access(ua, path, :redirect) }
      it("CMD-ZM → 200 (xem khu vực mình quản lý)") { expect_access(cmd_zm, path, :ok) }
      it("CMD → redirect (không quản lý khu vực)") { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "units" do
      let(:path) { units_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")     { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect") { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect")     { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "pump_allocations" do
      let(:path) { pump_allocations_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → 200")   { expect_access(ua_zm, path, :ok) }
      it("UA → redirect (không quản lý khu vực)") { expect_access(ua, path, :redirect) }
      it("CMD-ZM → 200")  { expect_access(cmd_zm, path, :ok) }
      it("CMD → redirect (không quản lý khu vực)") { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "pricing" do
      let(:path) { pricing_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")     { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect") { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect")     { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end

    describe "ranks" do
      let(:path) { ranks_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")      { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect")  { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect")     { expect_access(cmd, path, :redirect) }
      it("TECH → redirect") { expect_access(tech, path, :redirect) }
    end
  end

  describe "Hệ thống" do
    describe "users" do
      let(:path) { users_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")  { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect") { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect") { expect_access(cmd, path, :redirect) }
      it("TECH → 200")    { expect_access(tech, path, :ok) }
    end

    describe "audit_logs" do
      let(:path) { audit_logs_path }
      it("SA → 200")      { expect_access(sa, path, :ok) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")  { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect") { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect") { expect_access(cmd, path, :redirect) }
      it("TECH → 200")    { expect_access(tech, path, :ok) }
    end

    describe "backups" do
      let(:path) { backups_path }
      it("SA → redirect")  { expect_access(sa, path, :redirect) }
      it("UA-ZM → redirect") { expect_access(ua_zm, path, :redirect) }
      it("UA → redirect")  { expect_access(ua, path, :redirect) }
      it("CMD-ZM → redirect") { expect_access(cmd_zm, path, :redirect) }
      it("CMD → redirect") { expect_access(cmd, path, :redirect) }
      it("TECH → 200")    { expect_access(tech, path, :ok) }
    end
  end
end
