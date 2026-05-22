require "rails_helper"

RSpec.describe "Contact points", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:rank) { period.ranks.create!(name: "Hạ sĩ quan", quota: 100, position: 1) }
  let!(:cp1) { create(:contact_point, :residential, unit: unit1, name: "CP Alpha", initial_personnel_counts: { rank.id => 1 }) }
  let!(:cp2) { create(:contact_point, :residential, unit: unit2, name: "CP Beta", initial_personnel_counts: { rank.id => 1 }) }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { contact_points_path }
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "CP Alpha" }
  let(:content_excluded) { "CP Beta" }
  let(:search_text) { "Alpha" }
  let(:sort_column) { "name" }
  let(:deletable_name) { cp1.name }
  let(:filter_select_ids) { %w[zone_id unit_id] }
  def path_with_params(**params) = contact_points_path(**params)
  def create_extra_data = 12.times { |i| create(:contact_point, :public_type, unit: unit1, name: "CP Extra #{i}") }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "zone-unit cascade filter behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
  it_behaves_like "role-based filter visibility"
  it_behaves_like "zone-unit column visibility"

  # --- Page-specific: type dropdown ---

  it "type dropdown auto-submit lọc theo loại" do
    pub = create(:contact_point, :public_type, unit: unit1, name: "Công cộng test")
    visit contact_points_path
    expect(page).to have_content("CP Alpha")
    expect(page).to have_content("Công cộng test")

    select "Công cộng", from: "type"
    expect(page).to have_content("Công cộng test")
    expect(page).not_to have_content("CP Alpha")
  end
end
