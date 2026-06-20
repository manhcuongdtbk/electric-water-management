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

      it "khu vực KHÔNG có dòng billing: ?zone_id=X vẫn giữ chọn X (regression bug filter kỳ rỗng)" do
        # Bug cũ: @available_zones chỉ gồm khu vực có dòng dữ liệu → khu vực chưa
        # tính/không có dòng nào bị rớt khỏi dropdown → hiện "Tất cả" dù URL có zone_id.
        empty_zone = create(:zone, name: "Khu vực chưa có dữ liệu")
        get billing_path(zone_id: empty_zone.id)
        zone_select = Nokogiri::HTML(response.body).at_css("select[name='zone_id']")
        selected = zone_select.css("option[selected]")
        expect(selected.size).to eq(1)
        expect(selected.first["value"]).to eq(empty_zone.id.to_s)
        expect(selected.first.text).to eq(empty_zone.name)
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

      it "CHIEU-breakdown-tong-theo-loai: bảng đối chiếu hiện đủ dòng + tiêu đề" do
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
        expect(response.body).to include("Cộng (công tơ có tổn hao)")
        expect(response.body).to include("Không tổn hao")
        expect(response.body).to include("Tổng cộng")
      end

      it "khớp ví dụ mẫu #332 (số làm tròn tiếng Việt)" do
        get billing_path(zone_id: sample.zone.id)
        body = response.body
        expect(body).to include("38,24")
        expect(body).to include("12,44")
        expect(body).to include("9,33")
        expect(body).to include("60,00") # Tổng tổn hao C ở dòng "Cộng"/"Tổng cộng"
        expect(body).to include("2.100,00")
      end

      it "CHIEU-breakdown-lam-tron: có chú thích lệch ±0,01 do làm tròn" do
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).to include("±0,01")
      end

      it "CHIEU-breakdown-i18n: nhãn breakdown tiếng Việt (không lẫn tiếng Anh)" do
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).to include("Sử dụng thực tế")
        expect(response.body).not_to include("loss_bearing_total")
        expect(response.body).not_to include("grand_total")
      end

      it "CHIEU-breakdown-chua-tinh: chưa tính → không hiện bảng breakdown" do
        LossSummary.where(period: sample.period).delete_all
        get billing_path(zone_id: sample.zone.id)
        expect(response.body).not_to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
      end

      context "bảng chi tiết điện bơm nước theo trạm (S1)" do
        # Dựng ma trận đối tượng nhận × trạm: Đại đội 1 chỉ nhận điện từ Trạm bơm 1
        # (không từ Trạm bơm Đông) để chứng minh không trộn điện giữa các trạm.
        let!(:tram_bom_dong) do
          create(:contact_point, :water_pump, name: "Trạm bơm Đông", zone: sample.zone)
        end
        let(:ban_tac_huan) { sample.contact_points[:ban_tac_huan] }
        let(:dai_doi_1) { sample.contact_points[:dai_doi_1] }
        let(:tram_bom_1) { sample.contact_points[:tram_bom_1] }

        before do
          # Chỉ lưu đóng góp khác 0 (mirror PumpStationChargeWriter).
          PumpStationCharge.create!(period: sample.period, zone: sample.zone,
                                    contact_point: ban_tac_huan, pump_contact_point: tram_bom_1,
                                    amount: BigDecimal("12.5"))
          PumpStationCharge.create!(period: sample.period, zone: sample.zone,
                                    contact_point: ban_tac_huan, pump_contact_point: tram_bom_dong,
                                    amount: BigDecimal("7.25"))
          PumpStationCharge.create!(period: sample.period, zone: sample.zone,
                                    contact_point: dai_doi_1, pump_contact_point: tram_bom_1,
                                    amount: BigDecimal("4"))
        end

        it "render bảng + tiêu đề + cột tên trạm + dòng đối tượng nhận" do
          get billing_path(zone_id: sample.zone.id)
          expect(response.body).to include("Chi tiết điện bơm nước theo trạm")
          doc = Nokogiri::HTML(response.body)
          table = doc.at_css("[data-pump-station-table]")
          expect(table).to be_present
          # Tên trạm nằm trong div đầu của th (div thứ hai là % của khu vực).
          station_names = table.css("thead th > div:first-child").map(&:text).map(&:strip)
          expect(station_names).to include("Trạm bơm 1", "Trạm bơm Đông")
          recipient_header = table.at_css("thead th").text.strip
          expect(recipient_header).to eq("Đối tượng nhận")
          expect(table.css("thead th").last.text.strip).to eq("Tổng (kW)")
          expect(table.text).to include("Ban Tác huấn").and include("Đại đội 1")
        end

        it "ô khác 0 hiện đúng số (tiếng Việt), kèm hook hàng + ô" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          row = doc.at_css(%([data-pump-charge-row="#{dai_doi_1.id}"]))
          expect(row).to be_present
          cell = doc.at_css(%([data-pump-charge-cell="#{dai_doi_1.id}-#{tram_bom_1.id}"]))
          expect(cell.text.strip).to eq("4,00")
        end

        it "ô 0 (Đại đội 1 × Trạm bơm Đông) hiện 0,00 với style mờ — không trộn điện" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          cell = doc.at_css(%([data-pump-charge-cell="#{dai_doi_1.id}-#{tram_bom_dong.id}"]))
          expect(cell.text.strip).to eq("0,00")
          expect(cell["class"]).to include("text-gray-400")
        end

        it "dòng tổng cộng = tổng mỗi trạm + tổng toàn bộ" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          total_row = doc.at_css("[data-pump-station-table] tbody tr:last-child")
          expect(total_row.text).to include("Tổng cộng (= điện mỗi trạm)")
          cells = total_row.css("td").map(&:text).map(&:strip)
          # Trạm bơm 1 = 12,5 + 4 = 16,50; Trạm bơm Đông = 7,25; tổng = 23,75
          expect(cells).to include("16,50", "7,25", "23,75")
        end

        it "có chú thích ô 0,00 tiếng Việt" do
          get billing_path(zone_id: sample.zone.id)
          expect(response.body).to include("Ô 0,00 = đầu mối không nhận điện từ trạm đó")
        end

        # B — % của khu vực mỗi trạm dưới đầu cột trạm = điện trạm / tổng điện bơm.
        # Trạm bơm 1 = 16,50/23,75 = 69,47% → "69% khu vực"; Trạm bơm Đông = 7,25/23,75
        # = 30,53% → "31% khu vực"; tổng phần trăm = 100.
        it "B: đầu mỗi cột trạm hiện % của khu vực (suy từ tổng cột trạm)" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          share_1 = doc.at_css(%([data-pump-station-zone-share="#{tram_bom_1.id}"]))
          share_dong = doc.at_css(%([data-pump-station-zone-share="#{tram_bom_dong.id}"]))
          expect(share_1.text.strip).to eq("69% khu vực")
          expect(share_dong.text.strip).to eq("31% khu vực")
        end

        it "có chú thích lệch ±0,01 do làm tròn (parity với bảng tổn hao)" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          note = doc.at_css("[data-pump-station-table]").parent
          expect(note.text).to include("±0,01")
        end

        it "đã lọc một khu vực → caption bảng trạm KHÔNG lặp tên khu vực (#12)" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          caption = doc.at_css("[data-pump-station-table] caption")
          expect(caption.text.strip).to eq("Chi tiết điện bơm nước theo trạm")
          expect(caption.text).not_to include(sample.zone.name)
        end

        it "dòng đối tượng nhận: tên đầu mối in đậm + đường dẫn cha mờ (R5-6)" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          # Đầu mối bị tính tiền in đậm; đường dẫn cha (Đơn vị › Khối › Nhóm) ở div mờ
          # riêng để giữ ngữ cảnh mà không gộp/nén thông tin.
          cell = doc.at_css(%([data-pump-charge-row="#{dai_doi_1.id}"] td))
          expect(cell.at_css("div.font-medium").text.strip).to eq("Đại đội 1")
          path = cell.at_css("div.text-gray-400")
          expect(path).to be_present
          expect(path.text).to include(dai_doi_1.unit.name)
        end

        it "có chú thích giải thích cách chia điện theo trạm (#6)" do
          get billing_path(zone_id: sample.zone.id)
          expect(response.body).to include(
            "Điện mỗi trạm bơm được chia hết cho các đối tượng nhận của trạm đó; " \
            "tổng các trạm bằng tổng điện bơm nước toàn khu vực."
          )
        end

        it "kỳ gộp/legacy (không có pump_station_charges) → KHÔNG render bảng" do
          PumpStationCharge.where(period: sample.period).delete_all
          get billing_path(zone_id: sample.zone.id)
          expect(response.body).not_to include("Chi tiết điện bơm nước theo trạm")
          expect(response.body).not_to include("data-pump-station-table")
        end
      end

      # Dropdown chọn kỳ, filter/cascade, đổi kỳ auto-submit, nút Tính toán lại/Xuất Excel,
      # non-SA dropdown visibility: cover bởi system specs (spec/system/billing_filter_spec.rb).

      context "bộ lọc khu vực phản chiếu ?zone_id + caption đa khu vực (#9, #12)" do
        # Dựng hai khu vực có pump_station_charges + loss_summary để kiểm tra cả hai bảng
        # chi tiết khi xem nhiều khu vực (chưa lọc) so với khi đã lọc một khu vực.
        let!(:sample2) { setup_zone_two_full_sample(period: sample.period) }
        let(:loss_caption) { "Đối chiếu tổn hao/sử dụng theo loại đầu mối" }
        let(:pump_caption) { "Chi tiết điện bơm nước theo trạm" }

        before do
          CalculationOrchestrator.new(zone: sample2.zone, period: sample.period).call
          PumpStationCharge.create!(
            period: sample.period, zone: sample.zone,
            contact_point: sample.contact_points[:dai_doi_1],
            pump_contact_point: sample.contact_points[:tram_bom_1],
            amount: BigDecimal("5")
          )
          PumpStationCharge.create!(
            period: sample.period, zone: sample2.zone,
            contact_point: sample2.contact_points[:quan_y],
            pump_contact_point: sample2.contact_points[:tram_bom_2],
            amount: BigDecimal("5")
          )
        end

        it "đã lọc: ?zone_id=X → dropdown khu vực chọn X (không phải 'Tất cả')" do
          get billing_path(zone_id: sample.zone.id)
          doc = Nokogiri::HTML(response.body)
          zone_select = doc.at_css("select[name='zone_id']")
          selected = zone_select.css("option[selected]")
          expect(selected.size).to eq(1)
          expect(selected.first["value"]).to eq(sample.zone.id.to_s)
          expect(selected.first.text).to eq(sample.zone.name)
        end

        it "đã lọc: trang giới hạn về khu vực X — chỉ một bảng mỗi loại (của X)" do
          get billing_path(zone_id: sample.zone.id)
          # Một bảng trạm + một bảng tổn hao (chỉ khu vực đã lọc).
          expect(response.body.scan(pump_caption).size).to eq(1)
          expect(response.body.scan(loss_caption).size).to eq(1)
          doc = Nokogiri::HTML(response.body)
          # Bảng trạm chỉ chứa trạm của khu vực 1 (Trạm bơm 1), không có Trạm bơm 2.
          pump_table = doc.at_css("[data-pump-station-table]")
          expect(pump_table.text).to include("Trạm bơm 1")
          expect(pump_table.text).not_to include("Trạm bơm 2")
        end

        it "chưa lọc: dropdown khu vực chọn 'Tất cả' (option trống selected)" do
          get billing_path
          doc = Nokogiri::HTML(response.body)
          zone_select = doc.at_css("select[name='zone_id']")
          selected = zone_select.css("option[selected]")
          # options_for_select không đánh dấu selected cho giá trị nil → mặc định 'Tất cả'.
          expect(selected).to be_empty
          expect(zone_select.css("option").first.text).to eq("Tất cả")
        end

        it "chưa lọc: bảng bơm và bảng tổn hao đều render cho mỗi khu vực caption kèm tên (#410)" do
          get billing_path
          expect(response.body.scan(pump_caption).size).to eq(2)
          expect(response.body.scan(loss_caption).size).to eq(2)
          expect(response.body).not_to include(I18n.t("billing.loss_breakdown.select_zone_hint"))
          pump_table = Nokogiri::HTML(response.body).css("[data-pump-station-table] caption").map(&:text)
          expect(pump_table).to include(a_string_including(sample.zone.name))
                            .and include(a_string_including(sample2.zone.name))
        end
      end

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

        it "CHIEU-ton-hao-sau-tinh: A/B/C xuất ra Excel ở cuối sheet sau khi tính" do
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).to include("Công tơ tổng (A)")
          expect(all_text).to include("Tổng tổn hao (C = A − B)")
        end

        it "CHIEU-breakdown-excel: các dòng breakdown theo loại ở cuối sheet" do
          CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
          get billing_path(format: :xlsx)
          xlsx = parse_xlsx(response.body)
          all_text = xlsx.rows.compact.flatten.compact.map(&:to_s).join(" | ")
          expect(all_text).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
          expect(all_text).to include("Cộng (công tơ có tổn hao)")
          expect(all_text).to include("Tổng cộng")
        end

        it "CHIEU-ton-hao-chua-tinh: chưa tính → không có khối A/B/C trong Excel" do
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

        it "CHIEU-khac-don-vi-vi-du: cell U7 (Khác của Văn thư) = -16" do
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

  describe "GET /billing — no periods exist" do
    it "redirect to pricing when no periods" do
      sign_in create(:user, :system_admin)
      get billing_path
      expect(response).to redirect_to(pricing_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /billing/recalculate — no periods" do
    it "redirect to pricing when no periods" do
      sign_in create(:user, :system_admin)
      post recalculate_billing_path
      expect(response).to redirect_to(pricing_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "GET /billing — breakdown role + multi-zone (#332)" do
    let(:sample) { setup_zone_one_full_sample }
    before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

    let(:breakdown_title) { "Đối chiếu tổn hao/sử dụng theo loại đầu mối" }

    it "CHIEU-breakdown-vai-tro: unit_admin thấy breakdown khu vực mình" do
      sign_in create(:user, :unit_admin, unit: sample.unit_b)
      get billing_path
      expect(response.body).to include(breakdown_title)
    end

    it "CHIEU-breakdown-vai-tro: unit_admin quản lý khu vực (UA-ZM) thấy breakdown" do
      sign_in create(:user, :unit_admin, unit: sample.unit_a)
      get billing_path
      expect(response.body).to include(breakdown_title)
    end

    it "CHIEU-breakdown-vai-tro: commander đơn vị quản lý khu vực (CMD-ZM) thấy breakdown" do
      sign_in create(:user, :commander, unit: sample.unit_a)
      get billing_path
      expect(response.body).to include(breakdown_title)
    end

    it "CHIEU-breakdown-vai-tro: commander đơn vị thường (CMD) thấy breakdown" do
      sign_in create(:user, :commander, unit: sample.unit_b)
      get billing_path
      expect(response.body).to include(breakdown_title)
    end

    it "CHIEU-breakdown-vai-tro: technician bị chặn khỏi bảng tính tiền" do
      sign_in create(:user, :technician)
      get billing_path
      expect(response).to redirect_to(users_path)
    end

    it "CHIEU-breakdown-theo-zone: SA không chọn zone → hiện breakdown cho mỗi khu vực (#410)" do
      sample2 = setup_zone_two_full_sample(period: sample.period)
      CalculationOrchestrator.new(zone: sample2.zone, period: sample.period).call
      sign_in create(:user, :system_admin)
      get billing_path
      expect(response.body.scan(breakdown_title).size).to eq(2)
      expect(response.body).not_to include("Chọn khu vực để xem chi tiết tổn hao.")
    end

    it "CHIEU-breakdown-theo-zone: SA chọn zone → hiện breakdown của zone đó" do
      sample2 = setup_zone_two_full_sample(period: sample.period)
      CalculationOrchestrator.new(zone: sample2.zone, period: sample.period).call
      sign_in create(:user, :system_admin)
      get billing_path(zone_id: sample.zone.id)
      expect(response.body).to include(breakdown_title)
      expect(response.body.scan(breakdown_title).size).to eq(1)
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

    # CHIEU-phan-bo-tram-config-completeness (#401): khu vực chưa phân bổ hết điện bơm nước
    # → recalc bị chặn, không persist Calculation, hiển thị lỗi tiếng Việt nêu tên khu vực.
    # Dùng kỳ mẫu (đang mở, legacy zone-wide) + một khu vực mới chỉ có % cố định < 100%.
    it "khu vực chưa phân bổ hết điện → recalc bị chặn với lỗi, không ghi Calculation" do
      period = sample.period # kỳ đang mở, pump_allocation_per_station = false
      zone = create(:zone, name: "KV recalc chặn")
      pump_cp = create(:contact_point, :water_pump, name: "Bơm recalc chặn", zone: zone)
      meter = create(:meter, name: "CT-recalc-chặn", contact_point: pump_cp, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
      unit = create(:unit, name: "ĐV recalc chặn", zone: zone)
      # Zone-wide (không gắn trạm): chỉ % cố định 40%, không recipient hệ số → còn 60% điện thừa.
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: nil,
             unit: unit, contact_point: nil, block: nil, group: nil,
             fixed_percentage: BigDecimal("40"), coefficient: BigDecimal("1"))

      sign_in admin
      expect {
        post recalculate_billing_path(period_id: period.id)
      }.not_to change { Calculation.where(period: period).count }
      expect(response).to redirect_to(billing_path(period_id: period.id))
      expect(flash[:alert]).to include("KV recalc chặn")
      expect(flash[:alert]).to include("chưa phân bổ hết điện")
    end

    # CHIEU-phan-bo-tram-config-completeness (#401) — biến thể PER-TRẠM: một trạm có recipient
    # % cố định < 100% và KHÔNG có recipient hệ số → recalc bị chặn. Khác test legacy ở trên
    # (kỳ per-station true, recipient gắn pump_contact_point). Khẳng định KHÔNG persist gì:
    # PumpStationCharge và Calculation đều giữ 0 cho (zone, period).
    it "per-trạm: trạm chưa phân bổ hết điện → recalc bị chặn, KHÔNG ghi PumpStationCharge/Calculation" do
      sample.period.update!(closed: true) # đóng kỳ mẫu để mở kỳ per-trạm mới
      period = PeriodService.new.open_new_period(
        year: 2032, month: 1, unit_price: BigDecimal("2000")
      ).period
      expect(period.pump_allocation_per_station).to be(true)

      zone = create(:zone, name: "KV per-trạm chặn")
      station = create(:contact_point, :water_pump, name: "Trạm per chặn", zone: zone)
      meter = create(:meter, name: "CT-per-chặn", contact_point: station, no_loss: true)
      meter.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
      unit = create(:unit, name: "ĐV per chặn", zone: zone)
      # Chỉ % cố định 40% gắn trạm, không recipient hệ số → còn 60% điện thừa của trạm.
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil,
             fixed_percentage: BigDecimal("40"), coefficient: BigDecimal("1"))

      sign_in admin
      expect {
        post recalculate_billing_path(period_id: period.id, zone_id: zone.id)
      }.to change { PumpStationCharge.where(zone: zone, period: period).count }.by(0)
        .and change { Calculation.where(period: period).count }.by(0)
      expect(PumpStationCharge.where(zone: zone, period: period).count).to eq(0)
      expect(Calculation.where(period: period).count).to eq(0)
      expect(response).to redirect_to(billing_path(period_id: period.id, zone_id: zone.id))
      expect(flash[:alert]).to include("Trạm per chặn")
      expect(flash[:alert]).to include("chưa phân bổ hết điện")
    end

    # CHIEU-phan-bo-tram-tong: đối chiếu end-to-end calc→write→read. Sau một lượt orchestrator
    # THẬT trên kỳ per-trạm, tổng dòng bảng per-trạm của một recipient (Σ PumpStationCharge.amount)
    # PHẢI bằng Calculation#water_pump_usage của đầu mối đó (không dựng fixture tay).
    it "per-trạm: tổng dòng bảng trạm của recipient == Calculation#water_pump_usage (calc→write→read)" do
      sample.period.update!(closed: true)
      period = PeriodService.new.open_new_period(
        year: 2033, month: 1, unit_price: BigDecimal("2000")
      ).period
      zone = create(:zone, name: "KV đối chiếu")
      station_a = create(:contact_point, :water_pump, name: "Trạm ĐC A", zone: zone)
      station_b = create(:contact_point, :water_pump, name: "Trạm ĐC B", zone: zone)
      meter_a = create(:meter, name: "CT-ĐC-A", contact_point: station_a, no_loss: true)
      meter_b = create(:meter, name: "CT-ĐC-B", contact_point: station_b, no_loss: true)
      meter_a.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 100)
      meter_b.meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 60)

      rank = period.ranks.order(:position).first
      unit_a = create(:unit, name: "ĐV ĐC A", zone: zone)
      unit_b = create(:unit, name: "ĐV ĐC B", zone: zone)
      cp_a = create(:contact_point, :residential, name: "ĐM ĐC A", unit: unit_a,
                    initial_personnel_counts: { rank.id => 1 })
      cp_b = create(:contact_point, :residential, name: "ĐM ĐC B", unit: unit_b,
                    initial_personnel_counts: { rank.id => 1 })
      create(:meter, name: "CT-ĐM-ĐC-A", contact_point: cp_a, no_loss: true)
        .meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 0)
      create(:meter, name: "CT-ĐM-ĐC-B", contact_point: cp_b, no_loss: true)
        .meter_readings.find_by!(period: period).update!(reading_start: 0, reading_end: 0)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_a,
             unit: unit_a, contact_point: nil, block: nil, group: nil, coefficient: 1)
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_b,
             unit: unit_b, contact_point: nil, block: nil, group: nil, coefficient: 1)

      sign_in admin
      post recalculate_billing_path(period_id: period.id, zone_id: zone.id)

      calc_a = Calculation.find_by!(period: period, contact_point: cp_a)
      calc_b = Calculation.find_by!(period: period, contact_point: cp_b)
      charge_a = PumpStationCharge.where(period: period, zone: zone, contact_point: cp_a).sum(:amount)
      charge_b = PumpStationCharge.where(period: period, zone: zone, contact_point: cp_b).sum(:amount)
      expect(charge_a).to eq(calc_a.water_pump_usage)
      expect(charge_b).to eq(calc_b.water_pump_usage)
      expect(charge_a + charge_b).to eq(BigDecimal("160"))
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

      get billing_path(zone_id: sample.zone.id)
      expect(response.body).to include("Cộng (công tơ có tổn hao)")
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

    it "CHIEU-ton-hao-chua-tinh: chưa tính → không có khối A/B/C" do
      sample
      sign_in sa
      get billing_path
      expect(response.body).not_to include("Cộng (công tơ có tổn hao)")
    end

    it "CHIEU-ton-hao-sau-tinh: sau tính → A/B/C khớp LossCalculator (HTML)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(response.body).to include("Cộng (công tơ có tổn hao)")
      expect(response.body).to include(vi.number_to_vi(ls.a))
      expect(response.body).to include(vi.number_to_vi(ls.b))
      expect(response.body).to include(vi.number_to_vi(ls.c))
    end

    it "kèm chú thích A/B/C tính trên toàn khu vực (gồm công cộng + bơm nước)" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      expect(response.body).to include("tính trên toàn khu vực")
      expect(response.body).to include("Đúng khi A = B + C")
    end

    it "CHIEU-ton-hao-theo-zone: SA chọn zone → chỉ A/B/C của zone đó" do
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

    it "CHIEU-ton-hao-theo-zone: SA không chọn zone → hiện A/B/C cho mỗi khu vực (#410)" do
      sample
      other = create(:zone, name: "Khu vực Hai TN3")
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      LossSummary.create!(zone: other, period: sample.period,
                          a: BigDecimal("500"), b: BigDecimal("480"), c: BigDecimal("20"))
      sign_in sa
      get billing_path
      expect(response.body.scan("Cộng (công tơ có tổn hao)").size).to be >= 2
      expect(response.body).not_to include("Chọn khu vực để xem chi tiết tổn hao.")
    end

    it "CHIEU-ton-hao-vai-tro: cả 5 vai trò nghiệp vụ thấy A/B/C; TECH bị chặn" do
      sample
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      [
        [create(:user, :system_admin), { zone_id: sample.zone.id }], # SA must select zone
        [create(:user, :unit_admin, unit: sample.unit_a), {}],       # UA-ZM
        [create(:user, :unit_admin, unit: sample.unit_b), {}],       # UA
        [create(:user, :commander, unit: sample.unit_a), {}],        # CMD-ZM
        [create(:user, :commander, unit: sample.unit_b), {}]         # CMD
      ].each do |u, extra_params|
        sign_in u
        get billing_path(extra_params)
        expect(response.body).to include("Cộng (công tơ có tổn hao)")
      end

      sign_in create(:user, :technician)
      get billing_path
      expect(response).not_to have_http_status(:ok)
    end

    it "CHIEU-ton-hao-bien: B = 0 (mọi công tơ không tổn hao) → A/B/C hiển thị (B=C=0) + cảnh báo" do
      sample
      MeterReading.where(period: sample.period).update_all(no_loss: true)
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.b).to eq(BigDecimal("0"))
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Cộng (công tơ có tổn hao)")
      expect(response.body).to include("Khu vực không có công tơ có tổn hao")
    end

    it "CHIEU-ton-hao-bien: khu vực trống (có số điện lực, không đầu mối) → A/B/C (B=C=0) + cảnh báo trên billing" do
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

    it "CHIEU-ton-hao-bien: C < 0 → C hiển thị 0,00 + cảnh báo" do
      sample
      # Đặt sử dụng công tơ tổng rất thấp để tổng công tơ con > công tơ tổng (C<0, kẹp 0)
      sample.main_meter_reading.update!(usage: BigDecimal("1"))
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.c).to eq(BigDecimal("0"))
      expect(response.body).to include("Cộng (công tơ có tổn hao)")
      expect(response.body).to include("Tổng sử dụng các công tơ con lớn hơn công tơ tổng")
    end
  end

  describe "UI/UX improvements (#405)" do
    let(:sample) { setup_zone_one_full_sample }
    let(:sa) { create(:user, :system_admin) }

    before do
      CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    end

    it "bảng đối chiếu tổn hao nằm SAU bảng tính tiền (không trước)" do
      sign_in sa
      get billing_path(zone_id: sample.zone.id)
      body = response.body
      billing_table_pos = body.index("column-resize")
      breakdown_pos = body.index("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
      expect(billing_table_pos).to be < breakdown_pos
    end

    it "SA xem tất cả khu vực → hiện bảng đối chiếu cho mỗi khu vực (#410)" do
      sign_in sa
      get billing_path
      expect(response.body).not_to include("Chọn khu vực để xem chi tiết tổn hao.")
      expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
    end

    it "non-SA luôn thấy bảng đối chiếu (zone cố định qua đơn vị)" do
      ua = create(:user, :unit_admin, unit: sample.unit_a)
      sign_in ua
      get billing_path
      expect(response.body).to include("Đối chiếu tổn hao/sử dụng theo loại đầu mối")
    end

    it "nút Tính toán lại có data-controller submit-loading" do
      sign_in sa
      get billing_path
      doc = Nokogiri::HTML(response.body)
      form = doc.css("form[data-controller='submit-loading']").first
      expect(form).to be_present
      expect(form["data-submit-loading-loading-text-value"]).to eq("Đang tính toán...")
    end
  end
end
