require "rails_helper"

# Demo spec for TN1 — cột "Khác" dạng hệ số (đơn vị). A narrated, recorded
# walkthrough for the owner (pre-merge) and the customer (pre-release). Runs in
# CI like any spec (green-to-merge → anti-drift). Backfills the demo for a
# feature that shipped (PR #327, #319) before the demo engine existed, so the
# 1.2.0 release bundle covers it (#351/#355). See ADR-036..041 (#343), ADR-025
# (the feature: docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md).
#
# Tells the whole customer story for the feature (#363): the pain it removes
# (the kitchen credit used to be hand-computed and re-done every period), the
# setup, the correct result mirroring the customer's example (nghiệp vụ 10.2.1,
# Tiểu đoàn 1 has 22 residential people outside the kitchen → −2 × 22 = −44),
# the self-recalculation across periods (grow Đại đội 1 by 4 → the credit
# auto-moves to −52 with nothing re-entered), and who may change it (an admin
# sets it; a commander only views — controls are locked).
RSpec.describe "Demo: cột Khác hệ số đơn vị", type: :demo do
  include_context "demo seeded world"

  it "đặt khoản trừ Khác theo hệ số đơn vị cho bếp, tự tính lại sang kỳ sau, chỉ huy chỉ xem",
    demo_nv: %w[NV-cot-khac-he-so-don-vi] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực 1")
    unit = Unit.find_by!(name: "Tiểu đoàn 1")
    period = Period.find_by!(closed: false)
    kitchen = ContactPoint.find_by!(
      name: "Bếp ăn Tiểu đoàn 1", contact_point_type: "residential", unit_id: unit.id
    )
    dai_doi_1 = ContactPoint.find_by!(
      name: "Đại đội 1", contact_point_type: "residential", unit_id: unit.id
    )
    # The seeded "Khác" row for the kitchen (type starts as "fixed").
    other_deduction = OtherDeduction.find_by!(period_id: period.id, contact_point_id: kitchen.id)
    type_field = "other_deductions[#{other_deduction.id}][other_type]"
    value_field = "other_deductions[#{other_deduction.id}][other_value]"
    name_cell = "[data-contact-point-name-id='#{kitchen.id}']"
    other_cell = "[data-other-deduction-cp-id='#{kitchen.id}']"
    dai_doi_1_personnel = "[data-total-personnel-cp-id='#{dai_doi_1.id}']"

    # Sign in as the seeded admin (db/seeds/demo.rb) — programmatic, no login page.
    demo.sign_in_as(User.find_by!(username: "demo_admin"), role_label: "Quản trị viên")
    expect(page).to have_current_path("/", wait: 10)

    # Open the unit's config directly (zone + unit in the query so we land on the
    # "Khác" table without driving the filter dropdowns).
    demo.visit(
      "/unit_config?zone_id=#{zone.id}&unit_id=#{unit.id}",
      caption: "Mở Cấu hình đơn vị — Tiểu đoàn 1, kỳ tháng 6/2026"
    )
    demo.narrate("Bếp ăn phục vụ cả tiểu đoàn — mỗi người góp một phần tiêu chuẩn, bếp nhận lại tổng")
    demo.narrate(%(Trước phải tính tay mỗi kỳ; cách "Theo hệ số (đơn vị)" nhập một lần, hệ thống tự tính))

    # Pick the unit-coefficient type and a negative coefficient (bếp được cộng ngược).
    demo.select(
      "Theo hệ số (đơn vị)", from: type_field,
      caption: %(Chọn "Theo hệ số (đơn vị)" cho đầu mối Bếp ăn)
    )
    demo.fill(value_field, with: "-2", caption: "Hệ số −2: mỗi người trong tiểu đoàn góp 2 kW cho bếp")
    demo.click("Lưu cấu hình", caption: "Lưu — không cần tính tay, hệ thống tự tính theo quân số kỳ này")

    # Real assertions → green-to-merge.
    expect(page).to have_content("Đã lưu cấu hình đơn vị.", wait: 10)
    expect(page).to have_field(value_field, with: "-2.0")
    other_deduction.reload
    expect(other_deduction.other_type).to eq("unit_coefficient")
    expect(other_deduction.other_value).to eq(BigDecimal("-2"))

    # Show the EFFECT on the billing table — recalculate, then surface the kitchen
    # row: its name first (scroll left) and its −44 "Khác" cell (scroll right).
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Mở bảng tính tiền của khu vực")
    demo.click("Tính toán lại", confirm: true, caption: "Tính toán lại theo cấu hình vừa lưu")
    expect(page).to have_content("Đã tính toán lại bảng tính tiền.", wait: 15)
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Mở lại bảng tính tiền để xem kết quả")
    expect(page).to have_content("Bếp ăn Tiểu đoàn 1", wait: 15)
    demo.highlight(name_cell, caption: "Đầu mối Bếp ăn Tiểu đoàn 1 — bếp ăn chung của tiểu đoàn")
    demo.highlight(
      other_cell,
      caption: "Cột Khác của Bếp ăn = −44 kW — bếp được cộng ngược theo quân số phần còn lại của tiểu đoàn"
    )

    calc = Calculation.find_by!(contact_point_id: kitchen.id, period_id: period.id)
    expect(calc.other_deduction).to eq(BigDecimal("-44"))

    # (Excel export is intentionally NOT shown here: a browser recording cannot
    # render an .xlsx, so showing it would be theatre. The export is covered by
    # billing_spec's :xlsx request specs instead — #363.)

    # The whole point of the unit-coefficient: it is re-derived every period from
    # live headcount, with no re-entry. Close this period, open the next, grow Đại
    # đội 1 by 4 → the kitchen's credit auto-moves from −44 to −52.
    demo.narrate("Sang kỳ sau, hệ số −2 được giữ nguyên — chỉ quân số đổi là khoản trừ tự tính lại")
    demo.visit("/pricing", caption: "Mở trang Đơn giá điện để chuyển sang kỳ mới")
    demo.click("Đóng kỳ hiện tại", confirm: true, caption: "Đóng kỳ tháng 6/2026 — khóa số liệu")
    expect(page).to have_content("Đã đóng kỳ tháng 6/2026.", wait: 15)
    demo.click("Mở kỳ tháng 7/2026", confirm: true, caption: "Mở kỳ tháng 7/2026 — kế thừa cấu hình kỳ trước")
    expect(page).to have_content("Đã mở kỳ tháng 7/2026.", wait: 15)

    period_next = Period.order(:id).last
    rank_soldier = period_next.ranks.find_by!(position: 7)
    personnel_field = "contact_point[personnel_counts][#{rank_soldier.id}]"

    demo.visit(
      "/contact_points/#{dai_doi_1.id}/edit",
      caption: "Sửa quân số Đại đội 1 cho kỳ mới — không mở lại cấu hình bếp"
    )
    demo.fill(personnel_field, with: "16", caption: "Đại đội 1 thêm 4 hạ sĩ quan, binh sĩ (12 → 16)")
    demo.click("Cập nhật", caption: "Lưu quân số kỳ tháng 7/2026")
    expect(page).to have_content("Đã cập nhật", wait: 10)

    demo.visit("/billing?zone_id=#{zone.id}", caption: "Mở bảng tính tiền kỳ tháng 7/2026")
    demo.click("Tính toán lại", confirm: true, caption: "Tính toán lại kỳ mới")
    expect(page).to have_content("Đã tính toán lại bảng tính tiền.", wait: 15)
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Xem lại kết quả kỳ mới")
    expect(page).to have_content("Bếp ăn Tiểu đoàn 1", wait: 15)
    # Show cause then effect, both on screen: Đại đội 1's headcount grew (16 → 20)…
    demo.highlight(
      dai_doi_1_personnel,
      caption: "Đại đội 1 giờ 20 người — vừa thêm 4 ở bước trước, quân số đơn vị tăng"
    )
    # …so the kitchen's credit auto-grows, with the coefficient never re-entered.
    demo.highlight(
      other_cell,
      caption: "Khác của Bếp ăn tự −44 → −52 kW theo quân số mới — không ai mở lại, không nhập lại hệ số"
    )

    # The coefficient carried over untouched; only the result moved with headcount.
    other_deduction_next = OtherDeduction.find_by!(period_id: period_next.id, contact_point_id: kitchen.id)
    expect(other_deduction_next.other_type).to eq("unit_coefficient")
    expect(other_deduction_next.other_value).to eq(BigDecimal("-2"))
    calc_next = Calculation.find_by!(contact_point_id: kitchen.id, period_id: period_next.id)
    expect(calc_next.other_deduction).to eq(BigDecimal("-52"))

    # Who may change this? An admin sets it; a commander only views — the type
    # select is locked and there is no save button (CHIEU-khac-don-vi-vai-tro).
    demo.narrate("Ai được đổi cấu hình tính tiền? Quản trị viên đơn vị đặt — còn chỉ huy thì sao?")
    demo.sign_in_as(User.find_by!(username: "demo_commander"), role_label: "Chỉ huy")
    expect(page).to have_current_path("/", wait: 10)

    demo.visit("/unit_config", caption: "Chỉ huy mở Cấu hình đơn vị — đúng trang vừa rồi")
    expect(page).to have_content("Bếp ăn Tiểu đoàn 1", wait: 10)
    commander_type_select = "select[name=\"other_deductions[#{other_deduction_next.id}][other_type]\"]"
    demo.highlight(
      commander_type_select,
      caption: "Chỉ huy mở đúng cấu hình bếp — nhưng ô hệ số Khác bị khóa, không có nút Lưu: chỉ xem"
    )
    expect(page).to have_css("#{commander_type_select}[disabled]", wait: 10)
    expect(page).to have_no_button("Lưu cấu hình")
  end
end
