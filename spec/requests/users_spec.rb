require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:system_admin) { create(:user, :system_admin) }
  let(:technician) { create(:user) }
  let(:zone) { create(:zone) }
  let!(:unit) { create(:unit, zone: zone) }

  describe "system_admin perspective" do
    before { sign_in system_admin }

    describe "GET /users" do
      let(:html) { Nokogiri::HTML(response.body) }

      it "trả về 200" do
        get users_path
        expect(response).to have_http_status(:ok)
      end

      it "cột Khu vực và Đơn vị đứng trước cột Vai trò" do
        get users_path
        headers = html.css("table thead th").map(&:text).map(&:strip)
        zone_index = headers.index { |h| h.include?("Khu vực") }
        unit_index = headers.index { |h| h.include?("Đơn vị") }
        role_index = headers.index { |h| h.include?("Vai trò") }
        expect(zone_index).to be < role_index
        expect(unit_index).to be < role_index
        expect(zone_index).to be < unit_index
      end

      it "hiển thị khu vực của user" do
        ua = create(:user, :unit_admin, unit: unit)
        get users_path
        expect(response.body).to include(zone.name)
      end

      it "dropdown khu vực chỉ chứa khu vực có user" do
        create(:user, :unit_admin, unit: unit)
        zone_empty = create(:zone, name: "Khu vực trống")
        get users_path
        options = html.css("select#zone_id option").map(&:text)
        expect(options).to include(zone.name)
        expect(options).not_to include("Khu vực trống")
      end

      it "thấy được technician trong list (đọc OK)" do
        tech = create(:user, username: "kyThuat_test")
        get users_path
        expect(response.body).to include("kyThuat_test")
      end
    end

    describe "POST /users" do
      it "tạo unit_admin" do
        post users_path, params: {
          user: {
            username: "newAdmin",
            display_name: "Mới",
            role: "unit_admin",
            unit_id: unit.id,
            password: "Secure@123",
            password_confirmation: "Secure@123"
          }
        }
        expect(response).to redirect_to(users_path)
        expect(User.find_by(username: "newAdmin")).to be_present
      end
    end

    describe "T66: system_admin không quản lý technician" do
      it "không cho update tài khoản technician" do
        tech = create(:user, username: "techTest")
        patch user_path(tech), params: { user: { display_name: "Modified" } }
        # Ability deny → AccessDenied → redirect to root
        expect(response).to redirect_to(root_path)
        expect(tech.reload.display_name).not_to eq("Modified")
      end

      it "không cho destroy tài khoản technician" do
        tech = create(:user, username: "techDel")
        delete user_path(tech)
        expect(response).to redirect_to(root_path)
        expect(User.where(id: tech.id)).to be_present
      end
    end

    describe "T46: không tự xóa chính mình" do
      it "redirect alert khi xóa current_user" do
        delete user_path(system_admin)
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to include("Không thể tự xóa")
        expect(User.where(id: system_admin.id)).to be_present
      end
    end

    describe "T45: không xóa tài khoản mặc định" do
      it "chặn xóa default_account" do
        default_admin = create(:user, :system_admin, :default_account, username: "quanTriMacDinh")
        delete user_path(default_admin)
        expect(User.where(id: default_admin.id)).to be_present
      end
    end
  end

  describe "technician perspective" do
    before { sign_in technician }

    it "manage được mọi user (kể cả technician khác)" do
      tech2 = create(:user, username: "tech2")
      patch user_path(tech2), params: { user: { display_name: "T2 New" } }
      expect(tech2.reload.display_name).to eq("T2 New")
    end
  end

  describe "T93: reset mật khẩu user khác → force_password_change = true" do
    it "technician reset password unit_admin → unit_admin phải đổi mật khẩu lần sau" do
      sign_in technician
      target = create(:user, :unit_admin, unit: unit, force_password_change: false)
      patch user_path(target), params: {
        user: { password: "Reset@99New", password_confirmation: "Reset@99New" }
      }
      target.reload
      expect(target.valid_password?("Reset@99New")).to be true
      expect(target.force_password_change).to be true
    end

    it "system_admin reset password unit_admin → unit_admin phải đổi mật khẩu lần sau" do
      sign_in system_admin
      target = create(:user, :unit_admin, unit: unit, force_password_change: false)
      patch user_path(target), params: {
        user: { password: "Reset@99New", password_confirmation: "Reset@99New" }
      }
      target.reload
      expect(target.valid_password?("Reset@99New")).to be true
      expect(target.force_password_change).to be true
    end

    it "technician tự đổi password chính mình → force_password_change KHÔNG bị set" do
      sign_in technician
      patch user_path(technician), params: {
        user: { password: "Self@99New", password_confirmation: "Self@99New" }
      }
      technician.reload
      expect(technician.valid_password?("Self@99New")).to be true
      expect(technician.force_password_change).to be false
    end
  end

  describe "T47: xóa user A khi A đang đăng nhập từ thiết bị khác" do
    it "user bị hard-delete → request kế tiếp redirect login" do
      target = create(:user, :unit_admin, unit: unit, force_password_change: false)
      sign_in target
      get root_path
      expect(response.status).not_to eq(401)

      target.destroy!
      get root_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
