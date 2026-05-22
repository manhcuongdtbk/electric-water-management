require "rails_helper"

RSpec.describe "Billing filter cascade", type: :system do
  let!(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  it "chọn khu vực → bảng lọc đúng, dropdown đơn vị chỉ hiện đơn vị thuộc khu vực" do
    visit billing_path
    expect(page).to have_content("Tất cả khu vực")

    select sample.zone.name, from: "zone_id"
    expect(page).to have_select("zone_id", selected: sample.zone.name)
    unit_options = find("select#unit_id").all("option").map(&:text)
    expect(unit_options).to include("Tất cả đơn vị")
    expect(unit_options).to include(sample.unit_a.name)
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
