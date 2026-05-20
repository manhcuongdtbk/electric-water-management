require "rails_helper"

RSpec.describe "History", type: :request do
  let(:sample) { setup_zone_one_full_sample }

  before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

  describe "GET /history" do
    context "system_admin mặc định mode single (T83)" do
      let(:user) { create(:user, :system_admin) }
      before { sign_in user }

      it "render kỳ hiện tại với bảng tính tiền" do
        get history_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Tra cứu lịch sử")
        expect(response.body).to include("Ban Tác huấn")
      end

      it "chọn period cũ thì hiển thị data kỳ đó" do
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get history_path(mode: "single", period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("5/2026").or include("Tháng 5")
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
    end

    context "T87 - permission" do
      let(:unit_admin_a) { create(:user, :unit_admin, unit: sample.unit_a) }
      let(:unit_admin_b) { create(:user, :unit_admin, unit: sample.unit_b) }

      it "unit_admin B KHÔNG thấy đầu mối của unit A" do
        sign_in unit_admin_b
        get history_path(mode: "single", period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Ban Tác huấn")
        expect(response.body).not_to include("Chỉ huy khu vực")
        expect(response.body).to include("Đại đội 1")
      end

      it "unit_admin xem period chưa có data → vẫn 200, bảng trống" do
        sign_in unit_admin_a
        sample.period.update!(closed: true)
        new_period = PeriodService.new
                                  .open_new_period(year: 2026, month: 6,
                                                   unit_price: BigDecimal("2336.4")).period
        get history_path(mode: "single", period_id: new_period.id)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
