require "rails_helper"

RSpec.describe "MonthlySummary", type: :request do
  let_it_be(:division)  { create(:organization, :division) }
  let_it_be(:org_a)     { create(:organization, :unit, parent: division) }
  let_it_be(:org_b)     { create(:organization, :unit, parent: division) }

  let_it_be(:admin1)       { create(:user, :admin_level1, organization: division) }
  let_it_be(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let_it_be(:admin_unit_b) { create(:user, :admin_unit,   organization: org_b) }
  let_it_be(:commander)    { create(:user, :commander,    organization: org_a) }
  let_it_be(:tech_user)    { create(:user, :tech,          organization: org_a) }

  let_it_be(:rank_quotas)  { (1..7).map { |g| create(:rank_quota, :"rank#{g}") } }

  let_it_be(:cp_a) { create(:contact_point, organization: org_a) }
  let_it_be(:cp_b) { create(:contact_point, organization: org_b) }

  # period + calc_a/calc_b stay let! — deleted/updated by several contexts.
  let!(:period) { create(:monthly_period, year: 2026, month: 2) }

  let!(:calc_a) do
    create(:monthly_calculation,
           contact_point: cp_a,
           monthly_period: period,
           total_personnel: 40,
           rank1_kw: 1140, rank2_kw: 2200, rank3_kw: 3050,
           rank4_kw: 2600, rank5_kw: 0, rank6_kw: 330, rank7_kw: 0,
           water_pump_standard_kw: 378, water_pump_actual_kw: 350,
           total_standard_kw: 9698,
           savings_deduction_kw: 484, loss_deduction_kw: 96,
           division_public_deduction_kw: 484, unit_public_deduction_kw: 969,
           other_deduction_kw: 0, total_deduction_kw: 2033,
           remaining_standard_kw: 7665,
           meter_usage_kw: 7100, total_usage_kw: 7450,
           over_under_kw: -215, unit_price: 2000, total_amount: -430_000)
  end

  let!(:calc_b) do
    create(:monthly_calculation,
           contact_point: cp_b,
           monthly_period: period,
           total_personnel: 20,
           rank1_kw: 570, rank2_kw: 1100, rank3_kw: 1525,
           rank4_kw: 1300, rank5_kw: 0, rank6_kw: 165, rank7_kw: 0,
           water_pump_standard_kw: 189, water_pump_actual_kw: 175,
           total_standard_kw: 4849,
           savings_deduction_kw: 242, loss_deduction_kw: 48,
           division_public_deduction_kw: 242, unit_public_deduction_kw: 484,
           other_deduction_kw: 0, total_deduction_kw: 1016,
           remaining_standard_kw: 3833,
           meter_usage_kw: 3550, total_usage_kw: 3725,
           over_under_kw: -108, unit_price: 2000, total_amount: -216_000)
  end

  # ---------------------------------------------------------------------------
  # GET /monthly_summary
  # ---------------------------------------------------------------------------
  describe "GET /monthly_summary" do
    context "as admin_unit" do
      it "returns ok" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "shows own org's contact point data" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(cp_a.name)
      end

      it "does not show another org's data" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).not_to include(cp_b.name)
      end

      # Regression lock: set_target_org forces admin_unit to current_user.organization
      # regardless of params[:org_id]. If someone refactors set_target_org to honor
      # the param for all roles, this test catches the cross-org leak.
      it "ignores params[:org_id] and scopes to own org" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id, org_id: org_b.id)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end

      it "displays the 24-column table structure" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        body = response.body
        expect(body).to include(I18n.t("monthly_summary.groups.personnel"))
        expect(body).to include(I18n.t("monthly_summary.groups.standard"))
        expect(body).to include(I18n.t("monthly_summary.groups.deductions"))
        expect(body).to include(I18n.t("monthly_summary.groups.result"))
      end

      it "shows formatted kW values with Vietnamese delimiter (dot thousands, comma decimal)" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include("1.140,00")
      end

      it "shows the total row" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(I18n.t("monthly_summary.total_row"))
      end

      it "shows the Tính lại button" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(I18n.t("monthly_summary.recalculate"))
      end

      it "includes all 7 rank column headers" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        body = response.body
        rank_quotas.each do |rq|
          expect(body).to include(rq.rank_name)
        end
      end

      # Việc 4a: tên cột không viết tắt
      it "uses full column names (no abbreviations like Tổng QS / Tổng TC / TC còn lại / Bơm nước TT)" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        body = response.body
        expect(body).to include("Tổng quân số")
        expect(body).to include("Tổng tiêu chuẩn")
        expect(body).to include("Tiêu chuẩn còn lại")
        expect(body).not_to match(/>Tổng QS</)
        expect(body).not_to match(/>Tổng TC</)
        expect(body).not_to match(/>TC còn lại</)
        expect(body).not_to match(/>Bơm nước TT/)
      end

      # Việc 4b: 2 cột mới trong UI bảng tổng hợp
      it "shows new columns 'Sử dụng công tơ' and 'Bơm nước thực tế' in the result group" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        body = response.body
        expect(body).to include("Sử dụng công tơ")
        expect(body).to include("Bơm nước thực tế")
      end
    end

    context "as admin_level1" do
      it "returns ok with org selector" do
        sign_in admin1
        get monthly_summary_path(period_id: period.id, org_id: org_a.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(org_a.name)
      end

      it "can switch to another org via org_id" do
        sign_in admin1
        get monthly_summary_path(period_id: period.id, org_id: org_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cp_b.name)
      end

      it "shows data for org_a when org_id is org_a" do
        sign_in admin1
        get monthly_summary_path(period_id: period.id, org_id: org_a.id)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as commander" do
      it "returns ok" do
        sign_in commander
        get monthly_summary_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "does not show Tính lại button" do
        sign_in commander
        get monthly_summary_path(period_id: period.id)
        expect(response.body).not_to include(I18n.t("monthly_summary.recalculate"))
      end
    end

    context "as tech" do
      it "is silently redirected to user management" do
        sign_in tech_user
        get monthly_summary_path
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to be_blank
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get monthly_summary_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before {
        MonthlyCalculation.delete_all
        MonthlyPeriod.delete_all
      }

      it "renders ok showing no-period message" do
        sign_in admin_unit_a
        get monthly_summary_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("monthly_summary.no_period"))
      end
    end

    context "scope: admin_unit sees only own org data" do
      it "org_b admin cannot see org_a data" do
        sign_in admin_unit_b
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(cp_b.name)
        expect(response.body).not_to include(cp_a.name)
      end
    end

    context "scope: đầu mối công cộng không xuất hiện trong bảng thu tiền" do
      let!(:cp_public) { create(:contact_point, :communal, organization: org_a, name: "CP Đèn đường") }
      let!(:m_public)  { create(:meter, :public_meter, organization: org_a, contact_point: cp_public) }
      let!(:calc_public) do
        create(:monthly_calculation, contact_point: cp_public, monthly_period: period,
               total_personnel: 0, over_under_kw: 26, total_amount: 52_000)
      end

      it "ẩn đầu mối công cộng khỏi response" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_public.name)
      end
    end

    context "data correctness" do
      it "displays over_under_kw absolute value in surplus column (negative = tiết kiệm)" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        # calc_a.over_under_kw = -215 (negative = thừa/surplus) → surplus column shows "215,00" (absolute, no minus)
        expect(response.body).to include("215,00")
        expect(response.body).not_to include("-215,00")
      end

      it "displays total_amount absolute value without decimal places in surplus column (negative amount = thừa)" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        # calc_a.total_amount = -430_000 (negative = thừa/surplus) → surplus column shows "430.000" (absolute, no minus)
        expect(response.body).to include("430.000")
        expect(response.body).not_to include("-430.000")
      end

      it "totals row sums total_personnel across all contact points" do
        sign_in admin1
        get monthly_summary_path(period_id: period.id, org_id: org_a.id)
        # Only org_a calc: 40 people
        expect(response.body).to include("40")
      end
    end

    context "CSS color coding for chênh lệch (over_under_kw)" do
      it "applies text-green-600 when over_under_kw is negative (under standard)" do
        # calc_a.over_under_kw = -215 (negative = tiết kiệm = green)
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include("text-green-600")
      end

      it "applies text-red-600 when over_under_kw is positive (over standard)" do
        calc_a.update!(over_under_kw: 100, total_amount: 200_000)
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include("text-red-600")
      end

      it "applies text-green-700 on total_amount cell when total is negative" do
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        # calc_a.total_amount = -430_000 → green
        expect(response.body).to include("text-green-700")
      end

      it "applies text-red-700 on total_amount cell when total is positive" do
        calc_a.update!(over_under_kw: 100, total_amount: 200_000)
        sign_in admin_unit_a
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include("text-red-700")
      end
    end

    context "auto-calculate when no data exists" do
      before do
        # Remove existing calculations — controller should trigger engine
        MonthlyCalculation.delete_all
      end

      it "does not crash (gracefully handles engine errors)" do
        sign_in admin_unit_a
        # Engine will fail due to missing rank_quotas etc — controller rescues
        get monthly_summary_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Warning banner — shown when LossCalculator clamps a negative loss to 0
  # ---------------------------------------------------------------------------
  describe "negative-loss warning banner" do
    let(:zone)         { create(:zone, name: "Tiny zone") }
    let(:main_meter)   { create(:main_meter, zone: zone, name: "Tiny supply") }
    let(:org_tiny)     { create(:organization, :unit, parent: division, zone: zone) }
    let(:user_tiny)    { create(:user, :admin_unit, organization: org_tiny) }
    let!(:cp_tiny)     { create(:contact_point, organization: org_tiny, name: "CP tiny") }
    let!(:meter_tiny) do
      m = create(:meter, :normal, organization: org_tiny, contact_point: cp_tiny, name: "Big meter")
      create(:meter_reading, meter: m, monthly_period: period,
             reading_start: 0, reading_end: 999, consumption: 999)
      m
    end
    let!(:supply_tiny) do
      create(:main_meter_reading, main_meter: main_meter, monthly_period: period,
             electricity_supply_kw: 100)
    end

    it "shows the yellow warning banner with consumption and supply numbers" do
      sign_in user_tiny
      get monthly_summary_path(period_id: period.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("calculation.warnings.heading"))
      expect(response.body).to include("Tổng sử dụng công tơ")
      expect(response.body).to match(/100/)
      expect(response.body).to match(/999/)
    end

    it "does not show the banner when supply >= consumption" do
      supply_tiny.update!(electricity_supply_kw: 5_000)
      sign_in user_tiny
      get monthly_summary_path(period_id: period.id)
      expect(response.body).not_to include(I18n.t("calculation.warnings.heading"))
    end
  end

  # ---------------------------------------------------------------------------
  # GET /monthly_summary.csv (Việc 4c: đồng bộ với UI)
  # ---------------------------------------------------------------------------
  describe "GET /monthly_summary.csv" do
    it "returns CSV with full column headers in UI order (no abbreviations, includes 2 new cols)" do
      sign_in admin_unit_a
      get monthly_summary_path(format: :csv, period_id: period.id)
      expect(response).to have_http_status(:ok)
      body = response.body.force_encoding("UTF-8").sub(/\A\xEF\xBB\xBF/, "")
      headers = CSV.parse_line(body.lines.first.chomp)

      # Spot-check: all full names present, no abbreviations
      expect(headers).to include("Tổng quân số", "Tổng tiêu chuẩn", "Tiêu chuẩn còn lại",
                                 "Sử dụng công tơ", "Bơm nước thực tế", "Sử dụng")
      expect(headers).not_to include("Tổng QS", "Tổng TC", "TC còn lại", "Bơm nước TT")

      # Order check: meter_usage_kw + water_pump_actual_kw are between
      # remaining_standard_kw and total_usage_kw — same as UI.
      idx_remain = headers.index("Tiêu chuẩn còn lại")
      idx_meter  = headers.index("Sử dụng công tơ")
      idx_pump   = headers.index("Bơm nước thực tế")
      idx_total  = headers.index("Sử dụng")
      expect([ idx_remain, idx_meter, idx_pump, idx_total ]).to eq([ idx_remain, idx_remain + 1, idx_remain + 2, idx_remain + 3 ])
    end

    it "outputs raw decimals (dot decimal, no thousands delimiter) for data rows" do
      sign_in admin_unit_a
      get monthly_summary_path(format: :csv, period_id: period.id)
      body = response.body.force_encoding("UTF-8")
      # calc_a.water_pump_actual_kw = 350 → CSV raw "350.0"
      expect(body).to match(/(?:^|,)350\.0(?:,|\r|\n)/)
      # No VN-formatted numbers in CSV (e.g. "1.140,00" or "430.000,00")
      expect(body).not_to include("1.140,00")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /monthly_summary/recalculate
  # ---------------------------------------------------------------------------
  describe "POST /monthly_summary/recalculate" do
    context "as admin_unit" do
      it "triggers recalculation and redirects with notice" do
        sign_in admin_unit_a
        allow_any_instance_of(CalculationOrchestrator).to receive(:call).and_return([])
        post recalculate_monthly_summary_path, params: { period_id: period.id }
        expect(response).to redirect_to(monthly_summary_path(period_id: period.id, org_id: nil))
        expect(flash[:notice]).to eq(I18n.t("flash.monthly_summary.recalculated"))
      end

      it "redirects with alert on engine error" do
        sign_in admin_unit_a
        allow_any_instance_of(CalculationOrchestrator).to receive(:call).and_raise(StandardError, "test error")
        post recalculate_monthly_summary_path, params: { period_id: period.id }
        expect(response).to redirect_to(monthly_summary_path(period_id: period.id, org_id: nil))
        expect(flash[:alert]).to include("test error")
      end
    end

    context "as commander" do
      it "redirects with access_denied alert" do
        sign_in commander
        post recalculate_monthly_summary_path, params: { period_id: period.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "as admin_level1" do
      it "can recalculate for any org via org_id" do
        sign_in admin1
        allow_any_instance_of(CalculationOrchestrator).to receive(:call).and_return([])
        post recalculate_monthly_summary_path, params: { period_id: period.id, org_id: org_a.id }
        expect(response).to redirect_to(monthly_summary_path(period_id: period.id, org_id: org_a.id.to_s))
        expect(flash[:notice]).to eq(I18n.t("flash.monthly_summary.recalculated"))
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        post recalculate_monthly_summary_path, params: { period_id: period.id }
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        post recalculate_monthly_summary_path, params: { period_id: period.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
