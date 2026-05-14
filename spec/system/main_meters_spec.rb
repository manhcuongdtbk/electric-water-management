require "rails_helper"

# Quản lý công tơ tổng — CRUD nested trong trang khu vực (Zone). admin_level1
# thao tác trên mọi khu vực; admin_unit quản lý khu vực thao tác trên khu vực
# mình quản lý; commander chỉ xem.
RSpec.describe "MainMeters management", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "thấy khu vực chưa có công tơ tổng và nút thêm" do
      zone = create(:zone, name: "Khu vực A")
      visit zone_path(zone)
      expect(page).to have_content(I18n.t("zones.show.main_meters_section"))
      expect(page).to have_content(I18n.t("zones.show.main_meters_empty"))
      expect(page).to have_link(I18n.t("zones.show.add_main_meter"))
    end

    it "thêm công tơ tổng mới thành công" do
      zone = create(:zone, name: "Khu vực B")
      visit zone_path(zone)
      click_on I18n.t("zones.show.add_main_meter")

      fill_in I18n.t("main_meters.form.name"), with: "Công tơ tổng trạm biến áp"
      click_on I18n.t("main_meters.form.submit_create")

      expect(page).to have_current_path(zone_path(zone))
      expect(page).to have_content(I18n.t("flash.main_meters.created"))
      expect(page).to have_content("Công tơ tổng trạm biến áp")
      expect(zone.main_meters.pluck(:name)).to include("Công tơ tổng trạm biến áp")
    end

    it "validation: tên trùng → lỗi" do
      zone = create(:zone)
      create(:main_meter, name: "Công tơ trùng")
      visit new_zone_main_meter_path(zone)

      fill_in I18n.t("main_meters.form.name"), with: "Công tơ trùng"
      click_on I18n.t("main_meters.form.submit_create")

      expect(page).to have_content(I18n.t("errors.messages.taken"))
      expect(page).to have_content(I18n.t("main_meters.new.title"))
    end

    it "sửa công tơ tổng thành công" do
      zone = create(:zone)
      main_meter = create(:main_meter, name: "Công tơ cũ", zone: zone)

      visit zone_path(zone)
      within("tr", text: main_meter.name) { click_on I18n.t("main_meters.actions.edit") }
      fill_in I18n.t("main_meters.form.name"), with: "Công tơ mới"
      click_on I18n.t("main_meters.form.submit_update")

      expect(page).to have_current_path(zone_path(zone))
      expect(page).to have_content(I18n.t("flash.main_meters.updated"))
      expect(main_meter.reload.name).to eq("Công tơ mới")
    end

    it "xoá công tơ tổng không có chỉ số → khu vực vẫn còn" do
      zone = create(:zone)
      main_meter = create(:main_meter, zone: zone)

      visit zone_path(zone)
      within("tr", text: main_meter.name) { click_button I18n.t("main_meters.actions.delete") }

      expect(page).to have_content(I18n.t("flash.main_meters.destroyed"))
      expect(MainMeter.exists?(main_meter.id)).to be false
      expect(Zone.exists?(zone.id)).to be true
    end

    it "không xoá được công tơ tổng đang có chỉ số" do
      zone = create(:zone)
      main_meter = create(:main_meter, zone: zone)
      create(:main_meter_reading, main_meter: main_meter, monthly_period: scenario.period)

      visit zone_path(zone)
      within("tr", text: main_meter.name) { click_button I18n.t("main_meters.actions.delete") }

      expect(page).to have_content(I18n.t("flash.main_meters.cannot_destroy_with_readings"))
      expect(MainMeter.exists?(main_meter.id)).to be true
    end
  end

  describe "admin_unit quản lý khu vực" do
    it "thêm công tơ tổng trên khu vực mình quản lý" do
      zone = create(:zone, manager_organization: scenario.unit)
      login_as scenario.admin_unit, scope: :user

      visit zone_path(zone)
      click_on I18n.t("zones.show.add_main_meter")
      fill_in I18n.t("main_meters.form.name"), with: "Công tơ tổng đơn vị"
      click_on I18n.t("main_meters.form.submit_create")

      expect(page).to have_content(I18n.t("flash.main_meters.created"))
      expect(zone.main_meters.pluck(:name)).to include("Công tơ tổng đơn vị")
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "xem được công tơ tổng của khu vực mình nhưng không có nút thao tác" do
      zone = scenario.unit.zone
      create(:main_meter, name: "Công tơ tổng X", zone: zone)

      visit zone_path(zone)
      expect(page).to have_content("Công tơ tổng X")
      expect(page).not_to have_link(I18n.t("zones.show.add_main_meter"))
      expect(page).not_to have_link(I18n.t("main_meters.actions.edit"))
    end
  end
end
