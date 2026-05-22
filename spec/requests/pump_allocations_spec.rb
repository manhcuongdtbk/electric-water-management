require "rails_helper"

RSpec.describe "PumpAllocations", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }
  let!(:zone) { create(:zone) }
  let!(:unit) { create(:unit, zone: zone) }

  before { sign_in system_admin }

  describe "GET /pump_allocations" do
    it "trả về 200" do
      get pump_allocations_path
      expect(response).to have_http_status(:ok)
    end

    it "ẩn allocation khi unit đã bị discard" do
      alloc = create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil)
      get pump_allocations_path
      expect(response.body).to include(unit.name)

      unit.discard
      get pump_allocations_path
      expect(response.body).not_to include(unit.name)
    end

    it "ẩn allocation khi contact_point đã bị discard" do
      contact_point = create(:contact_point, :residential, unit: nil, zone: zone)
      alloc = create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: contact_point)
      get pump_allocations_path
      expect(response.body).to include(contact_point.name)

      contact_point.discard
      get pump_allocations_path
      expect(response.body).not_to include(contact_point.name)
    end
  end

  describe "GET /pump_allocations — lọc theo khu vực và tìm kiếm" do
    let!(:zone2) { create(:zone, name: "Khu vực 2") }
    let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị 2") }
    let!(:alloc1) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil) }
    let!(:alloc2) { create(:pump_allocation, zone: zone2, period: period, unit: unit2, contact_point: nil) }
    let(:html) { Nokogiri::HTML(response.body) }

    it "lọc theo khu vực chỉ hiển thị phân bổ của khu vực đó" do
      get pump_allocations_path, params: { zone_id: zone2.id }
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(1)
      expect(rows.first.text).to include(zone2.name)
      expect(rows.first.text).not_to include(zone.name)
    end

    it "dropdown khu vực chỉ chứa các khu vực có phân bổ" do
      get pump_allocations_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).to include("Tất cả", zone.name, zone2.name)
    end

    it "dropdown khu vực không chứa khu vực không có phân bổ" do
      zone_empty = create(:zone, name: "Khu vực trống")
      get pump_allocations_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).not_to include("Khu vực trống")
    end

    it "tìm kiếm theo tên đơn vị, không tìm theo tên khu vực" do
      get pump_allocations_path, params: { q: unit2.name }
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(1)
      expect(response.body).to include(unit2.name)
    end

    it "kết hợp lọc khu vực và tìm kiếm" do
      get pump_allocations_path, params: { zone_id: zone.id, q: "không tồn tại" }
      rows = html.css("table tbody tr")
      expect(rows.first.text).to include("Không có bản ghi")
    end

    it "hiển thị link xóa bộ lọc khi có filter" do
      get pump_allocations_path, params: { zone_id: zone.id }
      expect(response.body).to include(I18n.t("common.list.clear_filter"))
    end

    it "zone filter và per_page giữ lại giá trị của nhau" do
      get pump_allocations_path, params: { zone_id: zone2.id, per_page: 10 }
      expect(response).to have_http_status(:ok)
      selected_zone = html.css("select#zone_id option[selected]")
      expect(selected_zone.first&.attr("value")).to eq(zone2.id.to_s)
    end

    it "cột Đối tượng đứng trước cột Khu vực trong bảng" do
      get pump_allocations_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      target_index = headers.index { |h| h.include?("Đối tượng") }
      zone_index = headers.index { |h| h.include?("Khu vực") }
      expect(target_index).to be < zone_index
    end

    it "cột khu vực có tiêu đề là Khu vực" do
      get pump_allocations_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers).to include(a_string_including("Khu vực"))
      expect(headers).not_to include(a_string_including("Tên khu vực"))
    end

    it "sắp xếp mặc định: đối tượng tạo sau đứng trước" do
      get pump_allocations_path
      rows = html.css("table tbody tr")
      first_row_text = rows.first.text
      last_row_text = rows.last.text
      expect(first_row_text).to include(unit2.name)
      expect(last_row_text).to include(unit.name)
    end

    it "placeholder tìm kiếm ghi rõ tìm theo tên đối tượng" do
      get pump_allocations_path
      input = html.css("input#q").first
      expect(input["placeholder"]).to include("đối tượng")
    end
  end

  describe "POST /pump_allocations" do
    it "tạo phân bổ cho unit" do
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: unit.id,
          coefficient: "1", fixed_percentage: ""
        }
      }
      expect(response).to redirect_to(pump_allocations_path)
      expect(PumpAllocation.count).to eq(1)
    end

    it "T53: chặn khi tổng fixed_percentage > 100" do
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             contact_point: nil, fixed_percentage: 80, coefficient: 1)
      another_unit = create(:unit, zone: zone)
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: another_unit.id,
          coefficient: "0", fixed_percentage: "30"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("không được vượt quá 100")
    end
  end
end
