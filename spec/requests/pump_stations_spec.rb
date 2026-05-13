require "rails_helper"

RSpec.describe "PumpStations", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: org) }
  let(:commander)  { create(:user, :commander,    organization: org) }
  let(:tech_user)  { create(:user, :tech,         organization: division) }

  describe "GET /pump_stations/new" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the new form" do
        get new_pump_station_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get new_pump_station_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        get new_pump_station_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "is forbidden" do
        get new_pump_station_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "as unauthenticated user" do
      it "redirects to login" do
        get new_pump_station_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /pump_stations" do
    let!(:zone) { create(:zone, name: "Khu vực bơm A") }
    let(:valid_params) do
      {
        pump_station: {
          name: "Trạm bơm A",
          zone_id: zone.id,
          first_meter_name: "CT01 đầu vào",
          first_meter_serial_number: "SN-A001"
        }
      }
    end

    context "as admin_level1" do
      before do
        division
        sign_in admin1
      end

      it "creates pump station and first meter atomically" do
        expect {
          post pump_stations_path, params: valid_params
        }.to change(PumpStation, :count).by(1)
          .and change(Meter, :count).by(1)

        ps = PumpStation.last
        expect(ps.name).to eq("Trạm bơm A")
        expect(ps.zone).to eq(zone)
        expect(ps.meters.count).to eq(1)
        meter = ps.meters.first
        expect(meter.name).to eq("CT01 đầu vào")
        expect(meter.serial_number).to eq("SN-A001")
        expect(meter.meter_type).to eq("pump_station")
        expect(meter.contact_point_id).to be_nil
        expect(meter.organization).to eq(division)
        expect(response).to redirect_to(pump_stations_path)
      end

      it "accepts blank serial number" do
        params = valid_params.deep_merge(pump_station: { first_meter_serial_number: "" })
        expect {
          post pump_stations_path, params: params
        }.to change(PumpStation, :count).by(1)
        expect(PumpStation.last.meters.first.serial_number).to be_nil
      end

      it "rejects when pump station name is blank" do
        params = valid_params.deep_merge(pump_station: { name: "" })
        expect {
          post pump_stations_path, params: params
        }.not_to change(PumpStation, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects when first meter name is blank — neither persisted" do
        division
        params = valid_params.deep_merge(pump_station: { first_meter_name: "" })
        expect {
          post pump_stations_path, params: params
        }.to change(PumpStation, :count).by(0)
          .and change(Meter, :count).by(0)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        post pump_stations_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(PumpStation.count).to eq(0)
      end
    end
  end

  describe "GET /pump_stations/:id/edit" do
    let!(:pump_station) { create(:pump_station) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the edit form" do
        get edit_pump_station_path(pump_station)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get edit_pump_station_path(pump_station)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /pump_stations/:id" do
    let!(:pump_station) { create(:pump_station, name: "Original") }
    let(:params) { { pump_station: { name: "Renamed" } } }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates the name" do
        patch pump_station_path(pump_station), params: params
        expect(pump_station.reload.name).to eq("Renamed")
        expect(response).to redirect_to(pump_stations_path)
      end

      it "rejects blank name" do
        patch pump_station_path(pump_station), params: { pump_station: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(pump_station.reload.name).to eq("Original")
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        patch pump_station_path(pump_station), params: params
        expect(response).to redirect_to(root_path)
        expect(pump_station.reload.name).to eq("Original")
      end
    end
  end

  describe "DELETE /pump_stations/:id" do
    let!(:pump_station) { create(:pump_station) }
    let!(:meter) do
      create(:meter, :pump_station,
             pump_station: pump_station,
             organization: division)
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      context "when pump station has no readings" do
        it "destroys pump station + cascades meters + assignments" do
          create(:pump_station_assignment, pump_station: pump_station, organization: org)

          expect {
            delete pump_station_path(pump_station)
          }.to change(PumpStation, :count).by(-1)
            .and change(Meter, :count).by(-1)
            .and change(PumpStationAssignment, :count).by(-1)

          expect(response).to redirect_to(pump_stations_path)
          follow_redirect!
          expect(response.body).to include(I18n.t("flash.pump_stations.destroyed"))
        end
      end

      context "when pump station has meter readings" do
        before do
          period = create(:monthly_period)
          create(:meter_reading,
                 meter: meter, monthly_period: period,
                 reading_start: 100, reading_end: 200)
        end

        it "is rejected with cannot_destroy_with_readings flash" do
          expect {
            delete pump_station_path(pump_station)
          }.not_to change(PumpStation, :count)

          expect(response).to redirect_to(pump_stations_path)
          follow_redirect!
          expect(response.body).to include(I18n.t("flash.pump_stations.cannot_destroy_with_readings"))
        end
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        delete pump_station_path(pump_station)
        expect(response).to redirect_to(root_path)
        expect(PumpStation.exists?(pump_station.id)).to be true
      end
    end
  end
end
