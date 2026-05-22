require "rails_helper"

RSpec.describe "Groups", type: :request do
  let!(:unit) { create(:unit) }
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }

  before { sign_in system_admin }

  describe "GET /groups — hiển thị, lọc, sắp xếp" do
    let!(:zone) { unit.zone }
    let!(:zone2) { create(:zone) }
    let!(:unit2) { create(:unit, zone: zone2) }
    let!(:group1) { create(:group, unit: unit, name: "Nhóm A") }
    let!(:group2) { create(:group, unit: unit2, name: "Nhóm B") }
    let(:html) { Nokogiri::HTML(response.body) }

    it "cột header là Nhóm, không phải Tên nhóm" do
      get groups_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      expect(headers[0]).to include("Nhóm")
      expect(headers[0]).not_to include("Tên")
    end

    it "cột Khu vực đứng trước cột Đơn vị" do
      get groups_path
      headers = html.css("table thead th").map(&:text).map(&:strip)
      zone_index = headers.index { |h| h.include?("Khu vực") }
      unit_index = headers.index { |h| h.include?("Đơn vị") }
      expect(zone_index).to be < unit_index
    end

    it "hiển thị tên khu vực trong bảng" do
      get groups_path
      expect(response.body).to include(zone.name)
      expect(response.body).to include(zone2.name)
    end

    it "placeholder tìm kiếm ghi rõ tìm theo tên nhóm" do
      get groups_path
      input = html.css("input#q").first
      expect(input["placeholder"]).to include("nhóm")
    end

    it "sắp xếp mặc định: tạo sau đứng trước" do
      get groups_path
      rows = html.css("table tbody tr")
      expect(rows.first.text).to include("Nhóm B")
      expect(rows.last.text).to include("Nhóm A")
    end

    # Filter/cascade behavior (lọc khu vực, đơn vị, auto-select, reset)
    # đã cover bởi system specs (spec/system/groups_filter_spec.rb).
    # Request specs giữ lại: dropdown scoping (server-side logic).

    it "lọc khu vực → dropdown khu vực vẫn chứa tất cả khu vực có nhóm" do
      get groups_path, params: { zone_id: zone.id }
      zone_options = html.css("select#zone_id option").map(&:text)
      expect(zone_options).to include(zone.name, zone2.name)
    end

    it "dropdown khu vực chỉ chứa khu vực có nhóm" do
      zone_empty = create(:zone, name: "Khu vực trống")
      get groups_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).to include(zone.name, zone2.name)
      expect(options).not_to include("Khu vực trống")
    end

    # Tìm kiếm, non-admin dropdown visibility: cover bởi system spec.
  end

  describe "POST /groups" do
    it "tạo nhóm" do
      post groups_path, params: { group: { name: "Nhóm A", unit_id: unit.id } }
      expect(response).to redirect_to(groups_path)
      expect(Group.find_by(name: "Nhóm A")).to be_present
    end
  end

  describe "DELETE /groups/:id (T43 cascade nullify)" do
    it "discard nhóm + nullify group_id của contact_points kept" do
      group = create(:group, unit: unit, name: "Nhóm B")
      rank = period.ranks.create!(name: "R", quota: 1, position: 99)
      cp = create(:contact_point, :residential, unit: unit, group: group,
                  initial_personnel_counts: { rank.id => 1 })
      delete group_path(group)
      group.reload
      expect(group).to be_discarded
      expect(cp.reload.group_id).to be_nil
    end
  end
end
