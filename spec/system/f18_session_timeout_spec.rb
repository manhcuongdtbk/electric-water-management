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
end
