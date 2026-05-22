require "rails_helper"

RSpec.describe "Groups filter cascade", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:group1) { create(:group, unit: unit1, name: "Nhóm Alpha-1") }
  let!(:group2) { create(:group, unit: unit2, name: "Nhóm Beta-1") }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { groups_path }
  let(:content_zone1) { "Nhóm Alpha-1" }
  let(:content_zone2) { "Nhóm Beta-1" }
  def path_with_params(**params) = groups_path(**params)

  it_behaves_like "zone filter behavior"
  it_behaves_like "zone-unit cascade filter behavior"

  it "Xóa bộ lọc reset cả zone và unit" do
    visit groups_path(zone_id: zone1.id, unit_id: unit1.id)
    click_on "Xóa bộ lọc"

    expect(find("select#zone_id").value).to eq("")
    expect(find("select#unit_id").value).to eq("")
  end

  it "per_page auto-submit khi đổi" do
    12.times { |i| create(:group, unit: unit1, name: "Nhóm Extra #{i}") }
    visit groups_path
    expect(page).to have_css("table tbody tr", count: 14)

    select "10", from: "per_page"
    expect(page).to have_css("table tbody tr", count: 10)
  end

  context "as unit_admin" do
    let(:unit_admin) { create(:user, :unit_admin, unit: unit1) }
    before { sign_in unit_admin }

    it "không hiển thị dropdown khu vực và đơn vị" do
      visit groups_path
      expect(page).not_to have_select("zone_id")
      expect(page).not_to have_select("unit_id")
    end
  end
end
