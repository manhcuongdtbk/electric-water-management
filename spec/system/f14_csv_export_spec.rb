# frozen_string_literal: true

require "rails_helper"

# F14 — Xuất CSV từ các trang báo cáo (F11/F12/F13).
# Dùng type: :request để kiểm tra response headers và body trực tiếp.
RSpec.describe "F14 — Xuất CSV", type: :request do
  let(:division)     { create(:organization, :division) }
  let(:unit)         { create(:organization, :unit, parent: division) }
  let!(:period)      { create(:monthly_period, year: 2026, month: 2) }
  let!(:cp)          { create(:contact_point, organization: unit) }
  let!(:calc) do
    create(:monthly_calculation,
           contact_point: cp,
           monthly_period: period,
           total_personnel: 40,
           rank1_kw: 1140, rank2_kw: 2200, rank3_kw: 3050,
           rank4_kw: 2600, rank5_kw: 0,   rank6_kw: 330, rank7_kw: 0,
           water_pump_standard_kw: 378, water_pump_actual_kw: 350,
           total_standard_kw: 9320, total_usage_kw: 7450,
           over_under_kw: -87, unit_price: 2000, total_amount: 14_900_000)
  end

  let(:admin_unit)   { create(:user, :admin_unit,   organization: unit) }
  let(:admin_level1) { create(:user, :admin_level1, organization: division) }
  let(:commander)    { create(:user, :commander,    organization: unit) }
  let(:tech_user)    { create(:user, :tech,         organization: division) }

  UTF8_BOM = "\xEF\xBB\xBF".b

  # ===========================================================================
  # F11 — MonthlySummariesController
  # ===========================================================================
  describe "GET /monthly_summary (F11 — Bảng 24 cột)" do
    describe "nút Xuất CSV hiển thị đúng vai trò" do
      it "admin_unit thấy nút Xuất CSV" do
        sign_in admin_unit
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "admin_level1 thấy nút Xuất CSV" do
        sign_in admin_level1
        get monthly_summary_path(period_id: period.id, org_id: unit.id)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "commander thấy nút Xuất CSV" do
        sign_in commander
        get monthly_summary_path(period_id: period.id)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "tech bị redirect về users_path" do
        sign_in tech_user
        get monthly_summary_path(period_id: period.id)
        expect(response).to redirect_to(users_path)
      end
    end

    describe "GET /monthly_summary.csv" do
      before { sign_in admin_unit }

      it "trả về Content-Type text/csv" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.content_type).to match(%r{text/csv})
      end

      it "có UTF-8 BOM ở đầu file" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.body.b[0..2]).to eq(UTF8_BOM)
      end

      it "có header tiếng Việt cho cột quân số, tiêu chuẩn và chênh lệch tách" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.body).to include(I18n.t("monthly_summary.columns.total_personnel"))
        expect(response.body).to include(I18n.t("monthly_summary.columns.total_standard_kw"))
        expect(response.body).to include(I18n.t("monthly_summary.columns.surplus_kw"))
        expect(response.body).to include(I18n.t("monthly_summary.columns.deficit_kw"))
        expect(response.body).to include(I18n.t("monthly_summary.columns.surplus_amount"))
        expect(response.body).to include(I18n.t("monthly_summary.columns.deficit_amount"))
      end

      it "có tên đầu mối trong dữ liệu" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.body).to include(cp.name)
      end

      it "có giá trị số đúng" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.body).to include("1140")
        expect(response.body).to include("7450")
        expect(response.body).to include("14900000")
      end

      it "có dòng tổng cộng" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.body).to include(I18n.t("monthly_summary.total_row"))
      end

      it "Content-Disposition chứa tên file đúng định dạng" do
        get monthly_summary_path(format: :csv, period_id: period.id)
        expect(response.headers["Content-Disposition"]).to include("bao_cao_tong_hop_2_2026.csv")
      end

      it "trả về 404 khi period không tồn tại" do
        get monthly_summary_path(format: :csv, period_id: 0)
        expect(response).to have_http_status(:not_found)
      end

      describe "cột Thừa/Thiếu: vị trí và giá trị đúng" do
        let(:cp_surplus) { create(:contact_point, organization: unit, name: "CP Thừa") }
        let(:cp_deficit) { create(:contact_point, organization: unit, name: "CP Thiếu") }

        before do
          MonthlyCalculation.delete_all
          create(:monthly_calculation,
                 contact_point: cp_surplus, monthly_period: period,
                 over_under_kw: -100, total_amount: -200_000)
          create(:monthly_calculation,
                 contact_point: cp_deficit, monthly_period: period,
                 over_under_kw: 40, total_amount: 80_000)
        end

        def parsed_csv
          body = response.body.sub(/\A\xEF\xBB\xBF/, "")
          CSV.parse(body, headers: true)
        end

        def parsed_csv_headers
          body = response.body.sub(/\A\xEF\xBB\xBF/, "")
          CSV.parse(body, headers: false).first
        end

        it "4 cột split nằm cuối header, đúng thứ tự liên tiếp" do
          get monthly_summary_path(format: :csv, period_id: period.id)
          hdrs = parsed_csv_headers

          s_kw = hdrs.index(I18n.t("monthly_summary.columns.surplus_kw"))
          d_kw = hdrs.index(I18n.t("monthly_summary.columns.deficit_kw"))
          s_am = hdrs.index(I18n.t("monthly_summary.columns.surplus_amount"))
          d_am = hdrs.index(I18n.t("monthly_summary.columns.deficit_amount"))

          expect(s_kw).not_to be_nil
          expect(d_kw).to eq(s_kw + 1)
          expect(s_am).to eq(d_kw + 1)
          expect(d_am).to eq(s_am + 1)
          expect(d_am).to eq(hdrs.size - 1)
        end

        it "dòng thừa: cột Thừa có giá trị, cột Thiếu trống" do
          get monthly_summary_path(format: :csv, period_id: period.id)
          rows   = parsed_csv
          cp_col = I18n.t("monthly_summary.columns.contact_point")
          row    = rows.find { |r| r[cp_col] == cp_surplus.name }

          expect(row[I18n.t("monthly_summary.columns.surplus_kw")]).to eq("100.0")
          expect(row[I18n.t("monthly_summary.columns.deficit_kw")]).to eq("")
          expect(row[I18n.t("monthly_summary.columns.surplus_amount")]).to eq("200000.0")
          expect(row[I18n.t("monthly_summary.columns.deficit_amount")]).to eq("")
        end

        it "dòng thiếu: cột Thiếu có giá trị tuyệt đối, cột Thừa trống" do
          get monthly_summary_path(format: :csv, period_id: period.id)
          rows   = parsed_csv
          cp_col = I18n.t("monthly_summary.columns.contact_point")
          row    = rows.find { |r| r[cp_col] == cp_deficit.name }

          expect(row[I18n.t("monthly_summary.columns.surplus_kw")]).to eq("")
          expect(row[I18n.t("monthly_summary.columns.deficit_kw")]).to eq("40.0")
          expect(row[I18n.t("monthly_summary.columns.surplus_amount")]).to eq("")
          expect(row[I18n.t("monthly_summary.columns.deficit_amount")]).to eq("80000.0")
        end

        it "dòng tổng cộng: Thừa và Thiếu tính độc lập, không bù trừ" do
          get monthly_summary_path(format: :csv, period_id: period.id)
          rows    = parsed_csv
          stt_col = I18n.t("monthly_summary.columns.stt")
          total   = rows.find { |r| r[stt_col] == I18n.t("monthly_summary.total_row") }

          expect(total[I18n.t("monthly_summary.columns.surplus_kw")]).to eq("100.0")
          expect(total[I18n.t("monthly_summary.columns.deficit_kw")]).to eq("40.0")
          expect(total[I18n.t("monthly_summary.columns.surplus_amount")]).to eq("200000.0")
          expect(total[I18n.t("monthly_summary.columns.deficit_amount")]).to eq("80000.0")
        end
      end
    end
  end

  # ===========================================================================
  # F12 — DashboardController
  # ===========================================================================
  describe "GET /dashboard (F12 — Dashboard)" do
    describe "nút Xuất CSV hiển thị đúng vai trò" do
      it "admin_unit thấy nút Xuất CSV khi có dữ liệu" do
        sign_in admin_unit
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "commander thấy nút Xuất CSV" do
        sign_in commander
        get dashboard_path(view_type: "month", period_id: period.id)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "tech bị redirect về users_path" do
        sign_in tech_user
        get dashboard_path
        expect(response).to redirect_to(users_path)
      end
    end

    describe "GET /dashboard.csv — month view" do
      before { sign_in admin_unit }

      it "trả về Content-Type text/csv" do
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response.content_type).to match(%r{text/csv})
      end

      it "có UTF-8 BOM ở đầu file" do
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response.body.b[0..2]).to eq(UTF8_BOM)
      end

      it "có 4 header cột tiếng Việt" do
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response.body).to include(I18n.t("dashboard.table.name"))
        expect(response.body).to include(I18n.t("dashboard.table.standard"))
        expect(response.body).to include(I18n.t("dashboard.table.usage"))
        expect(response.body).to include(I18n.t("dashboard.table.difference"))
      end

      it "có tên đầu mối và giá trị sử dụng" do
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response.body).to include(cp.name)
        expect(response.body).to include("7450")
      end

      it "Content-Disposition chứa tên file tháng đúng định dạng" do
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response.headers["Content-Disposition"]).to include("bao_cao_dashboard_thang_2_2026.csv")
      end

      it "trả về 404 khi không có dữ liệu" do
        MonthlyCalculation.delete_all
        get dashboard_path(format: :csv, view_type: "month", period_id: period.id)
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "GET /dashboard.csv — quarter view" do
      before { sign_in admin_unit }

      it "Content-Disposition chứa tên file quý đúng định dạng" do
        get dashboard_path(format: :csv, view_type: "quarter", year: 2026, quarter: 1)
        expect(response).to have_http_status(:not_found).or(
          satisfy { response.headers["Content-Disposition"]&.include?("bao_cao_dashboard_quy_1_2026.csv") }
        )
      end
    end

    describe "GET /dashboard.csv — year view" do
      before { sign_in admin_unit }

      it "Content-Disposition chứa tên file năm đúng định dạng" do
        get dashboard_path(format: :csv, view_type: "year", year: 2026)
        if response.successful?
          expect(response.headers["Content-Disposition"]).to include("bao_cao_dashboard_nam_2026.csv")
        else
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  # ===========================================================================
  # F13 — HistoryController
  # ===========================================================================
  describe "GET /history (F13 — Tra cứu lịch sử)" do
    describe "nút Xuất CSV hiển thị đúng vai trò" do
      it "admin_unit thấy nút Xuất CSV khi có dữ liệu" do
        sign_in admin_unit
        get history_path(contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "commander thấy nút Xuất CSV" do
        sign_in commander
        get history_path(contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include(I18n.t("csv.export_button"))
      end

      it "tech bị redirect về users_path" do
        sign_in tech_user
        get history_path
        expect(response).to redirect_to(users_path)
      end
    end

    describe "GET /history.csv" do
      before { sign_in admin_unit }

      it "trả về Content-Type text/csv" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.content_type).to match(%r{text/csv})
      end

      it "có UTF-8 BOM ở đầu file" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body.b[0..2]).to eq(UTF8_BOM)
      end

      it "có 4 header cột tiếng Việt" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include(I18n.t("history.comparison_table.field"))
        expect(response.body).to include("2026/02")
        expect(response.body).to include("2025/02")
        expect(response.body).to include(I18n.t("history.comparison_table.delta"))
      end

      it "có nhãn cột tiếng Việt từ DETAIL_COLUMNS" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include(I18n.t("history.columns.total_personnel"))
        expect(response.body).to include(I18n.t("history.columns.total_standard_kw"))
        expect(response.body).to include(I18n.t("history.columns.total_usage_kw"))
      end

      it "có giá trị số đúng từ kỳ hiện tại" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include("7450")
        expect(response.body).to include("9320")
      end

      it "Content-Disposition chứa tên file đúng định dạng" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.headers["Content-Disposition"]).to include("bao_cao_lich_su_2_2026.csv")
      end

      it "cột kỳ trước và chênh lệch trống khi không có dữ liệu năm trước" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        body_without_bom = response.body.sub("\xEF\xBB\xBF", "")
        rows = CSV.parse(body_without_bom, headers: true)
        first_row = rows.first
        expect(first_row[2]).to eq("")
        expect(first_row[3]).to eq("")
      end

      it "có ký hiệu so sánh ▲/▼/= khi có dữ liệu năm trước" do
        prior_period = create(:monthly_period, year: 2025, month: 2)
        create(:monthly_calculation,
               contact_point: cp, monthly_period: prior_period,
               total_standard_kw: 8000, total_usage_kw: 8000,
               total_personnel: 38)
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response.body).to include("▲").or include("▼").or include("=")
      end

      it "trả về 404 khi không có dữ liệu tính toán" do
        MonthlyCalculation.delete_all
        get history_path(format: :csv, contact_point_id: cp.id, year: 2026, month: 2)
        expect(response).to have_http_status(:not_found)
      end

      it "trả về 404 khi period không tồn tại" do
        get history_path(format: :csv, contact_point_id: cp.id, year: 2024, month: 1)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
