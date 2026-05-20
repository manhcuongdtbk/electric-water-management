require "rails_helper"

# BusinessRoleRequired phải áp cho mọi trang nghiệp vụ. Kỹ thuật viên chỉ được vào
# 3 trang hệ thống (Tài khoản, Nhật ký, Sao lưu) — mọi trang nghiệp vụ phải chặn.
RSpec.describe "BusinessRoleRequired integration", type: :request do
  # Trang nghiệp vụ (đã loại 3 trang của kỹ thuật viên: users, audit_logs, backups).
  business_path_helpers = %i[
    zones_path units_path contact_points_path blocks_path groups_path
    ranks_path pump_allocations_path pricing_path electricity_supply_path
  ]

  context "kỹ thuật viên" do
    let(:user) { create(:user) }
    before { sign_in user }

    business_path_helpers.each do |helper|
      it "chặn GET #{helper}, redirect về /users kèm cảnh báo không có quyền" do
        get public_send(helper)
        expect(response).to redirect_to(users_path)
        follow_redirect!
        expect(flash[:alert]).to eq(I18n.t("errors.access_denied"))
      end
    end
  end

  context "system_admin" do
    let(:user) { create(:user, :system_admin) }
    before { sign_in user }

    business_path_helpers.each do |helper|
      it "không chặn GET #{helper}" do
        get public_send(helper)
        expect(response).not_to redirect_to(users_path)
      end
    end
  end
end
