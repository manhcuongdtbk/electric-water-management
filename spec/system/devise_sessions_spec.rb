require "rails_helper"

# Devise login page: Vietnamese UI, correct redirects, error messages,
# and verification that unused routes do not exist.
RSpec.describe "Devise sessions", type: :system do
  let(:division) { create(:organization, :division) }
  let(:unit)     { create(:organization, :unit, parent: division) }

  # ---------------------------------------------------------------------------
  # Login page UI
  # ---------------------------------------------------------------------------
  describe "login page" do
    before { visit new_user_session_path }

    it "shows Vietnamese title and labels" do
      expect(page).to have_text("Đăng nhập")
      expect(page).to have_text("Quản lý Điện Nước")
    end

    it "has Vietnamese form labels and button" do
      expect(page).to have_field("Email")
      expect(page).to have_field("Mật khẩu")
      expect(page).to have_button("Đăng nhập")
    end

    it "shows remember me checkbox in Vietnamese" do
      expect(page).to have_text("Ghi nhớ đăng nhập")
    end

    it "does not show self-service password or sign-up links" do
      expect(page).not_to have_text("Forgot")
      expect(page).not_to have_text("Sign up")
      expect(page).not_to have_text("Sign in")
      expect(page).not_to have_link(href: /password/)
    end
  end

  # ---------------------------------------------------------------------------
  # Login success → redirect
  # ---------------------------------------------------------------------------
  describe "successful login" do
    it "redirects admin_level1 to root after login" do
      user = create(:user, :admin_level1, organization: division, force_password_change: false)

      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Mật khẩu", with: "Password1!"
      click_button "Đăng nhập"

      expect(page).to have_current_path(root_path)
    end

    it "redirects tech user to users path after login" do
      user = create(:user, :tech, organization: division, force_password_change: false)

      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Mật khẩu", with: "Password1!"
      click_button "Đăng nhập"

      expect(page).to have_current_path(users_path)
    end
  end

  # ---------------------------------------------------------------------------
  # Login failure → Vietnamese error message
  # ---------------------------------------------------------------------------
  describe "failed login" do
    it "shows Vietnamese error for invalid credentials" do
      visit new_user_session_path
      fill_in "Email", with: "nobody@example.com"
      fill_in "Mật khẩu", with: "wrongpassword1"
      click_button "Đăng nhập"

      expect(page).to have_text(I18n.t("devise.failure.invalid"))
    end

    it "shows Vietnamese locked message for locked account" do
      user = create(:user, :admin_unit, organization: unit)
      user.update_columns(locked_at: Time.current, failed_attempts: 5)

      visit new_user_session_path
      fill_in "Email", with: user.email
      fill_in "Mật khẩu", with: "Password1!"
      click_button "Đăng nhập"

      expect(page).to have_text(I18n.t("devise.failure.locked"))
    end
  end
end

# ---------------------------------------------------------------------------
# Routing — verify unused Devise routes are absent (return 404)
# ---------------------------------------------------------------------------
RSpec.describe "Unused Devise routes", type: :request do
  it "returns 404 for /users/password/new (no route)" do
    get "/users/password/new"
    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for /users/sign_up (no route)" do
    get "/users/sign_up"
    expect(response).to have_http_status(:not_found)
  end
end
