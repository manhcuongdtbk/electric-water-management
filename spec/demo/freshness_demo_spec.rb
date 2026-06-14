require "rails_helper"

# Demo spec for #334 — chỉ báo độ tươi dữ liệu dẫn xuất + guard Xuất Excel.
# A narrated, recorded walkthrough for the owner (pre-merge) and the customer
# (pre-release). Runs in CI like any spec (green-to-merge → anti-drift). #334 is
# customer-facing, so per ADR-040 the PR ships this demo spec under spec/demo/.
# See ADR-036..041 (#343) + ADR-050/051 (#352) for the demo engine, and
# docs/superpowers/specs/2026-06-14-do-tuoi-du-lieu-dan-xuat-design.md for the
# feature (ADR-049). The narrated journey mirrors the "Demo (ADR-040)" section
# of that spec; the assertions cover dimension CHIEU-do-tuoi-5-trang
# (chỉ báo hiện trên trang billing + meter_entries) plus the appear/clear cycle.
RSpec.describe "Demo: chỉ báo độ tươi dữ liệu dẫn xuất", type: :demo do
  include_context "demo seeded world"

  # No NV- anchor exists for #334 in docs/V2_XAC_NHAN_NGHIEP_VU.md — the feature
  # is specified in docs/superpowers/specs/2026-06-14-do-tuoi-du-lieu-dan-xuat-design.md
  # (ADR-049). We trace this demo to the test-dimension anchor it proves
  # (CHIEU-do-tuoi-5-trang) rather than fabricate a requirement anchor.
  it "CHIEU-do-tuoi-5-trang: chỉ báo 'cần tính lại' hiện sau khi sửa chỉ số rồi biến mất khi tính lại",
     demo_nv: %w[CHIEU-do-tuoi-5-trang] do
    demo = DemoRecorder.new(self)

    # The seeded world: zone "Khu vực Trung tâm", open period tháng 6/2026, with
    # meters + readings (db/seeds/demo.rb). We edit one reading on the seeded
    # contact point "Đại đội 1" (meter CT-A2) to bump the zone's CalculationState.
    period = Period.find_by!(year: 2026, month: 6)
    meter = Meter.find_by!(name: "CT-A2")
    reading = meter.meter_readings.find_by!(period: period)
    reading_end_field = "meter_readings[#{reading.id}][reading_end]"

    # Step 1 — sign in as the seeded admin (db/seeds/demo.rb).
    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")
    demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")
    demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
    expect(page).to have_current_path("/", wait: 10)

    # Step 2 — open Billing and recalculate so the zone has fresh results. The
    # "Tính toán lại" button confirms via Turbo (turbo_confirm) — accept it.
    demo.visit("/billing", caption: "Mở Bảng tính tiền — kỳ tháng 6/2026")
    demo.narrate("Tính một lần để có kết quả mới — sau đó chỉ báo 'cần tính lại' sẽ ẩn")
    accept_confirm do
      demo.click("Tính toán lại", caption: "Bấm 'Tính toán lại' — hệ thống tính cho khu vực")
    end
    expect(page).to have_content("Đã tính toán lại", wait: 10)
    expect(page).not_to have_css('[data-testid="freshness-stale"]')
    demo.narrate("Trạng thái: đã tính và còn đúng — chưa có chỉ báo cần tính lại")

    # Step 3 — go to meter entries and edit one reading.
    demo.visit("/meter_entries", caption: "Sang trang nhập chỉ số đầu mối")
    demo.fill(reading_end_field, with: "3400", caption: "Sửa một chỉ số đầu mối")
    demo.click("Lưu toàn bộ", caption: "Lưu chỉ số vừa sửa")
    expect(page).to have_content(I18n.t("meter_entries.flash.saved"), wait: 10)

    # Step 4 — back to Billing; the stale banner now appears for the edited zone.
    demo.visit("/billing", caption: "Quay lại Bảng tính tiền")
    expect(page).to have_css('[data-testid="freshness-stale"]', wait: 10)
    demo.narrate("Chỉ báo 'cần tính lại' xuất hiện")

    # Step 5 — attempt Xuất Excel while stale → the system asks for confirmation.
    # Dismiss it (cancel the navigation) so no stale file is exported.
    demo.narrate("Khi dữ liệu đã cũ, bấm Xuất Excel → hệ thống hỏi xác nhận trước khi xuất")
    dismiss_confirm do
      demo.click("Xuất Excel", caption: "Bấm Xuất Excel — hệ thống hỏi xác nhận, ta huỷ")
    end
    expect(page).to have_current_path(/billing/, wait: 10)

    # Step 6 — recalculate again; the banner clears.
    accept_confirm do
      demo.click("Tính toán lại", caption: "Tính lại để dữ liệu khớp hiện trạng")
    end
    expect(page).to have_content("Đã tính toán lại", wait: 10)
    expect(page).not_to have_css('[data-testid="freshness-stale"]')
    demo.narrate("Tính lại → chỉ báo biến mất")
  end
end
