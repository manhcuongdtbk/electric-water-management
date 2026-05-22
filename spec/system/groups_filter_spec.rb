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
  def create_extra_data = 12.times { |i| create(:group, unit: unit1, name: "Nhóm Extra #{i}") }

  it_behaves_like "zone filter behavior"
  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "per_page auto-submit behavior"

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
