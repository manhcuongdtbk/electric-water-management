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

      it "trả 200 với mode range" do
        get history_path(mode: "range", from: "2026-04", to: "2026-06")
        expect(response).to have_http_status(:ok)
      end

      it "link kỳ trong range trỏ tới billing, không phải history single" do
        get history_path(mode: "range", from: "2026-05", to: "2026-05")
        expect(response.body).to include(billing_path(period_id: sample.period.id))
        expect(response.body).not_to include("mode=single")
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
