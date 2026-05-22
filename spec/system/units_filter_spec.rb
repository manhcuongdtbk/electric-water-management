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
  def create_extra_data = 12.times { |i| create(:unit, zone: zone1, name: "Đơn vị Extra #{i}") }

  let(:search_text) { "Đơn vị A1" }
  let(:content_match) { "Đơn vị A1" }
  let(:content_no_match) { "Đơn vị B1" }

  let(:sort_column) { "name" }

  it_behaves_like "search behavior"
  it_behaves_like "zone filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"

  # --- Page-specific ---

  it "xóa unit quản lý khu vực → confirm có cảnh báo" do
    visit units_path
    accept_confirm(/quản lý khu vực/) do
      within("tr", text: unit1.name) { click_on I18n.t("common.actions.destroy") }
    end
    expect(page).to have_current_path(units_path)
  end

  it "xóa unit không quản lý khu vực → confirm không có cảnh báo quản lý" do
    non_manager = create(:unit, zone: zone1, name: "Đơn vị không quản lý")
    visit units_path
    msg = accept_confirm do
      within("tr", text: non_manager.name) { click_on I18n.t("common.actions.destroy") }
    end
    expect(msg).not_to include("quản lý khu vực")
  end
end
