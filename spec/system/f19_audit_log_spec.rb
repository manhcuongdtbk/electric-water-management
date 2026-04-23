require "rails_helper"

RSpec.describe "F19 — Nhật ký hoạt động", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "xem được trang nhật ký" do
      visit audit_logs_path
      expect(page).to have_content(I18n.t("audit_log.index.title"))
    end

    it "trang trống khi không có kết quả khớp bộ lọc" do
      visit audit_logs_path(date_from: "2000-01-01", date_to: "2000-01-02")
      expect(page).to have_content(I18n.t("audit_log.index.empty"))
    end

    it "lọc theo loại dữ liệu — chỉ thấy ContactPoint versions" do
      cp = create(:contact_point, organization: scenario.unit)
      PaperTrail.request(whodunnit: scenario.admin_unit.id) do
        cp.update!(name: "#{cp.name} updated")
      end
      PaperTrail.request(whodunnit: scenario.admin_unit.id) do
        scenario.period.touch
      end

      visit audit_logs_path(item_type: "ContactPoint")
      within("tbody") do
        expect(page).to have_content(I18n.t("audit_log.item_types.ContactPoint"))
        expect(page).not_to have_content(I18n.t("audit_log.item_types.MonthlyPeriod"))
      end
    end

    it "lọc theo người thao tác" do
      cp = create(:contact_point, organization: scenario.unit)
      admin_unit2 = create(:user, :admin_unit, organization: scenario.unit, full_name: "Nguyen Van B")
      PaperTrail.request(whodunnit: scenario.admin_unit.id) do
        cp.update!(name: "#{cp.name} test")
      end
      PaperTrail.request(whodunnit: admin_unit2.id) do
        cp.update!(name: "#{cp.name} test2")
      end

      visit audit_logs_path(whodunnit: scenario.admin_unit.id)
      within("tbody") do
        expect(page).to have_content(scenario.admin_unit.full_name)
        expect(page).not_to have_content(admin_unit2.full_name)
      end
    end

    it "thay đổi contact_point → xuất hiện trong nhật ký với whodunnit đúng" do
      cp = create(:contact_point, organization: scenario.unit)
      original_name = cp.name
      PaperTrail.request(whodunnit: scenario.admin_unit.id) do
        cp.update!(name: "Tên mới cập nhật")
      end

      visit audit_logs_path
      expect(page).to have_content(scenario.admin_unit.full_name)
      expect(page).to have_content(I18n.t("audit_log.item_types.ContactPoint"))
      expect(page).to have_content(I18n.t("audit_log.events.update"))
      expect(page).to have_content(original_name)
      expect(page).to have_content("Tên mới cập nhật")
    end
  end

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "xem được trang nhật ký" do
      visit audit_logs_path
      expect(page).to have_content(I18n.t("audit_log.index.title"))
    end

    it "thấy link Nhật ký hoạt động trong nav" do
      visit audit_logs_path
      expect(page).to have_link(I18n.t("nav.audit_logs"), href: audit_logs_path)
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "bị redirect về root_path" do
      visit audit_logs_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "bị redirect về root_path" do
      visit audit_logs_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end
end
