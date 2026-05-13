require "rails_helper"

RSpec.describe "PumpStationMeters", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: org) }

  let!(:pump_station) { create(:pump_station) }
  let!(:initial_meter) do
    create(:meter, :pump_station, pump_station: pump_station, organization: division)
  end

  describe "GET /pump_stations/:pump_station_id/meters/new" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the new form" do
        get new_pump_station_meter_path(pump_station)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get new_pump_station_meter_path(pump_station)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /pump_stations/:pump_station_id/meters" do
    let(:valid_params) do
      {
        meter: {
          name: "CT thứ hai",
          serial_number: "SN-002",
          notes: "Đầu ra",
          position: "1"
        }
      }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a pump-station meter scoped to parent" do
        expect {
          post pump_station_meters_path(pump_station), params: valid_params
        }.to change(Meter, :count).by(1)

        m = Meter.last
        expect(m.name).to eq("CT thứ hai")
        expect(m.meter_type).to eq("pump_station")
        expect(m.contact_point_id).to be_nil
        expect(m.pump_station).to eq(pump_station)
        expect(m.organization).to eq(division)
        expect(response).to redirect_to(pump_stations_path)
      end

      it "ignores user-supplied meter_type and forces pump_station" do
        params = valid_params.deep_merge(meter: { meter_type: "normal" })
        post pump_station_meters_path(pump_station), params: params
        expect(Meter.last.meter_type).to eq("pump_station")
      end

      it "rejects blank name" do
        params = valid_params.deep_merge(meter: { name: "" })
        expect {
          post pump_station_meters_path(pump_station), params: params
        }.not_to change(Meter, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        post pump_station_meters_path(pump_station), params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /pump_stations/:pump_station_id/meters/:id" do
    let(:params) { { meter: { name: "Renamed", notes: "New notes" } } }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates name and notes" do
        patch pump_station_meter_path(pump_station, initial_meter), params: params
        initial_meter.reload
        expect(initial_meter.name).to eq("Renamed")
        expect(initial_meter.notes).to eq("New notes")
        expect(response).to redirect_to(pump_stations_path)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        patch pump_station_meter_path(pump_station, initial_meter), params: params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /pump_stations/:pump_station_id/meters/:id" do
    context "as admin_level1" do
      before { sign_in admin1 }

      context "when meter is the last meter of pump station" do
        it "is rejected with cannot_destroy_last_meter flash" do
          expect(pump_station.meters.count).to eq(1)
          expect {
            delete pump_station_meter_path(pump_station, initial_meter)
          }.not_to change(Meter, :count)
          expect(response).to redirect_to(pump_stations_path)
          follow_redirect!
          expect(response.body).to include(
            I18n.t("flash.pump_station_meters.cannot_destroy_last_meter")
          )
        end
      end

      context "when meter is not the last and has no readings" do
        let!(:second_meter) do
          create(:meter, :pump_station,
                 pump_station: pump_station,
                 organization: division,
                 name: "CT phụ")
        end

        it "destroys the meter" do
          expect {
            delete pump_station_meter_path(pump_station, second_meter)
          }.to change(Meter, :count).by(-1)
          expect(response).to redirect_to(pump_stations_path)
          follow_redirect!
          expect(response.body).to include(I18n.t("flash.pump_station_meters.destroyed"))
        end
      end

      context "when meter has readings" do
        let!(:second_meter) do
          create(:meter, :pump_station,
                 pump_station: pump_station,
                 organization: division,
                 name: "CT phụ")
        end

        before do
          period = create(:monthly_period)
          create(:meter_reading,
                 meter: second_meter,
                 monthly_period: period,
                 reading_start: 100, reading_end: 200)
        end

        it "is rejected with cannot_destroy_with_readings flash" do
          expect {
            delete pump_station_meter_path(pump_station, second_meter)
          }.not_to change(Meter, :count)
          follow_redirect!
          expect(response.body).to include(
            I18n.t("flash.pump_station_meters.cannot_destroy_with_readings")
          )
        end
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        delete pump_station_meter_path(pump_station, initial_meter)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "zone-manager cross-zone access denial" do
    let(:zone_manager_org) { create(:organization, level: :unit, parent: division) }
    let(:zone_manager)     { create(:user, :admin_unit, organization: zone_manager_org) }
    let(:managed_zone)     { create(:zone, manager_organization_id: zone_manager_org.id) }
    let(:foreign_zone)     { create(:zone) }
    let!(:foreign_ps)      { create(:pump_station, zone: foreign_zone) }

    before do
      managed_zone
      sign_in zone_manager
    end

    it "denies new meter form on foreign-zone pump station → 404" do
      get new_pump_station_meter_path(foreign_ps)
      expect(response).to have_http_status(:not_found)
    end

    it "denies POST meter on foreign-zone pump station → 404" do
      post pump_station_meters_path(foreign_ps), params: { meter: { name: "CT01" } }
      expect(response).to have_http_status(:not_found)
    end
  end
end
