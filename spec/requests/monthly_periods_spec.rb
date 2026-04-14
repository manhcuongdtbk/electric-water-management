require "rails_helper"

RSpec.describe "MonthlyPeriods", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org)      { create(:organization, level: :unit, parent: division) }
  let(:admin1)   { create(:user, role: :admin_level1, organization: org) }
  let(:admin_unit) { create(:user, role: :admin_unit, organization: org) }

  # ---------------------------------------------------------------------------
  # POST /monthly_periods — create
  # ---------------------------------------------------------------------------
  describe "POST /monthly_periods" do
    let(:valid_params) { { monthly_period: { year: 2026, month: 3, unit_price: "" } } }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates a new period" do
        expect {
          post monthly_periods_path, params: valid_params
        }.to change(MonthlyPeriod, :count).by(1)
      end

      it "redirects to personnel_review after creation" do
        post monthly_periods_path, params: valid_params
        new_period = MonthlyPeriod.last
        expect(response).to redirect_to(personnel_review_path(period_id: new_period.id))
      end

      context "when a previous period exists" do
        let!(:previous) { create(:monthly_period, year: 2026, month: 2, locked: false) }

        it "auto-locks the previous period" do
          post monthly_periods_path, params: valid_params
          expect(previous.reload.locked).to be(true)
        end

        it "records locked_by on the previous period" do
          post monthly_periods_path, params: valid_params
          expect(previous.reload.locked_by).to eq(admin1)
        end
      end

      context "when a previous period exists with personnel" do
        let!(:previous)  { create(:monthly_period, year: 2026, month: 2) }
        let!(:cp)        { create(:contact_point, organization: org) }
        let!(:prev_pers) { create(:personnel, contact_point: cp, monthly_period: previous) }

        it "inherits personnel into the new period" do
          post monthly_periods_path, params: valid_params
          new_period = MonthlyPeriod.last
          expect(Personnel.find_by(contact_point: cp, monthly_period: new_period)).not_to be_nil
        end
      end

      context "with duplicate year/month" do
        let!(:existing) { create(:monthly_period, year: 2026, month: 3) }

        it "does not create a duplicate and redirects with an error" do
          expect {
            post monthly_periods_path, params: valid_params
          }.not_to change(MonthlyPeriod, :count)
          expect(response).to redirect_to(personnel_review_path)
        end
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        post monthly_periods_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /monthly_periods/:id/unlock
  # ---------------------------------------------------------------------------
  describe "PATCH /monthly_periods/:id/unlock" do
    let!(:locked_period) { create(:monthly_period, :locked, year: 2026, month: 1) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "unlocks the period" do
        patch unlock_monthly_period_path(locked_period)
        expect(locked_period.reload.locked).to be(false)
      end

      it "clears locked_by and locked_at" do
        patch unlock_monthly_period_path(locked_period)
        locked_period.reload
        expect(locked_period.locked_by).to be_nil
        expect(locked_period.locked_at).to be_nil
      end

      it "redirects to personnel_review with the unlocked period" do
        patch unlock_monthly_period_path(locked_period)
        expect(response).to redirect_to(personnel_review_path(period_id: locked_period.id))
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit }

      it "is forbidden" do
        patch unlock_monthly_period_path(locked_period)
        expect(response).to redirect_to(root_path)
        expect(locked_period.reload.locked).to be(true)
      end
    end
  end
end
