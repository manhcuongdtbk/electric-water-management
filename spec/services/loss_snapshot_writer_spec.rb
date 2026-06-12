require "rails_helper"

RSpec.describe LossSnapshotWriter do
  let(:sample) { setup_zone_one_full_sample }
  let(:loss) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

  def reading_for(meter_key)
    MeterReading.find_by(meter: sample.meters[meter_key], period: sample.period)
  end

  describe "#call — sample T01 (B=1930, C=60, A=1990)" do
    before { described_class.new(zone: sample.zone, period: sample.period, loss_results: loss).call }

    it "ghi meter_readings.loss đúng meter_losses" do
      expect(reading_for(:ct_a1).reload.loss).to eq(loss.meter_losses[sample.meters[:ct_a1].id])
    end

    it "công tơ no_loss → loss = 0" do
      expect(reading_for(:ct_a3).reload.loss).to eq(BigDecimal("0"))
    end

    it "upsert LossSummary A/B/C khớp calculator" do
      ls = LossSummary.find_by(zone: sample.zone, period: sample.period)
      expect(ls.a).to eq(loss.total_a)
      expect(ls.b).to eq(loss.total_b)
      expect(ls.c).to eq(loss.total_loss)
    end

    it "idempotent: chạy lại ghi đè cùng 1 LossSummary (không tạo trùng)" do
      described_class.new(zone: sample.zone, period: sample.period, loss_results: loss).call
      expect(LossSummary.where(zone: sample.zone, period: sample.period).count).to eq(1)
    end
  end

  describe "#call — khu vực trống" do
    let(:empty_zone) { create(:zone, name: "Khu vực rỗng") }
    let(:empty_loss) { LossCalculator.new(zone: empty_zone, period: sample.period).call }

    it "vẫn ghi LossSummary với A/B/C = engine (0/0/0)" do
      described_class.new(zone: empty_zone, period: sample.period, loss_results: empty_loss).call
      ls = LossSummary.find_by(zone: empty_zone, period: sample.period)
      expect([ls.a, ls.b, ls.c]).to eq([empty_loss.total_a, BigDecimal("0"), BigDecimal("0")])
    end
  end
end
