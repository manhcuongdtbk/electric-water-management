require "rails_helper"

RSpec.describe "Organizations", type: :request do
  let!(:division) { create(:organization, :division) }
  let!(:unit_org) { create(:organization, :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:tech_user)  { create(:user, :tech,         organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: unit_org) }
  let(:commander)  { create(:user, :commander,    organization: unit_org) }

  describe "GET /organizations" do
    context "as admin_level1" do
      it "lists units" do
        sign_in admin1
        get organizations_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit_org.name)
      end
    end

    context "as admin_unit" do
      it "redirects to root with access denied" do
        sign_in admin_unit
        get organizations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      it "redirects to root with access denied" do
        sign_in commander
        get organizations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as tech" do
      it "redirects to users_path" do
        sign_in tech_user
        get organizations_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get organizations_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /organizations/new" do
    it "allows admin_level1" do
      sign_in admin1
      get new_organization_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects admin_unit" do
      sign_in admin_unit
      get new_organization_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects tech to users_path" do
      sign_in tech_user
      get new_organization_path
      expect(response).to redirect_to(users_path)
    end
  end

  describe "POST /organizations" do
    let(:valid_params) do
      { organization: { name: "Đại đội 30", position: 14 } }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a unit attached to the division" do
        expect {
          post organizations_path, params: valid_params
        }.to change(Organization.units, :count).by(1)

        expect(response).to redirect_to(organizations_path)
        created = Organization.find_by!(name: "Đại đội 30")
        expect(created.level).to eq("unit")
        expect(created.parent).to eq(division)
      end

      it "ignores user-supplied level/parent params" do
        post organizations_path, params: {
          organization: { name: "Hack division", level: "division", parent_id: nil }
        }
        created = Organization.find_by!(name: "Hack division")
        expect(created.level).to eq("unit")
        expect(created.parent).to eq(division)
      end

      it "re-renders form on duplicate name" do
        create(:organization, :unit, name: "Đại đội 30", parent: division)
        expect {
          post organizations_path, params: valid_params
        }.not_to change(Organization, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "re-renders form when name is missing" do
        post organizations_path, params: { organization: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      it "is forbidden" do
        sign_in admin_unit
        expect {
          post organizations_path, params: valid_params
        }.not_to change(Organization, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /organizations/:id/edit" do
    it "allows admin_level1" do
      sign_in admin1
      get edit_organization_path(unit_org)
      expect(response).to have_http_status(:ok)
    end

    it "redirects commander" do
      sign_in commander
      get edit_organization_path(unit_org)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /organizations/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates name and position" do
        patch organization_path(unit_org),
              params: { organization: { name: "Tên mới", position: 99 } }
        expect(response).to redirect_to(organizations_path)
        expect(unit_org.reload.name).to eq("Tên mới")
        expect(unit_org.reload.position).to eq(99)
      end

      it "re-renders on duplicate name" do
        other = create(:organization, :unit, name: "Trùng tên", parent: division)
        patch organization_path(unit_org),
              params: { organization: { name: other.name } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      it "is forbidden" do
        sign_in admin_unit
        patch organization_path(unit_org),
              params: { organization: { name: "Hacked" } }
        expect(response).to redirect_to(root_path)
        expect(unit_org.reload.name).not_to eq("Hacked")
      end
    end
  end

  describe "DELETE /organizations/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "destroys a unit with no related data" do
        empty_unit = create(:organization, :unit, parent: division)
        expect {
          delete organization_path(empty_unit)
        }.to change(Organization.units, :count).by(-1)
        expect(response).to redirect_to(organizations_path)
        expect(flash[:notice]).to eq(I18n.t("flash.organizations.destroyed"))
      end

      it "blocks destroying a unit with users" do
        create(:user, :admin_unit, organization: unit_org)
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(response).to redirect_to(organizations_path)
        expect(flash[:alert]).to eq(I18n.t("flash.organizations.cannot_destroy_with_data"))
      end

      it "blocks destroying a unit with contact_points" do
        create(:contact_point, organization: unit_org)
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(flash[:alert]).to eq(I18n.t("flash.organizations.cannot_destroy_with_data"))
      end

      it "blocks destroying a unit with meters" do
        create(:meter, :public_meter, organization: unit_org)
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(flash[:alert]).to eq(I18n.t("flash.organizations.cannot_destroy_with_data"))
      end

      it "blocks destroying a unit with unit_configs" do
        period = create(:monthly_period)
        create(:unit_config, organization: unit_org, monthly_period: period)
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(flash[:alert]).to eq(I18n.t("flash.organizations.cannot_destroy_with_data"))
      end

      it "blocks destroying a unit with pump_station_assignments" do
        pump = create(:pump_station)
        create(:pump_station_assignment, pump_station: pump, organization: unit_org)
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(flash[:alert]).to eq(I18n.t("flash.organizations.cannot_destroy_with_data"))
      end

      it "returns 404 when targeting a division (controller scopes to units)" do
        fresh_division = create(:organization, :division)
        delete organization_path(fresh_division)
        expect(response).to have_http_status(:not_found)
        expect(Organization.exists?(fresh_division.id)).to be true
      end
    end

    context "as admin_unit" do
      it "is forbidden" do
        sign_in admin_unit
        expect {
          delete organization_path(unit_org)
        }.not_to change(Organization, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
