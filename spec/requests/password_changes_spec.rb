require "rails_helper"

RSpec.describe "PasswordChanges", type: :request do
  let(:division) { create(:organization, :division) }
  let(:unit)     { create(:organization, :unit, parent: division) }
  let(:user)     { create(:user, :admin_unit, organization: unit, force_password_change: false) }
  let(:forced_user) { create(:user, :admin_unit, organization: unit, force_password_change: true) }

  # ---------------------------------------------------------------------------
  # GET /password_change/edit
  # ---------------------------------------------------------------------------
  describe "GET /password_change/edit" do
    context "when not signed in" do
      it "redirects to sign in" do
        get edit_password_change_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in with force_password_change = true" do
      before { sign_in forced_user }

      it "renders 200" do
        get edit_password_change_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in with force_password_change = false" do
      before { sign_in user }

      it "renders 200" do
        get edit_password_change_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /password_change
  # ---------------------------------------------------------------------------
  describe "PATCH /password_change" do
    context "when not signed in" do
      it "redirects to sign in" do
        patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "NewPass1!" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in with force_password_change = true" do
      before { sign_in forced_user }

      context "with valid matching passwords" do
        it "sets force_password_change to false and redirects to root" do
          patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "NewPass1!" } }
          expect(forced_user.reload.force_password_change).to be false
          expect(response).to redirect_to(root_path)
        end

        it "stores the new password" do
          patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "NewPass1!" } }
          expect(forced_user.reload.valid_password?("NewPass1!")).to be true
        end
      end

      context "with blank password" do
        it "re-renders form with 422" do
          patch password_change_path, params: { user: { password: "", password_confirmation: "" } }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "does not clear force_password_change" do
          patch password_change_path, params: { user: { password: "", password_confirmation: "" } }
          expect(forced_user.reload.force_password_change).to be true
        end
      end

      context "with mismatched passwords" do
        it "re-renders form with 422" do
          patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "Different1!" } }
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "does not clear force_password_change" do
          patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "Different1!" } }
          expect(forced_user.reload.force_password_change).to be true
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Before-action blocking
  # ---------------------------------------------------------------------------
  describe "before_action blocking when force_password_change = true" do
    before { sign_in forced_user }

    it "redirects away from contact_points" do
      get contact_points_path
      expect(response).to redirect_to(edit_password_change_path)
    end

    it "redirects away from users list" do
      get users_path
      expect(response).to redirect_to(edit_password_change_path)
    end

    it "allows access to the password change edit page" do
      get edit_password_change_path
      expect(response).to have_http_status(:ok)
    end

    it "allows PATCH to the password change endpoint" do
      patch password_change_path, params: { user: { password: "NewPass1!", password_confirmation: "NewPass1!" } }
      # After successful change, redirect to root (not blocked)
      expect(response).to redirect_to(root_path)
    end
  end

  # ---------------------------------------------------------------------------
  # after_sign_in_path_for
  # ---------------------------------------------------------------------------
  describe "after_sign_in_path_for" do
    context "user with force_password_change = true signs in" do
      it "redirects to password change page" do
        post user_session_path, params: {
          user: { email: forced_user.email, password: "Password1!" }
        }
        expect(response).to redirect_to(edit_password_change_path)
      end
    end

    context "user with force_password_change = false signs in" do
      it "redirects to root" do
        post user_session_path, params: {
          user: { email: user.email, password: "Password1!" }
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Admin resets another user's password → force_password_change = true
  # ---------------------------------------------------------------------------
  describe "admin resets password for another user" do
    let(:admin) { create(:user, :admin_level1, organization: division, force_password_change: false) }
    let(:target) { create(:user, :admin_unit, organization: unit, force_password_change: false) }

    before { sign_in admin }

    it "sets force_password_change = true on the target user" do
      patch user_path(target), params: {
        user: {
          email: target.email,
          full_name: target.full_name,
          role: target.role,
          password: "ResetPass1!",
          password_confirmation: "ResetPass1!"
        }
      }
      expect(target.reload.force_password_change).to be true
    end

    it "does NOT set force_password_change when admin updates their own password" do
      patch user_path(admin), params: {
        user: {
          email: admin.email,
          full_name: admin.full_name,
          role: admin.role,
          password: "MyNewPass1!",
          password_confirmation: "MyNewPass1!"
        }
      }
      expect(admin.reload.force_password_change).to be false
    end

    it "does NOT set force_password_change when no password provided" do
      patch user_path(target), params: {
        user: {
          email: target.email,
          full_name: target.full_name,
          role: target.role
        }
      }
      expect(target.reload.force_password_change).to be false
    end
  end
end
