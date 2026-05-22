# Shared system spec examples cho _list_toolbar behavior.
# Dùng Capybara API (visit, fill_in, select, click_on) — chỉ dùng trong type: :system.
#
# ============================================================

# Shared examples cho toolbar có dropdown lọc khu vực (không cascade).
#
# Yêu cầu let/method trong caller:
#   path:           → URL trang index (vd: units_path)
#   zone1:          → Zone thứ nhất (đã có data)
#   zone2:          → Zone thứ hai (đã có data)
#   content_zone1:  → Text xuất hiện khi lọc zone1 (vd: tên đơn vị thuộc zone1)
#   content_zone2:  → Text xuất hiện khi lọc zone2
#   path_with_params(**params) → URL với query params
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
# Yêu cầu let/method trong caller (ngoài những yêu cầu của zone filter behavior):
#   unit1:          → Unit thuộc zone1
#   unit2:          → Unit thuộc zone2
#   zone_select_id: → HTML id của zone select (mặc định "zone_id")
#   unit_select_id: → HTML id của unit select (mặc định "unit_id")
#   zone_blank_text → Text option "Tất cả" cho zone (mặc định "Tất cả")
#   unit_blank_text → Text option "Tất cả" cho unit (mặc định "Tất cả")
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
    expect(page).to have_select(zone_select_id, selected: zone2.name)
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
    expect(page).to have_select(zone_select_id, selected: zone1.name)
  end

  it "Xóa bộ lọc reset cả zone và unit" do
    visit send(:path_with_params, zone_id: zone1.id, unit_id: unit1.id)

    click_on "Xóa bộ lọc"
    expect(page).not_to have_content("Xóa bộ lọc")
    expect(find("select##{zone_select_id}").value).to eq("")
    expect(find("select##{unit_select_id}").value).to eq("")
  end
end

# Shared examples cho per_page auto-submit trong _list_toolbar.
#
# Yêu cầu trong caller:
#   path:             → URL trang index
#   create_extra_data → method tạo thêm data để có > 10 bản ghi
RSpec.shared_examples "per_page auto-submit behavior" do
  it "per_page auto-submit khi đổi" do
    create_extra_data
    visit path
    expect(page).to have_css("table tbody tr", minimum: 11)

    select "10", from: "per_page"
    expect(page).to have_css("table tbody tr", count: 10)
  end
end

# Shared examples cho tìm kiếm trong _list_toolbar.
#
# Yêu cầu trong caller:
#   path:             → URL trang index
#   search_text:      → Text tìm kiếm (vd: tên đơn vị, tên khu vực)
#   content_match:    → Text phải có trong kết quả
#   content_no_match: → Text không được có trong kết quả
# Shared examples cho confirm xóa (turbo_confirm) trên trang danh sách.
#
# Yêu cầu trong caller:
#   path:               → URL trang index
#   deletable_record:   → Record có thể xóa (không vi phạm constraint)
#   deletable_name:     → Tên hiển thị trong bảng và confirm dialog
RSpec.shared_examples "confirm delete behavior" do
  it "confirm xóa hiện tên entity và xóa thành công" do
    deletable_record # force creation
    visit path
    accept_confirm(/#{Regexp.escape(deletable_name)}/) do
      within("tr", text: deletable_name) { click_on I18n.t("common.actions.destroy") }
    end
    expect(page).to have_current_path(path)
    expect(page).not_to have_css("table tbody tr", text: deletable_name)
  end
end

RSpec.shared_examples "search behavior" do
  it "tìm kiếm submit đúng kết quả" do
    visit path
    fill_in "q", with: search_text
    click_on I18n.t("common.actions.search")
    expect(page).to have_content(content_match)
    expect(page).not_to have_content(content_no_match)
  end

  it "tìm kiếm → hiện Xóa bộ lọc" do
    visit path
    fill_in "q", with: search_text
    click_on I18n.t("common.actions.search")
    expect(page).to have_content("Xóa bộ lọc")
  end
end

# Shared examples cho search + filter kết hợp.
# Verify single-form giữ params của nhau khi thao tác.
#
# Yêu cầu trong caller (ngoài search behavior + zone filter behavior):
#   search_text, content_match, content_no_match, zone1, zone2, content_zone1, content_zone2
# Shared examples cho sort preserved qua toolbar interactions.
# Verify hidden fields sort/dir giữ khi search hoặc đổi filter.
#
# Yêu cầu trong caller:
#   path_with_params(**params) → URL với query params
#   sort_column:               → Sort column name dùng để test (vd: "name")
RSpec.shared_examples "sort preserved behavior" do
  it "sort giữ khi search" do
    visit send(:path_with_params, sort: sort_column, dir: "asc")

    fill_in "q", with: "test"
    click_on I18n.t("common.actions.search")
    expect(page).to have_current_path(/sort=#{sort_column}/)
    expect(page).to have_current_path(/dir=asc/)
  end
end

RSpec.shared_examples "search and filter combination behavior" do
  it "search text giữ khi đổi zone filter" do
    visit send(:path_with_params, q: search_text)
    expect(page).to have_field("q", with: search_text)

    select zone1.name, from: "zone_id"
    expect(page).to have_field("q", with: search_text)
    expect(page).to have_select("zone_id", selected: zone1.name)
  end

  it "zone filter giữ khi search" do
    visit send(:path_with_params, zone_id: zone1.id)
    expect(page).to have_select("zone_id", selected: zone1.name)

    fill_in "q", with: search_text
    click_on I18n.t("common.actions.search")
    expect(page).to have_select("zone_id", selected: zone1.name)
  end
end
