require "rails_helper"

RSpec.describe "Demo recording smoke", type: :demo do
  it "shows a caption banner on each step" do
    demo = DemoRecorder.new(self)
    demo.visit("/", caption: "Mở trang đăng nhập")
    expect(page).to have_css("#demo-caption", text: "Mở trang đăng nhập")
  end

  # Seeded login journey. This example drives a real Playwright browser and
  # requires committed data visible to Puma's DB connections. Transactional
  # fixtures wrap each example in a savepoint on the spec process's connection —
  # data committed there is NOT visible to Puma's separate connections. We
  # disable transactional tests for this nested group and seed in before(:each)
  # so that committed seed rows are visible to both the spec body and Puma.
  describe "seeded journey" do
    self.use_transactional_tests = false

    before(:each) do
      # Load curated demo dataset — commits data so Puma can read it.
      load Rails.root.join("db", "seeds", "demo.rb")
    end

    after(:each) do
      # Minimal teardown so the test DB stays predictable across re-runs within
      # the same rspec invocation. A full `db:reset && demo:seed` is the
      # canonical setup for each demo recording session.
      [MeterReading, MainMeterReading, PersonnelEntry, OtherDeduction,
       UnitConfig, NonEstablishmentSnapshot, Calculation, PumpAllocation,
       Meter, ContactPoint, Block, Group, Rank, Period, Unit, MainMeter,
       Zone].each { |model| model.unscoped.delete_all rescue nil }
      User.where(username: "demo_admin").delete_all
    end

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
