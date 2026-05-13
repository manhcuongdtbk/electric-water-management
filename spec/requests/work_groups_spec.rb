require "rails_helper"

RSpec.describe "WorkGroups", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:unit_a)   { create(:organization, level: :unit, parent: division) }
  let(:unit_b)   { create(:organization, level: :unit, parent: division) }

  let(:admin1)      { create(:user, :admin_level1, organization: division) }
  let(:admin_unit)  { create(:user, :admin_unit,   organization: unit_a) }
  let(:commander)   { create(:user, :commander,    organization: unit_a) }
  let(:tech_user)   { create(:user, :tech,         organization: division) }

  describe "GET /work_groups" do
    let!(:wg_a) { create(:work_group, owner_organization: unit_a, name: "Tho xay") }
    let!(:wg_b) { create(:work_group, owner_organization: unit_b, name: "Bep an") }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders work groups from all units" do
        get work_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tho xay")
        expect(response.body).to include("Bep an")
      end
    end

    context "as admin_unit of unit_a" do
      before { sign_in admin_unit }

      it "renders only own unit's work groups" do
        get work_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tho xay")
        expect(response.body).not_to include("Bep an")
      end
    end

    context "as commander of unit_a" do
      before { sign_in commander }

      it "renders only own unit's work groups" do
        get work_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tho xay")
        expect(response.body).not_to include("Bep an")
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "is forbidden (redirects to users)" do
        get work_groups_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "as unauthenticated user" do
      it "redirects to login" do
        get work_groups_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /work_groups" do
    let(:base_params) do
      { work_group: { name: "Tram che bien", personnel_count: "18", position: "1", notes: "Note" } }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a work group owned by the selected unit" do
        params = base_params.deep_merge(work_group: { owner_organization_id: unit_a.id.to_s })
        expect {
          post work_groups_path, params: params
        }.to change(WorkGroup, :count).by(1)

        wg = WorkGroup.last
        expect(wg.name).to eq("Tram che bien")
        expect(wg.personnel_count).to eq(18)
        expect(wg.owner_organization).to eq(unit_a)
        expect(response).to redirect_to(work_groups_path)
      end

      it "rejects when owner is not specified (nil owner fails validation)" do
        post work_groups_path, params: base_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(WorkGroup.count).to eq(0)
      end

      it "rejects negative personnel count" do
        params = base_params.deep_merge(work_group: { owner_organization_id: unit_a.id.to_s, personnel_count: "-5" })
        post work_groups_path, params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(WorkGroup.count).to eq(0)
      end
    end

    context "as admin_unit of unit_a" do
      before { sign_in admin_unit }

      it "creates a work group owned by own unit (owner forced server-side)" do
        expect {
          post work_groups_path, params: base_params
        }.to change(WorkGroup, :count).by(1)

        wg = WorkGroup.last
        expect(wg.owner_organization).to eq(unit_a)
        expect(response).to redirect_to(work_groups_path)
      end

      it "ignores any owner_organization_id in params" do
        params = base_params.deep_merge(work_group: { owner_organization_id: unit_b.id.to_s })
        post work_groups_path, params: params
        expect(WorkGroup.last.owner_organization).to eq(unit_a)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        post work_groups_path, params: base_params
        expect(response).to redirect_to(root_path)
        expect(WorkGroup.count).to eq(0)
      end
    end
  end

  describe "PATCH /work_groups/:id" do
    let!(:wg_a) { create(:work_group, owner_organization: unit_a, personnel_count: 10) }
    let!(:wg_b) { create(:work_group, owner_organization: unit_b, personnel_count: 10) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates any unit's work group" do
        patch work_group_path(wg_a), params: { work_group: { personnel_count: "20" } }
        expect(wg_a.reload.personnel_count).to eq(20)
        expect(response).to redirect_to(work_groups_path)
      end

      it "records a paper_trail version" do
        expect {
          patch work_group_path(wg_a), params: { work_group: { personnel_count: "20" } }
        }.to change { wg_a.versions.count }.by(1)
      end
    end

    context "as admin_unit of unit_a" do
      before { sign_in admin_unit }

      it "updates own unit's work group" do
        patch work_group_path(wg_a), params: { work_group: { personnel_count: "25" } }
        expect(wg_a.reload.personnel_count).to eq(25)
        expect(response).to redirect_to(work_groups_path)
      end

      it "cannot access another unit's work group" do
        patch work_group_path(wg_b), params: { work_group: { personnel_count: "25" } }
        expect(response).to have_http_status(:not_found)
        expect(wg_b.reload.personnel_count).to eq(10)
      end
    end

    context "as commander of unit_a" do
      before { sign_in commander }

      it "cannot update own unit's work group" do
        patch work_group_path(wg_a), params: { work_group: { personnel_count: "20" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /work_groups/:id" do
    let!(:wg_a) { create(:work_group, owner_organization: unit_a) }
    let!(:wg_b) { create(:work_group, owner_organization: unit_b) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "destroys any unit's work group when no assignments exist" do
        expect {
          delete work_group_path(wg_a)
        }.to change(WorkGroup, :count).by(-1)
        expect(response).to redirect_to(work_groups_path)
      end

      it "refuses when assignments exist (restrict_with_error)" do
        create(:pump_station_assignment, assignable: wg_a)
        expect {
          delete work_group_path(wg_a)
        }.not_to change(WorkGroup, :count)
        expect(flash[:alert]).to be_present
      end
    end

    context "as admin_unit of unit_a" do
      before { sign_in admin_unit }

      it "destroys own unit's work group" do
        expect {
          delete work_group_path(wg_a)
        }.to change(WorkGroup, :count).by(-1)
        expect(response).to redirect_to(work_groups_path)
      end

      it "cannot access another unit's work group" do
        delete work_group_path(wg_b)
        expect(response).to have_http_status(:not_found)
        expect(WorkGroup.exists?(wg_b.id)).to be true
      end
    end

    context "as commander of unit_a" do
      before { sign_in commander }

      it "cannot destroy own unit's work group" do
        delete work_group_path(wg_a)
        expect(response).to redirect_to(root_path)
        expect(WorkGroup.exists?(wg_a.id)).to be true
      end
    end
  end
end
