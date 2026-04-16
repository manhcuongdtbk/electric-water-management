require "rails_helper"

RSpec.describe "MeterReadings", type: :request do
  let(:division)  { create(:organization, :division) }
  let(:org_a)     { create(:organization, :unit, parent: division) }
  let(:org_b)     { create(:organization, :unit, parent: division) }

  let(:admin1)        { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a)  { create(:user, :admin_unit,   organization: org_a) }
  let(:admin_unit_b)  { create(:user, :admin_unit,   organization: org_b) }
  let(:commander)     { create(:user, :commander,    organization: org_a) }
  let(:tech_user)     { create(:user, :tech,          organization: org_a) }

  let!(:period)      { create(:monthly_period, year: 2026, month: 2) }
  let!(:prev_period) { create(:monthly_period, year: 2026, month: 1) }

  let!(:cp_a) { create(:contact_point, organization: org_a) }
  let!(:meter_a1) { create(:meter, :normal, organization: org_a, contact_point: cp_a) }
  let!(:meter_a2) { create(:meter, :public_meter, organization: org_a, contact_point: nil) }

  # ---------------------------------------------------------------------------
  # GET /meter_readings
  # ---------------------------------------------------------------------------
  describe "GET /meter_readings" do
    context "as admin_unit" do
      it "returns ok" do
        sign_in admin_unit_a
        get meter_readings_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "shows meters of own org" do
        sign_in admin_unit_a
        get meter_readings_path(period_id: period.id)
        expect(response.body).to include(meter_a1.name)
      end

      it "does not show meters from another org" do
        other_meter = create(:meter, organization: org_b)
        sign_in admin_unit_a
        get meter_readings_path(period_id: period.id)
        expect(response.body).not_to include(other_meter.name)
      end
    end

    context "as admin_level1" do
      it "returns ok with org selector" do
        sign_in admin1
        get meter_readings_path(period_id: period.id, org_id: org_a.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(org_a.name)
      end

      it "can switch to another org via org_id" do
        sign_in admin1
        get meter_readings_path(period_id: period.id, org_id: org_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(org_b.name)
      end
    end

    context "as commander" do
      it "returns ok (read-only)" do
        sign_in commander
        get meter_readings_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "does not include input fields" do
        sign_in commander
        get meter_readings_path(period_id: period.id)
        expect(response.body).not_to include('name="readings[')
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        get meter_readings_path
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get meter_readings_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before { MonthlyPeriod.delete_all }

      it "renders ok showing no-period message" do
        sign_in admin_unit_a
        get meter_readings_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("meter_readings.no_period"))
      end
    end

    context "start reading inheritance" do
      it "pre-fills reading_start from previous period reading_end" do
        # Create previous period reading for meter_a1
        create(:meter_reading, meter: meter_a1, monthly_period: prev_period,
               reading_start: 1000, reading_end: 1500)

        sign_in admin_unit_a
        get meter_readings_path(period_id: period.id)

        # The inherited start value (1500) should appear as input default
        expect(response.body).to include("1500")
      end

      it "does not inherit when current period already has a reading" do
        # Existing reading for current period
        create(:meter_reading, meter: meter_a1, monthly_period: period,
               reading_start: 2000, reading_end: 2500)
        # Previous period
        create(:meter_reading, meter: meter_a1, monthly_period: prev_period,
               reading_start: 1000, reading_end: 1500)

        sign_in admin_unit_a
        get meter_readings_path(period_id: period.id)

        # Should show current reading start (2000), not inherited (1500)
        expect(response.body).to include("2000")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /meter_readings
  # ---------------------------------------------------------------------------
  describe "PATCH /meter_readings" do
    let(:valid_params) do
      {
        period_id: period.id,
        readings: {
          meter_a1.id.to_s => { reading_start: "1000.00", reading_end: "1250.00" }
        }
      }
    end

    context "as admin_unit" do
      it "creates meter readings and redirects" do
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: valid_params
        }.to change(MeterReading, :count).by(1)

        reading = MeterReading.find_by(meter: meter_a1, monthly_period: period)
        expect(reading.reading_start).to eq(BigDecimal("1000.00"))
        expect(reading.reading_end).to eq(BigDecimal("1250.00"))
        expect(reading.consumption).to eq(BigDecimal("250.00"))

        expect(response).to redirect_to(meter_readings_path(period_id: period.id, org_id: nil))
        expect(flash[:notice]).to eq(I18n.t("flash.meter_readings.saved"))
      end

      it "updates an existing meter reading" do
        existing = create(:meter_reading, meter: meter_a1, monthly_period: period,
                          reading_start: 100, reading_end: 200)
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: valid_params
        }.not_to change(MeterReading, :count)

        expect(existing.reload.reading_end).to eq(BigDecimal("1250.00"))
        expect(existing.reload.consumption).to eq(BigDecimal("250.00"))
      end

      it "auto-calculates consumption = reading_end - reading_start" do
        sign_in admin_unit_a
        patch meter_readings_path, params: valid_params

        reading = MeterReading.find_by(meter: meter_a1, monthly_period: period)
        expect(reading.consumption).to eq(reading.reading_end - reading.reading_start)
      end

      it "cannot save readings for another org's meters" do
        other_meter = create(:meter, organization: org_b)
        sign_in admin_unit_a
        patch meter_readings_path, params: {
          period_id: period.id,
          readings: { other_meter.id.to_s => { reading_start: "0", reading_end: "999" } }
        }

        # Reading should not have been created for other_meter
        expect(MeterReading.find_by(meter: other_meter, monthly_period: period)).to be_nil
      end

      it "rolls back all changes when any reading fails validation" do
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: {
            period_id: period.id,
            readings: {
              meter_a1.id.to_s => { reading_start: "500", reading_end: "300" } # end < start → invalid
            }
          }
        }.not_to change(MeterReading, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rolls back all even when only one of multiple readings is invalid" do
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: {
            period_id: period.id,
            readings: {
              meter_a1.id.to_s => { reading_start: "100", reading_end: "200" },  # valid
              meter_a2.id.to_s => { reading_start: "500", reading_end: "300" }   # invalid
            }
          }
        }.not_to change(MeterReading, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "cannot save readings for a locked period" do
        period.lock!(admin1)
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: valid_params
        }.not_to change(MeterReading, :count)

        expect(response).to redirect_to(meter_readings_path(period_id: period.id, org_id: nil))
        expect(flash[:alert]).to eq(I18n.t("meter_readings.period_locked"))
      end

      it "re-renders show with errors when validation fails" do
        sign_in admin_unit_a
        patch meter_readings_path, params: {
          period_id: period.id,
          readings: {
            meter_a1.id.to_s => { reading_start: "500", reading_end: "300" }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("meter_readings.errors_header"))
      end
    end

    context "as admin_level1" do
      it "can save readings for any org via org_id" do
        sign_in admin1
        expect {
          patch meter_readings_path, params: valid_params.merge(org_id: org_a.id)
        }.to change(MeterReading, :count).by(1)

        expect(response).to redirect_to(
          meter_readings_path(period_id: period.id, org_id: org_a.id.to_s)
        )
      end
    end

    context "as commander" do
      it "redirects — no write access" do
        sign_in commander
        patch meter_readings_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        patch meter_readings_path, params: valid_params
        expect(response).to redirect_to(users_path)
      end
    end

    context "batch save with multiple meters" do
      it "saves readings for multiple meters in one request" do
        sign_in admin_unit_a
        expect {
          patch meter_readings_path, params: {
            period_id: period.id,
            readings: {
              meter_a1.id.to_s => { reading_start: "1000", reading_end: "1100" },
              meter_a2.id.to_s => { reading_start: "500",  reading_end: "600"  }
            }
          }
        }.to change(MeterReading, :count).by(2)
      end
    end
  end
end
