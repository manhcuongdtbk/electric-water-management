require "rails_helper"

RSpec.describe "PumpStationAssignments", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }

  let(:admin1)        { create(:user, :admin_level1, organization: division) }
  let(:admin_unit)    { create(:user, :admin_unit,   organization: org) }
  let(:commander)     { create(:user, :commander,    organization: org) }
  let(:tech_user)     { create(:user, :tech,         organization: division) }

  let!(:pump_station) { create(:pump_station) }
  let!(:assignment)   { create(:pump_station_assignment, pump_station: pump_station, organization: org) }

  describe "GET /pump_stations" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the list" do
        get pump_stations_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(pump_station.name)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get pump_stations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        get pump_stations_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as unauthenticated user" do
      it "redirects to login" do
        get pump_stations_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /pump_stations/:pump_station_id/assignments/:id/edit" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the edit form" do
        get edit_pump_station_assignment_path(pump_station, assignment)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get edit_pump_station_assignment_path(pump_station, assignment)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /pump_stations/:pump_station_id/assignments/:id" do
    let(:params) { { pump_station_assignment: { fixed_pump_percentage: "30" } } }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates fixed_pump_percentage" do
        patch pump_station_assignment_path(pump_station, assignment), params: params
        expect(assignment.reload.fixed_pump_percentage).to eq(BigDecimal("30"))
        expect(response).to redirect_to(pump_stations_path)
      end

      it "accepts blank value (variable)" do
        assignment.update!(fixed_pump_percentage: 30)
        patch pump_station_assignment_path(pump_station, assignment),
              params: { pump_station_assignment: { fixed_pump_percentage: "" } }
        expect(assignment.reload.fixed_pump_percentage).to be_nil
      end

      it "rejects out-of-range values" do
        patch pump_station_assignment_path(pump_station, assignment),
              params: { pump_station_assignment: { fixed_pump_percentage: "150" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assignment.reload.fixed_pump_percentage).to be_nil
      end

      it "creates a paper_trail version on update" do
        expect {
          patch pump_station_assignment_path(pump_station, assignment), params: params
        }.to change { assignment.versions.count }.by(1)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        patch pump_station_assignment_path(pump_station, assignment), params: params
        expect(response).to redirect_to(root_path)
        expect(assignment.reload.fixed_pump_percentage).to be_nil
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        patch pump_station_assignment_path(pump_station, assignment), params: params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /pump_stations/:pump_station_id/assignments/new" do
    let(:other_unit) { create(:organization, level: :unit, parent: division, zone: pump_station.zone) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders new form with available units" do
        other_unit
        get new_pump_station_assignment_path(pump_station)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(other_unit.name)
        expect(response.body).not_to include(">#{org.name}<") # already assigned
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get new_pump_station_assignment_path(pump_station)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /pump_stations/:pump_station_id/assignments" do
    let(:other_unit) { create(:organization, level: :unit, parent: division) }
    let(:create_params) do
      {
        pump_station_assignment: {
          assignable_type: "Organization",
          assignable_id: other_unit.id,
          fixed_pump_percentage: "25"
        }
      }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates an Organization assignment" do
        other_unit
        expect {
          post pump_station_assignments_path(pump_station), params: create_params
        }.to change(PumpStationAssignment, :count).by(1)

        new_assignment = PumpStationAssignment.last
        expect(new_assignment.assignable).to eq(other_unit)
        expect(new_assignment.fixed_pump_percentage).to eq(BigDecimal("25"))
        expect(response).to redirect_to(pump_stations_path)
      end

      it "creates a ContactPoint assignment (đầu mối đặc biệt)" do
        cp = create(:contact_point, organization: other_unit)
        params = create_params.deep_merge(pump_station_assignment: {
                                            assignable_type: "ContactPoint",
                                            assignable_id: cp.id,
                                            fixed_pump_percentage: "30"
                                          })
        expect {
          post pump_station_assignments_path(pump_station), params: params
        }.to change(PumpStationAssignment, :count).by(1)
        expect(PumpStationAssignment.last.assignable).to eq(cp)
      end

      it "creates a WorkGroup assignment (nhóm công tác)" do
        wg = create(:work_group, owner_organization: org)
        params = create_params.deep_merge(pump_station_assignment: {
                                            assignable_type: "WorkGroup",
                                            assignable_id: wg.id,
                                            fixed_pump_percentage: ""
                                          })
        expect {
          post pump_station_assignments_path(pump_station), params: params
        }.to change(PumpStationAssignment, :count).by(1)
        expect(PumpStationAssignment.last.assignable).to eq(wg)
      end

      it "creates a ContactPointGroup assignment (nhóm đầu mối)" do
        cpg = create(:contact_point_group, organization: org)
        params = create_params.deep_merge(pump_station_assignment: {
                                            assignable_type: "ContactPointGroup",
                                            assignable_id: cpg.id,
                                            fixed_pump_percentage: ""
                                          })
        expect {
          post pump_station_assignments_path(pump_station), params: params
        }.to change(PumpStationAssignment, :count).by(1)
        expect(PumpStationAssignment.last.assignable).to eq(cpg)
      end

      it "creates with nil percentage (variable)" do
        other_unit
        params = create_params.deep_merge(pump_station_assignment: { fixed_pump_percentage: "" })
        post pump_station_assignments_path(pump_station), params: params
        expect(PumpStationAssignment.last.fixed_pump_percentage).to be_nil
      end

      it "rejects duplicate (pump_station_id, assignable_type, assignable_id)" do
        params = create_params.deep_merge(pump_station_assignment: { assignable_id: org.id })
        expect {
          post pump_station_assignments_path(pump_station), params: params
        }.not_to change(PumpStationAssignment, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects out-of-range percentage" do
        other_unit
        params = create_params.deep_merge(pump_station_assignment: { fixed_pump_percentage: "150" })
        expect {
          post pump_station_assignments_path(pump_station), params: params
        }.not_to change(PumpStationAssignment, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        other_unit
        post pump_station_assignments_path(pump_station), params: create_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /pump_stations/:pump_station_id/assignments/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "destroys the assignment" do
        expect {
          delete pump_station_assignment_path(pump_station, assignment)
        }.to change(PumpStationAssignment, :count).by(-1)
        expect(response).to redirect_to(pump_stations_path)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        delete pump_station_assignment_path(pump_station, assignment)
        expect(response).to redirect_to(root_path)
        expect(PumpStationAssignment.exists?(assignment.id)).to be true
      end
    end
  end

  describe "zone-manager cross-zone access denial" do
    let(:zone_manager_org) { create(:organization, level: :unit, parent: division) }
    let(:zone_manager)     { create(:user, :admin_unit, organization: zone_manager_org) }
    let(:managed_zone)     { create(:zone, manager_organization_id: zone_manager_org.id) }
    let(:foreign_zone)     { create(:zone) }
    let!(:foreign_ps)      { create(:pump_station, zone: foreign_zone) }
    let(:foreign_org)      { create(:organization, level: :unit, parent: division, zone: foreign_zone) }

    before do
      managed_zone
      sign_in zone_manager
    end

    it "denies POST assignment on foreign-zone pump station → 404" do
      post pump_station_assignments_path(foreign_ps),
           params: { pump_station_assignment: {
             assignable_type: "Organization", assignable_id: foreign_org.id
           } }
      expect(response).to have_http_status(:not_found)
    end

    it "available_assignables only shows zone-scoped orgs for own pump station" do
      foreign_org
      own_ps = create(:pump_station, zone: managed_zone)
      get new_pump_station_assignment_path(own_ps)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(zone_manager_org.name)
      expect(response.body).not_to include(foreign_org.name)
    end
  end
end
