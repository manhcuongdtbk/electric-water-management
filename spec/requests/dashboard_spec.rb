require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:division)     { create(:organization, :division) }
  let(:org_a)        { create(:organization, :unit, parent: division) }
  let(:org_b)        { create(:organization, :unit, parent: division) }
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
      let!(:cp_public)  { create(:contact_point, :communal, organization: org_a, name: "CP Đèn đường") }
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

    context "Khối column" do
      it "shows Khối column header in month view HTML" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include("Khối")
      end

      it "shows group_name value for contact points with a group" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include(cp_normal.group_name)
      end

      it "has Khối at index 0 and Đầu mối at index 1 in month CSV" do
        sign_in admin_unit_a
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response).to have_http_status(:ok)
        body = response.body.force_encoding("UTF-8").sub(/\A\xEF\xBB\xBF/, "")
        headers = CSV.parse_line(body.lines.first.chomp)
        expect(headers[0]).to eq("Khối")
        expect(headers[1]).to eq("Đầu mối")
        data_row = CSV.parse_line(body.lines[1].chomp)
        expect(data_row[0]).to eq(cp_normal.group_name.to_s)
      end
    end

    context "quarter aggregate view" do
      let!(:period_jan) { create(:monthly_period, year: 2026, month: 1) }
      let!(:calc_jan) do
        create(:monthly_calculation,
               contact_point: cp_normal,
               monthly_period: period_jan,
               total_personnel: 10,
               total_standard_kw: 500, total_usage_kw: 450,
               over_under_kw: -50, total_amount: -100_000)
      end

      it "renders quarter view with Khối column and contact point data" do
        sign_in admin_unit_a
        get dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Khối")
        expect(response.body).to include(cp_normal.name)
      end

      it "does not merge two contact_points with the same name in aggregate view" do
        cp_dup = create(:contact_point, organization: org_b, name: cp_normal.name, group_name: "Khối khác")
        create(:monthly_calculation,
               contact_point: cp_dup,
               monthly_period: period_jan,
               total_personnel: 5,
               total_standard_kw: 200, total_usage_kw: 180,
               over_under_kw: -20, total_amount: -40_000)

        sign_in admin1
        get dashboard_path(view_type: "quarter", year: 2026, quarter: 1)
        expect(response).to have_http_status(:ok)

        body = response.body
        occurrences = body.scan(cp_normal.name).count
        expect(occurrences).to be >= 2
      end
    end
  end
end
