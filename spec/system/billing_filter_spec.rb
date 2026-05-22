require "rails_helper"

RSpec.describe "Billing filter cascade", type: :system do
  let!(:sample) { setup_zone_one_full_sample }
  let!(:zone2) { create(:zone, name: "Khu vực 2") }
  let!(:unit_c) { create(:unit, name: "Đơn vị C", zone: zone2) }
  let!(:cp_zone2) do
    rank = sample.period.ranks.first
    create(:contact_point, :residential, name: "Đầu mối Z2", unit: unit_c,
           initial_personnel_counts: { rank.id => 1 })
  end

  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  let(:path) { billing_path }
  let(:zone1) { sample.zone }
  let(:unit1) { sample.unit_a }
  let(:unit2) { unit_c }
  let(:content_zone1) { sample.unit_a.name }
  let(:content_zone2) { unit_c.name }
  def path_with_params(**params) = billing_path(**params)

  it_behaves_like "zone-unit cascade filter behavior"

  it "chọn khu vực → bảng chỉ hiện data thuộc khu vực đó" do
    visit billing_path
    select sample.zone.name, from: "zone_id"
    expect(page).to have_select("zone_id", selected: sample.zone.name)
    expect(page).to have_content(sample.unit_a.name)
    expect(page).not_to have_css("table", text: unit_c.name)
  end
end
