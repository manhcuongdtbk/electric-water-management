require "rails_helper"

RSpec.describe "Users", type: :system do
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:admin) { create(:user, :system_admin, username: "admin_main") }
  let!(:ua1) { create(:user, :unit_admin, username: "ua_alpha", unit: unit1) }
  let!(:ua2) { create(:user, :unit_admin, username: "ua_beta", unit: unit2) }

  before { sign_in admin }

  let(:path) { users_path }
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "ua_alpha" }
  let(:content_excluded) { "ua_beta" }
  let(:search_text) { "ua_alpha" }
  let(:sort_column) { "username" }
  let(:deletable_name) { ua2.username }
  let(:filter_select_ids) { %w[zone_id unit_id] }
  let(:dc_can_access) { false }
  def path_with_params(**params) = users_path(**params)
  def create_extra_data = 12.times { |i| create(:user, :unit_admin, username: "user_extra_#{i}", unit: unit1) }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
  it_behaves_like "role-based filter visibility"
  it_behaves_like "zone-unit column visibility"

  it "role filter lọc theo vai trò" do
    visit users_path
    select "Quản trị viên đơn vị", from: "role"
    expect(page).to have_content("ua_alpha")
    expect(page).not_to have_css("table tbody tr", text: "admin_main")
  end
end
