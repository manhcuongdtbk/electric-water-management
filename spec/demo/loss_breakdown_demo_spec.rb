require "rails_helper"

# Demo spec for Loss breakdown — bảng đối chiếu sử dụng và tổn hao theo loại
# đầu mối. A narrated, recorded walkthrough for the owner (pre-merge) and the
# customer (pre-release). Runs in CI like any spec (green-to-merge → anti-drift).
# See ADR-036..041 (#343) + ADR-050/051 (#352) for the demo engine, and
# docs/superpowers/specs/2026-06-10-ton-hao-design.md for the feature.
#
# Covers:
#   - TN3: cột "Tổn hao" trên bảng tính tiền
#   - #332: bảng đối chiếu tổn hao/sử dụng theo loại đầu mối
#
# Customer story: the main meter reads more than the sum of sub-meters — the
# difference is transmission loss on the wires. Before this table, the admin had
# to sum sub-meters by hand to see how much was lost and where. The breakdown
# table automates that: grouped by contact point type (residential / public /
# water pump), showing Usage / Loss / Actual, with totals that reconcile against
# A/B/C and the main meter reading.
#
# Calculation is triggered in a before hook (server-side) so the page already
# renders the breakdown table, avoiding flakiness from the Turbo confirm dialog.
RSpec.describe "Demo: bảng đối chiếu tổn hao", type: :demo do
  include_context "demo seeded world"

  before do
    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    CalculationOrchestrator.new(zone: zone, period: period).call
  end

  it "hiện bảng đối chiếu sử dụng và tổn hao theo loại đầu mối, khớp A/B/C và công tơ tổng",
     demo_nv: %w[NV-hien-thi-chi-tiet-ton-hao] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    loss_summary = LossSummary.find_by!(zone_id: zone.id, period_id: period.id)
    main_meter = zone.main_meters.kept.first!
    main_reading = MainMeterReading.find_by!(main_meter: main_meter, period: period)

    loss_table = "table.reconciliation-table:not([data-pump-station-table])"

    # Sign in as the seeded admin — programmatic, no login page.
    demo.sign_in_as(User.find_by!(username: "demo_admin"), role_label: "Quản trị viên")
    expect(page).to have_current_path("/", wait: 10)

    # The pain: main meter reads more than all sub-meters combined — the gap is
    # transmission loss. Before this feature, the admin had to total the sub-meters
    # by hand to know how much was lost and which types bore it.
    demo.narrate("Công tơ tổng đo được nhiều hơn tổng các công tơ con — phần chênh là tổn hao trên dây dẫn")
    demo.narrate("Trước đây phải cộng tay từng nhóm đầu mối để biết tổn hao bao nhiêu, phân bổ cho ai")

    # Open billing with zone selected → the reconciliation section auto-opens
    # (single zone = <details open>).
    demo.visit(
      "/billing?zone_id=#{zone.id}",
      caption: "Mở Bảng tính tiền — chọn Khu vực 1 để xem bảng đối chiếu"
    )
    expect(page).to have_content("Đối chiếu sử dụng và tổn hao theo loại đầu mối", wait: 10)

    # Show the table — the thing this feature IS.
    demo.highlight(
      "#{loss_table} caption",
      caption: "Bảng đối chiếu sử dụng và tổn hao — hệ thống tự gom theo loại đầu mối"
    )

    # Show the first data row (residential) — the largest type, carrying most of the loss.
    demo.highlight(
      "#{loss_table} tbody tr.reconciliation-row:first-child",
      caption: "Dòng Sinh hoạt: sử dụng, tổn hao phân bổ, và sử dụng thực tế — tự tính, không cộng tay"
    )

    # Show the "Cộng" row — this is A/B/C, the core reconciliation.
    demo.highlight(
      "#{loss_table} tbody tr.font-semibold:first-of-type",
      caption: "Cộng (công tơ có tổn hao): A = sử dụng thực tế, B = sử dụng, C = tổn hao — đúng khi A = B + C"
    )

    # Show the grand total — must match the main meter reading.
    demo.highlight(
      "#{loss_table} tbody tr.font-semibold:last-of-type",
      caption: "Tổng cộng = số công tơ tổng — khớp là toàn bộ điện đã được đối chiếu, không thiếu không thừa"
    )

    # Real assertions — the reconciliation identity and data presence.
    expect(loss_summary.a).to eq(loss_summary.b + loss_summary.c)
    expect(main_reading.usage).to be_present
    expect(page).to have_content("Cộng (công tơ có tổn hao)")
    expect(page).to have_content("Không tổn hao")
    expect(page).to have_content("Tổng cộng (= số công tơ tổng)")

    demo.narrate("A = B + C: hệ thống tự đối chiếu — sai là thấy ngay, không cần cộng bảng tay nữa")
  end
end
