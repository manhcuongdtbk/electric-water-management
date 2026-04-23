require "rails_helper"

RSpec.describe "F21 — Định mức cấp bậc", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "thấy danh sách 7 nhóm định mức" do
      visit rank_quotas_path
      expect(page).to have_content(I18n.t("rank_quotas.index.title"))
      expect(page).to have_content("Si quan cap cao")
      expect(page).to have_content("570")
    end

    it "sửa định mức thành công" do
      quota = RankQuota.find_by!(rank_group: 1)
      visit edit_rank_quota_path(quota)

      expect(page).to have_content(I18n.t("rank_quotas.edit.title"))
      fill_in I18n.t("rank_quotas.form.rank_name"), with: "Chỉ huy Sư đoàn"
      fill_in I18n.t("rank_quotas.form.quota_kw"), with: "600"
      click_on I18n.t("rank_quotas.form.submit")

      expect(page).to have_current_path(rank_quotas_path)
      expect(page).to have_content(I18n.t("flash.rank_quotas.updated"))
      expect(quota.reload.rank_name).to eq("Chỉ huy Sư đoàn")
      expect(quota.reload.quota_kw.to_f).to eq(600.0)
    end

    it "validation: quota_kw âm → lỗi" do
      quota = RankQuota.find_by!(rank_group: 1)
      visit edit_rank_quota_path(quota)

      fill_in I18n.t("rank_quotas.form.quota_kw"), with: "-10"
      click_on I18n.t("rank_quotas.form.submit")

      expect(page).to have_content(I18n.t("errors.messages.greater_than", count: 0))
      expect(page).to have_content(I18n.t("rank_quotas.edit.title"))
    end

    it "validation: quota_kw bằng 0 → lỗi" do
      quota = RankQuota.find_by!(rank_group: 1)
      visit edit_rank_quota_path(quota)

      fill_in I18n.t("rank_quotas.form.quota_kw"), with: "0"
      click_on I18n.t("rank_quotas.form.submit")

      expect(page).to have_content(I18n.t("errors.messages.greater_than", count: 0))
      expect(page).to have_content(I18n.t("rank_quotas.edit.title"))
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "thấy danh sách định mức, không thấy nút Sửa" do
      visit rank_quotas_path
      expect(page).to have_content(I18n.t("rank_quotas.index.title"))
      expect(page).not_to have_link(I18n.t("rank_quotas.actions.edit"))
    end

    it "không truy cập được trang sửa" do
      quota = RankQuota.find_by!(rank_group: 1)
      visit edit_rank_quota_path(quota)
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "thấy danh sách định mức, không thấy nút Sửa" do
      visit rank_quotas_path
      expect(page).to have_content(I18n.t("rank_quotas.index.title"))
      expect(page).not_to have_link(I18n.t("rank_quotas.actions.edit"))
    end
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "bị redirect về users_path khi truy cập danh sách" do
      visit rank_quotas_path
      expect(page).to have_current_path(users_path)
    end
  end
end
