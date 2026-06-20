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
#
# Refined to the ADR-059 "demo tốt" standard (#393): the stale badge — the thing
# the feature IS — is now scrolled into view with highlight() so the caption's
# claim is visible on screen, not merely asserted in the DOM; the narration is
# framed around the customer's pain (sau khi sửa chỉ số, số liệu tính tiền cũ đi
# trong khi vẫn nằm trên màn hình — xuất Excel lúc này gửi số SAI lên cấp trên);
# and the recalculation uses the recorder's confirm: primitive (mirroring the
# TN1 golden example spec/demo/cot_khac_he_so_don_vi_demo_spec.rb).
RSpec.describe "Demo: chỉ báo độ tươi dữ liệu dẫn xuất", type: :demo do
  include_context "demo seeded world"

  # No NV- anchor exists for #334 in docs/V2_XAC_NHAN_NGHIEP_VU.md — the feature
  # is specified in docs/superpowers/specs/2026-06-14-do-tuoi-du-lieu-dan-xuat-design.md
  # (ADR-049). We trace this demo to the test-dimension anchor it proves
  # (CHIEU-do-tuoi-5-trang) rather than fabricate a requirement anchor.
  it "CHIEU-do-tuoi-5-trang: chỉ báo 'cần tính lại' hiện sau khi sửa chỉ số rồi biến mất khi tính lại",
     demo_nv: %w[CHIEU-do-tuoi-5-trang] do
    demo = DemoRecorder.new(self)

    # The seeded world: zone "Khu vực 1", open period tháng 6/2026, with
    # meters + readings (db/seeds/demo.rb). We edit one reading on the seeded
    # contact point "Đại đội 1" (meter CT-A2) to bump the zone's CalculationState.
    period = Period.find_by!(year: 2026, month: 6)
    meter = Meter.find_by!(name: "CT-A2")
    reading = meter.meter_readings.find_by!(period: period)
    reading_end_field = "meter_readings[#{reading.id}][reading_end]"
    stale_badge = "[data-testid='freshness-stale']"

    # Sign in as the seeded admin (db/seeds/demo.rb) — programmatic, no login page.
    demo.sign_in_as(User.find_by!(username: "demo_admin"), role_label: "Quản trị viên")
    expect(page).to have_current_path("/", wait: 10)

    # The pain this feature removes: bảng tính tiền là số liệu dẫn xuất từ chỉ số
    # công tơ. Ai đó sửa một chỉ số là bảng cũ đi ngay — nhưng số cũ vẫn nằm trên
    # màn hình, dễ tưởng còn đúng mà xuất Excel gửi lên cấp trên.
    demo.visit("/billing", caption: "Mở Bảng tính tiền — kỳ tháng 6/2026")
    demo.narrate("Bảng tính tiền là số liệu dẫn xuất từ chỉ số công tơ — sửa chỉ số là bảng cũ đi")

    # Recalculate once so the zone has fresh results and no stale badge. The
    # "Tính toán lại" button confirms via Turbo (data-turbo-confirm) — confirm: true
    # accepts it (mirrors the TN1 golden example).
    demo.click(
      "Tính toán lại", confirm: true,
      caption: "Tính một lần để có kết quả mới — khi đã khớp, không có chỉ báo nào"
    )
    expect(page).to have_content("Đã tính toán lại", wait: 10)
    expect(page).not_to have_css(stale_badge)
    demo.narrate("Trạng thái sạch: đã tính và còn khớp — chưa có chỉ báo 'cần tính lại'")

    # Someone edits a meter reading on another page — the everyday case that
    # silently invalidates the billing table.
    demo.visit("/meter_entries", caption: "Một người sang trang nhập chỉ số đầu mối")
    demo.fill(reading_end_field, with: "3400", caption: "Sửa một chỉ số công tơ (đầu mối Đại đội 1)")
    demo.click("Lưu toàn bộ", caption: "Lưu chỉ số vừa sửa — bảng tính tiền giờ đã lệch")
    expect(page).to have_content(I18n.t("meter_entries.flash.saved"), wait: 10)

    # Back on Billing: the numbers still sit on screen looking authoritative, but
    # the stale badge now warns the zone needs recalculation. SHOW it — scroll the
    # badge into view so the caption's claim is visible, not just in the DOM.
    demo.visit("/billing", caption: "Quay lại Bảng tính tiền — số cũ vẫn nằm đó, trông như còn đúng")
    expect(page).to have_css(stale_badge, wait: 10)
    demo.highlight(
      stale_badge,
      caption: "Chỉ báo 'cần tính lại' hiện ngay trên đầu bảng — số đang xem KHÔNG khớp chỉ số mới"
    )

    # The export guard: with stale data, Xuất Excel asks before letting a wrong
    # file go to higher command. We cancel — no stale file is exported. (We do not
    # render the .xlsx in the browser; that medium is covered by billing_spec's
    # :xlsx request specs — criterion 4, honest about medium.)
    demo.narrate("Xuất Excel lúc này là gửi số SAI lên cấp trên — nên hệ thống chặn lại hỏi trước")
    dismiss_confirm do
      demo.click("Xuất Excel", caption: "Bấm Xuất Excel khi đang cũ → hệ thống hỏi xác nhận, ta huỷ")
    end
    expect(page).to have_current_path(/billing/, wait: 10)
    demo.narrate("Huỷ — không có file số liệu cũ nào lọt ra ngoài")

    # Recalculate again; the warning clears — the table is trustworthy to export.
    demo.click("Tính toán lại", confirm: true, caption: "Tính lại để bảng khớp chỉ số mới")
    expect(page).to have_content("Đã tính toán lại", wait: 10)
    expect(page).not_to have_css(stale_badge)
    demo.narrate("Tính lại xong → chỉ báo biến mất, bảng đã khớp và yên tâm xuất")
  end
end
