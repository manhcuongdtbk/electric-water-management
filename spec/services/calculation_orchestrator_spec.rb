require "rails_helper"

RSpec.describe CalculationOrchestrator do
  let(:sample) { setup_zone_one_full_sample }

  describe "#call — chạy đủ 3 bước, persist calculations" do
    let(:result) { described_class.new(zone: sample.zone, period: sample.period).call }

    it "trả về loss + pump + summary + warnings" do
      expect(result.loss_results).to be_a(LossCalculator::Result)
      expect(result.pump_results).to be_a(PumpAllocationCalculator::Result)
      expect(result.summary_results).to be_a(SummaryCalculator::Result)
      expect(result.warnings).to be_an(Array)
    end

    it "persist 5 Calculation cho residential" do
      result
      expect(Calculation.where(period: sample.period).count).to eq(5)
    end

    it "tổng hợp warnings từ 3 service" do
      expect(result.warnings).to be_empty
    end

    describe "T04 — hàng tổng" do
      before { result }
      let(:calcs) { Calculation.where(period: sample.period) }

      it "tổng quân số = 22" do
        expect(calcs.sum(:total_personnel)).to eq(22)
      end

      it "tiêu chuẩn sinh hoạt = 1.644,00" do
        expect(calcs.sum(:residential_standard)).to eq_display("1644.00")
      end

      it "tiêu chuẩn bơm nước = 207,90" do
        expect(calcs.sum(:water_pump_standard)).to eq_display("207.90")
      end

      it "tổng tiêu chuẩn = 1.851,90" do
        expect(calcs.sum(:total_standard)).to eq_display("1851.90")
      end

      it "tiết kiệm của Bộ = 92,60" do
        expect(calcs.sum(:savings_deduction)).to eq_display("92.60")
      end

      it "tổn hao = 38,24" do
        expect(calcs.sum(:loss_deduction)).to eq_display("38.24")
      end

      it "công cộng Sư đoàn = 185,19" do
        expect(calcs.sum(:division_public_deduction)).to eq_display("185.19")
      end

      it "công cộng đơn vị = 23,96" do
        expect(calcs.sum(:unit_public_deduction)).to eq_display("23.96")
      end

      it "Khác = 33,00" do
        expect(calcs.sum(:other_deduction)).to eq_display("33.00")
      end

      it "tổng trừ = 372,98" do
        expect(calcs.sum(:total_deduction)).to eq_display("372.98")
      end

      it "tiêu chuẩn còn lại = 1.478,92" do
        expect(calcs.sum(:remaining_standard)).to eq_display("1478.92")
      end

      it "sử dụng sinh hoạt = 1.340,00" do
        expect(calcs.sum(:residential_usage)).to eq_display("1340.00")
      end

      it "sử dụng bơm nước = 283,00" do
        expect(calcs.sum(:water_pump_usage)).to eq_display("283.00")
      end

      it "tổng sử dụng = 1.623,00" do
        expect(calcs.sum(:total_usage)).to eq_display("1623.00")
      end
    end
  end

  describe "transaction rollback khi summary fail" do
    it "không persist calculations nếu summary raise" do
      allow_any_instance_of(SummaryCalculator).to receive(:call).and_raise(StandardError, "boom")
      expect {
        begin
          described_class.new(zone: sample.zone, period: sample.period).call
        rescue StandardError
        end
      }.not_to change { Calculation.count }
    end
  end

  describe "thu thập warnings từ engine" do
    before do
      sample.contact_points[:tram_bom_1].discard
    end

    it "warning từ PumpAllocationCalculator được include trong result" do
      result = described_class.new(zone: sample.zone, period: sample.period).call
      expect(result.warnings)
        .to include(I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter"))
    end
  end
end
