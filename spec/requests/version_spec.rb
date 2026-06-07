require "rails_helper"

RSpec.describe "Version", type: :request do
  describe "GET /version" do
    it "trả JSON phiên bản, không cần đăng nhập" do
      get "/version"

      expect(response).to have_http_status(:ok)
      expect(response).not_to have_http_status(:redirect)
      expect(response.media_type).to eq("application/json")
      body = JSON.parse(response.body)
      expect(body["version"]).to eq(SystemInfo.version)
      expect(body["app_environment"]).to eq(SystemInfo.app_environment)
      expect(body["rails_env"]).to eq(Rails.env.to_s)
    end
  end

  describe "hiển thị phiên bản ở sidebar" do
    let(:user) { create(:user, :system_admin) }
    before { sign_in user }

    it "hiện phiên bản ở đáy sidebar trên trang đã đăng nhập" do
      get users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("v#{SystemInfo.version}")
      expect(response.body).to include(SystemInfo.app_environment)
    end
  end

  describe "hiển thị phiên bản ở màn hình đăng nhập" do
    it "hiện phiên bản trên trang đăng nhập (chưa đăng nhập)" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("v#{SystemInfo.version}")
      expect(response.body).to include(SystemInfo.app_environment)
    end
  end
end
