require "rails_helper"

RSpec.describe "Units filter", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { units_path }
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "Đơn vị A1" }
  let(:content_excluded) { "Đơn vị B1" }
  let(:search_text) { "Đơn vị A1" }
  let(:sort_column) { "name" }
  def path_with_params(**params) = units_path(**params)
  def create_extra_data = 12.times { |i| create(:unit, zone: zone1, name: "Đơn vị Extra #{i}") }

  # unit1 là manager → confirm có cảnh báo quản lý khu vực
  let(:deletable_name) { unit1.name }
  let(:confirm_message_pattern) { /quản lý khu vực/ }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
end
