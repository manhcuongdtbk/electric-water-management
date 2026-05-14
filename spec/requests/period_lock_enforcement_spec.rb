require "rails_helper"

# Bug 1: enforce period lock across every controller that writes data tied to
# a MonthlyPeriod. Two patterns:
#   - period-scoped controllers use `block_write_if_period_locked` (checks @period)
#   - master-data controllers use `block_write_if_latest_period_locked`
#     (checks MonthlyPeriod.ordered.first — the latest known period)
RSpec.describe "Period lock enforcement", type: :request do
  let(:division)    { create(:organization, :division) }
  let(:zone)        { create(:zone) }
  let!(:main_meter) { create(:main_meter, zone: zone) }
  let(:org)         { create(:organization, :unit, parent: division, zone: zone) }
  let(:admin1)      { create(:user, :admin_level1, organization: division) }
  let(:admin_unit)  { create(:user, :admin_unit, organization: org) }

  let(:locked_message) { I18n.t("flash.period_locked") }

  # =========================================================================
  # Period-scoped controllers — block when @period is locked
  # =========================================================================
  describe "period-scoped writes" do
    let!(:locked_period)   { create(:monthly_period, :locked, year: 2026, month: 2) }
    let!(:unlocked_period) { create(:monthly_period, year: 2026, month: 1) }

    before { sign_in admin_unit }

    describe "PATCH /meter_readings" do
      let!(:cp)    { create(:contact_point, organization: org) }
      let!(:meter) { create(:meter, :normal, organization: org, contact_point: cp) }

      it "rejects update when period is locked" do
        patch meter_readings_path,
              params: { period_id: locked_period.id,
                        readings: { meter.id.to_s => { reading_start: "10", reading_end: "20" } } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(MeterReading.count).to eq(0)
      end

      it "allows update when period is unlocked" do
        patch meter_readings_path,
              params: { period_id: unlocked_period.id,
                        readings: { meter.id.to_s => { reading_start: "10", reading_end: "20" } } }
        expect(response).to redirect_to(meter_readings_path(period_id: unlocked_period.id))
        expect(MeterReading.count).to eq(1)
      end
    end

    describe "PATCH /contact_points/:id/personnel" do
      let!(:cp) { create(:contact_point, organization: org) }
      before { (1..7).each { |g| create(:rank_quota, :"rank#{g}") } }

      it "rejects update when period is locked" do
        patch contact_point_personnel_path(cp),
              params: { period_id: locked_period.id,
                        personnel: { rank1_count: 5 } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(Personnel.where(contact_point: cp, monthly_period: locked_period)).to be_empty
      end

      it "allows update when period is unlocked" do
        patch contact_point_personnel_path(cp),
              params: { period_id: unlocked_period.id,
                        personnel: { rank1_count: 5 } }
        expect(response).to redirect_to(
          contact_point_personnel_path(cp, period_id: unlocked_period.id)
        )
        expect(Personnel.find_by(contact_point: cp, monthly_period: unlocked_period)).to be_present
      end
    end

    describe "PATCH /contact_points/:id/personnel/toggle_review" do
      let!(:cp) { create(:contact_point, organization: org) }
      let!(:personnel_record) do
        create(:personnel, contact_point: cp, monthly_period: locked_period)
      end

      it "rejects toggle_review when period is locked" do
        patch toggle_review_contact_point_personnel_path(cp),
              params: { period_id: locked_period.id }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(personnel_record.reload.reviewed_at).to be_nil
      end
    end

    describe "PATCH /electricity_supply" do
      it "rejects update when period is locked" do
        patch electricity_supply_path,
              params: { period_id: locked_period.id,
                        main_meter_id: main_meter.id,
                        electricity_supply: { electricity_supply_kw: "5000" } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(MainMeterReading.count).to eq(0)
      end

      it "allows update when period is unlocked" do
        sign_out admin_unit
        sign_in admin1
        patch electricity_supply_path,
              params: { period_id: unlocked_period.id,
                        main_meter_id: main_meter.id,
                        electricity_supply: { electricity_supply_kw: "5000" } }
        expect(MainMeterReading.count).to eq(1)
      end
    end

    describe "PATCH /unit_config" do
      it "rejects unit-section update when period is locked" do
        patch unit_config_path,
              params: { period_id: locked_period.id,
                        section: "unit",
                        unit_config: { unit_public_rate: "10" } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(UnitConfig.where(monthly_period: locked_period)).to be_empty
      end

      it "rejects division-section update when period is locked (admin_level1)" do
        sign_out admin_unit
        sign_in admin1
        patch unit_config_path,
              params: { period_id: locked_period.id,
                        section: "division",
                        division_config: { savings_rate: "5", division_public_rate: "3" } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(UnitConfig.where(monthly_period: locked_period)).to be_empty
      end
    end

    describe "PATCH /pump_station_readings" do
      let!(:pump_station) { create(:pump_station, zone: zone) }
      let!(:pump_meter) do
        create(:meter, :pump_station, pump_station: pump_station, organization: org)
      end
      let(:zone_with_manager) { zone.update!(manager_organization: org); zone }

      before { zone_with_manager }

      it "rejects update when period is locked" do
        patch pump_station_readings_path,
              params: { period_id: locked_period.id,
                        readings: { pump_meter.id.to_s => { reading_start: "100", reading_end: "200" } } }
        expect(response).to be_redirect
        follow_redirect!
        expect(flash[:alert]).to eq(locked_message)
        expect(MeterReading.count).to eq(0)
      end
    end
  end

  # =========================================================================
  # Master-data controllers — block when latest period is locked
  # =========================================================================
  describe "master-data writes" do
    before { sign_in admin1 }

    context "when the latest period is locked" do
      let!(:older_unlocked) { create(:monthly_period, year: 2026, month: 1) }
      let!(:latest_locked)  { create(:monthly_period, :locked, year: 2026, month: 2) }

      describe "POST /contact_points" do
        it "rejects create" do
          expect {
            post contact_points_path,
                 params: { contact_point: { name: "CP X", organization_id: org.id,
                                            contact_point_type: "residential" } }
          }.not_to change(ContactPoint, :count)
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
        end
      end

      describe "PATCH /contact_points/:id" do
        let!(:cp) { create(:contact_point, organization: org) }

        it "rejects update" do
          patch contact_point_path(cp),
                params: { contact_point: { name: "Renamed" } }
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
          expect(cp.reload.name).not_to eq("Renamed")
        end
      end

      describe "DELETE /contact_points/:id" do
        let!(:cp) { create(:contact_point, organization: org) }

        it "rejects destroy" do
          expect { delete contact_point_path(cp) }.not_to change(ContactPoint, :count)
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
        end
      end

      describe "POST /contact_points/:cp/meters" do
        let!(:cp) { create(:contact_point, organization: org) }

        it "rejects create" do
          expect {
            post contact_point_meters_path(cp),
                 params: { meter: { name: "M-X", meter_type: "normal" } }
          }.not_to change(Meter, :count)
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
        end
      end

      describe "PATCH /contact_points/:cp/meters/:id" do
        let!(:cp)    { create(:contact_point, organization: org) }
        let!(:meter) { create(:meter, :normal, organization: org, contact_point: cp) }

        it "rejects update" do
          patch contact_point_meter_path(cp, meter),
                params: { meter: { name: "Renamed Meter" } }
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
          expect(meter.reload.name).not_to eq("Renamed Meter")
        end
      end

      describe "DELETE /contact_points/:cp/meters/:id" do
        let!(:cp)    { create(:contact_point, organization: org) }
        let!(:meter) { create(:meter, :normal, organization: org, contact_point: cp) }

        it "rejects destroy" do
          expect { delete contact_point_meter_path(cp, meter) }.not_to change(Meter, :count)
          expect(response).to be_redirect
          follow_redirect!
          expect(flash[:alert]).to eq(locked_message)
        end
      end
    end

    context "when the latest period is unlocked" do
      let!(:latest_unlocked) { create(:monthly_period, year: 2026, month: 2) }

      it "allows POST /contact_points" do
        expect {
          post contact_points_path,
               params: { contact_point: { name: "CP New", organization_id: org.id,
                                          contact_point_type: "residential" } }
        }.to change(ContactPoint, :count).by(1)
      end

      it "allows POST /contact_points/:cp/meters" do
        cp = create(:contact_point, organization: org)
        expect {
          post contact_point_meters_path(cp),
               params: { meter: { name: "M-Y", meter_type: "normal" } }
        }.to change(Meter, :count).by(1)
      end
    end

    context "when no periods exist" do
      it "does not block POST /contact_points" do
        expect {
          post contact_points_path,
               params: { contact_point: { name: "CP None", organization_id: org.id,
                                          contact_point_type: "residential" } }
        }.to change(ContactPoint, :count).by(1)
      end
    end
  end
end
