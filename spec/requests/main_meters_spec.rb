require "rails_helper"

RSpec.describe "MainMeters", type: :request do
  let!(:division) { create(:organization, :division) }
  let(:admin1)    { create(:user, :admin_level1, organization: division) }
  let(:zone)      { create(:zone) }

  describe "POST /zones/:zone_id/main_meters" do
    before { sign_in admin1 }

    it "creates a main meter scoped to the zone and redirects to the zone page" do
      expect {
        post zone_main_meters_path(zone), params: { main_meter: { name: "Công tơ tổng A" } }
      }.to change(MainMeter, :count).by(1)
      expect(MainMeter.last.zone).to eq(zone)
      expect(response).to redirect_to(zone_path(zone))
    end

    it "re-renders form when name is missing → Vietnamese blank error" do
      expect {
        post zone_main_meters_path(zone), params: { main_meter: { name: "" } }
      }.not_to change(MainMeter, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("errors.messages.blank"))
    end

    it "re-renders form on duplicate name → Vietnamese taken error" do
      create(:main_meter, name: "Công tơ A")
      expect {
        post zone_main_meters_path(zone), params: { main_meter: { name: "Công tơ A" } }
      }.not_to change(MainMeter, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("errors.messages.taken"))
    end
  end

  describe "zone-manager cross-zone access denial" do
    let(:managed_zone)     { create(:zone) }
    let(:zone_manager_org) { create(:organization, :unit, parent: division, zone: managed_zone) }
    let(:zone_manager)     { create(:user, :admin_unit, organization: zone_manager_org) }
    let(:foreign_zone)     { create(:zone) }
    let!(:foreign_mm)      { create(:main_meter, zone: foreign_zone) }

    before do
      managed_zone.update!(manager_organization: zone_manager_org)
      sign_in zone_manager
    end

    it "denies PATCH on foreign-zone main meter → 404" do
      patch zone_main_meter_path(foreign_zone, foreign_mm), params: { main_meter: { name: "X" } }
      expect(response).to have_http_status(:not_found)
    end

    it "denies DELETE on foreign-zone main meter → 404" do
      delete zone_main_meter_path(foreign_zone, foreign_mm)
      expect(response).to have_http_status(:not_found)
    end

    it "allows managing a main meter in a managed zone" do
      mm = create(:main_meter, zone: managed_zone)
      patch zone_main_meter_path(managed_zone, mm), params: { main_meter: { name: "Đã sửa" } }
      expect(response).to redirect_to(zone_path(managed_zone))
      expect(mm.reload.name).to eq("Đã sửa")
    end
  end
end
