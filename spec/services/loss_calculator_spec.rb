require "rails_helper"

RSpec.describe LossCalculator do
  describe "#call — T01 (dữ liệu mẫu mục 1)" do
    let(:sample) { setup_zone_one_full_sample }
    let(:result) { described_class.new(zone: sample.zone, period: sample.period).call }

    it "total_b = 1930 (tổng sử dụng các công tơ có tổn hao)" do
      expect(result.total_b).to eq(BigDecimal("1930"))
    end

    it "total_loss (C) = 60 (chính xác)" do
      expect(result.total_loss).to eq(BigDecimal("60"))
    end

    it "total_a (A) = 1990 (= B + C khi C không bị kẹp)" do
      expect(result.total_a).to eq(BigDecimal("1990"))
    end

    it "CT-A1 tổn hao = 7,77 (hiển thị)" do
      expect(result.meter_losses[sample.meters[:ct_a1].id]).to eq_display("7.77")
    end

    it "CT-A2 tổn hao = 5,60" do
      expect(result.meter_losses[sample.meters[:ct_a2].id]).to eq_display("5.60")
    end

    it "CT-A3 (không tổn hao) = 0,00" do
      expect(result.meter_losses[sample.meters[:ct_a3].id]).to eq(BigDecimal("0"))
    end

    it "CT-CC-A tổn hao = 6,84" do
      expect(result.meter_losses[sample.meters[:ct_cc_a].id]).to eq_display("6.84")
    end

    it "CT-B1 tổn hao = 10,88" do
      expect(result.meter_losses[sample.meters[:ct_b1].id]).to eq_display("10.88")
    end

    it "CT-CC-B tổn hao = 1,55" do
      expect(result.meter_losses[sample.meters[:ct_cc_b].id]).to eq_display("1.55")
    end

    it "CT-KV1 tổn hao = 13,99" do
      expect(result.meter_losses[sample.meters[:ct_kv1].id]).to eq_display("13.99")
    end

    it "CT-CC-KV tổn hao = 4,04" do
      expect(result.meter_losses[sample.meters[:ct_cc_kv].id]).to eq_display("4.04")
    end

    it "CT-BN1 tổn hao = 9,33" do
      expect(result.meter_losses[sample.meters[:ct_bn1].id]).to eq_display("9.33")
    end

    it "tổng tổn hao tất cả công tơ có tổn hao = C = 60 (giá trị chính xác)" do
      sum = result.meter_losses.values.sum(BigDecimal("0"))
      expect(sum).to eq(BigDecimal("60"))
    end

    describe "tổn hao per đầu mối sinh hoạt" do
      it "Ban Tác huấn = 7,77" do
        expect(result.contact_point_losses[sample.contact_points[:ban_tac_huan].id]).to eq_display("7.77")
      end

      it "Văn thư = 5,60" do
        expect(result.contact_point_losses[sample.contact_points[:van_thu].id]).to eq_display("5.60")
      end

      it "Kho vật tư = 0,00" do
        expect(result.contact_point_losses[sample.contact_points[:kho_vat_tu].id]).to eq(BigDecimal("0"))
      end

      it "Đại đội 1 = 10,88" do
        expect(result.contact_point_losses[sample.contact_points[:dai_doi_1].id]).to eq_display("10.88")
      end

      it "Chỉ huy khu vực = 13,99" do
        expect(result.contact_point_losses[sample.contact_points[:chi_huy_khu_vuc].id]).to eq_display("13.99")
      end
    end

    it "không có cảnh báo" do
      expect(result.warnings).to be_empty
    end
  end

  describe "#call — khu vực trống (không có công tơ)" do
    let(:zone) { create(:zone) }
    let!(:period) { create(:period, closed: false) }
    let(:result) { described_class.new(zone: zone, period: period).call }

    it "total_a = 0, total_b = 0, total_loss = 0 + có cảnh báo" do
      expect(result.total_a).to eq(BigDecimal("0"))
      expect(result.total_b).to eq(BigDecimal("0"))
      expect(result.total_loss).to eq(BigDecimal("0"))
      expect(result.warnings).not_to be_empty
    end
  end

  describe "edge cases" do
    context "khu vực chưa có đầu mối" do
      let(:zone) { create(:zone) }
      let!(:period) { create(:period, closed: false) }

      it "trả về tổn hao rỗng + cảnh báo" do
        result = described_class.new(zone: zone, period: period).call
        expect(result.total_loss).to eq(0)
        expect(result.meter_losses).to be_empty
        expect(result.warnings)
          .to include(I18n.t("services.loss_calculator.warnings.zone_empty"))
      end
    end

    context "B = 0 (mọi công tơ đều no_loss)" do
      let(:sample) { setup_zone_one_full_sample }

      before do
        sample.meters.each_value do |meter|
          meter.meter_readings.find_by(period: sample.period).update!(no_loss: true)
        end
      end

      it "tổn hao tất cả = 0 + cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period).call
        expect(result.total_loss).to eq(0)
        expect(result.meter_losses.values).to all(eq(0))
        expect(result.warnings)
          .to include(I18n.t("services.loss_calculator.warnings.no_loss_bearing_meters"))
      end
    end

    context "C < 0 (công tơ con > công tơ tổng)" do
      let(:sample) { setup_zone_one_full_sample }

      before do
        sample.main_meter_reading.update!(usage: BigDecimal("500"))
      end

      it "clamp C về 0 + cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period).call
        expect(result.total_loss).to eq(0)
        expect(result.meter_losses.values).to all(eq(0))
        expect(result.warnings)
          .to include(I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main"))
      end
    end

    # Khoá biên `if c_raw < 0` (mutation #376): với dữ liệu mẫu A = công tơ tổng −
    # tổng no_loss(110), B (chịu tổn hao) = 1930. Đẩy công tơ tổng để C = A − B
    # rơi đúng vào 0 và (0,1) — chứng minh điều kiện kẹp là `< 0` chứ không phải
    # `<= 0` hay `< 1`.
    context "C = 0 đúng (A = B): KHÔNG kẹp, KHÔNG cảnh báo vượt tổng" do
      let(:sample) { setup_zone_one_full_sample }

      before { sample.main_meter_reading.update!(usage: BigDecimal("2040")) } # A = 1930 = B

      it "total_a = total_b = 1930, total_loss = 0, không có cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period).call
        expect(result.total_a).to eq(BigDecimal("1930"))
        expect(result.total_b).to eq(BigDecimal("1930"))
        expect(result.total_loss).to eq(BigDecimal("0"))
        expect(result.warnings).to be_empty
      end
    end

    context "C ∈ (0,1): tổn hao dương nhỏ hơn 1 KHÔNG bị kẹp về 0" do
      let(:sample) { setup_zone_one_full_sample }

      before { sample.main_meter_reading.update!(usage: BigDecimal("2040.5")) } # A = 1930,5; C = 0,5

      it "total_loss = 0,5 (giữ nguyên), không có cảnh báo" do
        result = described_class.new(zone: sample.zone, period: sample.period).call
        expect(result.total_loss).to eq(BigDecimal("0.5"))
        expect(result.warnings).to be_empty
      end
    end
  end
end
