require "rails_helper"

RSpec.describe "Zones", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { Zone.create!(name: "Khu vực Alpha", main_meters_attributes: [{ name: "CT-A" }]) }
  let!(:zone2) { Zone.create!(name: "Khu vực Beta", main_meters_attributes: [{ name: "CT-B" }]) }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { zones_path }
  def path_with_params(**params) = zones_path(**params)
  def create_extra_data = 12.times { |i| Zone.create!(name: "Khu vực Extra #{i}", main_meters_attributes: [{ name: "CT-#{i}" }]) }

  let(:search_text) { "Alpha" }
  let(:content_match) { "Khu vực Alpha" }
  let(:content_no_match) { "Khu vực Beta" }

  let(:sort_column) { "name" }

  it_behaves_like "search behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"

  it "confirm xóa zone" do
    zone_empty = Zone.create!(name: "Khu vực trống", main_meters_attributes: [{ name: "CT-X" }])
    visit zones_path
    accept_confirm(/Khu vực trống/) do
      within("tr", text: "Khu vực trống") { click_on I18n.t("common.actions.destroy") }
    end
    expect(page).to have_current_path(zones_path)
    expect(page).not_to have_css("table tbody tr", text: "Khu vực trống")
  end
end
