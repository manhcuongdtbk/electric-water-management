require "rails_helper"

RSpec.describe "Groups filter cascade", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }
  let!(:group1) { create(:group, unit: unit1, name: "Nhóm Alpha-1") }
  let!(:group2) { create(:group, unit: unit2, name: "Nhóm Beta-1") }
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  it "chọn khu vực → đơn vị chỉ hiện đơn vị thuộc khu vực, bảng lọc đúng" do
    visit groups_path
    expect(page).to have_content("Nhóm Alpha-1")
    expect(page).to have_content("Nhóm Beta-1")

    select "Khu vực Alpha", from: "zone_id"
    # auto-submit: trang tải lại với zone filter
    expect(page).to have_content("Nhóm Alpha-1")
    expect(page).not_to have_content("Nhóm Beta-1")

    # Dropdown đơn vị chỉ chứa đơn vị thuộc khu vực Alpha
    unit_options = find("select#unit_id").all("option").map(&:text)
    expect(unit_options).to include("Đơn vị A1")
    expect(unit_options).not_to include("Đơn vị B1")
  end

  it "đổi khu vực → reset đơn vị về Tất cả" do
    visit groups_path(zone_id: zone1.id, unit_id: unit1.id)
    expect(find("select#unit_id").value).to eq(unit1.id.to_s)

    select "Khu vực Beta", from: "zone_id"
    # reset-child-select reset unit về "", rồi auto-submit
    expect(page).to have_content("Nhóm Beta-1")
    expect(find("select#unit_id").value).to eq("")
  end

  it "chọn đơn vị mà chưa chọn khu vực → khu vực tự chọn theo" do
    visit groups_path
    select "Đơn vị B1", from: "unit_id"

    expect(page).to have_content("Nhóm Beta-1")
    expect(page).not_to have_content("Nhóm Alpha-1")
    expect(find("select#zone_id").value).to eq(zone2.id.to_s)
  end

  it "đổi đơn vị sang Tất cả → giữ khu vực" do
    visit groups_path(zone_id: zone1.id, unit_id: unit1.id)

    select "Tất cả", from: "unit_id"
    expect(page).to have_content("Nhóm Alpha-1")
    expect(find("select#zone_id").value).to eq(zone1.id.to_s)
  end

  it "Xóa bộ lọc reset tất cả về mặc định" do
    visit groups_path(zone_id: zone1.id)
    expect(page).to have_content("Xóa bộ lọc")

    click_on "Xóa bộ lọc"
    expect(page).to have_content("Nhóm Alpha-1")
    expect(page).to have_content("Nhóm Beta-1")
    expect(find("select#zone_id").value).to eq("")
    expect(find("select#unit_id").value).to eq("")
  end

  it "per_page auto-submit khi đổi" do
    # Tạo thêm data để có hơn 10 nhóm
    12.times { |i| create(:group, unit: unit1, name: "Nhóm Extra #{i}") }
    visit groups_path
    expect(page).to have_css("table tbody tr", count: 14)

    select "10", from: "per_page"
    expect(page).to have_css("table tbody tr", count: 10)
  end

  context "as unit_admin" do
    let(:unit_admin) { create(:user, :unit_admin, unit: unit1) }
    before { sign_in unit_admin }

    it "không hiển thị dropdown khu vực và đơn vị" do
      visit groups_path
      expect(page).not_to have_select("zone_id")
      expect(page).not_to have_select("unit_id")
    end
  end
end
