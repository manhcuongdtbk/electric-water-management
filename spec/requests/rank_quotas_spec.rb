require "rails_helper"

RSpec.describe "RankQuotas", type: :request do
  let_it_be(:division) { create(:organization, :division) }
  let_it_be(:org)      { create(:organization, :unit, parent: division) }

  let_it_be(:admin1)     { create(:user, :admin_level1, organization: division) }
  let_it_be(:admin_unit) { create(:user, :admin_unit,   organization: org) }
  let_it_be(:commander)  { create(:user, :commander,    organization: org) }
  let_it_be(:tech_user)  { create(:user, :tech,         organization: division) }

  let!(:rank_quota) { create(:rank_quota, :rank1) }

  describe "GET /rank_quotas" do
    it "returns 200 for admin_level1" do
      sign_in admin1
      get rank_quotas_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for admin_unit (read-only)" do
      sign_in admin_unit
      get rank_quotas_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for commander" do
      sign_in commander
      get rank_quotas_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects tech to user management" do
      sign_in tech_user
      get rank_quotas_path
      expect(response).to redirect_to(users_path)
    end
  end

  describe "GET /rank_quotas/:id/edit" do
    it "returns 200 for admin_level1" do
      sign_in admin1
      get edit_rank_quota_path(rank_quota)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /rank_quotas/:id" do
    context "as admin_level1" do
      it "updates quota_kw and redirects" do
        sign_in admin1
        patch rank_quota_path(rank_quota), params: { rank_quota: { quota_kw: 999 } }
        expect(response).to redirect_to(rank_quotas_path)
        expect(rank_quota.reload.quota_kw).to eq(999)
      end
    end

    context "as admin_unit" do
      it "is forbidden and does not change the quota" do
        sign_in admin_unit
        patch rank_quota_path(rank_quota), params: { rank_quota: { quota_kw: 999 } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
        expect(rank_quota.reload.quota_kw).not_to eq(999)
      end
    end
  end
end
