require "rails_helper"

RSpec.describe "MainMeters", type: :request do
  let!(:division) { create(:organization, :division) }
  let(:admin1)    { create(:user, :admin_level1, organization: division) }

  describe "POST /main_meters" do
    before { sign_in admin1 }

    it "re-renders form when name is missing → Vietnamese blank error" do
      expect {
        post main_meters_path, params: { main_meter: { name: "" } }
      }.not_to change(MainMeter, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("errors.messages.blank"))
    end

    it "re-renders form on duplicate name → Vietnamese taken error" do
      create(:main_meter, name: "Khu vực A")
      expect {
        post main_meters_path, params: { main_meter: { name: "Khu vực A" } }
      }.not_to change(MainMeter, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("errors.messages.taken"))
    end
  end
end
