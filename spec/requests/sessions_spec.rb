require "rails_helper"

RSpec.describe "Devise sessions", type: :request do
  let!(:user) do
    User.create!(
      username: "testUser",
      display_name: "Test User",
      role: :technician,
      password: "Abc@1234",
      password_confirmation: "Abc@1234"
    )
  end

  describe "GET /users/sign_in" do
    it "render form đăng nhập với field username (không phải email)" do
      get "/users/sign_in"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Đăng nhập")
      expect(response.body).to include('name="user[username]"')
      expect(response.body).not_to include('name="user[email]"')
    end
  end

  describe "POST /users/sign_in" do
    it "đăng nhập thành công với username + password đúng" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to("/")
    end

    it "đăng nhập thất bại với password sai" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "WrongPass!1A" } }
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:unauthorized)
      expect(response.body).to include("Đăng nhập")
    end

    it "đăng nhập thất bại với username sai" do
      post "/users/sign_in", params: { user: { username: "nonexistent", password: "Abc@1234" } }
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:unauthorized)
    end
  end
end
