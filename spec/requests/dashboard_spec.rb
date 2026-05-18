require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "khi chưa đăng nhập" do
      it "redirect đến trang đăng nhập" do
        get root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "khi đăng nhập system_admin" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả về 200 và render tổng quan" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tổng quan")
      end

      it "render sidebar với items system_admin" do
        get root_path
        expect(response.body).to include("Đầu mối")
        expect(response.body).to include("Khu vực")
        expect(response.body).to include("Tài khoản")
      end
    end

    context "khi đăng nhập technician" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "render sidebar không có data nghiệp vụ" do
        get root_path
        expect(response.body).not_to include("Đầu mối")
        expect(response.body).to include("Tài khoản")
      end
    end

    context "khi force_password_change" do
      let(:user) { create(:user, :system_admin, force_password_change: true) }
      before { sign_in user }

      it "redirect đến trang đổi mật khẩu" do
        get root_path
        expect(response).to redirect_to(edit_password_change_path)
      end
    end
  end
end
