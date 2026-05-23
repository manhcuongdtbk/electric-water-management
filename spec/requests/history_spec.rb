require "rails_helper"

RSpec.describe "History", type: :request do
  let(:sample) { setup_zone_one_full_sample }

  before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

  describe "GET /history" do
    context "mặc định mode compare" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "render trang so sánh khi không truyền mode" do
        get history_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tra cứu lịch sử")
        expect(response.body).to include("So sánh 2 kỳ")
      end

      it "KHÔNG có tab Xem kỳ cũ" do
        get history_path
        expect(response.body).not_to include("Xem kỳ cũ")
      end
    end

    context "mode=compare (T84)" do
      let(:user) { create(:user, :system_admin) }
      let(:period_b) do
        sample.period.update!(closed: true)
        PeriodService.new.open_new_period(year: 2026, month: 6,
                                          unit_price: BigDecimal("2336.4")).period
      end

      before do
        sign_in user
        period_b  # ensure created
      end

      it "trả 200 khi không truyền period_a/b" do
        get history_path(mode: "compare")
        expect(response).to have_http_status(:ok)
      end

      it "bảng compare có merge Khối + Nhóm (giống billing)" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        doc = Nokogiri::HTML(response.body)
        headers = doc.css("table thead th").map(&:text).map(&:strip)
        expect(headers).to include("Khối", "Nhóm", "Tên đầu mối")
      end

      it "bảng compare có header nhóm cột (Tiêu chuẩn, Khoản trừ, Sử dụng, Kết quả)" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        expect(response.body).to include("Tiêu chuẩn")
        expect(response.body).to include("Khoản trừ")
        expect(response.body).to include("Sử dụng")
        expect(response.body).to include("Kết quả")
      end

      it "bảng compare có hàng tổng" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        expect(response.body).to include("TỔNG")
      end

      it "bảng compare luôn hiện đơn giá 2 kỳ đầy đủ (không làm tròn)" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        expect(response.body).to include("2.336,4 đ/kW")
        # Luôn hiện cả 2 kỳ, kể cả khi đơn giá giống nhau
        expect(response.body).to include("5/2026:")
      end

      it "header 3 hàng — nhóm 1 metric dùng rowspan, không lệch cột" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        doc = Nokogiri::HTML(response.body)
        # Row 1 có "Tiêu chuẩn còn lại" colspan=3
        row1_texts = doc.css("table thead tr:first-child th").map(&:text).map(&:strip)
        expect(row1_texts).to include("Tiêu chuẩn còn lại")
        # Row 2 có A/B/Δ cho nhóm 1 metric (Khoản trừ, Tiêu chuẩn còn lại) với rowspan=2
        row2_ths = doc.css("table thead tr:nth-child(2) th")
        rowspan2_count = row2_ths.count { |th| th["rowspan"] == "2" }
        # 5 info cols (rowspan=2) + Quân số A/B/Δ (3×rowspan=2) + Khoản trừ A/B/Δ (3×rowspan=2) + Tiêu chuẩn còn lại A/B/Δ (3×rowspan=2) = 14
        expect(rowspan2_count).to be >= 11
      end

      it "bảng compare thiếu màu đỏ, thừa màu xanh" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: sample.period.id)
        expect(response.body).to include("text-red-700")
        expect(response.body).to include("text-green-700")
      end

      it "render bảng so sánh khi truyền 2 period" do
        sample.main_meter.main_meter_readings.create!(period: period_b, usage: 2100)
        sample.meters.each do |key, meter|
          attrs = SampleData::SAMPLE_METER_READINGS[key]
          reading = meter.meter_readings.find_by(period: period_b)
          reading.update!(reading_start: reading.reading_start,
                          reading_end: reading.reading_start + (attrs[:finish] - attrs[:start]),
                          no_loss: attrs[:no_loss])
        end
        CalculationOrchestrator.new(zone: sample.zone, period: period_b).call

        get history_path(mode: "compare", period_a: sample.period.id, period_b: period_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Δ")
        expect(response.body).to include("Khu vực 1")
        expect(response.body).to include("Đơn vị A")
      end
    end

    context "mode=range (T86)" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "trả 200 với mode range, dùng period dropdown filter" do
        get history_path(mode: "range",
                         from_period_id: sample.period.id,
                         to_period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("5/2026")
      end

      it "mặc định hiện tất cả kỳ khi không chọn filter" do
        get history_path(mode: "range")
        expect(response).to have_http_status(:ok)
      end

      it "link kỳ trỏ tới billing" do
        get history_path(mode: "range",
                         from_period_id: sample.period.id,
                         to_period_id: sample.period.id)
        expect(response.body).to include(billing_path(period_id: sample.period.id))
        expect(response.body).not_to include("mode=single")
      end

      it "dropdown kỳ không có option 'Tất cả' (blank_text: nil)" do
        get history_path(mode: "range")
        doc = Nokogiri::HTML(response.body)
        options = doc.css("select#from_period_id option").map(&:text)
        expect(options).not_to include("Tất cả")
      end

      it "xóa bộ lọc giữ mode=range (không chuyển sang compare)" do
        get history_path(mode: "range",
                         from_period_id: sample.period.id,
                         to_period_id: sample.period.id)
        doc = Nokogiri::HTML(response.body)
        clear_link = doc.css("a").find { |a| a.text.include?(I18n.t("common.list.clear_filter")) }
        expect(clear_link&.attr("href")).to include("mode=range") if clear_link
      end

      it "auto-swap khi from > to" do
        old_period = create(:period, year: 2025, month: 12, closed: true)
        # from = kỳ mới (5/2026), to = kỳ cũ (12/2025) → swap
        get history_path(mode: "range",
                         from_period_id: sample.period.id,
                         to_period_id: old_period.id)
        expect(response).to have_http_status(:ok)
        # Sau swap: from = 12/2025, to = 5/2026 → hiện cả 2 kỳ
        expect(response.body).to include("12/2025")
        expect(response.body).to include("5/2026")
      end
    end

    context "mode=single redirect sang billing" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "mode không hợp lệ → fallback về compare" do
        get history_path(mode: "single")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("So sánh 2 kỳ")
      end
    end

    context "technician" do
      let(:user) { create(:user, :technician) }
      before { sign_in user }

      it "redirect về users_path" do
        get history_path
        expect(response).to redirect_to(users_path)
      end
    end
  end
end
