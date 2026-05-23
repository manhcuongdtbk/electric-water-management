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

  describe "T79: thông báo kỳ đang mở sau khi đăng nhập" do
    context "khi có kỳ đang mở" do
      let!(:period) do
        Period.create!(year: 2026, month: 5, unit_price: 2336.4,
                       savings_rate: 5, division_public_rate: 10, water_pump_standard: 1,
                       closed: false)
      end

      it "set flash notice chứa 'Kỳ tháng 5/2026'" do
        post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
        expect(flash[:notice].to_s).to include("Kỳ tháng 5/2026")
      end
    end

    context "khi không có kỳ đang mở" do
      it "không set flash period_now_open" do
        post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
        expect(flash[:notice].to_s).not_to include("đã mở")
      end
    end
  end

  describe "T90: session timeout 2 giờ" do
    it "request kế tiếp sau khi idle 2h+ → user bị thoát" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      get root_path
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)

      travel 2.hours + 5.minutes do
        get root_path
        # Devise có thể redirect qua / trước rồi tới login; follow để tới đích cuối
        follow_redirect! while response.redirect? && response.location != new_user_session_url
        expect(response.location).to eq(new_user_session_url).or eq(new_user_session_path)
      end
    end

    it "vẫn truy cập được khi idle < 2h" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      travel 1.hour + 30.minutes do
        get root_path
        # Có thể là 200 hoặc 302 (depending on force_password_change), không phải redirect login
        expect(response.status).not_to eq(401)
        expect(response.headers["Location"]).not_to eq(new_user_session_url) if response.redirect?
      end
    end
  end

  describe "flash boolean true không hiện trên login page" do
    it "session timeout set flash[:timedout]=true → không render chữ 'true'" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      travel 2.hours + 5.minutes do
        get root_path
        follow_redirect! while response.redirect? && response.location != new_user_session_url
        get new_user_session_path
        expect(response.body).not_to include(">true<")
        expect(response.body).not_to match(%r{<div[^>]*>\s*<p>true</p>\s*</div>})
      end
    end
  end

  describe "T91: đăng nhập đa thiết bị" do
    it "2 cookie jars độc lập đều đăng nhập được" do
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      expect(response).to have_http_status(:redirect)
      reset!
      post "/users/sign_in", params: { user: { username: "testUser", password: "Abc@1234" } }
      expect(response).to have_http_status(:redirect)
    end
  end
end
