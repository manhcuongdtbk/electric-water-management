require "rails_helper"

# F17 — Account lockable. The core Devise behavior (counter, 5-attempt threshold,
# reset on success) is covered by spec/requests/f17_lockable_spec.rb. This spec
# focuses on the browser-facing flow — flash messages, redirects, and the admin
# unlock affordance in the users index.
#
# IMPORTANT: login_as (Warden helper) bypasses Devise lockable, so every test
# in this file uses sign_in_via_form to drive the actual login form.
RSpec.describe "F17 — Account lockable (system)", type: :system do
  let(:scenario) { setup_basic_scenario }

  # Rack::Attack throttles /users/sign_in to 5/min/IP. In isolation the spec
  # passes, but when the full suite hammers the login endpoint from many other
  # specs, the counter for 127.0.0.1 is already exhausted. Reset before each
  # example — same mitigation rack_attack_spec.rb uses.
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  it "locks the account after 5 failed login attempts and surfaces the locked flash" do
    user = scenario.admin_unit
    5.times { sign_in_via_form(user.email, "WrongPassword1!") }

    expect(user.reload.access_locked?).to be true
    # The final attempt returns to the sign-in page with the locked message.
    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_content(I18n.t("devise.failure.locked"))
  end

  it "rejects the correct password when the account is already locked" do
    user = create(:user, :admin_unit, :locked, organization: scenario.unit)

    sign_in_via_form(user.email, "Password1!")
    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_content(I18n.t("devise.failure.locked"))
  end

  it "lets the user log in again after admin_level1 unlocks them via the UI" do
    user = create(:user, :admin_unit, :locked, organization: scenario.unit)

    login_as scenario.admin_level1, scope: :user
    visit users_path
    within("tr", text: user.email) do
      click_button I18n.t("users.actions.unlock")
    end
    expect(page).to have_content(I18n.t("flash.users.unlocked"))
    expect(user.reload.access_locked?).to be false

    # Fully tear down the admin's session (Warden state + rack_test cookies)
    # before logging in as the freshly-unlocked user.
    Warden.test_reset!
    page.reset!
    sign_in_via_form(user.email, "Password1!")
    expect(page).to have_current_path(root_path)
  end
end
