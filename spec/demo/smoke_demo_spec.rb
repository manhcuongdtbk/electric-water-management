require "rails_helper"

# Walking skeleton: proves Playwright records a video. Replaced by real feature
# demos later; kept as the minimal smoke recording.
RSpec.describe "Demo recording smoke", type: :demo do
  it "loads the sign-in page" do
    visit "/"
    expect(page).to have_content("Đăng nhập").or have_current_path(%r{sign_in|users})
  end
end
