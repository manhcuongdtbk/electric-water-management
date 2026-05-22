# Shared system spec examples cho filter visibility theo role.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Verify:
#   - system_admin thấy dropdown zone/unit
#   - Các role khác (UA-ZM, UA, CMD-ZM, CMD) không thấy dropdown
#
# Yêu cầu trong caller:
#   path:           → URL trang index
#   zone1:          → Zone có unit là đơn vị quản lý khu vực
#   unit1:          → Unit thuộc zone1 và là đơn vị quản lý khu vực
#   system_admin:   → User system_admin (đã sign_in ở before block)
RSpec.shared_examples "role-based filter visibility" do
  context "as system_admin" do
    it "hiển thị dropdown khu vực và đơn vị" do
      visit path
      expect(page).to have_select("zone_id")
      expect(page).to have_select("unit_id")
    end
  end

  %w[unit_admin commander].each do |role|
    context "as #{role} quản lý khu vực" do
      before do
        user = create(:user, role.to_sym, unit: unit1)
        sign_in user
      end

      it "không hiển thị dropdown khu vực và đơn vị" do
        visit path
        expect(page).not_to have_select("zone_id")
        expect(page).not_to have_select("unit_id")
      end
    end

    context "as #{role} không quản lý khu vực" do
      before do
        non_manager = create(:unit, zone: zone1)
        user = create(:user, role.to_sym, unit: non_manager)
        sign_in user
      end

      it "không hiển thị dropdown khu vực và đơn vị" do
        visit path
        expect(page).not_to have_select("zone_id")
        expect(page).not_to have_select("unit_id")
      end
    end
  end
end
