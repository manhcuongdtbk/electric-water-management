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
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "Nhóm Alpha-1" }
  let(:content_excluded) { "Nhóm Beta-1" }
  let(:search_text) { "Nhóm Alpha" }
  let(:sort_column) { "name" }
  def path_with_params(**params) = groups_path(**params)
  def create_extra_data = 12.times { |i| create(:group, unit: unit1, name: "Nhóm Extra #{i}") }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "role-based filter visibility"
end
