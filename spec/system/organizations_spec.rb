require "rails_helper"

# Quản lý đơn vị cấp 2 — admin_level1 thêm/sửa/xoá đơn vị cấp 2 qua UI.
RSpec.describe "Organizations management", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "thấy danh sách đơn vị cấp 2" do
      scenario # touch lazy let to create
      visit organizations_path
      expect(page).to have_content(I18n.t("organizations.index.title"))
      expect(page).to have_content(scenario.unit.name)
    end

    it "tạo đơn vị mới thành công" do
      zone = create(:zone, name: "Khu vực mới")
      visit organizations_path
      click_on I18n.t("organizations.index.new_button")

      fill_in I18n.t("organizations.form.name"), with: "Đại đội 30"
      select zone.name, from: I18n.t("organizations.form.zone")
      click_on I18n.t("organizations.form.submit_create")

      expect(page).to have_current_path(organizations_path)
      expect(page).to have_content(I18n.t("flash.organizations.created"))
      created = Organization.find_by!(name: "Đại đội 30")
      expect(created.level).to eq("unit")
      expect(created.parent).to eq(scenario.division)
      expect(created.zone).to eq(zone)
    end

    it "validation: tên đơn vị trùng → lỗi" do
      visit new_organization_path
      fill_in I18n.t("organizations.form.name"), with: scenario.unit.name
      click_on I18n.t("organizations.form.submit_create")

      expect(page).to have_content(I18n.t("errors.messages.taken"))
      expect(page).to have_content(I18n.t("organizations.new.title"))
    end

    it "sửa tên đơn vị thành công" do
      visit edit_organization_path(scenario.unit)
      fill_in I18n.t("organizations.form.name"), with: "Đơn vị đổi tên"
      click_on I18n.t("organizations.form.submit_update")

      expect(page).to have_current_path(organizations_path)
      expect(page).to have_content(I18n.t("flash.organizations.updated"))
      expect(scenario.unit.reload.name).to eq("Đơn vị đổi tên")
    end

    it "xoá đơn vị rỗng thành công" do
      empty_unit = create(:organization, :unit, parent: scenario.division, name: "Đơn vị rỗng")
      visit organizations_path

      within("tr", text: empty_unit.name) do
        click_button I18n.t("organizations.actions.delete")
      end

      expect(page).to have_content(I18n.t("flash.organizations.destroyed"))
      expect(Organization.exists?(empty_unit.id)).to be false
    end

    it "không xoá được đơn vị có user gắn vào" do
      create(:user, :admin_unit, organization: scenario.unit)
      visit organizations_path

      within("tr", text: scenario.unit.name) do
        click_button I18n.t("organizations.actions.delete")
      end

      expect(page).to have_content(I18n.t("flash.organizations.cannot_destroy_with_data"))
      expect(Organization.exists?(scenario.unit.id)).to be true
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "không truy cập được trang quản lý đơn vị" do
      visit organizations_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "không truy cập được trang quản lý đơn vị" do
      visit organizations_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "bị redirect về users_path" do
      visit organizations_path
      expect(page).to have_current_path(users_path)
    end
  end
end
