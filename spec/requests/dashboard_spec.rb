require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:division)     { create(:organization, :division) }
  let(:org_a)        { create(:organization, :unit, parent: division) }
  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let(:tech_user)    { create(:user, :tech,         organization: org_a) }

  let!(:period)      { create(:monthly_period, year: 2026, month: 2) }
  let!(:rank_quotas) { (1..7).map { |g| create(:rank_quota, :"rank#{g}") } }

  let!(:cp_normal)  { create(:contact_point, organization: org_a, name: "CP Cơ quan") }
  let!(:m_normal)   { create(:meter, :normal, organization: org_a, contact_point: cp_normal) }
  let!(:calc_normal) do
    create(:monthly_calculation,
           contact_point: cp_normal,
           monthly_period: period,
           total_personnel: 40,
           total_standard_kw: 9698, total_usage_kw: 7450,
           over_under_kw: -215, total_amount: -430_000)
  end

  describe "GET /dashboard (F09)" do
    context "as admin_unit" do
      it "returns ok" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "shows normal contact point" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include(cp_normal.name)
      end
    end

    # F09: regression — đầu mối có TOÀN BỘ meter là public_meter không xuất hiện
    # trong trang chủ (tương tự F11 đã fix ở PR#85). Engine vẫn lưu dữ liệu để capture
    # public consumption nhưng UI thanh toán không nên hiển thị.
    context "scope: đầu mối công cộng không xuất hiện trên trang chủ" do
      let!(:cp_public)  { create(:contact_point, organization: org_a, name: "CP Đèn đường") }
      let!(:m_public)   { create(:meter, :public_meter, organization: org_a, contact_point: cp_public) }
      let!(:calc_public) do
        create(:monthly_calculation, contact_point: cp_public, monthly_period: period,
               total_personnel: 0, total_standard_kw: 0, total_usage_kw: 120,
               over_under_kw: 120, total_amount: 240_000)
      end

      it "ẩn đầu mối công cộng (admin_unit)" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include(cp_normal.name)
        expect(response.body).not_to include(cp_public.name)
      end

      it "ẩn đầu mối công cộng (admin_level1, single org)" do
        sign_in admin1
        get dashboard_path(view_type: "month", period_id: period.id, org_id: org_a.id.to_s)
        expect(response.body).to include(cp_normal.name)
        expect(response.body).not_to include(cp_public.name)
      end

      it "ẩn đầu mối công cộng (admin_level1, all orgs)" do
        sign_in admin1
        get dashboard_path(view_type: "month", period_id: period.id, org_id: "all")
        expect(response.body).to include(cp_normal.name)
        expect(response.body).not_to include(cp_public.name)
      end

      it "ẩn đầu mối công cộng ở quarter view" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
        expect(response.body).to include(cp_normal.name)
        expect(response.body).not_to include(cp_public.name)
      end

      it "ẩn đầu mối công cộng ở year view" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "year", year: 2026)
        expect(response.body).to include(cp_normal.name)
        expect(response.body).not_to include(cp_public.name)
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        get dashboard_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
