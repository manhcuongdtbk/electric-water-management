require "rails_helper"

# CHIEU-phan-bo-tram-vai-tro: sáu vai trò + đơn vị quản lý khu vực cấu hình được,
# chỉ huy chỉ xem (xem thêm spec/system/pump_allocations_spec.rb, spec/abilities/ability_spec.rb).
RSpec.describe "PumpAllocations", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:period) { create(:period, closed: false) }
  let!(:zone) { create(:zone, name: "Khu vực Bắc") }
  let!(:unit) { create(:unit, zone: zone, name: "Tiểu đoàn 14") }

  before { sign_in system_admin }

  describe "GET /pump_allocations" do
    it "trả về 200" do
      get pump_allocations_path
      expect(response).to have_http_status(:ok)
    end

    it "ẩn allocation khi unit đã bị discard" do
      alloc = create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil)
      get pump_allocations_path
      expect(response.body).to include(unit.name)

      unit.contact_points.kept.find_each(&:discard)
      unit.discard
      get pump_allocations_path
      expect(response.body).not_to include(unit.name)
    end

    it "ẩn allocation khi contact_point đã bị discard" do
      contact_point = create(:contact_point, :residential, unit: nil, zone: zone)
      alloc = create(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: contact_point)
      get pump_allocations_path
      expect(response.body).to include(contact_point.name)

      contact_point.discard
      get pump_allocations_path
      expect(response.body).not_to include(contact_point.name)
    end

    # R5-1: đối tượng nhận có thể ở cấp đơn vị/khối/nhóm/đầu mối. Giữ đủ 4 cột,
    # nhưng ô của ĐÚNG cấp nhận phải tô đậm, ô cha (ngữ cảnh) để mờ — để user
    # low-tech nhìn là biết cấp nào nhận, không cần caption.
    it "tô đậm ô đúng cấp đối tượng nhận (Khối), ô đơn vị cha để mờ" do
      block = create(:block, unit: unit, name: "Khối Ban Chỉ huy")
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM Khối BCH")
      alloc = create(:pump_allocation, zone: zone, period: period, unit: nil, block: block, contact_point: nil)
      get pump_allocations_path
      row = Nokogiri::HTML(response.body).at_css("tr[data-pump-allocation-target-id='#{alloc.id}']")
      cells = row.css("td")
      block_cell = cells.find { |c| c.text.strip == block.name }
      unit_cell  = cells.find { |c| c.text.strip == unit.name }
      expect(block_cell["class"]).to include("bg-blue-50")    # cấp nhận = Khối → tô đậm
      expect(unit_cell["class"]).to include("text-gray-400")  # đơn vị cha → mờ
    end
  end

  describe "GET /pump_allocations — lọc theo khu vực và tìm kiếm" do
    let!(:zone2) { create(:zone, name: "Khu vực Nam") }
    let!(:unit2) { create(:unit, zone: zone2, name: "Phòng Hậu cần") }
    let!(:alloc1) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil) }
    let!(:alloc2) { create(:pump_allocation, zone: zone2, period: period, unit: unit2, contact_point: nil) }
    let(:html) { Nokogiri::HTML(response.body) }

    # Filter behavior (lọc khu vực, xóa bộ lọc) đã cover bởi system specs
    # (spec/system/pump_allocations_filter_spec.rb).

    it "dropdown khu vực chỉ chứa các khu vực có phân bổ" do
      get pump_allocations_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).to include("Tất cả", zone.name, zone2.name)
    end

    it "dropdown khu vực không chứa khu vực không có phân bổ" do
      zone_empty = create(:zone, name: "Khu vực trống")
      get pump_allocations_path
      options = html.css("select#zone_id option").map(&:text)
      expect(options).not_to include("Khu vực trống")
    end

    it "tìm kiếm theo tên đơn vị, không tìm theo tên khu vực" do
      get pump_allocations_path, params: { q: unit2.name }
      rows = html.css("table tbody tr")
      expect(rows.size).to eq(1)
      expect(response.body).to include(unit2.name)
      expect(response.body).not_to include(unit.name)
    end

    it "kết hợp lọc khu vực và tìm kiếm" do
      get pump_allocations_path, params: { zone_id: zone.id, q: "không tồn tại" }
      # Kỳ cũ (legacy): thẻ gộp duy nhất; không có đối tượng khớp → không có thẻ.
      expect(response.body).not_to include(unit.name)
      expect(response.body).not_to include(unit2.name)
    end

    it "hiển thị link xóa bộ lọc khi có filter" do
      get pump_allocations_path, params: { zone_id: zone.id }
      expect(response.body).to include(I18n.t("common.list.clear_filter"))
    end

    it "zone filter giữ lại giá trị đã chọn" do
      get pump_allocations_path, params: { zone_id: zone2.id }
      expect(response).to have_http_status(:ok)
      selected_zone = html.css("select#zone_id option[selected]")
      expect(selected_zone.first&.attr("value")).to eq(zone2.id.to_s)
    end

    it "kỳ cũ gộp toàn bộ vào một thẻ" do
      get pump_allocations_path
      expect(response.body).to include(I18n.t("pump_allocations.index.legacy_card_title"))
    end

    it "placeholder tìm kiếm ghi rõ tìm theo tên đối tượng" do
      get pump_allocations_path
      input = html.css("input#q").first
      expect(input["placeholder"]).to include("đối tượng")
    end

    it "không render dropdown per_page (trang nhóm theo trạm)" do
      get pump_allocations_path
      expect(html.css("select#per_page")).to be_empty
    end
  end

  describe "POST /pump_allocations" do
    it "tạo phân bổ cho unit" do
      create(:contact_point, :residential, unit: unit, name: "ĐM Tiểu đoàn 14")
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: unit.id,
          coefficient: "1", fixed_percentage: ""
        }
      }
      expect(response).to redirect_to(pump_allocations_path)
      expect(PumpAllocation.count).to eq(1)
    end

  end

  describe "GET /pump_allocations/:id/edit" do
    let!(:alloc) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil, coefficient: 1) }

    it "renders edit form" do
      get edit_pump_allocation_path(alloc)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /pump_allocations/:id (I10)" do
    let!(:alloc) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil, coefficient: 1) }

    it "update coefficient thành công" do
      patch pump_allocation_path(alloc), params: { pump_allocation: { coefficient: "2.5" } }
      expect(response).to redirect_to(pump_allocations_path)
      expect(alloc.reload.coefficient.to_f).to eq(2.5)
    end

    it "update validation failure renders :edit" do
      # coefficient and fixed_percentage both empty or invalid
      patch pump_allocation_path(alloc), params: { pump_allocation: { coefficient: "", fixed_percentage: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /pump_allocations/:id (I10)" do
    let!(:alloc) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil, coefficient: 1) }

    it "xóa phân bổ" do
      expect { delete pump_allocation_path(alloc) }.to change(PumpAllocation, :count).by(-1)
      expect(response).to redirect_to(pump_allocations_path)
    end
  end

  describe "ensure_allocation_belongs_to_open_period (I10)" do
    it "chặn edit allocation kỳ đã đóng" do
      old_period = create(:period, year: 2025, month: 1, closed: true)
      old_alloc = create(:pump_allocation, zone: zone, period: old_period, unit: unit, contact_point: nil)
      patch pump_allocation_path(old_alloc), params: { pump_allocation: { coefficient: "99" } }
      expect(response).to redirect_to(pump_allocations_path)
      expect(old_alloc.reload.coefficient.to_f).not_to eq(99)
    end
  end

  # CHIEU-phan-bo-tram-rang-buoc: "đúng MỘT recipient" chống lỗi XOR-radio.
  # Form dùng radio XOR + div ẩn (giống lỗi cũ của contact_point: div ẩn vẫn SUBMIT
  # value cũ → ghi đè im lặng lựa chọn). Stimulus clearSelect xóa select ẩn về "",
  # nhưng nếu một id cũ rò rỉ (JS tắt / param giả) thì model PHẢI TỪ CHỐI (không
  # lưu nhầm recipient im lặng). Đây là chốt chặn server-side cho lỗi đó.
  describe "POST /pump_allocations — chống ghi đè recipient ẩn (XOR)" do
    it "TỪ CHỐI khi gửi HAI recipient id (unit_id + contact_point_id rò rỉ)" do
      leaked_cp = create(:contact_point, :residential, unit: unit)
      expect {
        post pump_allocations_path, params: { pump_allocation: {
          zone_id: zone.id, unit_id: unit.id, contact_point_id: leaked_cp.id,
          coefficient: "1", fixed_percentage: ""
        } }
      }.not_to change(PumpAllocation, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_must_be_one")
      )
    end

    it "TỪ CHỐI khi gửi unit_id + block_id (không lưu nhầm cái nào)" do
      block = create(:block, unit: unit, name: "Khối rò rỉ")
      expect {
        post pump_allocations_path, params: { pump_allocation: {
          zone_id: zone.id, unit_id: unit.id, block_id: block.id,
          coefficient: "1", fixed_percentage: ""
        } }
      }.not_to change(PumpAllocation, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "zone-manager access to pump_allocations" do
    it "zone-manager can access index" do
      zone.update!(manager_unit: unit)
      zone_manager = create(:user, :unit_admin, unit: unit)
      sign_in zone_manager
      get pump_allocations_path
      expect(response).to have_http_status(:ok)
    end

    it "technician accesses users page but not pump_allocations" do
      tech = create(:user)
      sign_in tech
      get pump_allocations_path
      expect(response).to redirect_to(users_path)
    end
  end

  describe "POST /pump_allocations — create failure" do
    it "create validation failure renders :new" do
      # Missing zone_id
      post pump_allocations_path, params: {
        pump_allocation: { zone_id: "", unit_id: unit.id, coefficient: "1" }
      }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # CHIEU-phan-bo-tram-rang-buoc: đổi LOẠI recipient khi update — Stimulus xóa select
  # ẩn về "" (unit_id=""), gửi contact_point_id mới. Phải persist DUY NHẤT
  # recipient mới; id cũ thành nil (không còn unit_id cũ "dính lại").
  describe "PATCH /pump_allocations/:id — đổi loại recipient (XOR, clear id cũ)" do
    let!(:alloc) { create(:pump_allocation, zone: zone, period: period, unit: unit, contact_point: nil, coefficient: 1) }

    it "đổi từ unit sang contact_point với unit_id=\"\" → chỉ còn contact_point_id, unit_id nil" do
      new_cp = create(:contact_point, :residential, unit: unit, name: "Đầu mối mới")
      patch pump_allocation_path(alloc), params: { pump_allocation: {
        zone_id: zone.id, unit_id: "", contact_point_id: new_cp.id,
        coefficient: "1", fixed_percentage: ""
      } }
      expect(response).to redirect_to(pump_allocations_path)
      alloc.reload
      expect(alloc.contact_point_id).to eq(new_cp.id)
      expect(alloc.unit_id).to be_nil
    end

    it "TỪ CHỐI update nếu unit_id cũ rò rỉ kèm contact_point_id mới (hai recipient)" do
      new_cp = create(:contact_point, :residential, unit: unit, name: "Đầu mối rò rỉ")
      patch pump_allocation_path(alloc), params: { pump_allocation: {
        zone_id: zone.id, unit_id: unit.id, contact_point_id: new_cp.id,
        coefficient: "1", fixed_percentage: ""
      } }
      expect(response).to have_http_status(:unprocessable_content)
      alloc.reload
      expect(alloc.unit_id).to eq(unit.id)
      expect(alloc.contact_point_id).to be_nil
    end
  end


  describe "POST /pump_allocations — validations" do
    it "T53: chặn khi tổng fixed_percentage > 100" do
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             contact_point: nil, fixed_percentage: 80, coefficient: 1)
      another_unit = create(:unit, zone: zone)
      post pump_allocations_path, params: {
        pump_allocation: {
          zone_id: zone.id, unit_id: another_unit.id,
          coefficient: "0", fixed_percentage: "30"
        }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("không được vượt quá 100")
    end
  end

  describe "kỳ per-station (TN2)" do
    let(:system_admin) { create(:user, :system_admin) }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let!(:zone) { create(:zone, name: "KV req") }
    let!(:station) { create(:contact_point, :water_pump, name: "Trạm req", zone: zone) }
    let!(:unit) { create(:unit, zone: zone, name: "ĐV req") }
    before { sign_in system_admin }

    it "tạo phân bổ với block_id + pump_contact_point_id" do
      block = create(:block, unit: unit, name: "Khối req")
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM Khối req")
      expect {
        post pump_allocations_path, params: { pump_allocation: {
          zone_id: zone.id, pump_contact_point_id: station.id, block_id: block.id,
          coefficient: "1", fixed_percentage: ""
        } }
      }.to change(PumpAllocation, :count).by(1)
      expect(response).to redirect_to(pump_allocations_path)
      expect(PumpAllocation.last.block_id).to eq(block.id)
      expect(PumpAllocation.last.pump_contact_point_id).to eq(station.id)
    end

    it "index hiện tên trạm bơm" do
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path
      expect(response.body).to include("Trạm req")
    end

    it "form new (kỳ per-station) có select trạm bơm + radio loại đối tượng nhận" do
      get new_pump_allocation_path
      expect(response.body).to include("Trạm bơm")
      expect(response.body).to include('value="block"')
      expect(response.body).to include('value="group"')
    end

    it "new?pump_contact_point_id=X chọn sẵn trạm trong form" do
      get new_pump_allocation_path(pump_contact_point_id: station.id)
      html = Nokogiri::HTML(response.body)
      selected = html.css("select#pump_allocation_pump_contact_point_id option[selected]")
      expect(selected.first&.attr("value")).to eq(station.id.to_s)
    end

    # A: vào form qua "Thêm đối tượng vào trạm này" phải set sẵn ĐÚNG khu vực của
    # trạm (zone + trạm nhất quán) để Stimulus không disable fieldset vì zone trống.
    it "new?pump_contact_point_id=X chọn sẵn khu vực của trạm trong form" do
      get new_pump_allocation_path(pump_contact_point_id: station.id)
      html = Nokogiri::HTML(response.body)
      selected = html.css("select#pump_allocation_zone_id option[selected]")
      expect(selected.first&.attr("value")).to eq(station.zone_id.to_s)
    end

    it "index hiện một thẻ cho mỗi trạm; trạm rỗng có cảnh báo" do
      empty_station = create(:contact_point, :water_pump, name: "Trạm trống", zone: zone)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path
      html = Nokogiri::HTML(response.body)
      expect(html.css("[data-pump-station-card='#{station.id}']")).not_to be_empty
      empty_card = html.css("[data-pump-station-card='#{empty_station.id}']")
      expect(empty_card).not_to be_empty
      expect(empty_card.text).to include("chưa có đối tượng nhận")
    end
  end

  # CHIEU-phan-bo-tram-nhom: đối tượng nhận khối/nhóm + sắp xếp A→Z, tìm theo tên
  # trạm, thông tin cấu hình E1, empty-state, ẩn thẻ rỗng khi tìm kiếm — tầng
  # request/view (phân phối khối/nhóm đã có ở pump_allocation_calculator_spec.rb).
  describe "kỳ per-station — đối tượng khối/nhóm + nhóm theo trạm (E4)" do
    let(:system_admin) { create(:user, :system_admin) }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let!(:zone) { create(:zone, name: "KV E4") }
    let!(:unit) { create(:unit, zone: zone, name: "ĐV E4") }
    let!(:station) { create(:contact_point, :water_pump, name: "Trạm E4", zone: zone) }
    before { sign_in system_admin }

    # Cột cấp trong một dòng đối tượng (Đơn vị | Khối | Nhóm | Đầu mối | % cố định | Hệ số | Actions).
    cells = ->(row) { row.css("td").map { |td| td.text.strip } }

    # A — đối tượng khối hiển thị ở CỘT RIÊNG: Đơn vị = đơn vị cha, Khối = tên khối,
    # Nhóm/Đầu mối = "—".
    it "A: dòng khối có Đơn vị = đơn vị cha và Khối = tên khối, các cột khác —" do
      block = create(:block, unit: unit, name: "Khối Alpha")
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM Khối Alpha")
      alloc = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             block: block, unit: nil, contact_point: nil, group: nil, coefficient: 1)
      get pump_allocations_path
      row = Nokogiri::HTML(response.body).at_css(%([data-pump-allocation-target-id="#{alloc.id}"]))
      expect(row).to be_present
      unit_col, block_col, group_col, cp_col = cells.call(row)
      expect(unit_col).to eq(unit.name)
      expect(block_col).to eq("Khối Alpha")
      expect(group_col).to eq("—")
      expect(cp_col).to eq("—")
    end

    # B — đối tượng nhóm: Đơn vị = đơn vị cha, Nhóm = tên nhóm; Khối = khối của nhóm
    # nếu có (ở đây nhóm không gắn khối → "—"), Đầu mối = "—".
    it "B: dòng nhóm có Đơn vị = đơn vị cha và Nhóm = tên nhóm" do
      group = create(:group, unit: unit, name: "Nhóm Alpha")
      create(:contact_point, :residential, unit: unit, group: group, name: "ĐM Nhóm Alpha")
      alloc = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             group: group, unit: nil, contact_point: nil, block: nil, coefficient: 1)
      get pump_allocations_path
      row = Nokogiri::HTML(response.body).at_css(%([data-pump-allocation-target-id="#{alloc.id}"]))
      expect(row).to be_present
      unit_col, block_col, group_col, cp_col = cells.call(row)
      expect(unit_col).to eq(unit.name)
      expect(block_col).to eq("—")
      expect(group_col).to eq("Nhóm Alpha")
      expect(cp_col).to eq("—")
    end

    # B2 — đối tượng khối/nhóm: tên đơn vị sở hữu nằm ở CỘT "Đơn vị" (không gộp chung ô).
    it "B2: tên đơn vị sở hữu của khối/nhóm nằm ở cột Đơn vị" do
      block = create(:block, unit: unit, name: "Khối ngữ cảnh")
      group = create(:group, unit: unit, name: "Nhóm ngữ cảnh")
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM Khối ngữ cảnh")
      create(:contact_point, :residential, unit: unit, group: group, name: "ĐM Nhóm ngữ cảnh")
      alloc_block = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
                           block: block, unit: nil, contact_point: nil, group: nil, coefficient: 1)
      alloc_group = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
                           group: group, unit: nil, contact_point: nil, block: nil, coefficient: 1)
      get pump_allocations_path
      doc = Nokogiri::HTML(response.body)
      block_row = doc.at_css(%([data-pump-allocation-target-id="#{alloc_block.id}"]))
      group_row = doc.at_css(%([data-pump-allocation-target-id="#{alloc_group.id}"]))
      expect(cells.call(block_row)[0]).to eq(unit.name)
      expect(cells.call(block_row)[1]).to eq("Khối ngữ cảnh")
      expect(cells.call(group_row)[0]).to eq(unit.name)
      expect(cells.call(group_row)[2]).to eq("Nhóm ngữ cảnh")
    end

    # B3 — đối tượng đơn vị: chỉ cột Đơn vị có tên, còn lại "—". Đầu mối cấp khu vực
    # (không có đơn vị): cột Đơn vị = "—", cột Đầu mối = tên.
    it "B3: dòng đơn vị và dòng đầu-mối-khu-vực đặt đúng cột" do
      zone_cp = create(:contact_point, :zone_residential, name: "Chỉ huy KV E4", zone: zone)
      alloc_unit = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
                          unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      alloc_zone_cp = create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
                             contact_point: zone_cp, unit: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path
      doc = Nokogiri::HTML(response.body)
      unit_cells = cells.call(doc.at_css(%([data-pump-allocation-target-id="#{alloc_unit.id}"])))
      zone_cp_cells = cells.call(doc.at_css(%([data-pump-allocation-target-id="#{alloc_zone_cp.id}"])))
      expect(unit_cells[0]).to eq(unit.name)
      expect(unit_cells[1..3]).to eq(%w[— — —])
      expect(zone_cp_cells[0]).to eq("—")
      expect(zone_cp_cells[3]).to eq("Chỉ huy KV E4")
    end

    # C — POST create với group_id + pump_contact_point_id persist được.
    it "C: tạo phân bổ với group_id + pump_contact_point_id" do
      group = create(:group, unit: unit, name: "Nhóm tạo")
      create(:contact_point, :residential, unit: unit, group: group, name: "ĐM Nhóm tạo")
      expect {
        post pump_allocations_path, params: { pump_allocation: {
          zone_id: zone.id, pump_contact_point_id: station.id, group_id: group.id,
          coefficient: "1", fixed_percentage: ""
        } }
      }.to change(PumpAllocation, :count).by(1)
      expect(response).to redirect_to(pump_allocations_path)
      expect(PumpAllocation.last.group_id).to eq(group.id)
      expect(PumpAllocation.last.pump_contact_point_id).to eq(station.id)
    end

    # D — sắp xếp trạm A→Z và đối tượng A→Z trong một thẻ.
    it "D: thẻ trạm sắp A→Z và đối tượng trong thẻ sắp A→Z" do
      station_z = create(:contact_point, :water_pump, name: "Trạm Z", zone: zone)
      station_a = create(:contact_point, :water_pump, name: "Trạm A", zone: zone)
      unit_b = create(:unit, zone: zone, name: "ĐV Bravo")
      unit_a = create(:unit, zone: zone, name: "ĐV Alpha")
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
             unit: unit_b, contact_point: nil, block: nil, group: nil, coefficient: 1)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
             unit: unit_a, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path
      body = response.body
      expect(body.index("Trạm A")).to be < body.index("Trạm Z")
      expect(body.index("ĐV Alpha")).to be < body.index("ĐV Bravo")
    end

    # E — không có trạm nào (và không allocation) → empty-state "Không có bản ghi".
    it "E: không có trạm bơm nào → hiện empty-state" do
      station.discard
      get pump_allocations_path
      expect(response.body).to include(I18n.t("common.list.no_records"))
      expect(response.body).not_to include("data-pump-station-card")
    end

    # F — hàng "Tổng" trong tfoot: nhãn "Tổng" + Σ % cố định dưới đúng cột; KHÔNG
    # còn số đối tượng hệ số, KHÔNG còn "= 100%".
    it "F: tfoot hàng Tổng chỉ hiện nhãn Tổng + Σ % cố định" do
      block_fixed = create(:block, unit: unit, name: "Khối cố định")
      group_coef = create(:group, unit: unit, name: "Nhóm hệ số")
      create(:contact_point, :residential, unit: unit, block: block_fixed, name: "ĐM Khối cố định")
      create(:contact_point, :residential, unit: unit, group: group_coef, name: "ĐM Nhóm hệ số")
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             block: block_fixed, unit: nil, contact_point: nil, group: nil,
             fixed_percentage: 30, coefficient: 0)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             group: group_coef, unit: nil, contact_point: nil, block: nil,
             fixed_percentage: nil, coefficient: 1)
      get pump_allocations_path
      card = Nokogiri::HTML(response.body).css("[data-pump-station-card='#{station.id}']")
      tfoot = card.css("tfoot")
      expect(tfoot).not_to be_empty
      expect(tfoot.text).to include(I18n.t("pump_allocations.index.total_label"))
      # Cột % cố định: tổng giá trị (số + %), không còn nhãn "Σ % cố định:".
      expect(tfoot.text).to include("30,00%")
      expect(tfoot.text).not_to include("Σ")
      expect(tfoot.text).not_to include("= 100")
      # KHÔNG còn số đối tượng hệ số trong tfoot.
      expect(tfoot.text).not_to include(
        I18n.t("pump_allocations.index.coefficient_count", count: 1)
      )
    end

    # G — tìm theo tên trạm (chứng minh join pump_contact_points.name); query không
    # khớp đối tượng lẫn trạm → không thẻ nào.
    it "G: tìm theo tên trạm hiện thẻ trạm đó; query không khớp → không thẻ" do
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path, params: { q: "Trạm E4" }
      html = Nokogiri::HTML(response.body)
      expect(html.css("[data-pump-station-card='#{station.id}']")).not_to be_empty

      get pump_allocations_path, params: { q: "không khớp gì cả" }
      html = Nokogiri::HTML(response.body)
      expect(html.css("[data-pump-station-card]")).to be_empty
    end

    # H — khi tìm kiếm, thẻ rỗng (trạm chưa cấu hình) KHÔNG render.
    it "H: tìm theo đối tượng của trạm cấu hình → ẩn thẻ trạm rỗng" do
      empty_station = create(:contact_point, :water_pump, name: "Trạm rỗng H", zone: zone)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path, params: { q: unit.name }
      html = Nokogiri::HTML(response.body)
      expect(html.css("[data-pump-station-card='#{station.id}']")).not_to be_empty
      expect(html.css("[data-pump-station-card='#{empty_station.id}']")).to be_empty
      expect(response.body).not_to include(I18n.t("pump_allocations.index.station_without_recipient"))
    end
  end

  # CHIEU-tram-phan-tram-khu-vuc: % của khu vực mỗi trạm = D_trạm / D_khu_vực, suy từ
  # CHỈ SỐ HIỆN TẠI (không cần đã tính toán). Công tơ bơm no_loss → tổn hao 0 nên
  # D = sử dụng, dễ kiểm tra số mong đợi.
  describe "kỳ per-station — % của khu vực mỗi trạm (suy từ chỉ số)" do
    let(:system_admin) { create(:user, :system_admin) }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let!(:zone) { create(:zone, name: "KV %") }
    let!(:unit) { create(:unit, zone: zone, name: "ĐV %") }
    let!(:station_west) { create(:contact_point, :water_pump, name: "Trạm bơm Tây", zone: zone) }
    let!(:station_east) { create(:contact_point, :water_pump, name: "Trạm bơm Đông", zone: zone) }
    before { sign_in system_admin }

    let!(:unit2) { create(:unit, zone: zone, name: "ĐV % 2") }

    # D_Tây = 65, D_Đông = 35 → 65% và 35%; tổng = 100%.
    def add_pump_reading(station, usage, recipient_unit)
      meter = create(:meter, contact_point: station, no_loss: true)
      reading = meter.meter_readings.find_or_initialize_by(period: period)
      reading.update!(reading_start: 0, reading_end: usage, no_loss: true)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: recipient_unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
    end

    it "tiêu đề thẻ hiện kW tuyệt đối + 'chiếm X% điện bơm của khu vực'" do
      add_pump_reading(station_west, 65, unit)
      add_pump_reading(station_east, 35, unit2)
      get pump_allocations_path, params: { zone_id: zone.id }
      doc = Nokogiri::HTML(response.body)
      west = doc.at_css("[data-pump-station-name='#{station_west.id}']").text
      east = doc.at_css("[data-pump-station-name='#{station_east.id}']").text
      expect(west).to include("65%")
      expect(west).to include("kW")
      expect(east).to include("35%")
      expect(east).to include("kW")
    end

    it "D_khu_vực = 0 (chưa nhập chỉ số) → hiện '—', không chia cho 0" do
      # Có trạm + đối tượng nhưng KHÔNG có meter_reading → D_khu_vực = 0.
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_west,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      get pump_allocations_path, params: { zone_id: zone.id }
      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      title = doc.at_css("[data-pump-station-name='#{station_west.id}']").text
      # Không có chuỗi "chiếm ...% điện bơm"; tiêu đề chỉ là tên trạm.
      expect(title).not_to include("chiếm")
      expect(title.strip).to include("Trạm bơm Tây")
    end
  end
end
