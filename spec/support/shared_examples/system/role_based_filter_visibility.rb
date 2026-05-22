# Shared system spec examples cho role-based filter visibility.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Verify rằng non-SA roles không thấy dropdown zone/unit trên các trang có filter.
#
# Yêu cầu trong caller:
#   path:   → URL trang index
#   zone1:  → Zone có unit là zone manager
#   unit1:  → Unit thuộc zone1 và là zone manager
RSpec.shared_examples "non-admin filter visibility" do
  %w[unit_admin commander].each do |role|
    context "as #{role} zone-manager" do
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
