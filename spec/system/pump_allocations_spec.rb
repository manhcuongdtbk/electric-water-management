require "rails_helper"

RSpec.describe "Pump allocations filter", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:alloc1) { create(:pump_allocation, zone: zone1, period: period, unit: unit1, contact_point: nil) }
  let!(:alloc2) { create(:pump_allocation, zone: zone2, period: period, unit: unit2, contact_point: nil) }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { pump_allocations_path }
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "Đơn vị A1" }
  let(:content_excluded) { "Đơn vị B1" }
  let(:search_text) { "Đơn vị A1" }
  let(:sort_column) { "target" }
  def path_with_params(**params) = pump_allocations_path(**params)
  def create_extra_data = 12.times { |i| create(:pump_allocation, zone: zone1, period: period, unit: create(:unit, zone: zone1, name: "Unit Extra #{i}"), contact_point: nil) }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
end
