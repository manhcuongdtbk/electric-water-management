require "rails_helper"

# Demo spec for TN2 — phân bổ điện bơm nước theo từng trạm bơm. A narrated,
# recorded walkthrough for the owner (pre-merge) and the customer (pre-release).
# Runs in CI like any spec (green-to-merge → anti-drift). See ADR-059 (the demo
# bundle "demo tốt" standard) and the TN2 feature design.
#
# The customer story (no fabricated geography — a station "phục vụ một vùng" means
# nothing more than "có danh sách đối tượng nhận riêng"): a zone can have MORE THAN
# ONE pump station. Before TN2, the zone's whole pump electricity was pooled and
# split across the entire zone, so a unit paid for a station that never served it.
# Now each station carries its OWN recipient list, and its electricity is shared
# ONLY among those recipients. The demo shows the grouped page with two stations
# and their distinct recipient lists, expands a Khối + a Nhóm recipient (TN2 adds
# Khối, Nhóm và đầu mối sinh hoạt thuộc đơn vị as recipient types, on top of the
# đơn vị + đầu mối khu vực that already existed), ADDS a real recipient to one
# station through the live form, recalculates billing, and proves on the per-station
# table that Đại đội 1 (Tiểu đoàn 2) draws electricity from Trạm bơm Đông and 0,00
# from Trạm bơm Tây — the two stations' electricity never mixes. It then reopens an
# OLD period (pre-TN2) and proves backward compatibility: zone-wide pooling still
# works, TN2 changed nothing for legacy data.
RSpec.describe "Demo: phân bổ điện bơm theo từng trạm bơm", type: :demo do
  include_context "demo seeded world"

  it "mỗi trạm bơm có danh sách đối tượng nhận riêng, kỳ cũ vẫn gộp toàn khu vực",
    demo_id: "tn2_phan_bo_bom", demo_nv: %w[NV-phan-bo-bom-theo-tram] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    legacy_period = Period.find_by!(year: 2026, month: 5)
    station_tay = ContactPoint.find_by!(
      name: "Trạm bơm Tây", contact_point_type: "water_pump", zone_id: zone.id
    )
    station_dong = ContactPoint.find_by!(
      name: "Trạm bơm Đông", contact_point_type: "water_pump", zone_id: zone.id
    )
    unit_alpha = Unit.find_by!(name: "Tiểu đoàn 1")
    unit_beta = Unit.find_by!(name: "Tiểu đoàn 2")

    # Beat-4 recipients to expand: a Khối on Trạm bơm Tây and a Nhóm on Trạm
    # bơm Đông — recipients are no longer limited to đơn vị.
    block_ban_chi_huy = Block.find_by!(name: "Ban Chỉ huy", unit_id: unit_alpha.id)
    group_quan_y = Group.find_by!(name: "Tổ Quân y", unit_id: unit_beta.id)
    alloc_khoi = PumpAllocation.find_by!(
      period_id: period.id, pump_contact_point_id: station_tay.id,
      block_id: block_ban_chi_huy.id
    )
    alloc_nhom = PumpAllocation.find_by!(
      period_id: period.id, pump_contact_point_id: station_dong.id,
      group_id: group_quan_y.id
    )

    # Beat-5 add: a recipient NOT yet on any station, added to Trạm bơm Tây
    # through the real form. "Nhà ăn" (đầu mối public, Tiểu đoàn 1) is unallocated
    # in the seed; a fixed 10% keeps Trạm bơm Tây valid (Σ% = 30 + 10 = 40 ≤ 100)
    # and touches NO Beta recipient, so the no-mixing proof below stays clean.
    nha_an = ContactPoint.find_by!(
      name: "Nhà ăn", contact_point_type: "public", unit_id: unit_alpha.id
    )

    # Beat-6 proof: a residential contact point that sits under ONE station's area
    # only. Đại đội 1 (Tiểu đoàn 2) receives pump electricity solely via the Beta
    # đơn-vị allocation on Trạm bơm Đông → non-zero from Đông, 0 from Tây.
    dai_doi_1_beta = ContactPoint
      .where(name: "Đại đội 1", contact_point_type: "residential", unit_id: unit_beta.id)
      .first!

    # Backward-compat data: the legacy period (pre-TN2) uses zone-wide pooling.
    cp_chi_huy_kv = ContactPoint.find_by!(
      name: "Chỉ huy khu vực 1", contact_point_type: "residential",
      zone_id: zone.id, unit_id: nil
    )

    # =========================================================================
    # PHẦN 1: Kỳ mới — phân bổ theo từng trạm bơm
    # =========================================================================

    # 1. Đăng nhập — programmatic, no login page.
    demo.sign_in_as(User.find_by!(username: "demo_admin"), role_label: "Quản trị viên hệ thống")
    expect(page).to have_current_path("/", wait: 10)

    # 2. Mở Phân bổ bơm nước cho khu vực, nêu đúng vấn đề của khách.
    demo.visit(
      "/pump_allocations?zone_id=#{zone.id}",
      caption: "Mở Phân bổ bơm nước — Khu vực 1, kỳ tháng 6/2026"
    )
    demo.narrate("Trước đây điện cả hai trạm bơm gộp chung rồi chia cho toàn khu vực — đối tượng nhận phải gánh cả điện của trạm không phục vụ mình")
    demo.narrate("Giờ mỗi trạm bơm có danh sách đối tượng nhận riêng — điện của trạm chỉ chia trong danh sách đó")
    expect(page).to have_content("Trạm bơm Tây", wait: 10)
    expect(page).to have_content("Trạm bơm Đông")

    # 3. Cho thấy HAI trạm, mỗi trạm một thẻ với danh sách riêng.
    demo.highlight(
      "[data-pump-station-card='#{station_tay.id}']",
      caption: "Trạm bơm Tây — danh sách đối tượng nhận riêng"
    )
    demo.highlight(
      "[data-pump-station-card='#{station_dong.id}']",
      caption: "Trạm bơm Đông — danh sách riêng, khác trạm Tây"
    )

    # 4. Cho thấy đối tượng nhận đã được bổ sung. Trước TN2 có 3 loại: đơn vị, đầu mối
    #    sinh hoạt thuộc khu vực, đầu mối ngoài biên chế thuộc khu vực. TN2 thêm 3 loại
    #    nữa: Khối, Nhóm, đầu mối sinh hoạt thuộc đơn vị (đủ 6 loại — nghiệp vụ §9.2).
    demo.highlight(
      "[data-pump-allocation-target-id='#{alloc_khoi.id}']",
      caption: "Trạm bơm Tây nhận về một Khối — Ban Chỉ huy của Tiểu đoàn 1"
    )
    demo.highlight(
      "[data-pump-allocation-target-id='#{alloc_nhom.id}']",
      caption: "Trạm bơm Đông nhận về một Nhóm — Tổ Quân y của Tiểu đoàn 2"
    )
    demo.narrate("Trước đây chỉ có ba loại đối tượng nhận: đơn vị, đầu mối sinh hoạt thuộc khu vực, đầu mối ngoài biên chế thuộc khu vực. TN2 bổ sung thêm ba loại: Khối, Nhóm, và đầu mối sinh hoạt thuộc đơn vị")

    # Real assertions on the seeded configuration → green-to-merge.
    expect(period.pump_allocation_per_station).to be(true)
    expect(alloc_khoi.pump_contact_point).to eq(station_tay)
    expect(alloc_nhom.pump_contact_point).to eq(station_dong)

    # 4b. Xem "Tất cả khu vực" — bỏ bộ lọc khu vực. Quản trị viên hệ thống quản nhiều
    #     khu vực, mỗi trạm có thể trùng tên giữa các khu vực, nên tiêu đề mỗi thẻ trạm
    #     kèm luôn tên khu vực để biết trạm nào thuộc khu vực nào.
    demo.visit(
      "/pump_allocations",
      caption: "Bỏ bộ lọc — xem trạm bơm của tất cả khu vực cùng lúc"
    )
    demo.narrate("Khi xem tất cả khu vực, tiêu đề mỗi thẻ trạm kèm luôn tên khu vực — biết ngay trạm nào thuộc khu vực nào, kể cả khi hai khu vực có trạm trùng tên")
    demo.highlight(
      "[data-pump-station-name='#{station_tay.id}']",
      caption: "Trạm bơm Tây · Khu vực 1 — tiêu đề thẻ kèm tên khu vực"
    )
    # Thật trên màn: tiêu đề thẻ trạm có tên khu vực (station_card_with_zone) khi
    # quản trị viên xem mọi khu vực (chưa lọc) → người xem phân biệt được khu vực.
    within("[data-pump-station-card='#{station_tay.id}']") do
      expect(page).to have_content(zone.name, wait: 10)
    end
    expect(page).to have_css(
      "[data-pump-station-name='#{station_tay.id}']", text: zone.name
    )

    # 5. Thêm một đối tượng THẬT vào riêng Trạm bơm Tây, qua đúng form người dùng.
    demo.visit(
      "/pump_allocations/new?pump_contact_point_id=#{station_tay.id}",
      caption: "Thêm đối tượng nhận cho riêng Trạm bơm Tây — khu vực đã tự chọn sẵn"
    )
    # Vào form qua "Thêm đối tượng vào trạm này" → khu vực của trạm đã được chọn sẵn,
    # không cần chọn lại. Kiểm tra để chắc chắn form mở ra ở đúng khu vực.
    expect(page).to have_select("pump_allocation[zone_id]", selected: "Khu vực 1")
    # Đối tượng nhận = Đầu mối (radio name=target_mode). Stimulus hiện ô chọn đầu mối.
    page.find("input[name='target_mode'][value='contact_point']").click
    demo.select(
      "Nhà ăn", from: "pump_allocation[contact_point_id]",
      caption: "Chọn đầu mối Nhà ăn — chưa thuộc trạm bơm nào"
    )
    # Chế độ phân bổ = % cố định (radio name=alloc_mode).
    page.find("input[name='alloc_mode'][value='fixed']").click
    demo.fill(
      "pump_allocation[fixed_percentage]", with: "10",
      caption: "Nhà ăn nhận 10% điện của riêng Trạm bơm Tây"
    )
    demo.click("Lưu", caption: "Lưu — thêm đối tượng cho riêng trạm này")
    expect(page).to have_content("Đã tạo", wait: 10)

    # The new recipient persists AND shows inside Trạm bơm Tây's card only.
    alloc_nha_an = PumpAllocation.find_by!(
      period_id: period.id, pump_contact_point_id: station_tay.id,
      contact_point_id: nha_an.id
    )
    expect(alloc_nha_an.fixed_percentage).to eq(BigDecimal("10"))
    demo.visit(
      "/pump_allocations?zone_id=#{zone.id}",
      caption: "Quay lại danh sách — Nhà ăn giờ nằm trong Trạm bơm Tây"
    )
    within("[data-pump-station-card='#{station_tay.id}']") do
      expect(page).to have_content("Nhà ăn", wait: 10)
    end
    demo.highlight(
      "[data-pump-allocation-target-id='#{alloc_nha_an.id}']",
      caption: "Nhà ăn vừa thêm — chỉ thuộc Trạm bơm Tây, đúng danh sách riêng của trạm"
    )

    # 6. Khép vòng trên Bảng tính tiền: tính lại, rồi đọc bảng điện bơm theo trạm.
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Mở bảng tính tiền — Khu vực 1")
    demo.click("Tính toán lại", confirm: true, caption: "Tính toán lại bảng tính tiền")
    expect(page).to have_content("Đã tính toán lại bảng tính tiền.", wait: 15)
    # Tính toán lại redirect thẳng về bảng tính tiền với kết quả mới — bảng điện bơm
    # theo trạm đã có sẵn trên trang này, không cần mở lại.
    expect(page).to have_css("[data-pump-station-table]", wait: 10)

    # 6a. Bộ lọc bảng tính tiền — xem "Tất cả" (không chọn khu vực): mỗi khu vực một
    #     bảng điện bơm theo trạm riêng, mỗi bảng kèm tên khu vực ở tiêu đề.
    demo.visit("/billing", caption: "Bỏ bộ lọc khu vực — bảng tính tiền của tất cả khu vực")
    demo.narrate("Không chọn khu vực thì bảng tính tiền gộp mọi khu vực — mỗi khu vực có bảng điện bơm theo trạm riêng, tiêu đề kèm tên khu vực")
    expect(page).to have_css("[data-pump-station-table]", wait: 10)

    # 6b. Lọc theo một khu vực VÀ một đơn vị — chỉ còn đầu mối của đơn vị đó trên bảng
    #     chính. Đại đội 1 thuộc Tiểu đoàn 2 nên vẫn hiện; bảng điện bơm theo trạm
    #     (cấp khu vực) vẫn đủ các trạm để đối chiếu.
    demo.visit(
      "/billing?zone_id=#{zone.id}&unit_id=#{unit_beta.id}",
      caption: "Lọc Khu vực 1 và Tiểu đoàn 2 — bảng tính tiền chính chỉ còn đầu mối của đơn vị này, bảng chi tiết theo trạm vẫn hiện toàn khu vực để đối chiếu"
    )
    demo.narrate("Chọn cả khu vực và đơn vị thì bảng chính chỉ còn đầu mối của đơn vị đó — bảng chi tiết theo trạm vẫn hiện toàn khu vực vì điện bơm tính ở cấp khu vực")
    expect(page).to have_css("[data-pump-station-table]", wait: 10)
    expect(page).to have_css("[data-water-pump-usage-cp-id='#{dai_doi_1_beta.id}']", wait: 10)

    demo.highlight(
      "[data-pump-station-table]",
      caption: "Bảng điện bơm nước theo từng trạm — mỗi trạm một cột"
    )
    demo.highlight(
      "[data-pump-charge-row='#{dai_doi_1_beta.id}']",
      caption: "Đại đội 1 (Tiểu đoàn 2) — đầu mối chỉ thuộc danh sách của Trạm bơm Đông"
    )
    demo.highlight(
      "[data-pump-charge-cell='#{dai_doi_1_beta.id}-#{station_dong.id}']",
      caption: "Nhận điện từ Trạm bơm Đông"
    )
    demo.highlight(
      "[data-pump-charge-cell='#{dai_doi_1_beta.id}-#{station_tay.id}']",
      caption: "0,00 từ Trạm bơm Tây — điện hai trạm không lẫn nhau"
    )
    demo.narrate("Đại đội 1 chỉ nhận điện từ Trạm bơm Đông, 0 từ Trạm bơm Tây — mỗi trạm chia điện trong danh sách riêng của mình")

    # Real proof on screen AND in the data: non-zero from Đông, exactly 0 from Tây.
    charge_from_dong = PumpStationCharge.find_by(
      period_id: period.id, contact_point_id: dai_doi_1_beta.id,
      pump_contact_point_id: station_dong.id
    )
    expect(charge_from_dong).to be_present
    expect(charge_from_dong.amount).to be > BigDecimal("0")
    expect(
      PumpStationCharge.find_by(
        period_id: period.id, contact_point_id: dai_doi_1_beta.id,
        pump_contact_point_id: station_tay.id
      )
    ).to be_nil
    expect(page).to have_css(
      "[data-pump-charge-cell='#{dai_doi_1_beta.id}-#{station_tay.id}']", text: "0,00"
    )

    # 7. Đối chiếu THẤY ĐƯỢC: trong CÙNG một màn (đã lọc Tiểu đoàn 2), đọc đúng con số
    #    ở ô tổng theo trạm và ô "Sử dụng điện bơm nước", rồi khẳng định chúng bằng nhau.
    total_cell = page.find("[data-pump-charge-total='#{dai_doi_1_beta.id}']")
    usage_cell = page.find("[data-water-pump-usage-cp-id='#{dai_doi_1_beta.id}']")
    total_text = total_cell.text.strip.delete("*")
    usage_text = usage_cell.text.strip
    demo.highlight(
      "[data-pump-charge-total='#{dai_doi_1_beta.id}']",
      caption: "Tổng điện bơm của Đại đội 1 trên bảng chi tiết theo trạm: #{total_text}"
    )
    demo.highlight(
      "[data-water-pump-usage-cp-id='#{dai_doi_1_beta.id}']",
      caption: "Cùng con số #{usage_text} ở cột \"Sử dụng điện bơm nước\" trên bảng tính tiền chính"
    )
    demo.narrate("Cả hai ô đều là #{total_text} — tổng theo trạm của Đại đội 1 khớp đúng ô Sử dụng điện bơm nước trên bảng chính, bảng theo trạm chỉ bóc tách cùng một con số")

    expect(usage_text).to eq(total_text)
    per_station_total = PumpStationCharge
      .where(period_id: period.id, contact_point_id: dai_doi_1_beta.id)
      .sum(:amount)
    calc_dai_doi_1 = Calculation.find_by!(period_id: period.id, contact_point_id: dai_doi_1_beta.id)
    expect(per_station_total).to eq(calc_dai_doi_1.water_pump_usage)
    expect(per_station_total).to be > BigDecimal("0")

    # =========================================================================
    # PHẦN 2: Kỳ cũ trước TN2 — gộp toàn khu vực, không đổi
    # =========================================================================

    demo.narrate("Kỳ cũ trước khi có tính năng phân bổ theo từng trạm thì sao? Mở lại kỳ cũ để kiểm chứng")

    # Precondition: the seed left May 2026 closed + legacy (gộp toàn khu vực), June
    # 2026 open + per-station.
    expect(legacy_period.pump_allocation_per_station).to be(false)
    expect(legacy_period.closed?).to be(true)
    expect(legacy_period.pump_allocations.where(zone_id: zone.id, pump_contact_point_id: nil).count).to eq(2)

    # Reopen the old period: close June first, then reopen May. Now current_period =
    # May → "Trạng thái C: Kỳ cũ mở lại" (V2_HANH_VI_HE_THONG.md mục 3).
    PeriodService.new.close_period(period)
    PeriodService.new.reopen_period(legacy_period)
    expect(Period.current).to eq(legacy_period)

    # 8. Mở Phân bổ bơm nước cho kỳ cũ — chỉ còn MỘT thẻ gộp, không có thẻ theo trạm.
    demo.visit(
      "/pump_allocations?zone_id=#{zone.id}",
      caption: "Mở Phân bổ bơm nước — kỳ cũ tháng 5/2026 vừa mở lại"
    )
    demo.narrate("Đây là kỳ cũ trước khi có tính năng phân bổ theo từng trạm — toàn bộ điện bơm của khu vực vẫn gộp chung thành một")
    demo.narrate("Kỳ cũ giữ nguyên cách gộp toàn khu vực — tính năng phân bổ theo từng trạm chỉ áp dụng cho kỳ mới, không đụng tới kỳ đã đóng")
    expect(page).to have_content("Gộp toàn khu vực (kỳ cũ)", wait: 10)
    expect(page).to have_css("[data-pump-station-card='']", wait: 10)
    expect(page).to have_no_content("Trạm bơm Tây")
    expect(page).to have_no_content("Trạm bơm Đông")

    demo.highlight(
      "[data-pump-station-card='']",
      caption: "Thẻ \"Gộp toàn khu vực (kỳ cũ)\" — một danh sách chung cho cả khu vực, đúng cách kỳ cũ vẫn làm"
    )

    within("[data-pump-station-card='']") do
      expect(page).to have_content("Tiểu đoàn 2", wait: 10)
      expect(page).to have_content("Chỉ huy khu vực 1")
    end

    # 9. Bảng tính tiền kỳ cũ — cột "Sử dụng điện bơm nước" vẫn gộp, KHÔNG có bảng
    #    chi tiết theo trạm.
    demo.visit(
      "/billing?zone_id=#{zone.id}&period_id=#{legacy_period.id}",
      caption: "Mở Bảng tính tiền — kỳ cũ tháng 5/2026"
    )
    demo.narrate("Trên bảng tính tiền của kỳ cũ, cột Sử dụng điện bơm nước vẫn là phần điện bơm gộp toàn khu vực chia cho từng đối tượng nhận")
    demo.narrate("Không có bảng chi tiết điện bơm nước theo trạm — kỳ cũ không bóc tách theo trạm, đúng như trước khi có tính năng mới")
    expect(page).to have_content("Sử dụng điện bơm nước", wait: 10)

    usage_cell = page.find("[data-water-pump-usage-cp-id='#{cp_chi_huy_kv.id}']")
    demo.highlight(
      "[data-water-pump-usage-cp-id='#{cp_chi_huy_kv.id}']",
      caption: "Chỉ huy khu vực 1 — điện bơm gộp toàn khu vực: #{usage_cell.text.strip}"
    )

    expect(page).to have_no_css("[data-pump-station-table]")
    expect(page).to have_no_content("Chi tiết điện bơm nước theo trạm")

    # Backward-compat correctness: Σ recipients' water_pump_usage == zone's pump total.
    pooled_water_pump_usage = Calculation.where(period_id: legacy_period.id).sum(:water_pump_usage)
    loss = LossCalculator.new(zone: zone, period: legacy_period).call
    query = ZoneQuery.new(zone: zone, period: legacy_period)
    usages = query.meter_usages
    zone_pump_total = query.pump_meters.to_a.sum(BigDecimal("0")) do |meter|
      (usages[meter.id] || BigDecimal("0")) + (loss.meter_losses[meter.id] || BigDecimal("0"))
    end
    expect(zone_pump_total).to be > BigDecimal("0")
    expect(pooled_water_pump_usage).to eq(zone_pump_total)
    expect(PumpStationCharge.where(period_id: legacy_period.id).count).to eq(0)

    demo.narrate("Tổng điện bơm chia cho các đối tượng nhận đúng bằng điện bơm thật của cả khu vực — kỳ cũ tính y hệt trước đây, tính năng mới không làm sai lệch số liệu kỳ đã đóng")
  end
end
