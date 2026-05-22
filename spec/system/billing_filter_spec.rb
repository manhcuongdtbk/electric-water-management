require "rails_helper"

RSpec.describe "Billing filter cascade", type: :system do
  let!(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  # Shared examples cần zone1/zone2/unit1/unit2 — billing chỉ có 1 zone nên
  # test cascade riêng. Dùng shared example cho phần auto-select zone từ unit.
  let(:path) { billing_path }
  let(:zone1) { sample.zone }
  let(:zone2) { sample.zone } # billing test data chỉ có 1 zone
  let(:unit1) { sample.unit_a }
  let(:unit2) { sample.unit_b }
  let(:zone_blank_text) { "Tất cả khu vực" }
  let(:unit_blank_text) { "Tất cả đơn vị" }
  def path_with_params(**params) = billing_path(**params)

  it "chọn khu vực → dropdown đơn vị hiện đơn vị thuộc khu vực" do
    visit billing_path
    select sample.zone.name, from: "zone_id"
    expect(page).to have_select("zone_id", selected: sample.zone.name)
    expect(page).to have_select("unit_id", with_options: [sample.unit_a.name])
  end

  it "đổi khu vực → reset đơn vị về Tất cả" do
    visit billing_path(zone_id: sample.zone.id, unit_id: sample.unit_a.id)
    expect(find("select#unit_id").value).to eq(sample.unit_a.id.to_s)

    select "Tất cả khu vực", from: "zone_id"
    expect(find("select#unit_id").value).to eq("")
  end

  it "chọn đơn vị mà chưa chọn khu vực → khu vực tự chọn theo" do
    visit billing_path
    select sample.unit_b.name, from: "unit_id"

    expect(page).to have_select("zone_id", selected: sample.zone.name)
  end

  it "đổi đơn vị sang Tất cả → giữ khu vực" do
    visit billing_path(zone_id: sample.zone.id, unit_id: sample.unit_a.id)

    select "Tất cả đơn vị", from: "unit_id"
    expect(find("select#zone_id").value).to eq(sample.zone.id.to_s)
  end
end
