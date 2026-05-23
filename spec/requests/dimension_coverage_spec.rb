# Cover gaps từ V2_TEST_COVERAGE_GAPS.md: chiều 5, 7, 10.
# Chiều 1 (State A) ghi nhận nhưng PeriodGuard concern spec đã cover logic chặn.
require "rails_helper"

RSpec.describe "Test dimension coverage", type: :request do
  let(:sample) { setup_zone_one_full_sample }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
  end

  # ---------------------------------------------------------------------------
  # Chiều 5 — Loại đầu mối: cleanup khi discard per type
  # ---------------------------------------------------------------------------
  describe "Chiều 5 — cleanup per loại đầu mối" do
    let(:admin) { create(:user, :system_admin) }
    before { sign_in admin }

    it "xóa public CP → cleanup meter_readings kỳ đang mở, giữ kỳ cũ" do
      public_cp = sample.contact_points[:nha_an]
      meter = sample.meters[:ct_cc_a]
      reading = meter.meter_readings.find_by!(period: sample.period)
      expect(reading).to be_present

      delete contact_point_path(public_cp)

      expect(MeterReading.find_by(id: reading.id)).to be_nil
    end

    it "xóa water_pump CP → cleanup meter_readings kỳ đang mở, giữ kỳ cũ" do
      pump_cp = sample.contact_points[:tram_bom_1]
      meter = sample.meters[:ct_bn1]
      reading = meter.meter_readings.find_by!(period: sample.period)
      expect(reading).to be_present

      delete contact_point_path(pump_cp)

      expect(MeterReading.find_by(id: reading.id)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Chiều 7 — Kỳ đang xem ≠ kỳ đang mở
  # ---------------------------------------------------------------------------
  describe "Chiều 7 — kỳ đang xem ≠ kỳ đang mở" do
    # Setup: kỳ 5/2026 (sample) đóng, mở kỳ 6/2026
    let!(:new_period) do
      sample.period.update!(closed: true)
      PeriodService.new.open_new_period(year: 2026, month: 6,
                                        unit_price: BigDecimal("2336.4")).period
    end

    context "SA xem kỳ cũ khi kỳ mới nhất mở" do
      let(:admin) { create(:user, :system_admin) }
      before { sign_in admin }

      it "billing hiện data kỳ cũ, recalculate disabled (kỳ cũ đóng)" do
        get billing_path(period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")  # data kỳ cũ
        expect(response.body).to include("Đã đóng")
      end
    end

    context "SA mở lại kỳ cũ, xem kỳ khác" do
      let(:admin) { create(:user, :system_admin) }
      before do
        sign_in admin
        # Đóng kỳ mới (6/2026), mở lại kỳ cũ (5/2026)
        new_period.update!(closed: true)
        sample.period.update!(closed: false)
      end

      it "xem kỳ 6/2026 (đóng) khi kỳ 5/2026 (cũ) đang mở → data kỳ 6, recalculate disabled" do
        get billing_path(period_id: new_period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đã đóng")
      end
    end

    context "non-SA xem kỳ cũ" do
      let(:ua_zm) { create(:user, :unit_admin, unit: sample.unit_a) }
      before { sign_in ua_zm }

      it "UA-ZM xem billing kỳ cũ → data kỳ cũ hiển thị" do
        get billing_path(period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ban Tác huấn")
      end
    end

    context "non-SA (UA) xem kỳ cũ" do
      let(:ua) { create(:user, :unit_admin, unit: sample.unit_b) }
      before { sign_in ua }

      it "UA xem billing kỳ cũ → chỉ data đơn vị mình" do
        get billing_path(period_id: sample.period.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Đại đội 1")
        expect(response.body).not_to include("Ban Tác huấn")
      end
    end

    context "history cho non-SA" do
      let(:ua) { create(:user, :unit_admin, unit: sample.unit_b) }
      before { sign_in ua }

      it "UA xem history compare → trả 200" do
        get history_path(mode: "compare",
                         period_a: sample.period.id,
                         period_b: new_period.id)
        expect(response).to have_http_status(:ok)
      end

      it "UA xem history range → trả 200" do
        get history_path(mode: "range", from: "2026-05", to: "2026-06")
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Chiều 10 — Vị trí phân cấp: rowspan cho tất cả 5 vị trí
  # ---------------------------------------------------------------------------
  describe "Chiều 10 — rowspan cho 5 vị trí phân cấp" do
    it "RowspanComputer xử lý vị trí 2 (trong khối, không nhóm)" do
      # Vị trí 2: block_id có, group_id null
      calcs = [
        OpenStruct.new(contact_point: OpenStruct.new(
          effective_zone: OpenStruct.new(name: "Z1"),
          unit: OpenStruct.new(name: "U1"),
          block: OpenStruct.new(name: "Block A"),
          group: nil, name: "CP1"
        )),
        OpenStruct.new(contact_point: OpenStruct.new(
          effective_zone: OpenStruct.new(name: "Z1"),
          unit: OpenStruct.new(name: "U1"),
          block: OpenStruct.new(name: "Block A"),
          group: nil, name: "CP2"
        ))
      ]
      result = Billing::RowspanComputer.compute(calcs, show_zone: true, show_unit: true)
      # Block A merge 2 dòng
      expect(result[0][:block]).to eq(2)
      expect(result[1][:block]).to be_nil
    end

    it "RowspanComputer xử lý vị trí 3 (trong nhóm trực tiếp, không khối)" do
      # Vị trí 3: block_id null, group_id có
      calcs = [
        OpenStruct.new(contact_point: OpenStruct.new(
          effective_zone: OpenStruct.new(name: "Z1"),
          unit: OpenStruct.new(name: "U1"),
          block: nil,
          group: OpenStruct.new(name: "Group X"), name: "CP1"
        )),
        OpenStruct.new(contact_point: OpenStruct.new(
          effective_zone: OpenStruct.new(name: "Z1"),
          unit: OpenStruct.new(name: "U1"),
          block: nil,
          group: OpenStruct.new(name: "Group X"), name: "CP2"
        ))
      ]
      result = Billing::RowspanComputer.compute(calcs, show_zone: true, show_unit: true)
      # Group X merge 2 dòng. Block nil cũng merge (nil == nil → same → merge)
      expect(result[0][:group]).to eq(2)
      expect(result[1][:group]).to be_nil
      expect(result[0][:block]).to eq(2)  # nil == nil → merge thành 1 ô trống
    end
  end
end
