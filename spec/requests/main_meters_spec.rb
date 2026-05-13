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

  describe "zone-manager cross-zone access denial" do
    let(:zone_manager_org) { create(:organization, :unit, parent: division) }
    let(:zone_manager)     { create(:user, :admin_unit, organization: zone_manager_org) }
    let(:managed_zone)     { create(:zone, manager_organization_id: zone_manager_org.id) }
    let(:foreign_zone)     { create(:zone) }
    let!(:foreign_mm)      { create(:main_meter, zone: foreign_zone) }

    before do
      managed_zone
      sign_in zone_manager
    end

    it "denies PATCH on foreign-zone main meter → 404" do
      patch main_meter_path(foreign_mm), params: { main_meter: { name: "X" } }
      expect(response).to have_http_status(:not_found)
    end

    it "denies DELETE on foreign-zone main meter → 404" do
      delete main_meter_path(foreign_mm)
      expect(response).to have_http_status(:not_found)
    end
  end
end
