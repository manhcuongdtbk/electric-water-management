require "rails_helper"

# Demo spec for TN3 loss breakdown + freshness indicator — a single billing-page
# story covering both features. A narrated, recorded walkthrough for the owner
# (pre-merge) and the customer (pre-release). Runs in CI like any spec
# (green-to-merge → anti-drift).
#
# Covers:
#   - TN3 (#319/#332): cột "Tổn hao" + "Sử dụng thực tế" trên bảng tính tiền,
#     trang chỉ số đầu mối, trang chỉ số bơm nước; bảng đối chiếu tổn hao/sử
#     dụng theo loại đầu mối (A/B/C reconciliation)
#   - Freshness (#334): chỉ báo "cần tính lại" trên 5 trang dữ liệu dẫn xuất +
#     guard Xuất Excel khi dữ liệu đã cũ
#
# Customer story: the main meter reads more than all sub-meters combined — the
# difference is transmission loss. The system now calculates loss automatically
# and shows it on THREE pages (billing reconciliation table, meter entries, pump
# entries). And when someone edits a meter reading, a stale-data badge appears on
# EVERY derived-data page (billing, meter entries, pump entries, dashboard,
# electricity supply) — so no one accidentally exports or reads outdated numbers.
#
# Calculation is triggered in a before hook (server-side) so the page already
# renders the breakdown table, avoiding flakiness from the Turbo confirm dialog.
RSpec.describe "Demo: tổn hao và độ tươi dữ liệu", type: :demo do
  include_context "demo seeded world"

  before do
    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    CalculationOrchestrator.new(zone: zone, period: period).call
  end

  it "tổn hao hiện trên 3 trang, chỉ báo cần tính lại hiện khi dữ liệu cũ đi",
     demo_id: "tn3_ton_hao_va_do_tuoi",
     demo_nv: %w[NV-hien-thi-chi-tiet-ton-hao CHIEU-do-tuoi-5-trang] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    loss_summary = LossSummary.find_by!(zone_id: zone.id, period_id: period.id)
    meter = Meter.find_by!(name: "CT-A2")
    reading = meter.meter_readings.find_by!(period: period)
    reading_end_field = "meter_readings[#{reading.id}][reading_end]"
    stale_badge = "[data-testid='freshness-stale']"
    loss_table = "table.reconciliation-table:not([data-pump-station-table])"

    # Sign in as the seeded admin — programmatic, no login page.
    demo.sign_in_as(User.find_by!(username: "demo_admin"), role_label: "Quản trị viên hệ thống")
    expect(page).to have_current_path("/", wait: 10)

    # =========================================================================
    # PHẦN 1: Tổn hao — bảng đối chiếu trên billing + cột trên 2 trang nhập
    # =========================================================================

    demo.narrate("Công tơ tổng đo được nhiều hơn tổng các công tơ con — phần chênh là tổn hao trên dây dẫn")
    demo.narrate("Hệ thống tự tính tổn hao và hiện trên 3 trang: bảng tính tiền, chỉ số đầu mối, chỉ số bơm nước")

    # 1a. Billing — bảng đối chiếu tổn hao theo loại đầu mối (A/B/C).
    demo.visit(
      "/billing?zone_id=#{zone.id}",
      caption: "Mở Bảng tính tiền — chọn Khu vực 1 để xem bảng đối chiếu"
    )
    expect(page).to have_content("Đối chiếu sử dụng và tổn hao theo loại đầu mối", wait: 10)

    demo.highlight(
      "#{loss_table} caption",
      caption: "Bảng đối chiếu sử dụng và tổn hao — hệ thống tự gom theo loại đầu mối"
    )
    demo.highlight(
      "#{loss_table} tbody tr.reconciliation-row:first-child",
      caption: "Dòng Sinh hoạt: sử dụng, tổn hao phân bổ, và sử dụng thực tế — tự tính, không cộng tay"
    )
    demo.highlight(
      "#{loss_table} tbody tr.font-semibold:first-of-type",
      caption: "Cộng (công tơ có tổn hao): A = sử dụng thực tế, B = sử dụng, C = tổn hao — đúng khi A = B + C"
    )
    demo.highlight(
      "#{loss_table} tbody tr.font-semibold:last-of-type",
      caption: "Tổng cộng = số công tơ tổng — khớp là toàn bộ điện đã được đối chiếu, không thiếu không thừa"
    )

    expect(loss_summary.a).to eq(loss_summary.b + loss_summary.c)
    expect(page).to have_content("Cộng (công tơ có tổn hao)")
    expect(page).to have_content("Tổng cộng (= số công tơ tổng)")

    demo.narrate("A = B + C: hệ thống tự đối chiếu — sai là thấy ngay, không cần cộng bảng tay nữa")

    # 1b. Pump entries — 2 cột Tổn hao + Sử dụng thực tế trên trang chỉ số bơm nước.
    demo.visit("/pump_entries", caption: "Mở trang Chỉ số bơm nước")
    expect(page).to have_content("Tổn hao", wait: 10)
    expect(page).to have_content("Sử dụng thực tế")
    demo.highlight(
      "thead",
      caption: "Hai cột mới: Tổn hao và Sử dụng thực tế — hiện ngay trên trang nhập chỉ số bơm nước"
    )

    # 1c. Meter entries — 2 cột Tổn hao + Sử dụng thực tế trên trang chỉ số đầu mối.
    demo.visit("/meter_entries", caption: "Mở trang Chỉ số đầu mối")
    expect(page).to have_content("Tổn hao", wait: 10)
    expect(page).to have_content("Sử dụng thực tế")
    demo.highlight(
      "thead",
      caption: "Cùng hai cột Tổn hao và Sử dụng thực tế — người nhập chỉ số thấy ngay kết quả tính toán gần nhất"
    )

    # =========================================================================
    # PHẦN 2: Độ tươi — chỉ báo "cần tính lại" khi sửa chỉ số + guard Excel
    # =========================================================================

    demo.narrate("Tổn hao và bảng tính tiền là số liệu dẫn xuất — sửa chỉ số là bảng cũ đi ngay")
    demo.narrate("Hệ thống giờ cảnh báo khi số liệu cũ đi, và chặn xuất Excel khi chưa tính lại")

    # 2a. Sửa chỉ số trên meter_entries — trigger freshness.
    demo.fill(reading_end_field, with: "3400", caption: "Sửa một chỉ số công tơ (đầu mối Đại đội 1)")
    demo.click("Lưu toàn bộ", caption: "Lưu chỉ số vừa sửa — bảng tính tiền giờ đã lệch")
    expect(page).to have_content(I18n.t("meter_entries.flash.saved"), wait: 10)

    # 2b. Billing — stale badge hiện ngay.
    demo.visit(
      "/billing?zone_id=#{zone.id}",
      caption: "Quay lại Bảng tính tiền — số cũ vẫn nằm đó, trông như còn đúng"
    )
    expect(page).to have_css(stale_badge, wait: 10)
    demo.highlight(
      stale_badge,
      caption: "Chỉ báo 'cần tính lại' hiện ngay — số đang xem KHÔNG còn khớp chỉ số mới"
    )

    # 2c. Dashboard — stale badge cũng hiện ở đây.
    demo.visit("/", caption: "Mở Tổng quan — chỉ báo cũng hiện trên trang chính")
    expect(page).to have_css(stale_badge, wait: 10)
    demo.highlight(
      stale_badge,
      caption: "Cùng chỉ báo trên Tổng quan — bất kỳ trang nào có số liệu dẫn xuất đều cảnh báo"
    )

    # 2d. Excel guard — chặn xuất khi dữ liệu cũ.
    demo.visit(
      "/billing?zone_id=#{zone.id}",
      caption: "Quay lại Bảng tính tiền — thử xuất Excel khi dữ liệu đã cũ"
    )
    demo.narrate("Xuất Excel lúc này là gửi số SAI lên cấp trên — nên hệ thống chặn lại hỏi trước")
    dismiss_confirm do
      demo.click("Xuất Excel", caption: "Bấm Xuất Excel khi đang cũ → hệ thống hỏi xác nhận, ta huỷ")
    end
    expect(page).to have_current_path(/billing/, wait: 10)
    demo.narrate("Huỷ — không có file số liệu cũ nào lọt ra ngoài")

    # 2e. Tính lại — badge biến mất, an toàn xuất.
    demo.click("Tính toán lại", confirm: true, caption: "Tính lại để bảng khớp chỉ số mới")
    expect(page).to have_content("Đã tính toán lại", wait: 10)
    expect(page).not_to have_css(stale_badge)
    demo.narrate("Tính lại xong → chỉ báo biến mất, bảng đã khớp và yên tâm xuất")
  end
end
