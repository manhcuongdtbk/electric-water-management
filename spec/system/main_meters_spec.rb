require "rails_helper"

# Quản lý khu vực đồng hồ tổng — admin_level1 tạo/sửa/xoá MainMeter và gán
# Organization vào. Đây là tiền đề cho F05 (PR2): admin_level1 sẽ nhập số điện
# lực theo khu vực, engine tính tổn hao trên toàn khu vực.
RSpec.describe "MainMeters management", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "thấy danh sách khu vực rỗng và link tạo mới" do
      scenario # touch lazy let
      visit main_meters_path
      expect(page).to have_content(I18n.t("main_meters.index.title"))
      expect(page).to have_content(I18n.t("main_meters.index.empty"))
    end

    it "tạo khu vực mới + gán đơn vị thành công" do
      other_unit = create(:organization, :unit, parent: scenario.division, name: "Tiểu đoàn 18")
      visit main_meters_path
      click_on I18n.t("main_meters.index.new_button")

      fill_in I18n.t("main_meters.form.name"), with: "Khu vực Cơ quan SĐB"
      check scenario.unit.name
      check other_unit.name
      click_on I18n.t("main_meters.form.submit_create")

      expect(page).to have_current_path(main_meters_path)
      expect(page).to have_content(I18n.t("flash.main_meters.created"))

      mm = MainMeter.find_by!(name: "Khu vực Cơ quan SĐB")
      expect(mm.organizations).to contain_exactly(scenario.unit, other_unit)
    end

    it "validation: tên trùng → lỗi" do
      create(:main_meter, name: "Khu vực trùng")
      visit new_main_meter_path

      fill_in I18n.t("main_meters.form.name"), with: "Khu vực trùng"
      click_on I18n.t("main_meters.form.submit_create")

      expect(page).to have_content(I18n.t("errors.messages.taken"))
      expect(page).to have_content(I18n.t("main_meters.new.title"))
    end

    it "sửa khu vực + thêm đơn vị thành công" do
      mm = create(:main_meter, name: "Khu vực A")
      scenario.unit.update!(zone: mm.zone)
      other_unit = create(:organization, :unit, parent: scenario.division, name: "Đơn vị B")

      visit edit_main_meter_path(mm)
      check other_unit.name
      click_on I18n.t("main_meters.form.submit_update")

      expect(page).to have_current_path(main_meters_path)
      expect(page).to have_content(I18n.t("flash.main_meters.updated"))
      # Both units now share the zone — units cannot be detached (must reassign).
      expect(scenario.unit.reload.zone_id).to eq(mm.zone_id)
      expect(other_unit.reload.zone_id).to eq(mm.zone_id)
    end

    it "gán đơn vị đang thuộc khu vực khác → chuyển sang khu vực mới (cảnh báo hiển thị)" do
      old_zone = create(:zone, name: "Khu vực cũ")
      old_mm = create(:main_meter, name: "Đồng hồ tổng cũ", zone: old_zone)
      scenario.unit.update!(zone: old_zone)
      new_mm = create(:main_meter, name: "Đồng hồ tổng mới")

      visit edit_main_meter_path(new_mm)
      expect(page).to have_content(I18n.t("main_meters.form.org_in_other", zone: old_zone.name))
      check scenario.unit.name
      click_on I18n.t("main_meters.form.submit_update")

      expect(page).to have_content(I18n.t("flash.main_meters.updated"))
      expect(scenario.unit.reload.zone_id).to eq(new_mm.zone_id)
      expect(old_mm.reload.organizations).to be_empty
    end

    it "ghi nhật ký (paper_trail) cho Organization khi gán vào khu vực mới" do
      mm = create(:main_meter, name: "Khu vực X")
      expect {
        visit edit_main_meter_path(mm)
        check scenario.unit.name
        click_on I18n.t("main_meters.form.submit_update")
        expect(page).to have_content(I18n.t("flash.main_meters.updated"))
      }.to change { PaperTrail::Version.where(item_type: "Organization", item_id: scenario.unit.id).count }.by(1)
    end

    it "xoá đồng hồ tổng không có reading → đơn vị vẫn thuộc khu vực, zone không bị xoá" do
      mm = create(:main_meter)
      zone = mm.zone
      scenario.unit.update!(zone: zone)

      visit main_meters_path
      within("tr", text: mm.name) do
        click_button I18n.t("main_meters.actions.delete")
      end

      expect(page).to have_content(I18n.t("flash.main_meters.destroyed"))
      expect(MainMeter.exists?(mm.id)).to be false
      # Zone outlives the main_meter — orgs keep their zone membership.
      expect(scenario.unit.reload.zone_id).to eq(zone.id)
      expect(Zone.exists?(zone.id)).to be true
    end

    it "không xoá được khu vực có chỉ số đồng hồ tổng" do
      mm = create(:main_meter)
      create(:main_meter_reading, main_meter: mm, monthly_period: scenario.period)

      visit main_meters_path
      within("tr", text: mm.name) do
        click_button I18n.t("main_meters.actions.delete")
      end

      expect(page).to have_content(I18n.t("flash.main_meters.cannot_destroy_with_readings"))
      expect(MainMeter.exists?(mm.id)).to be true
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "không truy cập được trang quản lý khu vực" do
      visit main_meters_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "không truy cập được trang quản lý khu vực" do
      visit main_meters_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content(I18n.t("flash.access_denied"))
    end
  end

  describe "tech" do
    before { login_as scenario.tech, scope: :user }

    it "bị redirect về users_path" do
      visit main_meters_path
      expect(page).to have_current_path(users_path)
    end
  end
end
