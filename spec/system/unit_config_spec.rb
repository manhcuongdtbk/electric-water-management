require "rails_helper"

RSpec.describe "Unit config", type: :system do
  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Alpha") }
  let!(:zone2) { create(:zone, name: "Khu vực Beta") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị A1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị B1") }

  context "as system_admin" do
    let(:system_admin) { create(:user, :system_admin) }
    before { sign_in system_admin }

    let(:path) { unit_config_path }
    let(:filter_select_ids) { %w[zone_id unit_id] }
    let(:unit_blank_text) { "— Chọn đơn vị —" }
    def path_with_params(**params) = unit_config_path(**params)

    it_behaves_like "zone-unit cascade filter behavior"

    it "chọn đơn vị → hiện form cấu hình" do
      visit unit_config_path(unit_id: unit1.id)
      expect(page).to have_content("Tỷ lệ công cộng đơn vị")
    end

    it "chưa chọn đơn vị → không hiện form cấu hình" do
      visit unit_config_path
      expect(page).not_to have_content("Tỷ lệ công cộng đơn vị")
    end

    it "dropdown hiện — Chọn khu vực — thay vì Tất cả" do
      visit unit_config_path
      zone_options = all("select#zone_id option").map(&:text)
      expect(zone_options).to include("— Chọn khu vực —")
      expect(zone_options).not_to include("Tất cả")
    end

    it "dropdown hiện — Chọn đơn vị — thay vì Tất cả" do
      visit unit_config_path
      unit_options = all("select#unit_id option").map(&:text)
      expect(unit_options).to include("— Chọn đơn vị —")
      expect(unit_options).not_to include("Tất cả")
    end
  end

  context "as unit_admin" do
    let(:unit_admin) { create(:user, :unit_admin, unit: unit1) }
    before { sign_in unit_admin }

    it "không hiển thị toolbar" do
      visit unit_config_path
      expect(page).not_to have_select("zone_id")
      expect(page).not_to have_select("unit_id")
    end

    it "tự động hiện form cấu hình đơn vị của mình" do
      visit unit_config_path
      expect(page).to have_content("Tỷ lệ công cộng đơn vị")
    end
  end
end
