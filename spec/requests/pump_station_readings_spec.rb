require "rails_helper"

RSpec.describe "PumpStationReadings", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: org) }
  let(:commander)  { create(:user, :commander,    organization: org) }

  let!(:pump_station) { create(:pump_station) }
  let!(:meter) do
    create(:meter, :pump_station, pump_station: pump_station, organization: division)
  end
  let!(:period) { create(:monthly_period, year: 2026, month: 2) }

  describe "GET /pump_station_readings" do
    context "as admin_level1" do
      before { sign_in admin1 }

      it "renders the readings entry page" do
        get pump_station_readings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(pump_station.name)
        expect(response.body).to include(meter.name)
      end

      it "auto-inherits reading_start from previous period's reading_end" do
        prior_period = create(:monthly_period, year: 2026, month: 1)
        create(:meter_reading,
               meter: meter, monthly_period: prior_period,
               reading_start: 0, reading_end: 1234)

        get pump_station_readings_path(period_id: period.id)
        expect(response.body).to include("1234")
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        get pump_station_readings_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        get pump_station_readings_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as unauthenticated user" do
      it "redirects to login" do
        get pump_station_readings_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /pump_station_readings" do
    let(:save_params) do
      {
        period_id: period.id,
        readings: {
          meter.id.to_s => { reading_start: "1000", reading_end: "1500" }
        }
      }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "saves a new MeterReading" do
        expect {
          patch pump_station_readings_path, params: save_params
        }.to change(MeterReading, :count).by(1)

        reading = MeterReading.last
        expect(reading.meter).to eq(meter)
        expect(reading.monthly_period).to eq(period)
        expect(reading.reading_start).to eq(BigDecimal("1000"))
        expect(reading.reading_end).to eq(BigDecimal("1500"))
        expect(reading.consumption).to eq(BigDecimal("500"))
      end

      it "skips meters with both fields blank — does not create empty rows" do
        params = save_params.deep_merge(readings: {
          meter.id.to_s => { reading_start: "", reading_end: "" }
        })
        expect {
          patch pump_station_readings_path, params: params
        }.not_to change(MeterReading, :count)
      end

      it "rejects when end < start" do
        params = save_params.deep_merge(readings: {
          meter.id.to_s => { reading_start: "1500", reading_end: "1000" }
        })
        expect {
          patch pump_station_readings_path, params: params
        }.not_to change(MeterReading, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "ignores meter ids that are not pump-station meters" do
        cp = create(:contact_point, organization: org)
        normal_meter = create(:meter, :normal, contact_point: cp, organization: org)
        params = {
          period_id: period.id,
          readings: {
            normal_meter.id.to_s => { reading_start: "0", reading_end: "100" }
          }
        }
        expect {
          patch pump_station_readings_path, params: params
        }.not_to change(MeterReading, :count)
      end

      it "blocks save when period is locked" do
        period.update!(locked: true, locked_at: Time.current, locked_by: admin1)
        expect {
          patch pump_station_readings_path, params: save_params
        }.not_to change(MeterReading, :count)
        expect(response).to redirect_to(pump_station_readings_path(period_id: period.id))
        follow_redirect!
        expect(response.body).to include(I18n.t("flash.pump_station_readings.period_locked"))
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        patch pump_station_readings_path, params: save_params
        expect(response).to redirect_to(root_path)
        expect(MeterReading.count).to eq(0)
      end
    end
  end
end
