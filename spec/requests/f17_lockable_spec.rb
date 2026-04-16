require "rails_helper"

RSpec.describe "F17 Account Lockable", type: :request do
  let!(:division) { create(:organization, :division) }
  let!(:org_a)    { create(:organization, :unit, parent: division) }

  let!(:target_user) { create(:user, :admin_unit, organization: org_a) }
  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:tech_user)    { create(:user, :tech, organization: division) }

  def attempt_sign_in(email, password)
    post user_session_path, params: { user: { email: email, password: password } }
  end

  # ---------------------------------------------------------------------------
  # Auto-lock after 5 consecutive failed attempts
  # ---------------------------------------------------------------------------
  describe "auto-lock on failed attempts" do
    it "locks the account after 5 wrong passwords" do
      5.times { attempt_sign_in(target_user.email, "wrongpassword") }
      expect(target_user.reload.access_locked?).to be true
    end

    it "does not lock after only 4 failed attempts" do
      4.times { attempt_sign_in(target_user.email, "wrongpassword") }
      expect(target_user.reload.access_locked?).to be false
    end

    it "shows the Vietnamese locked message when account is locked" do
      5.times { attempt_sign_in(target_user.email, "wrongpassword") }
      attempt_sign_in(target_user.email, "Password1!")
      expect(response.body).to include(I18n.t("devise.failure.locked"))
    end

    it "shows last-attempt warning on the 4th failed attempt" do
      4.times { attempt_sign_in(target_user.email, "wrongpassword") }
      expect(response.body).to include(I18n.t("devise.failure.last_attempt"))
    end
  end

  # ---------------------------------------------------------------------------
  # Admin unlock restores access
  # ---------------------------------------------------------------------------
  describe "admin unlock" do
    before do
      5.times { attempt_sign_in(target_user.email, "wrongpassword") }
    end

    context "as admin_level1" do
      it "unlocks the account and the user can sign in again" do
        sign_in admin1
        patch unlock_user_path(target_user)
        expect(target_user.reload.access_locked?).to be false

        sign_out admin1
        attempt_sign_in(target_user.email, "Password1!")
        expect(response).to redirect_to(root_path)
      end
    end

    context "as tech" do
      it "unlocks the account and the user can sign in again" do
        sign_in tech_user
        patch unlock_user_path(target_user)
        expect(target_user.reload.access_locked?).to be false

        sign_out tech_user
        attempt_sign_in(target_user.email, "Password1!")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Failed attempts counter resets after successful login
  # ---------------------------------------------------------------------------
  describe "failed_attempts counter" do
    it "resets to 0 after a successful login" do
      2.times { attempt_sign_in(target_user.email, "wrongpassword") }
      expect(target_user.reload.failed_attempts).to eq(2)

      attempt_sign_in(target_user.email, "Password1!")
      expect(target_user.reload.failed_attempts).to eq(0)
    end
  end
end
