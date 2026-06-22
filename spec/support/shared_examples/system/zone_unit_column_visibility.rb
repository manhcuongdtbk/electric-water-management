# Shared system spec examples cho zone/unit column visibility theo role.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Verify:
#   - system_admin và division_commander thấy cột Khu vực và Đơn vị
#   - Non-SA không thấy cột Khu vực và Đơn vị
#
# Yêu cầu trong caller:
#   path:                → URL trang index
#   dc_can_access (opt)  → false nếu DC không vào được trang (mặc định true)
RSpec.shared_examples "zone-unit column visibility" do
  context "as system_admin" do
    before do
      user = create(:user, :system_admin)
      sign_in user
    end

    it "hiển thị cột Khu vực và Đơn vị" do
      visit path
      expect(page).to have_css("thead", text: /khu vực/i)
      expect(page).to have_css("thead", text: /đơn vị/i)
    end
  end

  context "as division_commander" do
    before do
      user = create(:user, :division_commander)
      sign_in user
    end

    it "hiển thị cột Khu vực và Đơn vị" do
      skip "DC cannot access this page" if respond_to?(:dc_can_access) && !dc_can_access
      visit path
      expect(page).to have_css("thead", text: /khu vực/i)
      expect(page).to have_css("thead", text: /đơn vị/i)
    end
  end

  context "as unit_admin" do
    before do
      zone = create(:zone)
      unit = create(:unit, zone: zone)
      user = create(:user, :unit_admin, unit: unit)
      sign_in user
    end

    it "không hiển thị cột Khu vực và Đơn vị" do
      visit path
      expect(page).not_to have_css("thead", text: /khu vực/i)
      expect(page).not_to have_css("thead", text: /đơn vị/i)
    end
  end
end
