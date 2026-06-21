# Shared system spec examples cho filter visibility theo role.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Verify:
#   - system_admin thấy dropdown filters
#   - Các role khác (UA-ZM, UA, CMD-ZM, CMD) không thấy dropdown filters
#
# Yêu cầu trong caller:
#   path:              → URL trang index
#   filter_select_ids: → Array HTML ids của selects cần check (vd: ["zone_id"] hoặc ["zone_id", "unit_id"])
RSpec.shared_examples "role-based filter visibility" do
  context "as system_admin" do
    before do
      user = create(:user, :system_admin)
      sign_in user
    end

    it "hiển thị dropdown filters" do
      visit path
      filter_select_ids.each do |select_id|
        expect(page).to have_select(select_id)
      end
    end
  end

  context "as division_commander" do
    before do
      user = create(:user, :division_commander)
      sign_in user
    end

    it "hiển thị dropdown filters" do
      visit path
      filter_select_ids.each do |select_id|
        expect(page).to have_select(select_id)
      end
    end
  end

  %w[unit_admin commander].each do |role|
    context "as #{role} - zone manager" do
      before do
        zone = create(:zone, name: "RoleTest-ZM-#{role}-#{SecureRandom.hex(4)}")
        zone_manager_unit = create(:unit, zone: zone)
        user = create(:user, role.to_sym, unit: zone_manager_unit)
        sign_in user
      end

      it "không hiển thị dropdown filters" do
        visit path
        filter_select_ids.each do |select_id|
          expect(page).not_to have_select(select_id)
        end
      end
    end

    context "as #{role} - non zone manager" do
      before do
        zone = create(:zone, name: "RoleTest-NonZM-#{role}-#{SecureRandom.hex(4)}")
        create(:unit, zone: zone) # first unit = auto zone manager
        non_zone_manager = create(:unit, zone: zone)
        user = create(:user, role.to_sym, unit: non_zone_manager)
        sign_in user
      end

      it "không hiển thị dropdown filters" do
        visit path
        filter_select_ids.each do |select_id|
          expect(page).not_to have_select(select_id)
        end
      end
    end
  end
end
