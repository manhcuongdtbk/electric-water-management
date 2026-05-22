require "rails_helper"

RSpec.describe "Ranks", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:rank1) { create(:rank, period: period, name: "Hạ sĩ quan", quota: 100, position: 1) }
  let!(:rank2) { create(:rank, period: period, name: "Sĩ quan", quota: 200, position: 2) }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { ranks_path }
  let(:search_text) { "Hạ sĩ quan" }
  let(:content_included) { "Hạ sĩ quan" }
  let(:content_excluded) { "Sĩ quan" }
  let(:sort_column) { "name" }
  let(:deletable_name) { rank2.name }
  def path_with_params(**params) = ranks_path(**params)
  def create_extra_data = 12.times { |i| create(:rank, period: period, name: "Cấp bậc #{i}", quota: 50, position: 10 + i) }

  it_behaves_like "search behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
end
