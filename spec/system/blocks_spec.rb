require "rails_helper"

RSpec.describe "Blocks", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:block1) { create(:block, unit: unit1, name: "Phòng Alpha") }
  let!(:block2) { create(:block, unit: unit2, name: "Phòng Beta") }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { blocks_path }
  let(:content_zone1) { "Phòng Alpha" }
  let(:content_zone2) { "Phòng Beta" }
  let(:search_text) { "Alpha" }
  let(:content_match) { "Phòng Alpha" }
  let(:content_no_match) { "Phòng Beta" }
  let(:sort_column) { "name" }
  let(:deletable_name) { block1.name }
  def path_with_params(**params) = blocks_path(**params)
  def create_extra_data = 12.times { |i| create(:block, unit: unit1, name: "Phòng Extra #{i}") }

  it_behaves_like "search behavior"
  it_behaves_like "zone filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
  it_behaves_like "role-based filter visibility"
end
