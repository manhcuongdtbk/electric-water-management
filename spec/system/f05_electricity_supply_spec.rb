require "rails_helper"

# F05 — admin_level1 nhập số điện lực (MainMeterReading) per khu vực (MainMeter).
# admin_unit + commander chỉ xem (read-only); tech bị chuyển sang /users.
RSpec.describe "F05 — Electricity supply", type: :system do
  let(:scenario) { setup_basic_scenario }
  let(:main_meter) { create(:main_meter, name: "Khu vực A") }

  before { scenario.unit.update!(main_meter: main_meter) }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "saves the total kWh supplied for the current period and zone" do
      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.show.title"))

      fill_in I18n.t("electricity_supplies.section_input.field_label"), with: "50000"
      click_on I18n.t("electricity_supplies.section_input.submit")

      expect(page).to have_content(I18n.t("flash.electricity_supplies.updated"))
      field = find("input[name='electricity_supply[electricity_supply_kw]']")
      expect(field.value.to_f).to eq(50_000.0)

      reading = MainMeterReading.find_by!(main_meter: main_meter, monthly_period: scenario.period)
      expect(reading.electricity_supply_kw.to_f).to eq(50_000.0)
    end
  end

  describe "admin_unit" do
    before do
      create(:main_meter_reading,
             main_meter: main_meter, monthly_period: scenario.period,
             electricity_supply_kw: 12_345)
      login_as scenario.admin_unit, scope: :user
    end

    it "sees the value in a read-only view with no save button" do
      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.show.title"))
      expect(page).to have_content(main_meter.name)
      expect(page).not_to have_css("input[name='electricity_supply[electricity_supply_kw]']")
      expect(page).not_to have_button(I18n.t("electricity_supplies.section_input.submit"))
      expect(page).to have_content("12,345.00")
    end

    it "shows no-main-meter notice when their org is not assigned a zone" do
      scenario.unit.update!(main_meter: nil)
      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.no_main_meter"))
    end
  end

  describe "commander" do
    it "sees the value in a read-only view with no save button" do
      create(:main_meter_reading,
             main_meter: main_meter, monthly_period: scenario.period,
             electricity_supply_kw: 12_345)
      login_as scenario.commander, scope: :user

      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.show.title"))
      expect(page).not_to have_css("input[name='electricity_supply[electricity_supply_kw]']")
      expect(page).not_to have_button(I18n.t("electricity_supplies.section_input.submit"))
    end
  end

  describe "tech" do
    it "is redirected to users_path" do
      login_as scenario.tech, scope: :user
      visit electricity_supply_path
      expect(page).to have_current_path(users_path)
    end
  end
end
