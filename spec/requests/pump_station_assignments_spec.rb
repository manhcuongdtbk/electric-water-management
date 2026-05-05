require "rails_helper"

RSpec.describe "PumpStationAssignments", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }

  let(:admin1)        { create(:user, :admin_level1, organization: division) }
  let(:admin_unit)    { create(:user, :admin_unit,   organization: org) }
  let(:commander)     { create(:user, :commander,    organization: org) }
  let(:tech_user)     { create(:user, :tech,         organization: division) }

  let!(:pump_station) { create(:pump_station, organization: division) }
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
end
