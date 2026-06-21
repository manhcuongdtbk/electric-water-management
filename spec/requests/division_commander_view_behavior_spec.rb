require "rails_helper"

# View-behavior assertions for the division_commander role across 10 pages.
# Verifies that the role sees the same display layout as system_admin
# (filter dropdowns, zone/unit columns) but all CRUD controls are hidden.
#
# Access (200 vs redirect) is already covered by role_access_matrix_spec.
# Read-only on entry pages is covered by commander_readonly shared example.
# This spec covers the remaining 10 pages.

RSpec.describe "Division commander view behavior", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:user) { create(:user, :division_commander) }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    sign_in user
  end

  # ---------------------------------------------------------------------------
  # 1. Dashboard
  # ---------------------------------------------------------------------------
  describe "dashboard" do
    before { get root_path }

    it "renders the system-admin partial with zone and unit summaries" do
      expect(response.body).to include(sample.zone.name)
      expect(response.body).to include(sample.unit_a.name)
    end

    it "does not render the open-period banner (SA precondition: banner exists)" do
      sa = create(:user, :system_admin)
      sign_out :user
      sign_in sa
      get root_path
      expect(response.body).to include("Vui lòng nhập liệu trước khi đóng kỳ"),
        "precondition: SA should see the open-period banner"

      sign_out :user
      sign_in user
      get root_path
      expect(response.body).not_to include("Vui lòng nhập liệu trước khi đóng kỳ")
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Billing
  # ---------------------------------------------------------------------------
  describe "billing" do
    before { get billing_path }

    it "shows zone and unit filter dropdowns" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
      expect(html.css("select#unit_id")).to be_present
    end

    it "shows the export link but not the recalculate button" do
      expect(response.body).to include("Xuất Excel")
      expect(response.body).not_to include("Tính toán lại")
    end

    it "shows zone and unit columns in the billing table" do
      html = Nokogiri::HTML(response.body)
      header_text = html.css("thead").text
      expect(header_text).to include("Khu vực")
      expect(header_text).to include("Đơn vị")
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Contact points
  # ---------------------------------------------------------------------------
  describe "contact_points" do
    before { get contact_points_path }

    it "shows zone and unit filter dropdowns and columns" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
      expect(html.css("select#unit_id")).to be_present
      header_text = html.css("thead").text
      expect(header_text).to include("Đơn vị")
      expect(header_text).to include("Khu vực")
    end

    it "hides add/edit/delete controls and shows the dash instead" do
      expect(response.body).not_to include("Thêm đầu mối")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
      expect(response.body).to include("—")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Blocks
  # ---------------------------------------------------------------------------
  describe "blocks" do
    before { get blocks_path }

    it "shows zone and unit filter dropdowns and columns" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
      header_text = html.css("thead").text
      expect(header_text).to include("Đơn vị")
      expect(header_text).to include("Khu vực")
    end

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm khối")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Groups
  # ---------------------------------------------------------------------------
  describe "groups" do
    before { get groups_path }

    it "shows zone and unit filter dropdowns and columns" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
      header_text = html.css("thead").text
      expect(header_text).to include("Đơn vị")
      expect(header_text).to include("Khu vực")
    end

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm nhóm")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Zones
  # ---------------------------------------------------------------------------
  describe "zones" do
    before { get zones_path }

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm khu vực")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Units
  # ---------------------------------------------------------------------------
  describe "units" do
    before { get units_path }

    it "shows zone filter dropdown" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
    end

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm đơn vị")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Pump allocations
  # ---------------------------------------------------------------------------
  describe "pump_allocations" do
    before { get pump_allocations_path }

    it "shows zone filter dropdown" do
      html = Nokogiri::HTML(response.body)
      expect(html.css("select#zone_id")).to be_present
    end

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm phân bổ bơm nước")
      expect(response.body).not_to include("Thêm đối tượng vào trạm này")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Pricing (period configuration)
  # ---------------------------------------------------------------------------
  describe "pricing" do
    before { get pricing_path }

    it "shows the current period info as read-only" do
      expect(response.body).to include("Kỳ đang mở")
      expect(response.body).to include("đ/kW") # formatted unit price present
    end

    it "hides all period mutation controls" do
      expect(response.body).not_to include("Lưu cập nhật")
      expect(response.body).not_to include("Đóng kỳ hiện tại")
      expect(response.body).not_to include("Mở lại")
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Ranks
  # ---------------------------------------------------------------------------
  describe "ranks" do
    before { get ranks_path }

    it "hides add/edit/delete controls" do
      expect(response.body).not_to include("Thêm nhóm cấp bậc")
      html = Nokogiri::HTML(response.body)
      action_cells = html.css("td.text-right")
      expect(action_cells.text).not_to include("Sửa")
      expect(action_cells.text).not_to include("Xóa")
    end
  end
end
