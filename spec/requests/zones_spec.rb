require "rails_helper"

RSpec.describe "Zones", type: :request do
  let(:division) { create(:organization, :division) }
  let(:org_a)    { create(:organization, :unit, parent: division) }
  let(:org_b)    { create(:organization, :unit, parent: division) }

  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit, organization: org_a) }
  let(:commander_a)  { create(:user, :commander, organization: org_a) }
  let(:tech_user)    { create(:user, :tech, organization: division) }

  let!(:zone_a) { create(:zone, name: "Zone Alpha") }
  let!(:zone_b) { create(:zone, name: "Zone Beta") }

  before do
    # Place each org in its respective zone so the zone_id FK is set
    org_a.update!(zone: zone_a)
    org_b.update!(zone: zone_b)
  end

  describe "GET /zones" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the list with all zones" do
        get zones_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Zone Alpha")
        expect(response.body).to include("Zone Beta")
      end
    end

    context "as zone-manager admin_unit" do
      before do
        zone_a.update!(manager_organization: org_a)
        sign_in admin_unit_a
      end

      it "shows only the managed zone" do
        get zones_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Zone Alpha")
        expect(response.body).not_to include("Zone Beta")
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "shows own zone (read-only)" do
        get zones_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Zone Alpha")
        expect(response.body).not_to include("Zone Beta")
      end
    end

    context "as non-manager admin_unit" do
      before { sign_in admin_unit_a }

      it "is forbidden" do
        get zones_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "redirects to users path" do
        get zones_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get zones_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /zones/:id" do
    let!(:main_meter) { create(:main_meter, name: "Công tơ tổng Alpha", zone: zone_a) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the zone with its main meters and the add button" do
        get zone_path(zone_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Công tơ tổng Alpha")
        expect(response.body).to include(I18n.t("zones.show.add_main_meter"))
      end
    end

    context "as zone-manager admin_unit" do
      before do
        zone_a.update!(manager_organization: org_a)
        sign_in admin_unit_a
      end

      it "renders the managed zone with the add button" do
        get zone_path(zone_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("zones.show.add_main_meter"))
      end

      it "returns 404 for a zone it does not manage" do
        get zone_path(zone_b)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "renders own zone read-only without the add button" do
        get zone_path(zone_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Công tơ tổng Alpha")
        expect(response.body).not_to include(I18n.t("zones.show.add_main_meter"))
      end

      it "returns 404 for another unit's zone" do
        get zone_path(zone_b)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /zones/new" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the form" do
        get new_zone_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "is forbidden" do
        get new_zone_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "is forbidden" do
        get new_zone_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /zones" do
    let(:valid_params) { { zone: { name: "Zone Nova" } } }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a zone with a name" do
        expect {
          post zones_path, params: valid_params
        }.to change(Zone, :count).by(1)

        zone = Zone.last
        expect(zone.name).to eq("Zone Nova")
        expect(response).to redirect_to(zones_path)
      end

      it "creates a zone with a manager organization" do
        post zones_path, params: { zone: { name: "Zone Managed", manager_organization_id: org_a.id } }
        expect(Zone.last.manager_organization).to eq(org_a)
        expect(response).to redirect_to(zones_path)
      end

      it "rejects blank name" do
        post zones_path, params: { zone: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(Zone.where(name: "")).to be_empty
      end

      it "rejects duplicate name" do
        post zones_path, params: { zone: { name: "Zone Alpha" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "is forbidden" do
        post zones_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(Zone.where(name: "Zone Nova")).to be_empty
      end
    end
  end

  describe "GET /zones/:id/edit" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the edit form" do
        get edit_zone_path(zone_a)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as zone-manager admin_unit (no :update ability)" do
      before do
        zone_a.update!(manager_organization: org_a)
        sign_in admin_unit_a
      end

      it "is forbidden even for the managed zone" do
        get edit_zone_path(zone_a)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when zone does not exist" do
      before { sign_in admin1 }

      it "returns 404" do
        get edit_zone_path(id: 999_999)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /zones/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates zone name" do
        patch zone_path(zone_a), params: { zone: { name: "Zone Updated" } }
        expect(response).to redirect_to(zones_path)
        expect(zone_a.reload.name).to eq("Zone Updated")
      end

      it "updates manager organization" do
        patch zone_path(zone_a), params: { zone: { manager_organization_id: org_b.id } }
        expect(zone_a.reload.manager_organization).to eq(org_b)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "returns 404 (zone not in accessible scope)" do
        patch zone_path(zone_a), params: { zone: { name: "Hacked" } }
        expect(response).to have_http_status(:not_found)
        expect(zone_a.reload.name).to eq("Zone Alpha")
      end
    end
  end

  describe "DELETE /zones/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "destroys an empty zone" do
        empty_zone = create(:zone, name: "Empty Zone")
        expect {
          delete zone_path(empty_zone)
        }.to change(Zone, :count).by(-1)
        expect(response).to redirect_to(zones_path)
      end

      it "refuses to destroy a zone with organizations" do
        expect {
          delete zone_path(zone_a)
        }.not_to change(Zone, :count)
        expect(response).to redirect_to(zones_path)
        expect(flash[:alert]).to be_present
      end

      it "refuses to destroy a zone with main_meters" do
        zone_with_meter = create(:zone, name: "Zone With Meter")
        create(:main_meter, zone: zone_with_meter)
        expect {
          delete zone_path(zone_with_meter)
        }.not_to change(Zone, :count)
        expect(response).to redirect_to(zones_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "returns 404 (zone not in accessible scope)" do
        expect {
          delete zone_path(zone_a)
        }.not_to change(Zone, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
