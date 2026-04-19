require "rails_helper"

# F04 — Cấu hình tỷ lệ (unit_configs). Division section belongs to admin_level1;
# unit section (including the "Khác" table) belongs to admin_unit.
RSpec.describe "F04 — Unit configs", type: :system do
  let(:scenario) { setup_basic_scenario }

  # ---------------------------------------------------------------------------
  # admin_unit — unit section + Stimulus "Khác" toggle
  # ---------------------------------------------------------------------------
  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "saves unit_public_rate for the current period" do
      visit unit_config_path
      expect(page).to have_content(I18n.t("unit_configs.show.title"))

      find("input[name='unit_config[unit_public_rate]']").set("3.0")
      click_on I18n.t("unit_configs.section_unit.submit")

      expect(page).to have_content(I18n.t("flash.unit_configs.unit_updated"))
      # UnitConfig stores the decimal form (0.03 for 3%), shown back as 3 in %.
      saved = find("input[name='unit_config[unit_public_rate]']").value
      expect(saved.to_f).to eq(3.0)

      config = UnitConfig.find_by!(organization: scenario.unit, monthly_period: scenario.period)
      expect(config.unit_public_rate.to_f).to be_within(0.0001).of(0.03)
    end

    it "updates the 'Khác' row result realtime when switching input types", :js do
      cp = create(:contact_point, organization: scenario.unit)
      create(:personnel,
             contact_point: cp, monthly_period: scenario.period,
             rank1_count: 2, rank2_count: 3, rank3_count: 5,
             rank4_count: 0, rank5_count: 0, rank6_count: 0, rank7_count: 0) # total = 10

      visit unit_config_path

      within("tr[data-cp-id='#{cp.id}']") do
        # fixed_kw is the default; fill value=10 → result should start with "10"
        find("input[data-role='other-value']").set("10")
        expect(page).to have_css("[data-role='other-result']", text: /\A10[.,]/)

        # Switch to factor_per_person → 10 × 10 personnel = "100.xx"
        find("select[data-role='other-type']")
          .select(I18n.t("unit_configs.other_types.factor_per_person"))
        expect(page).to have_css("[data-role='other-result']", text: /\A100[.,]/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # admin_level1 — division section only (unit section is a read-only table)
  # ---------------------------------------------------------------------------
  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "saves savings_rate and division_public_rate in the division section" do
      visit unit_config_path
      expect(page).to have_content(I18n.t("unit_configs.section_division.title"))

      find("input[name='division_config[savings_rate]']").set("7.5")
      find("input[name='division_config[division_public_rate]']").set("12")
      click_on I18n.t("unit_configs.section_division.submit")

      expect(page).to have_content(I18n.t("flash.unit_configs.division_updated"))

      config = UnitConfig.find_by!(organization: scenario.division, monthly_period: scenario.period)
      expect(config.savings_rate.to_f).to be_within(0.0001).of(0.075)
      expect(config.division_public_rate.to_f).to be_within(0.0001).of(0.12)
    end

    it "sees each unit's public rate as a read-only overview row" do
      # Give the baseline unit a unit_public_rate so the overview row is meaningful
      create(:unit_config,
             organization: scenario.unit, monthly_period: scenario.period,
             unit_public_rate: 0.2)

      visit unit_config_path
      expect(page).to have_content(scenario.unit.name)
      # admin_level1 should NOT see the editable unit form
      expect(page).not_to have_css("input[name='unit_config[unit_public_rate]']")
    end
  end

  # ---------------------------------------------------------------------------
  # commander — read-only
  # ---------------------------------------------------------------------------
  describe "commander" do
    it "shows the page without any editable form controls" do
      login_as scenario.commander, scope: :user
      visit unit_config_path

      expect(page).to have_content(I18n.t("unit_configs.show.title"))
      expect(page).not_to have_css("input[name='unit_config[unit_public_rate]']")
      expect(page).not_to have_button(I18n.t("unit_configs.section_unit.submit"))
    end
  end

  # ---------------------------------------------------------------------------
  # tech — bounced to /users
  # ---------------------------------------------------------------------------
  describe "tech" do
    it "is redirected to users_path" do
      login_as scenario.tech, scope: :user
      visit unit_config_path
      expect(page).to have_current_path(users_path)
    end
  end
end
