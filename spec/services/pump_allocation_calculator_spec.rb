require "rails_helper"

RSpec.describe PumpAllocationCalculator do
  describe "#call — T02 (dữ liệu mẫu mục 1)" do
    let(:sample) { setup_zone_one_full_sample }
    let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }
    let(:result) {
      described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
    }

    it "total_d = 309,33 (raw 300 + tổn hao 9,33)" do
      expect(result.total_d).to eq_display("309.33")
    end

    it "Chỉ huy khu vực (20% cố định) = 61,87" do
      expect(result.contact_point_allocations[sample.contact_points[:chi_huy_khu_vuc].id]).to eq_display("61.87")
    end

    it "Ban Tác huấn (Đơn vị A → 5 người) = 52,65" do
      expect(result.contact_point_allocations[sample.contact_points[:ban_tac_huan].id]).to eq_display("52.65")
    end

    it "Văn thư (Đơn vị A → 2 người) = 21,06" do
      expect(result.contact_point_allocations[sample.contact_points[:van_thu].id]).to eq_display("21.06")
    end

    it "Kho vật tư (Đơn vị A → 3 người) = 31,59" do
      expect(result.contact_point_allocations[sample.contact_points[:kho_vat_tu].id]).to eq_display("31.59")
    end

    it "Đại đội 1 (Đơn vị B → 11 người, nhận toàn bộ phần B) = 115,83" do
      expect(result.contact_point_allocations[sample.contact_points[:dai_doi_1].id]).to eq_display("115.83")
    end

    it "Thợ xây (ngoài biên chế) nhận 26,33 — vẫn ở contact_point_allocations" do
      expect(result.contact_point_allocations[sample.contact_points[:tho_xay].id]).to eq_display("26.33")
    end

    it "tổng tất cả phân bổ = D = 309,33" do
      total = result.contact_point_allocations.values.sum(BigDecimal("0"))
      expect(total.round(2, BigDecimal::ROUND_HALF_UP)).to eq(BigDecimal("309.33"))
    end

    it "không có cảnh báo" do
      expect(result.warnings).to be_empty
    end
  end

  describe "edge cases" do
    context "không có công tơ bơm nước (hard delete để engine với .with_discarded vẫn không thấy)" do
      let(:sample) { setup_zone_one_full_sample }
      let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

      before do
        # v2.3.0: engine query với .with_discarded, nên discard không đủ.
        # Hard delete meter_readings + meter + contact_point để thật sự không còn pump meter.
        MeterReading.where(meter_id: sample.meters[:ct_bn1].id).delete_all
        PumpAllocation.where(contact_point_id: sample.contact_points[:tram_bom_1].id).delete_all
        Meter.with_discarded.where(id: sample.meters[:ct_bn1].id).delete_all
        ContactPoint.with_discarded.where(id: sample.contact_points[:tram_bom_1].id).delete_all
      end

      it "d = 0 + cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
        expect(result.total_d).to eq(0)
        expect(result.contact_point_allocations).to be_empty
        expect(result.warnings)
          .to include(I18n.t("services.pump_allocation_calculator.warnings.no_pump_meter"))
      end
    end

    context "tổng fixed_percentage = 100% → coefficient bỏ qua" do
      let(:sample) { setup_zone_one_full_sample }
      let(:loss_results) { LossCalculator.new(zone: sample.zone, period: sample.period).call }

      before do
        sample.pump_allocations[:chi_huy_khu_vuc].update!(fixed_percentage: BigDecimal("100"))
      end

      it "Chỉ huy khu vực nhận 100% D, các đơn vị nhận 0" do
        result = described_class.new(zone: sample.zone, period: sample.period, loss_results: loss_results).call
        expect(result.contact_point_allocations[sample.contact_points[:chi_huy_khu_vuc].id])
          .to eq_display("309.33")
        expect(result.contact_point_allocations[sample.contact_points[:ban_tac_huan].id] || 0).to eq(0)
      end
    end
  end
end
