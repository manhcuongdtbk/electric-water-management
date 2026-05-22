# Shared system spec examples cho _list_toolbar behavior.
# Dùng Capybara API (visit, fill_in, select, click_on) — chỉ dùng trong type: :system.
#
# Params chung (caller khai báo 1 lần, dùng cho nhiều shared examples):
#   path:                → URL trang index
#   filter_param:        → HTML id/name của dropdown filter (vd: "zone_id", "type")
#   filter_option_text:  → Text option để chọn (vd: zone1.name, "Công cộng")
#   filter_option_value: → Value option đó (vd: zone1.id, "residential")
#   content_included:    → Text phải có khi lọc / tìm kiếm
#   content_excluded:    → Text không được có khi lọc / tìm kiếm
#   search_text:         → Text tìm kiếm
#   sort_column:         → Sort column name (vd: "name")
#   deletable_name:      → Tên entity để test xóa
#   path_with_params(**params) → URL với query params
#   create_extra_data    → method tạo thêm data để test per_page
#
# ============================================================

# Dropdown filter auto-submit + clear + xóa bộ lọc.
RSpec.shared_examples "single filter behavior" do
  it "chọn filter → bảng chỉ hiện data đúng" do
    visit path
    expect(page).to have_content(content_included)
    expect(page).to have_content(content_excluded)

    select filter_option_text, from: filter_param
    expect(page).to have_content(content_included)
    expect(page).not_to have_content(content_excluded)
  end

  it "chọn filter rồi chọn Tất cả → hiện lại toàn bộ" do
    visit send(:path_with_params, filter_param.to_sym => filter_option_value)
    expect(page).not_to have_content(content_excluded)

    select "Tất cả", from: filter_param
    expect(page).to have_content(content_included)
    expect(page).to have_content(content_excluded)
  end

  it "Xóa bộ lọc reset filter về mặc định" do
    visit send(:path_with_params, filter_param.to_sym => filter_option_value)
    expect(page).to have_content("Xóa bộ lọc")

    click_on "Xóa bộ lọc"
    expect(page).to have_content(content_included)
    expect(page).to have_content(content_excluded)
    expect(find("select##{filter_param}").value).to eq("")
  end
end

# Cascade khu vực → đơn vị.
RSpec.shared_examples "zone-unit cascade filter behavior" do
  let(:zone_select_id) { "zone_id" }
  let(:unit_select_id) { "unit_id" }
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

# Per_page auto-submit.
RSpec.shared_examples "per_page auto-submit behavior" do
  it "per_page auto-submit khi đổi" do
    create_extra_data
    visit path
    expect(page).to have_css("table tbody tr", minimum: 11)

    select "10", from: "per_page"
    expect(page).to have_css("table tbody tr", count: 10)
  end
end

# Tìm kiếm submit.
RSpec.shared_examples "search behavior" do
  it "tìm kiếm submit đúng kết quả" do
    visit path
    fill_in "q", with: search_text
    click_on I18n.t("common.actions.search")
    expect(page).to have_content(content_included)
    expect(page).not_to have_content(content_excluded)
  end
end

# Sort preserved qua toolbar interactions.
RSpec.shared_examples "sort preserved behavior" do
  it "sort giữ khi search" do
    visit send(:path_with_params, sort: sort_column, dir: "asc")

    fill_in "q", with: "test"
    click_on I18n.t("common.actions.search")
    expect(page).to have_current_path(/sort=#{sort_column}/)
    expect(page).to have_current_path(/dir=asc/)
  end
end

# Search + filter giữ params của nhau.
RSpec.shared_examples "search and filter combination behavior" do
  it "search text giữ khi đổi filter" do
    visit send(:path_with_params, q: search_text)
    expect(page).to have_field("q", with: search_text)

    select filter_option_text, from: filter_param
    expect(page).to have_field("q", with: search_text)
    expect(page).to have_select(filter_param, selected: filter_option_text)
  end

  it "filter giữ khi search" do
    visit send(:path_with_params, filter_param.to_sym => filter_option_value)
    expect(page).to have_select(filter_param, selected: filter_option_text)

    fill_in "q", with: search_text
    click_on I18n.t("common.actions.search")
    expect(page).to have_select(filter_param, selected: filter_option_text)
  end
end
