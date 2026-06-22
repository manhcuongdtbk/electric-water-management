require "rails_helper"

# CHIEU-phan-bo-tram-vai-tro: sáu vai trò + đơn vị quản lý khu vực cấu hình được,
# chỉ huy chỉ xem (xem thêm spec/requests/pump_allocations_spec.rb, spec/abilities/ability_spec.rb).
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

  let(:path) { pump_allocations_path }
  let(:filter_param) { "zone_id" }
  let(:filter_option_text) { zone1.name }
  let(:filter_option_value) { zone1.id }
  let(:content_included) { "Đơn vị A1" }
  let(:content_excluded) { "Đơn vị B1" }
  let(:search_text) { "Đơn vị A1" }
  def path_with_params(**params) = pump_allocations_path(**params)

  let(:deletable_name) { alloc1.unit.name }
  let(:filter_select_ids) { %w[zone_id] }

  # Trang nhóm theo trạm (xem controller#index): bỏ pagy/per_page + sortable header,
  # nên KHÔNG còn áp dụng "sort preserved behavior" / "per_page auto-submit behavior".
  it_behaves_like "search behavior"
  it_behaves_like "single filter behavior"
  it_behaves_like "search and filter combination behavior"
  it_behaves_like "confirm delete behavior"
  it_behaves_like "role-based filter visibility"
end

# CHIEU-phan-bo-tram-nhom: index nhóm theo trạm — mỗi trạm một thẻ; trạm rỗng
# hiện cảnh báo; link "Thêm đối tượng vào trạm này" mang theo id trạm.
RSpec.describe "Pump allocations grouped by station", type: :system do
  let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
  let!(:zone) { create(:zone, name: "KV nhóm") }
  let!(:unit) { create(:unit, zone: zone, name: "Đơn vị nhóm") }
  let!(:station_a) { create(:contact_point, :water_pump, name: "Trạm Alpha", zone: zone) }
  let!(:station_b) { create(:contact_point, :water_pump, name: "Trạm Beta", zone: zone) }
  let!(:alloc_a) do
    create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
           unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
  end

  before { sign_in create(:user, :system_admin) }

  it "render một thẻ cho mỗi trạm với đối tượng riêng" do
    visit pump_allocations_path
    card_a = find("[data-pump-station-card='#{station_a.id}']")
    expect(card_a).to have_content("Trạm Alpha")
    expect(card_a).to have_content("Đơn vị nhóm")
  end

  it "trạm chưa có đối tượng hiện thẻ rỗng kèm cảnh báo" do
    visit pump_allocations_path
    card_b = find("[data-pump-station-card='#{station_b.id}']")
    expect(card_b).to have_content("Trạm Beta")
    expect(card_b).to have_content("chưa có đối tượng nhận")
  end

  it "link Thêm đối tượng vào trạm này mang theo id trạm" do
    visit pump_allocations_path
    within("[data-pump-station-card='#{station_b.id}']") do
      link = find_link("Thêm đối tượng vào trạm này")
      expect(link[:href]).to include("pump_contact_point_id=#{station_b.id}")
    end
  end
end

RSpec.describe "Pump allocations form (per-station)", type: :system do
  before do
    sign_in create(:user, :system_admin)
    create(:period, closed: false, pump_allocation_per_station: true)
    @zone = create(:zone, name: "KV sys")
    create(:contact_point, :water_pump, name: "Trạm sys", zone: @zone)
    @unit = create(:unit, zone: @zone)
  end

  it "chọn loại Khối thì hiện select khối" do
    create(:block, unit: @unit, name: "Khối sys")
    visit new_pump_allocation_path
    select "KV sys", from: "pump_allocation_zone_id"
    choose "Khối"
    expect(page).to have_select("pump_allocation_block_id")
  end

  it "chọn loại Nhóm thì hiện select nhóm" do
    create(:group, unit: @unit, name: "Nhóm sys")
    visit new_pump_allocation_path
    select "KV sys", from: "pump_allocation_zone_id"
    choose "Nhóm"
    expect(page).to have_select("pump_allocation_group_id")
  end

  it "chọn loại Đầu mối thì hiện select đầu mối" do
    create(:contact_point, :zone_residential, zone: @zone, name: "ĐM sys")
    visit new_pump_allocation_path
    select "KV sys", from: "pump_allocation_zone_id"
    choose "Đầu mối"
    expect(page).to have_select("pump_allocation_contact_point_id")
  end
end
