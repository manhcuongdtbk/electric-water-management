require "rails_helper"

RSpec.describe "WorkGroups", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:unit)     { create(:organization, level: :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: unit) }
  let(:commander)  { create(:user, :commander,    organization: unit) }
  let(:tech_user)  { create(:user, :tech,         organization: division) }

  describe "GET /work_groups" do
    let!(:wg) { create(:work_group, owner_organization: division, name: "Tho xay") }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the list" do
        get work_groups_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tho xay")
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get work_groups_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        get work_groups_path
        expect(response).to redirect_to(root_path)
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
    before { division }

    let(:create_params) do
      { work_group: { name: "Tram che bien", personnel_count: "18", position: "1", notes: "Note" } }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a work group and auto-assigns the division as owner" do
        expect {
          post work_groups_path, params: create_params
        }.to change(WorkGroup, :count).by(1)

        wg = WorkGroup.last
        expect(wg.name).to eq("Tram che bien")
        expect(wg.personnel_count).to eq(18)
        expect(wg.owner_organization).to eq(division)
        expect(response).to redirect_to(work_groups_path)
      end

      it "rejects negative personnel count" do
        params = create_params.deep_merge(work_group: { personnel_count: "-5" })
        post work_groups_path, params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(WorkGroup.count).to eq(0)
      end

      it "rejects blank name" do
        params = create_params.deep_merge(work_group: { name: "" })
        post work_groups_path, params: params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        post work_groups_path, params: create_params
        expect(response).to redirect_to(root_path)
        expect(WorkGroup.count).to eq(0)
      end
    end
  end

  describe "PATCH /work_groups/:id" do
    let!(:wg) { create(:work_group, owner_organization: division, personnel_count: 10) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates the personnel count" do
        patch work_group_path(wg), params: { work_group: { personnel_count: "20" } }
        expect(wg.reload.personnel_count).to eq(20)
        expect(response).to redirect_to(work_groups_path)
      end

      it "records a paper_trail version" do
        expect {
          patch work_group_path(wg), params: { work_group: { personnel_count: "20" } }
        }.to change { wg.versions.count }.by(1)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        patch work_group_path(wg), params: { work_group: { personnel_count: "20" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /work_groups/:id" do
    let!(:wg) { create(:work_group, owner_organization: division) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "destroys the work group when there are no assignments" do
        expect {
          delete work_group_path(wg)
        }.to change(WorkGroup, :count).by(-1)
        expect(response).to redirect_to(work_groups_path)
      end

      it "refuses when assignments exist (restrict_with_error)" do
        create(:pump_station_assignment, assignable: wg)
        expect {
          delete work_group_path(wg)
        }.not_to change(WorkGroup, :count)
        expect(flash[:alert]).to be_present
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        delete work_group_path(wg)
        expect(response).to redirect_to(root_path)
        expect(WorkGroup.exists?(wg.id)).to be true
      end
    end
  end
end
