require "rails_helper"

# Demo spec for TN1 — cột "Khác" dạng hệ số (đơn vị). A narrated, recorded
# walkthrough for the owner (pre-merge) and the customer (pre-release). Runs in
# CI like any spec (green-to-merge → anti-drift). Backfills the demo for a
# feature that shipped (PR #327, #319) before the demo engine existed, so the
# 1.2.0 release bundle covers it (#351/#355). See ADR-036..041 (#343), ADR-025
# (the feature: docs/superpowers/specs/2026-06-11-cot-khac-he-so-don-vi-design.md).
RSpec.describe "Demo: cột Khác hệ số đơn vị", type: :demo do
  include_context "demo seeded world"

  it "đặt khoản trừ Khác theo hệ số đơn vị cho một đầu mối", demo_nv: %w[NV-cot-khac-he-so-don-vi] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực Trung tâm")
    unit = Unit.find_by!(name: "Tiểu đoàn Alpha")
    period = Period.order(:id).last
    # The seeded "Khác" row for this residential contact point (type starts as "fixed").
    other_deduction = OtherDeduction.joins(:contact_point).find_by!(
      period_id: period.id,
      contact_points: { name: "Ban Chỉ huy Tiểu đoàn Alpha", contact_point_type: "residential" }
    )
    type_field = "other_deductions[#{other_deduction.id}][other_type]"
    value_field = "other_deductions[#{other_deduction.id}][other_value]"

    # Sign in as the seeded admin (db/seeds/demo.rb).
    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")
    demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")
    demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
    expect(page).to have_current_path("/", wait: 10)

    # Open the unit's config directly (zone + unit in the query so we land on the
    # "Khác" table without driving the filter dropdowns).
    demo.visit(
      "/unit_config?zone_id=#{zone.id}&unit_id=#{unit.id}",
      caption: "Mở Cấu hình đơn vị — Tiểu đoàn Alpha, kỳ tháng 6/2026"
    )
    demo.narrate(%(Cột "Khác" có ba cách nhập: Cố định, Theo hệ số, và Theo hệ số (đơn vị)))
    demo.narrate(%(Dạng "đơn vị" hợp cho bếp ăn chung: khoản trừ = hệ số × (tổng quân số đơn vị − quân số đầu mối đó)))

    # Pick the unit-coefficient type and a negative coefficient (bếp được cộng ngược).
    demo.select(
      "Theo hệ số (đơn vị)", from: type_field,
      caption: %(Chọn cách nhập "Theo hệ số (đơn vị)" cho đầu mối Ban Chỉ huy)
    )
    demo.fill(value_field, with: "-2", caption: "Nhập hệ số −2 (bếp: cộng ngược vào tiêu chuẩn)")
    demo.click("Lưu cấu hình", caption: "Lưu — hệ thống tự tính lại theo quân số kỳ này")

    # Real assertions → green-to-merge.
    expect(page).to have_content("Đã lưu cấu hình đơn vị.", wait: 10)
    expect(page).to have_field(value_field, with: "-2.0")
    demo.narrate("Đã lưu: kỳ sau quân số đổi, hệ thống tự tính lại — không phải sửa tay")

    other_deduction.reload
    expect(other_deduction.other_type).to eq("unit_coefficient")
    expect(other_deduction.other_value).to eq(BigDecimal("-2"))
  end
end
