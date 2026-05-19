require "rails_helper"

RSpec.describe "PasswordChanges", type: :request do
  let(:user) { create(:user, :system_admin, force_password_change: true) }
  before { sign_in user }

  describe "GET /password_change/edit" do
    it "trả về 200" do
      get edit_password_change_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Đổi mật khẩu")
    end

    it "không bị enforce_password_change redirect (skip ở controller này)" do
      get edit_password_change_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /password_change" do
    let(:new_password) { "NewSecure@123" }

    it "đổi mật khẩu thành công + set force_password_change = false" do
      patch password_change_path, params: {
        user: { password: new_password, password_confirmation: new_password }
      }
      expect(response).to redirect_to(root_path)
      user.reload
      expect(user.force_password_change).to be false
      expect(user.valid_password?(new_password)).to be true
    end

    it "chặn khi password yếu" do
      patch password_change_path, params: {
        user: { password: "weak", password_confirmation: "weak" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      user.reload
      expect(user.valid_password?("weak")).to be false
    end

  end

  describe "Force password change flow" do
    it "user mới buộc đổi mật khẩu trước khi vào trang khác" do
      get root_path
      expect(response).to redirect_to(edit_password_change_path)
    end

    it "sau khi đổi xong, truy cập được mọi trang" do
      patch password_change_path, params: {
        user: { password: "Secure@123", password_confirmation: "Secure@123" }
      }
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "T92: đổi mật khẩu tự nguyện (KHÔNG force change)" do
    let(:voluntary_user) do
      create(:user, :system_admin, force_password_change: false,
                                     password: "Current@1", password_confirmation: "Current@1")
    end

    before do
      sign_out user
      sign_in voluntary_user
    end

    it "form edit có field current_password khi không force change" do
      get edit_password_change_path
      expect(response.body).to include("Mật khẩu hiện tại")
    end

    it "đổi thành công khi nhập đúng mật khẩu cũ" do
      patch password_change_path, params: {
        user: {
          current_password: "Current@1",
          password: "NewSecure@99",
          password_confirmation: "NewSecure@99"
        }
      }
      expect(response).to redirect_to(root_path)
      voluntary_user.reload
      expect(voluntary_user.valid_password?("NewSecure@99")).to be true
    end

    it "chặn khi nhập sai mật khẩu cũ" do
      patch password_change_path, params: {
        user: {
          current_password: "WrongOldPass@1",
          password: "NewSecure@99",
          password_confirmation: "NewSecure@99"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      voluntary_user.reload
      expect(voluntary_user.valid_password?("NewSecure@99")).to be false
      expect(voluntary_user.valid_password?("Current@1")).to be true
    end

    it "chặn khi bỏ trống mật khẩu cũ" do
      patch password_change_path, params: {
        user: { password: "NewSecure@99", password_confirmation: "NewSecure@99" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      voluntary_user.reload
      expect(voluntary_user.valid_password?("Current@1")).to be true
    end
  end
end
