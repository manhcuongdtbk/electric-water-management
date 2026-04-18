require "rails_helper"

# F18 — Session timeout after 2 hours of inactivity
RSpec.describe "F18 — Session timeout", type: :system do
  include ActiveSupport::Testing::TimeHelpers

  let(:division) { create(:organization, :division) }
  let(:unit)     { create(:organization, :unit, parent: division) }
  let(:user)     { create(:user, :admin_unit, organization: unit) }

  it "redirects to sign-in with timeout flash after 2 hours of inactivity" do
    login_as user, scope: :user

    # First request sets last_request_at in the session
    visit contact_points_path
    expect(page).to have_current_path(contact_points_path)

    # Simulate 121 minutes of inactivity
    travel_to 121.minutes.from_now do
      visit contact_points_path

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content(I18n.t("devise.failure.timeout"))
    end
  end

  it "does not time out within 2 hours" do
    login_as user, scope: :user

    visit contact_points_path
    expect(page).to have_current_path(contact_points_path)

    travel_to 119.minutes.from_now do
      visit contact_points_path
      expect(page).to have_current_path(contact_points_path)
    end
  end

  describe "session timeout warning modal", :js do
    before { login_as user, scope: :user }

    def set_session_expires_in(seconds)
      page.execute_script(<<~JS)
        const el = document.querySelector('[data-controller="session-timeout"]');
        if (el) {
          el.setAttribute(
            'data-session-timeout-expires-at-value',
            Math.floor(Date.now() / 1000) + #{seconds}
          );
        }
      JS
    end

    # 300s < 600s warning threshold → modal appears immediately; safe from the
    # auto-reload that fires when remaining reaches 0.
    it "shows warning modal when session is about to expire" do
      visit contact_points_path
      set_session_expires_in(300)
      expect(page).to have_selector('[data-session-timeout-target="modal"]', visible: true, wait: 5)
      expect(page).to have_text("Phiên sẽ hết hạn sau")
    end

    it "hides modal when expiresAt is updated to far future" do
      visit contact_points_path
      set_session_expires_in(300)
      expect(page).to have_selector('[data-session-timeout-target="modal"]', visible: true, wait: 5)
      set_session_expires_in(7200)
      expect(page).not_to have_selector('[data-session-timeout-target="modal"]', visible: true, wait: 5)
    end

    it "closes modal after clicking Duy trì phiên" do
      visit contact_points_path
      set_session_expires_in(300)
      expect(page).to have_selector('[data-session-timeout-target="modal"]', visible: true, wait: 5)
      click_button "Duy trì phiên"
      expect(page).not_to have_selector('[data-session-timeout-target="modal"]', visible: true, wait: 10)
    end
  end
end
