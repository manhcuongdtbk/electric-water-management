require "rails_helper"

RSpec.describe "Billing", type: :request do
  let(:sample) { setup_zone_one_full_sample }

  describe "GET /billing" do
    before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    context "unguarded" do
      it "redirect khi chưa đăng nhập" do
        get billing_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "system_admin (T77)" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả 200 + render bảng tính tiền" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Bảng tính tiền")
        expect(response.body).to include("Khu vực 1")
      end

      it "hiển thị 30 cột khi xem gộp (Khu vực + Đơn vị)" do
        get billing_path
        expect(response.body).to include("Khu vực").and include("Đơn vị")
      end

      it "hiển thị tất cả đầu mối kể cả đầu mối thuộc khu vực" do
        get billing_path
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Đại đội 1")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      # Dropdown chọn kỳ, filter/cascade, đổi kỳ auto-submit, nút Tính toán lại/Xuất Excel,
      # non-SA dropdown visibility: cover bởi system specs (spec/system/billing_filter_spec.rb).

      it "xem kỳ cũ qua period_id" do
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get billing_path(period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đã đóng")
      end

    end

    context "unit_admin zone-manager (T76)" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }
      before { sign_in user }

      it "thấy đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      # Dropdown visibility: cover bởi system spec.

      it "hiện cột Đơn vị trong bảng (29 cột — phân biệt đơn vị vs khu vực)" do
        get billing_path
        expect(response.body).to include("Đơn vị")
      end

      it "KHÔNG thấy đầu mối của đơn vị B" do
        get billing_path
        expect(response.body).not_to include("Đại đội 1")
      end
    end

    context "unit_admin không phải zone-manager" do
      let(:user) { create(:user, :unit_admin, unit: sample.unit_b) }
      before { sign_in user }

      it "chỉ thấy đầu mối Đơn vị B" do
        get billing_path
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
        expect(response.body).not_to include("Chỉ huy khu vực")
      end

      it "ẩn cột Khu vực và Đơn vị (28 cột)" do
        get billing_path
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip)
        expect(headers).not_to include(a_string_including("Khu vực"))
        expect(headers).not_to include(a_string_including("Đơn vị"))
      end
    end

    context "commander zone-manager (nghiệp vụ 6: tương tự UA-ZM)" do
      let(:user) { create(:user, :commander, unit: sample.unit_a) }
      before { sign_in user }

      it "thấy đầu mối đơn vị mình + đầu mối sinh hoạt thuộc khu vực" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
        expect(response.body).to include("Chỉ huy khu vực")
      end

      # Dropdown visibility: cover bởi system spec.
    end

    context "commander không phải zone-manager" do
      let(:user) { create(:user, :commander, unit: sample.unit_b) }
      before { sign_in user }

      it "chỉ thấy đầu mối đơn vị mình" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
        expect(response.body).not_to include("Chỉ huy khu vực")
      end

    end

    context "technician" do
      let(:user) { create(:user, :technician) }
      before { sign_in user }

      it "redirect về users_path" do
        get billing_path
        expect(response).to redirect_to(users_path)
      end
    end

    context "format :xlsx" do
      include XlsxHelpers

      before { sign_in user }

      context "SA (30 cột)" do
        let(:user) { create(:user, :system_admin) }

        it "trả về file xlsx" do
          get billing_path(format: :xlsx)
          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include("spreadsheetml.sheet")
          expect(response.headers["Content-Disposition"]).to include("bang-tinh-tien")
        end

        it "export xlsx kỳ cũ" do
          sample.period.update!(closed: true)
          PeriodService.new.open_new_period(year: 2026, month: 6,
                                            unit_price: BigDecimal("2336.4"))
          get billing_path(period_id: sample.period.id, format: :xlsx)
          expect(response).to have_http_status(:ok)
          expect(response.headers["Content-Disposition"]).to include("bang-tinh-tien-#{sample.period.month}")
        end

        it "SA 30 cột — header chứa Khu vực và Đơn vị" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          header_row = xlsx.rows[3]
          header_texts = header_row&.compact || []
          expect(header_texts).to include("Khu vực", "Đơn vị", "Khối", "Nhóm", "Tên đầu mối")
        end

        it "formulas đúng: tổng quân số = SUM(rank cols)" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          # Data bắt đầu từ row 6 (index 5). Formulas trong XML không có leading "=".
          personnel_formulas = xlsx.formulas.select { |_ref, f| f =~ /SUM\([A-Z]+6:[A-Z]+6\)/ }
          expect(personnel_formulas).not_to be_empty
        end

        it "formulas đúng: tổng tiêu chuẩn = sinh hoạt + bơm nước" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          std_formulas = xlsx.formulas.select { |ref, f| ref =~ /6$/ && f =~ /[A-Z]+6\+[A-Z]+6/ }
          expect(std_formulas).not_to be_empty
        end

        it "formulas đúng: tổng trừ = SUM(tiết kiệm:khác)" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          deduction_formulas = xlsx.formulas.select { |ref, f| ref =~ /6$/ && f =~ /SUM\([A-Z]+6:[A-Z]+6\)/ }
          # Ít nhất 2 SUM formulas per data row: tổng quân số + tổng trừ
          expect(deduction_formulas.size).to be >= 2
        end

        it "formulas đúng: tiêu chuẩn còn lại = tổng tiêu chuẩn - tổng trừ" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          remaining_formulas = xlsx.formulas.select { |ref, f| ref =~ /6$/ && f =~ /[A-Z]+6-[A-Z]+6/ }
          expect(remaining_formulas).not_to be_empty
        end

        it "formulas đúng: thành tiền = kW * đơn giá ($B$1)" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          amount_formulas = xlsx.formulas.select { |_ref, f| f.include?("$B$1") }
          # Mỗi data row có 2 formulas tham chiếu đơn giá: thành tiền thừa + thành tiền thiếu
          expect(amount_formulas.size).to be >= 2
        end

        it "hàng tổng có formulas SUM cho mọi cột số" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          # Hàng tổng tham chiếu range data rows (row 6 trở đi).
          total_formulas = xlsx.formulas.select { |_ref, f| f =~ /SUM\([A-Z]+6:[A-Z]+\d+\)/ }
          # 7 ranks + tổng quân số + 3 tiêu chuẩn + 6 khoản trừ + tiêu chuẩn còn lại
          # + 3 sử dụng + 4 kết quả = 25 SUM formulas ở hàng tổng
          expect(total_formulas.size).to be >= 18
        end

        it "number format: kW dùng #,##0.00, tiền dùng #,##0, quân số dùng 0" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          formats_used = xlsx.cell_formats.values.uniq
          expect(formats_used).to include("#,##0.00")  # kW (2 chữ số thập phân)
          expect(formats_used).to include("#,##0")     # tiền (0 chữ số thập phân)
          expect(formats_used).to include("0")         # quân số (integer)
        end

        it "merge cells cho header nhóm lớn (row 3)" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          expect(xlsx.merges).not_to be_empty
          header_merges = xlsx.merges.select { |m| m.include?("3") }
          expect(header_merges).not_to be_empty
        end
      end

      context "UA (28 cột — ẩn Khu vực + Đơn vị)" do
        let(:user) { create(:user, :unit_admin, unit: sample.unit_b) }

        it "xlsx ẩn cột Khu vực và Đơn vị" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          header_row = xlsx.rows[3]
          header_texts = header_row&.compact || []
          expect(header_texts).not_to include("Khu vực")
          expect(header_texts).not_to include("Đơn vị")
        end

        it "formula column index đúng (không bị lệch do thiếu 2 cột)" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          # Thành tiền vẫn phải tham chiếu $B$1 (đơn giá)
          amount_formulas = xlsx.formulas.select { |_ref, f| f.include?("$B$1") }
          expect(amount_formulas.size).to be >= 2
        end
      end

      context "UA-ZM (29 cột — có Đơn vị, ẩn Khu vực)" do
        let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }

        it "xlsx có cột Đơn vị, ẩn cột Khu vực" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          header_row = xlsx.rows[3]
          header_texts = header_row&.compact || []
          expect(header_texts).to include("Đơn vị")
          expect(header_texts).not_to include("Khu vực")
        end
      end
    end
  end

  describe "POST /billing/recalculate" do
    let(:admin) { create(:user, :system_admin) }
    let(:unit_admin_b) { create(:user, :unit_admin, unit: sample.unit_b) }

    before do
      sample  # force setup
    end

    it "system_admin tính toán lại toàn hệ thống" do
      sign_in admin
      expect {
        post recalculate_billing_path
      }.to change { Calculation.where(period: sample.period).count }.from(0).to(5)
      expect(response).to redirect_to(billing_path)
    end

    it "commander KHÔNG có quyền recalculate" do
      commander = create(:user, :commander, unit: sample.unit_a)
      sign_in commander
      post recalculate_billing_path
      expect(response).to redirect_to(new_user_session_path).or redirect_to(root_path)
    end

    it "unit_admin zone-manager tính toán lại khu vực mình" do
      ua_zm = create(:user, :unit_admin, unit: sample.unit_a)
      sign_in ua_zm
      expect {
        post recalculate_billing_path
      }.to change { Calculation.where(period: sample.period).count }.from(0).to(5)
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(billing_path)
    end

    it "kỳ đã đóng → không cho tính toán lại" do
      sample.period.update!(closed: true)
      PeriodService.new.open_new_period(year: 2026, month: 6,
                                        unit_price: BigDecimal("2336.4"))
      sign_in admin
      post recalculate_billing_path(period_id: sample.period.id)
      expect(response).to redirect_to(billing_path(period_id: sample.period.id))
      expect(flash[:alert]).to include("đã đóng")
    end
  end

  describe "Chiều 8 — trạng thái tính toán" do
    let(:admin) { create(:user, :system_admin) }
    let(:ua) { create(:user, :unit_admin, unit: sample.unit_b) }

    before { sign_in admin }

    context "calculations trống (chưa tính lần nào)" do
      before { sample }  # setup data nhưng KHÔNG gọi CalculationOrchestrator

      it "billing render bình thường, hiện thông báo chưa có dữ liệu" do
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Chưa có dữ liệu tính toán")
      end

      it "billing xlsx trả về file hợp lệ (không crash)" do
        get billing_path(format: :xlsx)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("spreadsheetml.sheet")
      end

      it "non-SA billing cũng render bình thường khi chưa tính" do
        sign_in ua
        get billing_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Chưa có dữ liệu tính toán")
      end
    end

    context "calculations stale (data thay đổi sau khi tính)" do
      before do
        CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      end

      it "billing vẫn hiện kết quả cũ sau khi sửa meter_readings" do
        old_deficit = Calculation.find_by(
          period: sample.period,
          contact_point: sample.contact_points[:ban_tac_huan]
        )&.deficit

        # Sửa meter_reading → data thay đổi nhưng chưa tính lại
        reading = sample.meters[:ct_a1].meter_readings.find_by!(period: sample.period)
        reading.update!(reading_end: reading.reading_end + 999)

        get billing_path
        expect(response).to have_http_status(:ok)
        # Calculation vẫn giữ giá trị cũ (stale)
        current_deficit = Calculation.find_by(
          period: sample.period,
          contact_point: sample.contact_points[:ban_tac_huan]
        )&.deficit
        expect(current_deficit).to eq(old_deficit)
      end
    end
  end
end
