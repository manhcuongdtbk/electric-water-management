require "rails_helper"

# F05 — Nhập số điện lực (electricity_supply) cho đơn vị + period hiện tại.
RSpec.describe "F05 — Electricity supply", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "saves the total kWh supplied for the current period" do
      visit electricity_supply_path
      expect(page).to have_content(I18n.t("electricity_supplies.show.title"))

      fill_in I18n.t("electricity_supplies.section_input.field_label"), with: "50000"
      click_on I18n.t("electricity_supplies.section_input.submit")

      expect(page).to have_content(I18n.t("flash.electricity_supplies.updated"))
      field = find("input[name='electricity_supply[electricity_supply_kw]']")
      expect(field.value.to_f).to eq(50_000.0)

      config = UnitConfig.find_by!(organization: scenario.unit, monthly_period: scenario.period)
      expect(config.electricity_supply_kw.to_f).to eq(50_000.0)
    end
  end

  describe "commander" do
    it "sees the value in a read-only view with no save button" do
      create(:unit_config,
             organization: scenario.unit, monthly_period: scenario.period,
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
