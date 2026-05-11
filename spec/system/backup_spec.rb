require "rails_helper"

RSpec.describe "Sao lưu dữ liệu", type: :system do
  let(:scenario) { setup_basic_scenario }

  before do
    allow(BackupService).to receive(:backup!).and_return("backup_20260423_120000.dump")
    allow(BackupService).to receive(:list).and_return([
      { name: "backup_20260423_120000.dump", size: 1_048_576, created_at: Time.current }
    ])
    allow(BackupService).to receive(:delete!)
    allow(BackupService).to receive(:restore!)
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "thấy link Sao lưu dữ liệu trong sidebar" do
      visit backups_path
      expect(page).to have_link(I18n.t("nav.backups"), href: backups_path)
    end

    it "hiển thị trang với tiêu đề và nút sao lưu" do
      visit backups_path
      expect(page).to have_content(I18n.t("backups.index.title"))
      expect(page).to have_button(I18n.t("backups.index.backup_button"))
    end

    it "hiển thị danh sách file backup với kích thước dễ đọc" do
      visit backups_path
      expect(page).to have_content("backup_20260423_120000.dump")
      expect(page).to have_content("1,0 MB")
    end

    it "hiển thị cảnh báo phục hồi" do
      visit backups_path
      expect(page).to have_content(I18n.t("backups.index.restore_warning"))
    end

    it "trang trống khi chưa có backup" do
      allow(BackupService).to receive(:list).and_return([])
      visit backups_path
      expect(page).to have_content(I18n.t("backups.index.empty"))
    end

    it "nhấn Sao lưu ngay → flash thành công" do
      visit backups_path
      click_button I18n.t("backups.index.backup_button")
      expect(page).to have_content("backup_20260423_120000.dump")
    end
  end

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "bị redirect khi truy cập /backups" do
      visit backups_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end

    it "không thấy link Sao lưu dữ liệu trong sidebar" do
      visit root_path
      expect(page).not_to have_link(I18n.t("nav.backups"))
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "bị redirect khi truy cập /backups" do
      visit backups_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "bị redirect khi truy cập /backups" do
      visit backups_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end
end
