require "rails_helper"

RSpec.describe "Pump allocations filter", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:alloc1) { create(:pump_allocation, zone: zone1, period: period, unit: unit1, contact_point: nil) }
  let!(:alloc2) { create(:pump_allocation, zone: zone2, period: period, unit: unit2, contact_point: nil) }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  it "chọn khu vực → bảng chỉ hiện phân bổ thuộc khu vực đó" do
    visit pump_allocations_path
    expect(page).to have_content("Đơn vị A1")
    expect(page).to have_content("Đơn vị B1")

    select "Khu vực Alpha", from: "zone_id"
    expect(page).to have_content("Đơn vị A1")
    expect(page).not_to have_content("Đơn vị B1")
  end

  it "chọn khu vực rồi chọn Tất cả → hiện lại toàn bộ" do
    visit pump_allocations_path(zone_id: zone1.id)
    expect(page).not_to have_content("Đơn vị B1")

    select "Tất cả", from: "zone_id"
    expect(page).to have_content("Đơn vị A1")
    expect(page).to have_content("Đơn vị B1")
  end

  it "Xóa bộ lọc reset tất cả về mặc định" do
    visit pump_allocations_path(zone_id: zone1.id)
    expect(page).to have_content("Xóa bộ lọc")

    click_on "Xóa bộ lọc"
    expect(page).to have_content("Đơn vị A1")
    expect(page).to have_content("Đơn vị B1")
    expect(find("select#zone_id").value).to eq("")
  end
end
