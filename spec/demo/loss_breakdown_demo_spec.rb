require "rails_helper"

# Demo spec for Loss breakdown — a narrated, recorded walkthrough for the
# owner (pre-merge) and the customer (pre-release). Runs in CI like any spec
# (green-to-merge → anti-drift). See ADR-036..041 (#343) + ADR-050/051 (#352).
#
# Covers:
#   - TN3: cột "Tổn hao" trên bảng tính tiền
#   - #332: bảng đối chiếu tổn hao/sử dụng theo loại đầu mối
#
# Approach B: calculation is triggered in a before hook (server-side) so the
# page already renders the breakdown table. This avoids flakiness from the
# Turbo confirm dialog in the headless demo driver.
RSpec.describe "Demo: Loss breakdown", type: :demo do
  include_context "demo seeded world"

  before do
    zone = Zone.find_by!(name: "Khu vực Trung tâm")
    period = Period.find_by!(year: 2026, month: 6)
    CalculationOrchestrator.new(zone: zone, period: period).call
  end

  it "walks through loss breakdown", demo_nv: %w[NV-hien-thi-chi-tiet-ton-hao] do
    demo = DemoRecorder.new(self)

    # Bước 1 — đăng nhập
    demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")
    demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")
    demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")
    demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
    expect(page).to have_current_path("/", wait: 10)

    # Bước 2 — mở Bảng tính tiền MỘT lần (đã có kết quả tính toán từ before hook),
    # rồi narrate các caption tại chỗ (không tải lại trang) để video gọn, không lặp.
    demo.visit("/billing", caption: "Mở Bảng tính tiền tháng 6/2026")
    expect(page).to have_content("Đối chiếu tổn hao/sử dụng theo loại đầu mối", wait: 10)

    demo.narrate("Bảng đối chiếu tổn hao/sử dụng theo từng loại đầu mối (Sinh hoạt / Công cộng / Bơm nước)")
    demo.narrate("Dòng \"Cộng\" chính là A/B/C; \"Tổng cộng\" bằng số công tơ tổng")

    # Assert nội dung bảng breakdown: các dòng tổng + cột Tổn hao
    expect(page).to have_content("Cộng (công tơ có tổn hao)")
    expect(page).to have_content("Không tổn hao")
    expect(page).to have_content("Tổng cộng")
    expect(page).to have_content("Tổn hao")
  end
end
