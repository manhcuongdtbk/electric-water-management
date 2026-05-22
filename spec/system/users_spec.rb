require "rails_helper"

RSpec.describe "Users", type: :system do
  let!(:admin) { create(:user, :system_admin, username: "admin_alpha", display_name: "Admin Alpha") }
  let!(:other) { create(:user, :system_admin, username: "admin_beta", display_name: "Admin Beta") }
  let!(:unit_admin_user) do
    zone = create(:zone)
    unit = create(:unit, zone: zone)
    create(:user, :unit_admin, username: "ua_gamma", display_name: "UA Gamma", unit: unit)
  end

  before { sign_in admin }

  let(:path) { users_path }
  let(:filter_param) { "role" }
  let(:filter_option_text) { "Quản trị viên đơn vị" }
  let(:filter_option_value) { "unit_admin" }
  let(:content_included) { "ua_gamma" }
  let(:content_excluded) { "admin_beta" }
  let(:search_text) { "gamma" }
  let(:sort_column) { "username" }
  let(:deletable_name) { other.username }
  def path_with_params(**params) = users_path(**params)
  def create_extra_data = 12.times { |i| create(:user, :system_admin, username: "user_extra_#{i}") }

  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "sort preserved behavior"
  it_behaves_like "per_page auto-submit behavior"
  it_behaves_like "confirm delete behavior"
end
