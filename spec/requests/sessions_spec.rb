require "rails_helper"

RSpec.describe "Sessions", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:division) { create(:organization, :division) }
  let(:unit)     { create(:organization, :unit, parent: division) }
  let(:user)     { create(:user, :admin_unit, organization: unit) }

  describe "POST /sessions/extend" do
    context "when authenticated" do
      before { sign_in user }

      it "returns 204 No Content" do
        post extend_session_path
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when not authenticated" do
      it "returns 401 Unauthorized" do
        post extend_session_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
