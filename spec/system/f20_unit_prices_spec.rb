require "rails_helper"

RSpec.describe "F20 — Đơn giá điện", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "thấy danh sách kỳ kèm đơn giá" do
      visit monthly_periods_path
      expect(page).to have_content(I18n.t("monthly_periods.index.title"))
      expect(page).to have_content(scenario.period.label)
      expect(page).to have_content("2,000")
    end

    it "sửa đơn giá thành công" do
      visit monthly_periods_path
      click_on I18n.t("monthly_periods.actions.edit")

      expect(page).to have_content(I18n.t("monthly_periods.edit.title"))
      fill_in I18n.t("monthly_periods.form.unit_price"), with: "2092.20"
      click_on I18n.t("monthly_periods.form.submit")

      expect(page).to have_current_path(monthly_periods_path)
      expect(page).to have_content(I18n.t("flash.monthly_periods.updated"))
      expect(scenario.period.reload.unit_price.to_f).to be_within(0.01).of(2092.20)
    end

    it "validation: đơn giá âm → lỗi" do
      visit edit_monthly_period_path(scenario.period)
      fill_in I18n.t("monthly_periods.form.unit_price"), with: "-100"
      click_on I18n.t("monthly_periods.form.submit")

      expect(page).to have_content(I18n.t("errors.messages.greater_than", count: 0))
      expect(page).to have_content(I18n.t("monthly_periods.edit.title"))
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "thấy danh sách kỳ, không thấy nút Sửa" do
      visit monthly_periods_path
      expect(page).to have_content(I18n.t("monthly_periods.index.title"))
      expect(page).to have_content(scenario.period.label)
      expect(page).not_to have_link(I18n.t("monthly_periods.actions.edit"))
    end

    it "không truy cập được trang sửa" do
      visit edit_monthly_period_path(scenario.period)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "thấy danh sách kỳ, không thấy nút Sửa" do
      visit monthly_periods_path
      expect(page).to have_content(I18n.t("monthly_periods.index.title"))
      expect(page).not_to have_link(I18n.t("monthly_periods.actions.edit"))
    end
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "bị redirect về users_path khi truy cập danh sách" do
      visit monthly_periods_path
      expect(page).to have_current_path(users_path)
    end
  end
end
