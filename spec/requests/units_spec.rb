require "rails_helper"

RSpec.describe "Units", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:open_period) { create(:period, closed: false) }
  let(:zone) { create(:zone) }

  before { sign_in system_admin }

  describe "GET /units — hiển thị, lọc, sắp xếp" do
    let!(:zone2) { create(:zone, name: "Khu vực B") }
    let!(:unit1) { create(:unit, zone: zone, name: "Đơn vị A") }
    let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B") }
    let(:html) { Nokogiri::HTML(response.body) }

    it "cột Đơn vị đứng trước cột Khu vực" do
      get units_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers[0]).to include("Đơn vị")
      expect(headers[1]).to include("Khu vực")
    end

    it "cột header là Đơn vị, không phải Tên đơn vị" do
      get units_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers[0]).not_to include("Tên")
    end

    it "cột header là Quản lý khu vực" do
      get units_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers).to include(a_string_including("Quản lý khu vực"))
    end

    it "cột quản lý khu vực hiển thị ✓ / —" do
      create(:unit, zone: zone, name: "Đơn vị không quản lý")
      get units_path
      body = response.body
      expect(body).to include("✓")
      expect(body).to include("—")
    end

    # Filter behavior, tìm kiếm, per_page đã cover bởi system specs
    # (spec/system/units_filter_spec.rb).

    it "dropdown khu vực chỉ chứa khu vực có đơn vị" do
      zone_empty = create(:zone, name: "Khu vực trống")
      get units_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).to include("Tất cả", zone.name, zone2.name)
      expect(options).not_to include("Khu vực trống")
    end

    it "sắp xếp mặc định: tạo sau đứng trước" do
      get units_path
      rows = html.css("table tbody tr")
      expect(rows.first.text).to include("Đơn vị B")
      expect(rows.last.text).to include("Đơn vị A")
    end

    it "placeholder tìm kiếm ghi rõ tìm theo tên đơn vị" do
      get units_path
      input = html.css("input#q").first
      expect(input["placeholder"]).to include("đơn vị")
    end

    it "tìm kiếm sanitize ký tự ILIKE wildcard (%, _)" do
      create(:unit, zone: zone, name: "Đơn vị 100%")
      create(:unit, zone: zone, name: "Đơn vị 1000 người")
      get units_path, params: { q: "100%" }
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(1)
      expect(response.body).to include("Đơn vị 100%")
      expect(response.body).not_to include("1000 người")
    end
  end

  describe "GET /units/:id (show)" do
    let!(:unit) { create(:unit, zone: zone, name: "Show unit") }

    it "renders show page" do
      get unit_path(unit)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Show unit")
    end
  end

  describe "POST /units (T29, T32)" do
    it "T29: tạo unit" do
      post units_path, params: { unit: { name: "Đơn vị A", zone_id: zone.id } }
      expect(response).to redirect_to(units_path)
      unit = Unit.find_by!(name: "Đơn vị A")
      expect(unit.zone).to eq(zone)
    end

    it "T32: unit đầu tiên tự động là manager" do
      post units_path, params: { unit: { name: "Đơn vị A", zone_id: zone.id } }
      unit = Unit.find_by!(name: "Đơn vị A")
      expect(zone.reload.manager_unit_id).to eq(unit.id)
    end

    it "create validation failure renders :new" do
      create(:unit, zone: zone, name: "Duplicate")
      post units_path, params: { unit: { name: "Duplicate", zone_id: zone.id } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /units/:id (T30)" do
    it "chặn đổi zone_id" do
      zone_b = create(:zone)
      unit = create(:unit, zone: zone)
      patch unit_path(unit), params: { unit: { name: "Tên mới", zone_id: zone_b.id } }
      expect(response).to redirect_to(units_path)
      unit.reload
      expect(unit.zone_id).to eq(zone.id)
      expect(unit.name).to eq("Tên mới")
    end

    it "update validation failure renders :edit" do
      unit = create(:unit, zone: zone, name: "Unit A")
      create(:unit, zone: zone, name: "Unit B")
      patch unit_path(unit), params: { unit: { name: "Unit B" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /units/:id (T39, T41)" do
    let(:unit) { create(:unit, zone: zone) }

    it "T39: chặn xóa khi còn contact_point kept" do
      rank = open_period.ranks.create!(name: "R", quota: 1, position: 1)
      create(:contact_point, :residential, unit: unit, initial_personnel_counts: { rank.id => 1 })
      delete unit_path(unit)
      unit.reload
      expect(unit).not_to be_discarded
      expect(flash[:alert]).to include("Phải xóa hết đầu mối")
    end

    it "destroy non-manager unit succeeds without zone warning" do
      non_manager = create(:unit, zone: zone)
      # non_manager is second unit, so it's NOT the auto-assigned manager
      zone.update!(manager_unit_id: unit.id)
      delete unit_path(non_manager)
      expect(response).to redirect_to(units_path)
      expect(flash[:notice]).not_to include("Cảnh báo")
    end

    it "T41: xóa unit là manager → zone.manager_unit_id = nil" do
      u = unit  # force unit creation first
      expect(zone.reload.manager_unit_id).to eq(u.id)
      delete unit_path(u)
      expect(zone.reload.manager_unit_id).to be_nil
    end

    it "xóa unit → cascade discard blocks + groups" do
      u = create(:unit, zone: zone)
      block = create(:block, unit: u)
      group = create(:group, unit: u)
      delete unit_path(u)
      expect(block.reload).to be_discarded
      expect(group.reload).to be_discarded
    end

    it "xóa unit → cleanup unit_config kỳ đang mở" do
      u = create(:unit, zone: zone)
      config = UnitConfig.find_by(unit: u, period: open_period)
      expect(config).to be_present
      delete unit_path(u)
      expect(UnitConfig.find_by(id: config.id)).to be_nil
    end
  end

  describe "Unit#discard cleanup (model level)" do
    it "cleanup pump_allocations kỳ đang mở, giữ kỳ cũ" do
      u = create(:unit, zone: zone)
      alloc_current = PumpAllocation.create!(zone: zone, period: open_period, unit: u, coefficient: 1)

      old_period = create(:period, year: 2025, month: 1, closed: true)
      alloc_old = PumpAllocation.create!(zone: zone, period: old_period, unit: u, coefficient: 1)

      u.discard
      expect(PumpAllocation.find_by(id: alloc_current.id)).to be_nil
      expect(PumpAllocation.find_by(id: alloc_old.id)).to be_present
    end

    it "cleanup unit_config kỳ đang mở, giữ kỳ cũ" do
      u = create(:unit, zone: zone)
      old_period = create(:period, year: 2025, month: 1, closed: true)
      UnitConfig.create!(unit: u, period: old_period, unit_public_rate: 5)

      config_current = UnitConfig.find_by(unit: u, period: open_period)
      config_old = UnitConfig.find_by(unit: u, period: old_period)

      u.discard
      expect(UnitConfig.find_by(id: config_current.id)).to be_nil
      expect(UnitConfig.find_by(id: config_old.id)).to be_present
    end
  end
end
