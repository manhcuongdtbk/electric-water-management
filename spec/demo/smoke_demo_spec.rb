require "rails_helper"

RSpec.describe "Demo recording smoke", type: :demo do
  it "shows a caption banner on each step" do
    demo = DemoRecorder.new(self)
    demo.visit("/", caption: "Mở trang đăng nhập")
    expect(page).to have_css("#demo-caption", text: "Mở trang đăng nhập")
  end

  # Seeded login journey. Setup (commit seed so Puma's separate connections can
  # see it, disable transactional fixtures, teardown) lives in the shared
  # "demo seeded world" context — the same one the `rails g demo:spec` scaffold
  # wires into generated specs. See spec/support/shared_contexts/demo_seeded_world.rb.
  describe "seeded journey" do
    include_context "demo seeded world"

    it "logs in as demo_admin and shows seeded zone on the dashboard" do
      demo = DemoRecorder.new(self)

      # Step 1 — open the login page
      demo.visit("/users/sign_in", caption: "Mở trang đăng nhập")

      # Step 2 — fill username
      demo.fill("Tên đăng nhập", with: "demo_admin", caption: "Nhập tên đăng nhập")

      # Step 3 — fill password (label: "Mật khẩu" per sessions/new.html.erb)
      demo.fill("Mật khẩu", with: "Demo@1234", caption: "Nhập mật khẩu")

      # Step 4 — submit ("Đăng nhập" button). Turbo intercepts the form POST and
      # follows the Devise redirect client-side; we wait for the URL to leave
      # the sign_in page before the next DSL step.
      demo.click("Đăng nhập", caption: "Nhấn Đăng nhập")
      expect(page).to have_current_path("/", wait: 10)

      # Step 5 — visit the dashboard and show a caption on real seeded data
      demo.visit("/dashboard", caption: "Xem bảng điều khiển")

      # Assert real seeded Vietnamese data renders on the dashboard.
      # The zones table is populated from meter_readings (which the seed creates).
      # The units table requires billing calculations — not seeded — so we assert
      # the zone row and the open-period notice instead.
      expect(page).to have_content("Khu vực Trung tâm")
      expect(page).to have_content("Kỳ tháng 6/2026")
    end
  end
end
