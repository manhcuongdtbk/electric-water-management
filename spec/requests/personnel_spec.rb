require "rails_helper"

RSpec.describe "Personnel", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org_a) { create(:organization, level: :unit, parent: division) }
  let(:org_b) { create(:organization, level: :unit, parent: division) }

  let(:admin1) { create(:user, role: :admin_level1, organization: org_a) }
  let(:admin_unit_a) { create(:user, role: :admin_unit, organization: org_a) }
  let(:admin_unit_b) { create(:user, role: :admin_unit, organization: org_b) }
  let(:commander) { create(:user, role: :commander, organization: org_a) }
  let(:tech_user) { create(:user, role: :tech, organization: org_a) }

  let!(:cp_a) { create(:contact_point, organization: org_a) }
  let!(:cp_b) { create(:contact_point, organization: org_b) }
  let!(:period) { create(:monthly_period) }

  before do
    (1..7).each { |g| create(:rank_quota, :"rank#{g}") }
  end

  # ---------------------------------------------------------------------------
  # SHOW
  # ---------------------------------------------------------------------------
  describe "GET /contact_points/:contact_point_id/personnel" do
    context "as admin_unit of org_a" do
      it "returns ok for own contact_point" do
        sign_in admin_unit_a
        get contact_point_personnel_path(cp_a, period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "cannot access another org's contact_point" do
        sign_in admin_unit_a
        get contact_point_personnel_path(cp_b, period_id: period.id)
        expect(response).to have_http_status(:not_found)
      end

      it "renders without period_id param (uses first period)" do
        sign_in admin_unit_a
        get contact_point_personnel_path(cp_a)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_level1" do
      it "can access any contact_point" do
        sign_in admin1
        get contact_point_personnel_path(cp_b, period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as commander" do
      it "can view (read-only)" do
        sign_in commander
        get contact_point_personnel_path(cp_a, period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        get contact_point_personnel_path(cp_a, period_id: period.id)
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get contact_point_personnel_path(cp_a)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before { MonthlyPeriod.delete_all }

      it "renders ok with no-period message" do
        sign_in admin_unit_a
        get contact_point_personnel_path(cp_a)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE (upsert)
  # ---------------------------------------------------------------------------
  describe "PATCH /contact_points/:contact_point_id/personnel" do
    let(:valid_params) do
      {
        personnel: {
          rank1_count: 2, rank2_count: 3, rank3_count: 5,
          rank4_count: 10, rank5_count: 0, rank6_count: 8, rank7_count: 20
        },
        period_id: period.id
      }
    end

    context "as admin_unit of org_a" do
      it "creates personnel when none exists" do
        sign_in admin_unit_a
        expect {
          patch contact_point_personnel_path(cp_a), params: valid_params
        }.to change(Personnel, :count).by(1)

        record = Personnel.last
        expect(record.contact_point).to eq(cp_a)
        expect(record.monthly_period).to eq(period)
        expect(record.rank1_count).to eq(2)
        expect(record.rank7_count).to eq(20)
        expect(response).to redirect_to(contact_point_personnel_path(cp_a, period_id: period.id))
      end

      it "updates personnel when record already exists" do
        existing = create(:personnel, contact_point: cp_a, monthly_period: period, rank1_count: 1)
        sign_in admin_unit_a

        expect {
          patch contact_point_personnel_path(cp_a), params: valid_params
        }.not_to change(Personnel, :count)

        expect(existing.reload.rank1_count).to eq(2)
        expect(existing.reload.rank7_count).to eq(20)
      end

      it "scopes correctly — cannot update another org's contact_point" do
        sign_in admin_unit_a
        expect {
          patch contact_point_personnel_path(cp_b), params: valid_params
        }.not_to change(Personnel, :count)
        expect(response).to have_http_status(:not_found)
      end

      it "rejects negative counts" do
        sign_in admin_unit_a
        patch contact_point_personnel_path(cp_a),
              params: { personnel: { rank1_count: -1, rank2_count: 0, rank3_count: 0,
                                     rank4_count: 0, rank5_count: 0, rank6_count: 0,
                                     rank7_count: 0 },
                        period_id: period.id }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "accepts zero counts for all ranks" do
        sign_in admin_unit_a
        patch contact_point_personnel_path(cp_a),
              params: { personnel: { rank1_count: 0, rank2_count: 0, rank3_count: 0,
                                     rank4_count: 0, rank5_count: 0, rank6_count: 0,
                                     rank7_count: 0 },
                        period_id: period.id }
        expect(response).to redirect_to(contact_point_personnel_path(cp_a, period_id: period.id))
        expect(Personnel.last.total_count).to eq(0)
      end
    end

    context "as admin_level1" do
      it "can update any contact_point's personnel" do
        sign_in admin1
        expect {
          patch contact_point_personnel_path(cp_b), params: valid_params
        }.to change(Personnel, :count).by(1)
        expect(Personnel.last.contact_point).to eq(cp_b)
      end
    end

    context "as commander" do
      it "is redirected (no write access)" do
        sign_in commander
        expect {
          patch contact_point_personnel_path(cp_a), params: valid_params
        }.not_to change(Personnel, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        expect {
          patch contact_point_personnel_path(cp_a), params: valid_params
        }.not_to change(Personnel, :count)
        expect(response).to redirect_to(users_path)
      end
    end
  end
end
