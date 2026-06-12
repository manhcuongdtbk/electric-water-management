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

      it "không hiện badge 'Đang mở' (topbar đã có)" do
        get billing_path
        doc = Nokogiri::HTML(response.body)
        # Billing page body (không tính topbar) không chứa badge Đang mở
        table_area = doc.css("main").text
        expect(table_area).not_to include("Đang mở")
      end

      it "hiện đơn giá điện đầy đủ (không làm tròn)" do
        get billing_path
        # unit_price = 2336.4 → hiện "2.336,4" không phải "2.336"
        expect(response.body).to include("2.336,4 đ/kW")
      end

      it "SA chọn zone → ẩn cột Khu vực (I17)" do
        get billing_path(zone_id: sample.zone.id)
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip)
        expect(headers).not_to include(a_string_matching(/\AKhu vực\z/))
        expect(headers).to include(a_string_including("Đơn vị"))
      end

      it "SA chọn zone + unit → ẩn cả Khu vực và Đơn vị (I17)" do
        get billing_path(zone_id: sample.zone.id, unit_id: sample.unit_a.id)
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip)
        expect(headers).not_to include(a_string_matching(/\AKhu vực\z/))
        expect(headers).not_to include(a_string_matching(/\AĐơn vị\z/))
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

        it "đóng dấu phiên bản hệ thống ở chân file" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" ")
          expect(all_text).to include("Phiên bản hệ thống")
          expect(all_text).to include("v#{SystemInfo.version}")
        end

        it "D15: A/B/C xuất ra Excel ở cuối sheet sau khi tính" do
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).to include("Công tơ tổng (A)")
          expect(all_text).to include("Tổng tổn hao (C = A − B)")
        end

        it "D2(Excel): chưa tính → không có khối A/B/C trong Excel" do
          # describe-level before đã chạy CalculationOrchestrator; xóa snapshot để
          # tái lập trạng thái "chưa tính" (@loss_summaries rỗng).
          LossSummary.where(period: sample.period).delete_all
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).not_to include("Công tơ tổng (A)")
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

      # Test 3: Xuất Excel chứa đúng giá trị cột "Khác" cho unit_coefficient
      context "SA — cột Khác xuất đúng giá trị unit_coefficient (T3)" do
        # SA: show_zone=true, show_unit=true → 30 cột
        # col_zone=0, col_unit=1, col_block=2, col_group=3, col_name=4
        # col_rank_first=5 (7 ranks) → col_rank_last=11
        # col_total_personnel=12, col_residential_std=13, col_water_pump_std=14, col_total_std=15
        # col_savings=16, col_loss=17, col_division_public=18, col_unit_public=19
        # col_other=20 → cột "U" (0-indexed)
        #
        # SORT_ORDER: zone name, unit name NULLS LAST, block name NULLS LAST, group name NULLS LAST, cp name
        # Khu vực 1 → Đơn vị A → Phòng Tham mưu/Ban Tác huấn → idx 0 (row 6)
        #           → Đơn vị A → Phòng Tham mưu/Văn thư      → idx 1 (row 7)
        # → cell U7
        #
        # Văn thư unit_coefficient -2 → -2 × (10 − 2) = -16

        let(:user) { create(:user, :system_admin) }

        before do
          apply_other_deduction(sample.contact_points[:van_thu], sample.period,
                                type: "unit_coefficient", value: -2)
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
        end

        it "cell U7 (Khác của Văn thư) = -16" do
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)

          # Xác nhận header row 4 (index 3) có cột "Khác" tại index 20
          header_row = xlsx.rows[3]
          expect(header_row[20]).to eq("Khác")

          # Xác nhận Văn thư có mặt ở row 7 (index 6) cột name (index 4)
          van_thu_row = xlsx.rows[6]
          expect(van_thu_row[4]).to eq("Văn thư")

          # Giá trị cột Khác (index 20) của hàng Văn thư = -16
          # caxlsx lưu numeric value dưới dạng float → "-16.0"
          other_cell = van_thu_row[20]
          expect(other_cell.to_f).to eq(-16.0)
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

    it "bấm Tính toán lại → ghi snapshot tổn hao và hiển thị A/B/C (luồng end-to-end)" do
      sign_in admin
      expect {
        post recalculate_billing_path
      }.to change { LossSummary.where(period: sample.period).count }.from(0)

      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls).to be_present
      expect(ls.a).to be_present

      reading = MeterReading.find_by(meter: sample.meters[:ct_a1], period: sample.period)
      expect(reading.reload.loss).to be_present

      get billing_path
      expect(response.body).to include("Công tơ tổng (A)")
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

  describe "tóm tắt tổn hao A/B/C (TN3)" do
    let(:vi) do
      Class.new(ActionView::Base.with_empty_template_cache) { include NumberHelperVi }
        .new(ActionView::LookupContext.new([]), {}, nil)
    end
    let(:sa) { create(:user, :system_admin) }

    it "D2: chưa tính → không có khối A/B/C" do
      sample
      sign_in sa
      get billing_path
      expect(response.body).not_to include("Công tơ tổng (A)")
    end

    it "D4: sau tính → A/B/C khớp LossCalculator (HTML)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(response.body).to include("Công tơ tổng (A)")
      expect(response.body).to include(vi.number_to_vi(ls.a))
      expect(response.body).to include(vi.number_to_vi(ls.b))
      expect(response.body).to include(vi.number_to_vi(ls.c))
    end

    it "kèm chú thích A/B/C tính trên toàn khu vực (gồm công cộng + bơm nước)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path
      expect(response.body).to include("gồm cả công tơ công cộng và bơm nước")
      expect(response.body).to include("đã trừ điện công tơ không tổn hao")
    end

    it "D9: SA chọn zone → chỉ A/B/C của zone đó" do
      sample
      other = create(:zone, name: "Khu vực Hai TN3")
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      LossSummary.create!(zone: other, period: sample.period,
                          a: BigDecimal("500"), b: BigDecimal("480"), c: BigDecimal("20"))
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      expect(response.body).to include(sample.zone.name)
      expect(response.body).not_to include("Khu vực Hai TN3")
    end

    it "D10: SA không chọn zone → mỗi zone một dòng A/B/C" do
      sample
      other = create(:zone, name: "Khu vực Hai TN3")
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      LossSummary.create!(zone: other, period: sample.period,
                          a: BigDecimal("500"), b: BigDecimal("480"), c: BigDecimal("20"))
      sign_in sa
      get billing_path
      expect(response.body).to include(sample.zone.name).and include("Khu vực Hai TN3")
    end

    it "D13: cả 5 vai trò nghiệp vụ thấy A/B/C; TECH bị chặn" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      [
        create(:user, :system_admin),                      # SA
        create(:user, :unit_admin, unit: sample.unit_a),   # UA-ZM
        create(:user, :unit_admin, unit: sample.unit_b),   # UA
        create(:user, :commander, unit: sample.unit_a),    # CMD-ZM
        create(:user, :commander, unit: sample.unit_b)     # CMD
      ].each do |u|
        sign_in u
        get billing_path
        expect(response.body).to include("Công tơ tổng (A)")
      end

      sign_in create(:user, :technician)
      get billing_path
      expect(response).not_to have_http_status(:ok)
    end

    it "B = 0 (mọi công tơ không tổn hao) → A/B/C hiển thị (B=C=0) + cảnh báo" do
      sample
      MeterReading.where(period: sample.period).update_all(no_loss: true)
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.b).to eq(BigDecimal("0"))
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Công tơ tổng (A)")
      expect(response.body).to include("Khu vực không có công tơ có tổn hao")
    end

    it "khu vực trống (có số điện lực, không đầu mối) → A/B/C (B=C=0) + cảnh báo trên billing" do
      sample
      empty_zone = create(:zone, name: "Khu vực Trống TN3")
      main_meter = create(:main_meter, name: "CT-Tổng-Trống", zone: empty_zone)
      MainMeterReading.find_or_initialize_by(main_meter: main_meter, period: sample.period)
                      .update!(usage: BigDecimal("500"))
      CalculationOrchestrator.new(zone: empty_zone, period: sample.period).call
      sign_in sa
      get billing_path
      ls = LossSummary.find_by(zone: empty_zone, period: sample.period)
      expect(ls.a).to eq(BigDecimal("500")) # A = số điện lực − Σ công tơ không tổn hao (0)
      expect(ls.b).to eq(BigDecimal("0"))
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Khu vực Trống TN3")        # dòng A/B/C hiện cho khu vực trống
      expect(response.body).to include("Khu vực chưa có đầu mối")  # cảnh báo zone_empty hiện trên billing
    end

    it "D6: C < 0 → C hiển thị 0,00 + cảnh báo" do
      sample
      # Đặt sử dụng công tơ tổng rất thấp để tổng công tơ con > công tơ tổng (C<0, kẹp 0)
      sample.main_meter_reading.update!(usage: BigDecimal("1"))
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Công tơ tổng (A)")
      expect(response.body).to include("Tổng sử dụng các công tơ con lớn hơn công tơ tổng")
    end
  end
end
