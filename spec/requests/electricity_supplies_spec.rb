require "rails_helper"

RSpec.describe "ElectricitySupplies", type: :request do
  let(:division)   { create(:organization, :division) }
  let(:main_meter_a) { create(:main_meter, name: "Zone A") }
  let(:main_meter_b) { create(:main_meter, name: "Zone B") }
  let(:org_a)      { create(:organization, :unit, parent: division, zone: main_meter_a.zone) }
  let(:org_b)      { create(:organization, :unit, parent: division, zone: main_meter_b.zone) }
  let(:orphan_org) { create(:organization, :unit, parent: division, zone: nil) }

  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let(:commander)    { create(:user, :commander,    organization: org_a) }
  let(:orphan_admin) { create(:user, :admin_unit,   organization: orphan_org) }
  let(:tech_user)    { create(:user, :tech,          organization: org_a) }

  let!(:period)  { create(:monthly_period, year: 2026, month: 2) }
  let!(:period2) { create(:monthly_period, year: 2026, month: 1) }

  # ---------------------------------------------------------------------------
  # SHOW
  # ---------------------------------------------------------------------------
  describe "GET /electricity_supply" do
    context "as admin_unit" do
      it "returns ok and shows their zone read-only" do
        create(:main_meter_reading, main_meter: main_meter_a, monthly_period: period,
               electricity_supply_kw: 11_111)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(main_meter_a.name)
        expect(response.body).to include("11.111,00")
      end

      it "does not render the submit form (read-only)" do
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response.body).not_to include(I18n.t("electricity_supplies.section_input.submit"))
      end

      # Regression: admin_unit cannot peek at a different zone by passing main_meter_id.
      it "ignores params[:main_meter_id] and uses own zone" do
        create(:main_meter_reading, main_meter: main_meter_a, monthly_period: period,
               electricity_supply_kw: 11_111)
        create(:main_meter_reading, main_meter: main_meter_b, monthly_period: period,
               electricity_supply_kw: 22_222)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id, main_meter_id: main_meter_b.id)
        expect(response.body).to include("11.111,00")
        expect(response.body).not_to include("22.222,00")
      end

      it "shows no-main-meter notice when org has no main_meter" do
        sign_in orphan_admin
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("electricity_supplies.no_main_meter"))
      end
    end

    context "as admin_level1" do
      it "returns ok with main meter selector" do
        main_meter_a
        sign_in admin1
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("electricity_supplies.main_meter_select"))
      end

      it "can view a specific zone via main_meter_id param" do
        main_meter_b
        sign_in admin1
        get electricity_supply_path(period_id: period.id, main_meter_id: main_meter_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(main_meter_b.name)
      end
    end

    context "as commander" do
      it "returns ok (read-only)" do
        sign_in commander
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("electricity_supplies.section_input.submit"))
      end
    end

    context "as tech" do
      it "is silently redirected to user management" do
        sign_in tech_user
        get electricity_supply_path
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to be_blank
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get electricity_supply_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before { MonthlyPeriod.delete_all }

      it "renders ok showing no-period message" do
        sign_in admin_unit_a
        get electricity_supply_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "history display" do
      it "shows past periods' entries for own zone" do
        create(:main_meter_reading, main_meter: main_meter_a, monthly_period: period2,
               electricity_supply_kw: 3500)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response.body).to include("3.500,00")
      end

      it "excludes the currently selected period from history" do
        create(:main_meter_reading, main_meter: main_meter_a, monthly_period: period,
               electricity_supply_kw: 9999)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response.body).to include(I18n.t("electricity_supplies.section_history.empty"))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------
  describe "PATCH /electricity_supply" do
    let(:valid_params) do
      { period_id: period.id, main_meter_id: main_meter_a.id,
        electricity_supply: { electricity_supply_kw: "12345.67" } }
    end

    context "as admin_level1" do
      it "creates main_meter_reading for the selected zone and redirects" do
        sign_in admin1
        expect {
          patch electricity_supply_path, params: valid_params
        }.to change(MainMeterReading, :count).by(1)

        reading = MainMeterReading.find_by(main_meter: main_meter_a, monthly_period: period)
        expect(reading.electricity_supply_kw).to eq(BigDecimal("12345.67"))
        expect(response).to redirect_to(
          electricity_supply_path(period_id: period.id, main_meter_id: main_meter_a.id.to_s)
        )
      end

      it "updates existing main_meter_reading" do
        existing = create(:main_meter_reading, main_meter: main_meter_a, monthly_period: period,
                          electricity_supply_kw: 1000)
        sign_in admin1
        expect {
          patch electricity_supply_path, params: valid_params
        }.not_to change(MainMeterReading, :count)

        expect(existing.reload.electricity_supply_kw).to eq(BigDecimal("12345.67"))
      end

      it "defaults to first main_meter when no main_meter_id given, and preserves it" do
        main_meter_a
        main_meter_b
        sign_in admin1
        # No main_meter_id — controller defaults to MainMeter.ordered.first.
        patch electricity_supply_path,
              params: { period_id: period.id, electricity_supply: { electricity_supply_kw: "555" } }

        first_meter = MainMeter.ordered.first
        reading = MainMeterReading.find_by(main_meter: first_meter, monthly_period: period)
        expect(reading.electricity_supply_kw).to eq(BigDecimal("555"))
        expect(response).to redirect_to(
          electricity_supply_path(period_id: period.id, main_meter_id: first_meter.id.to_s)
        )
      end
    end

    context "as admin_unit" do
      it "is denied — cannot write electricity supply" do
        sign_in admin_unit_a
        patch electricity_supply_path, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
        expect(MainMeterReading.find_by(main_meter: main_meter_a, monthly_period: period)).to be_nil
      end

      it "is denied even when targeting their own zone explicitly" do
        # Even with their own main_meter_id, admin_unit lacks :update on MainMeterReading.
        sign_in admin_unit_a
        patch electricity_supply_path,
              params: valid_params.merge(main_meter_id: main_meter_a.id)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end

      it "redirects to no-main-meter alert when org has no zone" do
        sign_in orphan_admin
        patch electricity_supply_path,
              params: { period_id: period.id,
                        electricity_supply: { electricity_supply_kw: "100" } }
        expect(response).to redirect_to(electricity_supply_path)
        expect(flash[:alert]).to eq(I18n.t("electricity_supplies.no_main_meter"))
      end
    end

    context "as commander" do
      it "redirects — no write access" do
        sign_in commander
        patch electricity_supply_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        patch electricity_supply_path, params: valid_params
        expect(response).to redirect_to(users_path)
      end
    end
  end
end
