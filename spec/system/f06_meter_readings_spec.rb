require "rails_helper"

# F06 — Nhập chỉ số công tơ (meter_readings) — batch form, Stimulus realtime
# consumption, and automatic inheritance of reading_start from the prior period.
RSpec.describe "F06 — Meter readings", type: :system do
  let(:scenario) { setup_basic_scenario }
  let(:cp)       { create(:contact_point, organization: scenario.unit) }

  # ---------------------------------------------------------------------------
  # admin_unit — realtime Stimulus + batch save (requires :js for Stimulus)
  # ---------------------------------------------------------------------------
  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "shows consumption = end - start realtime as the user types", :js do
      create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "CT A")

      visit meter_readings_path
      expect(page).to have_content(I18n.t("meter_readings.show.title"))
      expect(page).to have_content("CT A")

      within("tr[data-controller='meter-reading']") do
        find("input[data-meter-reading-target='start']").set("100")
        find("input[data-meter-reading-target='end']").set("250")

        # Stimulus: 250 - 100 = 150 (vi-VN: "150,00" or en "150.00")
        expect(page).to have_css(
          "[data-meter-reading-target='consumption']",
          text: /\A150[.,]/
        )
      end

      click_on I18n.t("meter_readings.save_all")
      expect(page).to have_content(I18n.t("flash.meter_readings.saved"))
    end

    it "persists a batch of readings for multiple meters at once" do
      m1 = create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "CT 1")
      m2 = create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "CT 2")

      visit meter_readings_path

      find("input[name='readings[#{m1.id}][reading_start]']").set("100")
      find("input[name='readings[#{m1.id}][reading_end]']").set("180")
      find("input[name='readings[#{m2.id}][reading_start]']").set("200")
      find("input[name='readings[#{m2.id}][reading_end]']").set("320")

      click_on I18n.t("meter_readings.save_all")
      expect(page).to have_content(I18n.t("flash.meter_readings.saved"))

      r1 = MeterReading.find_by!(meter: m1, monthly_period: scenario.period)
      r2 = MeterReading.find_by!(meter: m2, monthly_period: scenario.period)
      expect(r1.reading_end.to_f).to eq(180)
      expect(r2.reading_end.to_f).to eq(320)
    end

    it "inherits reading_start from the previous period's reading_end" do
      meter = create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "CT K")
      jan = create(:monthly_period, year: 2026, month: 1)
      create(:meter_reading,
             meter: meter, monthly_period: jan,
             reading_start: 500, reading_end: 800, consumption: 300)

      visit meter_readings_path(period_id: scenario.period.id)

      input = find("input[name='readings[#{meter.id}][reading_start]']")
      expect(input.value.to_f).to eq(800.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Scope — admin_unit only sees meters belonging to their own organization
  # ---------------------------------------------------------------------------
  describe "scope isolation" do
    it "does not list meters from another unit" do
      other_unit = create(:organization, :unit, parent: scenario.division)
      own = create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "Own meter")
      other_cp = create(:contact_point, organization: other_unit)
      foreign = create(:meter, :normal, contact_point: other_cp, organization: other_unit, name: "Foreign meter")

      login_as scenario.admin_unit, scope: :user
      visit meter_readings_path

      expect(page).to have_content(own.name)
      expect(page).not_to have_content(foreign.name)
    end
  end

  # ---------------------------------------------------------------------------
  # commander — read-only
  # ---------------------------------------------------------------------------
  describe "commander" do
    it "sees the readings but no save button / input fields" do
      meter = create(:meter, :normal, contact_point: cp, organization: scenario.unit, name: "CT RO")
      create(:meter_reading,
             meter: meter, monthly_period: scenario.period,
             reading_start: 100, reading_end: 300, consumption: 200)

      login_as scenario.commander, scope: :user
      visit meter_readings_path

      expect(page).to have_content(meter.name)
      expect(page).not_to have_css("input[name='readings[#{meter.id}][reading_start]']")
      expect(page).not_to have_button(I18n.t("meter_readings.save_all"))
    end
  end

  describe "tech" do
    it "is redirected to users_path" do
      login_as scenario.tech, scope: :user
      visit meter_readings_path
      expect(page).to have_current_path(users_path)
    end
  end
end
