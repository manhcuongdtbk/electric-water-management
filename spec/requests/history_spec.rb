require "rails_helper"

RSpec.describe "History", type: :request do
  let_it_be(:division) { create(:organization, :division) }
  let_it_be(:org_a)    { create(:organization, :unit, parent: division) }
  let_it_be(:org_b)    { create(:organization, :unit, parent: division) }

  let_it_be(:admin1)       { create(:user, :admin_level1, organization: division) }
  let_it_be(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let_it_be(:commander_a)  { create(:user, :commander,    organization: org_a) }
  let_it_be(:tech_user)    { create(:user, :tech,         organization: division) }

  let_it_be(:cp_a) { create(:contact_point, organization: org_a) }
  let_it_be(:cp_b) { create(:contact_point, organization: org_b) }

  let!(:period) { create(:monthly_period, year: 2026, month: 2) }

  describe "GET /history" do
    context "as admin_level1" do
      it "returns 200" do
        sign_in admin1
        get history_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      it "returns 200 and shows only its own org's contact points" do
        sign_in admin_unit_a
        get history_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as commander" do
      it "returns 200" do
        sign_in commander_a
        get history_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      it "redirects to user management with access_denied alert" do
        sign_in tech_user
        get history_path
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get history_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /history.csv" do
    let!(:calc) do
      create(:monthly_calculation, contact_point: cp_a, monthly_period: period)
    end

    it "returns a CSV export for admin_level1" do
      sign_in admin1
      get history_path(format: :csv, org_id: org_a.id, contact_point_id: cp_a.id,
                       year: 2026, month: 2)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
    end
  end
end
