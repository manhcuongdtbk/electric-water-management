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
  let(:content_included) { "Khu vực Alpha" }
  let(:content_excluded) { "Khu vực Beta" }

  let(:sort_column) { "name" }

  let!(:zone_deletable) { Zone.create!(name: "Khu vực trống", main_meters_attributes: [{ name: "CT-X" }]) }
  let(:deletable_name) { zone_deletable.name }

  it_behaves_like "search behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
end
