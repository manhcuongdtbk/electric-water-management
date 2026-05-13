require "rails_helper"

RSpec.describe "ContactPointGroups", type: :request do
  let(:division) { create(:organization, :division) }
  let(:org_a)    { create(:organization, :unit, parent: division) }
  let(:org_b)    { create(:organization, :unit, parent: division) }

  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit, organization: org_a) }
  let(:admin_unit_b) { create(:user, :admin_unit, organization: org_b) }
  let(:commander_a)  { create(:user, :commander, organization: org_a) }
  let(:tech_user)    { create(:user, :tech, organization: division) }

  let!(:cpg_a) { create(:contact_point_group, organization: org_a, name: "Nhom A") }
  let!(:cpg_b) { create(:contact_point_group, organization: org_b, name: "Nhom B") }

  describe "GET /contact_point_groups" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the list for the first unit org" do
        get contact_point_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Nhom A")
      end
    end

    context "as admin_unit of org_a" do
      before { sign_in admin_unit_a }

      it "shows only own org groups" do
        get contact_point_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Nhom A")
        expect(response.body).not_to include("Nhom B")
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "shows own org groups (read-only)" do
        get contact_point_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Nhom A")
        expect(response.body).not_to include("Nhom B")
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "redirects to users path" do
        get contact_point_groups_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to login" do
        get contact_point_groups_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /contact_point_groups/new" do
    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "renders the form" do
        get new_contact_point_group_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "is forbidden" do
        get new_contact_point_group_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /contact_point_groups" do
    let(:valid_params) { { contact_point_group: { name: "Nhom moi" } } }

    context "as admin_unit of org_a" do
      before { sign_in admin_unit_a }

      it "creates a group in own org" do
        expect {
          post contact_point_groups_path, params: valid_params
        }.to change(ContactPointGroup, :count).by(1)

        cpg = ContactPointGroup.last
        expect(cpg.name).to eq("Nhom moi")
        expect(cpg.organization).to eq(org_a)
        expect(response).to redirect_to(contact_point_groups_path)
      end

      it "rejects blank name" do
        post contact_point_groups_path, params: { contact_point_group: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(ContactPointGroup.where(name: "")).to be_empty
      end

      it "assigns contact_points via contact_point_ids" do
        cp = create(:contact_point, :residential, organization: org_a)
        post contact_point_groups_path,
             params: { contact_point_group: { name: "With members", contact_point_ids: [ cp.id ] } }
        expect(ContactPointGroup.last.contact_points).to include(cp)
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "is forbidden" do
        post contact_point_groups_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(ContactPointGroup.where(name: "Nhom moi")).to be_empty
      end
    end
  end

  describe "GET /contact_point_groups/:id/edit" do
    context "as admin_unit of org_a" do
      before { sign_in admin_unit_a }

      it "renders own group form" do
        get edit_contact_point_group_path(cpg_a)
        expect(response).to have_http_status(:ok)
      end

      it "cannot edit another org's group" do
        get edit_contact_point_group_path(cpg_b)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when group does not exist" do
      before { sign_in admin_unit_a }

      it "redirects (enumeration protection)" do
        get edit_contact_point_group_path(id: 999_999)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /contact_point_groups/:id" do
    context "as admin_unit of org_a" do
      before { sign_in admin_unit_a }

      it "updates own group" do
        patch contact_point_group_path(cpg_a), params: { contact_point_group: { name: "Updated" } }
        expect(response).to redirect_to(contact_point_groups_path)
        expect(cpg_a.reload.name).to eq("Updated")
      end

      it "cannot update another org's group" do
        patch contact_point_group_path(cpg_b), params: { contact_point_group: { name: "Hacked" } }
        expect(response).to redirect_to(root_path)
        expect(cpg_b.reload.name).to eq("Nhom B")
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "is forbidden" do
        patch contact_point_group_path(cpg_a), params: { contact_point_group: { name: "Updated" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /contact_point_groups/:id" do
    context "as admin_unit of org_a" do
      before { sign_in admin_unit_a }

      it "destroys own group" do
        expect {
          delete contact_point_group_path(cpg_a)
        }.to change(ContactPointGroup, :count).by(-1)
        expect(response).to redirect_to(contact_point_groups_path)
      end

      it "cannot destroy another org's group" do
        expect {
          delete contact_point_group_path(cpg_b)
        }.not_to change(ContactPointGroup, :count)
        expect(response).to redirect_to(root_path)
      end

      it "is blocked when pump_station_assignments exist" do
        # ContactPointGroup will be added to ALLOWED_ASSIGNABLE_TYPES in next PR;
        # bypass model validation here to test restrict_with_error behavior.
        ps = create(:pump_station)
        PumpStationAssignment.new(pump_station: ps, assignable: cpg_a).save(validate: false)
        expect {
          delete contact_point_group_path(cpg_a)
        }.not_to change(ContactPointGroup, :count)
        expect(response).to redirect_to(contact_point_groups_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "as commander" do
      before { sign_in commander_a }

      it "is forbidden" do
        expect {
          delete contact_point_group_path(cpg_a)
        }.not_to change(ContactPointGroup, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
