# Shared examples cho toolbar có dropdown lọc khu vực (không cascade).
#
# Yêu cầu let trong caller:
#   path:           → URL trang index (vd: units_path)
#   zone1:          → Zone thứ nhất (đã có data)
#   zone2:          → Zone thứ hai (đã có data)
#   content_zone1:  → Text xuất hiện khi lọc zone1 (vd: tên đơn vị thuộc zone1)
#   content_zone2:  → Text xuất hiện khi lọc zone2
RSpec.shared_examples "zone filter behavior" do
  it "chọn khu vực → bảng chỉ hiện data thuộc khu vực đó" do
    visit path
    expect(page).to have_content(content_zone1)
    expect(page).to have_content(content_zone2)

    select zone1.name, from: "zone_id"
    expect(page).to have_content(content_zone1)
    expect(page).not_to have_content(content_zone2)
  end

  it "chọn khu vực rồi chọn Tất cả → hiện lại toàn bộ" do
    visit send(:path_with_params, zone_id: zone1.id)
    expect(page).not_to have_content(content_zone2)

    select "Tất cả", from: "zone_id"
    expect(page).to have_content(content_zone1)
    expect(page).to have_content(content_zone2)
  end

  it "Xóa bộ lọc reset tất cả về mặc định" do
    visit send(:path_with_params, zone_id: zone1.id)
    expect(page).to have_content("Xóa bộ lọc")

    click_on "Xóa bộ lọc"
    expect(page).to have_content(content_zone1)
    expect(page).to have_content(content_zone2)
    expect(find("select#zone_id").value).to eq("")
  end
end

# Shared examples cho toolbar có cascade khu vực → đơn vị.
#
# Yêu cầu let trong caller:
#   path:           → URL trang index
#   zone1:          → Zone thứ nhất
#   zone2:          → Zone thứ hai
#   unit1:          → Unit thuộc zone1
#   unit2:          → Unit thuộc zone2
#   zone_select_id: → HTML id của zone select (mặc định "zone_id")
#   unit_select_id: → HTML id của unit select (mặc định "unit_id")
#
# Billing dùng include_blank text khác ("Tất cả khu vực"/"Tất cả đơn vị")
# nên truyền zone_blank_text / unit_blank_text nếu cần.
RSpec.shared_examples "zone-unit cascade filter behavior" do
  let(:zone_select_id) { "zone_id" }
  let(:unit_select_id) { "unit_id" }
  let(:zone_blank_text) { "Tất cả" }
  let(:unit_blank_text) { "Tất cả" }

  it "chọn khu vực → dropdown đơn vị chỉ hiện đơn vị thuộc khu vực" do
    visit path
    select zone1.name, from: zone_select_id
    expect(page).to have_select(zone_select_id, selected: zone1.name)
    expect(page).to have_select(unit_select_id, with_options: [unit1.name])
    expect(page).not_to have_select(unit_select_id, with_options: [unit2.name])
  end

  it "đổi khu vực → reset đơn vị về Tất cả" do
    visit send(:path_with_params, zone_id: zone1.id, unit_id: unit1.id)
    expect(find("select##{unit_select_id}").value).to eq(unit1.id.to_s)

    select zone2.name, from: zone_select_id
    expect(find("select##{unit_select_id}").value).to eq("")
  end

  it "chọn đơn vị mà chưa chọn khu vực → khu vực tự chọn theo" do
    visit path
    select unit2.name, from: unit_select_id

    expect(page).to have_select(zone_select_id, selected: zone2.name)
  end

  it "đổi đơn vị sang Tất cả → giữ khu vực" do
    visit send(:path_with_params, zone_id: zone1.id, unit_id: unit1.id)

    select unit_blank_text, from: unit_select_id
    expect(find("select##{zone_select_id}").value).to eq(zone1.id.to_s)
  end
end
