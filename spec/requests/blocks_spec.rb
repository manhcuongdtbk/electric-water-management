require "rails_helper"

RSpec.describe "Blocks", type: :request do
  let!(:unit) { create(:unit) }
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }

  before { sign_in system_admin }

  describe "GET /blocks — hiển thị, sắp xếp" do
    let!(:zone) { unit.zone }
    let!(:zone2) { create(:zone) }
    let!(:unit2) { create(:unit, zone: zone2) }
    let!(:block1) { create(:block, unit: unit, name: "Phòng Tham mưu") }
    let!(:block2) { create(:block, unit: unit2, name: "Phòng Hậu cần") }
    let(:html) { Nokogiri::HTML(response.body) }

    it "cột header là Khối, không phải Tên khối" do
      get blocks_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers[0]).to include("Khối")
      expect(headers[0]).not_to include("Tên")
    end

    it "cột theo hierarchy: Khối → Đơn vị → Khu vực" do
      get blocks_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      name_index = headers.index { |h| h.include?("Khối") }
      unit_index = headers.index { |h| h.include?("Đơn vị") }
      zone_index = headers.index { |h| h.include?("Khu vực") }
      expect(name_index).to be < unit_index
      expect(unit_index).to be < zone_index
    end

    it "hiển thị khu vực trong bảng" do
      get blocks_path
      expect(response.body).to include(zone.name)
      expect(response.body).to include(zone2.name)
    end

    it "sắp xếp mặc định: tạo sau đứng trước" do
      get blocks_path
      rows = html.css("table tbody tr")
      expect(rows.first.text).to include("Phòng Hậu cần")
      expect(rows.last.text).to include("Phòng Tham mưu")
    end

    it "placeholder tìm kiếm ghi rõ tìm theo tên khối" do
      get blocks_path
      input = html.css("input#q").first
      expect(input["placeholder"]).to include("khối")
    end

    it "dropdown khu vực chỉ chứa khu vực có khối" do
      zone_empty = create(:zone, name: "Khu vực trống")
      get blocks_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).to include(zone.name, zone2.name)
      expect(options).not_to include("Khu vực trống")
    end

    it "lọc khu vực → dropdown khu vực vẫn chứa tất cả khu vực có khối" do
      get blocks_path, params: { zone_id: zone.id }
      zone_options = html.css("select#zone_id option").map(&:text)
      expect(zone_options).to include(zone.name, zone2.name)
    end

    # Filter/cascade behavior, tìm kiếm, per_page, confirm delete:
    # cover bởi system specs (spec/system/blocks_spec.rb).
  end

  describe "POST /blocks" do
    it "tạo khối" do
      post blocks_path, params: { block: { name: "Phòng mới", unit_id: unit.id } }
      expect(response).to redirect_to(blocks_path)
      expect(Block.find_by(name: "Phòng mới")).to be_present
    end
  end

  describe "PATCH /blocks/:id (I7)" do
    let!(:block) { create(:block, unit: unit, name: "Phòng cũ") }

    it "update tên thành công" do
      patch block_path(block), params: { block: { name: "Phòng mới" } }
      expect(response).to redirect_to(blocks_path)
      expect(block.reload.name).to eq("Phòng mới")
    end

    it "update tên trùng → lỗi validation" do
      create(:block, unit: unit, name: "Phòng trùng")
      patch block_path(block), params: { block: { name: "Phòng trùng" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /blocks/:id (T42 cascade nullify)" do
    it "discard khối + nullify children" do
      block = create(:block, unit: unit, name: "Phòng X")
      group = create(:group, unit: unit, block: block, name: "Nhóm trong khối")
      cp = create(:contact_point, :residential, unit: unit, block: block,
                  initial_personnel_counts: { period.ranks.create!(name: "R", quota: 1, position: 99).id => 1 })
      delete block_path(block)
      block.reload
      expect(block).to be_discarded
      expect(group.reload.block_id).to be_nil
      expect(cp.reload.block_id).to be_nil
    end
  end
end
