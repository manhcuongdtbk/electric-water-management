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
  let(:content_zone1) { "Đơn vị A1" }
  let(:content_zone2) { "Đơn vị B1" }
  def path_with_params(**params) = pump_allocations_path(**params)
  def create_extra_data = 12.times { |i| create(:pump_allocation, zone: zone1, period: period, unit: create(:unit, zone: zone1, name: "Unit Extra #{i}"), contact_point: nil) }

  let(:search_text) { "Đơn vị A1" }
  let(:content_match) { "Đơn vị A1" }
  let(:content_no_match) { "Đơn vị B1" }

  it_behaves_like "search behavior"
  it_behaves_like "zone filter behavior"
  it_behaves_like "per_page auto-submit behavior"
end
