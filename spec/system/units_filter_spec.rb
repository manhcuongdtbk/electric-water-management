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
  let(:content_zone1) { "Đơn vị A1" }
  let(:content_zone2) { "Đơn vị B1" }
  def path_with_params(**params) = units_path(**params)

  it_behaves_like "zone filter behavior"
end
