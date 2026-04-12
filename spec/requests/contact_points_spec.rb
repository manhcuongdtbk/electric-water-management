require "rails_helper"

RSpec.describe "ContactPoints", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org_a) { create(:organization, level: :unit, parent: division) }
  let(:org_b) { create(:organization, level: :unit, parent: division) }

  let(:admin1) { create(:user, role: :admin_level1, organization: org_a) }
  let(:admin_unit_a) { create(:user, role: :admin_unit, organization: org_a) }
  let(:admin_unit_b) { create(:user, role: :admin_unit, organization: org_b) }
  let(:commander) { create(:user, role: :commander, organization: org_a) }
  let(:tech_user) { create(:user, role: :tech, organization: org_a) }

  let!(:cp_a) { create(:contact_point, organization: org_a) }
  let!(:cp_b) { create(:contact_point, organization: org_b) }

  describe "GET /contact_points" do
    context "as admin_level1" do
      it "shows all contact points" do
        sign_in admin1
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name, cp_b.name)
      end
    end

    context "as admin_unit" do
      it "shows only own organization's contact points" do
        sign_in admin_unit_a
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as commander" do
      it "shows only own organization's contact points" do
        sign_in commander
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as tech" do
      it "shows only own organization's contact points (read-only)" do
        sign_in tech_user
        get contact_points_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get contact_points_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /contact_points/:id" do
    context "as admin_unit" do
      it "shows own contact point" do
        sign_in admin_unit_a
        get contact_point_path(cp_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
      end

      it "cannot access another organization's contact point" do
        sign_in admin_unit_a
        get contact_point_path(cp_b)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as admin_level1" do
      it "can access any contact point" do
        sign_in admin1
        get contact_point_path(cp_b)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /contact_points/new" do
    it "allows admin_unit" do
      sign_in admin_unit_a
      get new_contact_point_path
      expect(response).to have_http_status(:ok)
    end

    it "allows admin_level1" do
      sign_in admin1
      get new_contact_point_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects commander" do
      sign_in commander
      get new_contact_point_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects tech" do
      sign_in tech_user
      get new_contact_point_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /contact_points" do
    let(:valid_params) { { contact_point: { name: "Ban Tác huấn", position: 1 } } }

    context "as admin_unit" do
      it "creates a contact point in own organization" do
        sign_in admin_unit_a
        expect {
          post contact_points_path, params: valid_params
        }.to change(ContactPoint, :count).by(1)

        expect(ContactPoint.last.organization).to eq(org_a)
        expect(response).to redirect_to(contact_points_path)
      end

      it "re-renders form on invalid data" do
        sign_in admin_unit_a
        post contact_points_path, params: { contact_point: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_level1" do
      it "creates a contact point for a specific organization" do
        sign_in admin1
        expect {
          post contact_points_path, params: {
            contact_point: { name: "Ban Quân lực", position: 2, organization_id: org_b.id }
          }
        }.to change(ContactPoint, :count).by(1)

        expect(ContactPoint.last.organization).to eq(org_b)
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        post contact_points_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /contact_points/:id" do
    context "as admin_unit" do
      it "updates own contact point" do
        sign_in admin_unit_a
        patch contact_point_path(cp_a), params: { contact_point: { name: "Ban Tác chiến" } }
        expect(response).to redirect_to(contact_points_path)
        expect(cp_a.reload.name).to eq("Ban Tác chiến")
      end

      it "cannot update another org's contact point" do
        sign_in admin_unit_a
        patch contact_point_path(cp_b), params: { contact_point: { name: "Hacked" } }
        expect(response).to have_http_status(:not_found)
        expect(cp_b.reload.name).not_to eq("Hacked")
      end
    end
  end

  describe "DELETE /contact_points/:id" do
    context "as admin_unit" do
      it "destroys own contact point" do
        sign_in admin_unit_a
        expect {
          delete contact_point_path(cp_a)
        }.to change(ContactPoint, :count).by(-1)
        expect(response).to redirect_to(contact_points_path)
      end

      it "cannot destroy another org's contact point" do
        sign_in admin_unit_a
        delete contact_point_path(cp_b)
        expect(response).to have_http_status(:not_found)
        expect { cp_b.reload }.not_to raise_error
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        expect {
          delete contact_point_path(cp_a)
        }.not_to change(ContactPoint, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
