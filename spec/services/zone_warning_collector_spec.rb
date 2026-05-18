require "rails_helper"

RSpec.describe ZoneWarningCollector do
  let(:sample) { setup_zone_one_full_sample }

  describe "#call" do
    context "với data mẫu đầy đủ" do
      it "không có warning" do
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings).to be_empty
      end
    end

    context "khi công tơ tổng có tổng usage = 0 (T105/T109 base)" do
      it "warning 'chưa nhập số sử dụng công tơ tổng'" do
        sample.main_meter_reading.update!(usage: 0)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).to include("chưa nhập số sử dụng công tơ tổng")
      end
    end

    context "khi đầu mối chưa nhập reading_end (T73)" do
      it "warning 'chưa nhập chỉ số công tơ'" do
        meter = sample.meters[:ct_a1]
        meter.meter_readings.find_by(period: sample.period).update!(reading_end: nil, manual_usage: nil)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).to include("Ban Tác huấn")
        expect(warnings.join(" ")).to include("chưa nhập chỉ số công tơ")
      end
    end

    context "khi trạm bơm chưa nhập" do
      it "warning 'trạm bơm chưa nhập số liệu'" do
        meter = sample.meters[:ct_bn1]
        meter.meter_readings.find_by(period: sample.period).update!(reading_end: nil, manual_usage: nil)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).to include("Trạm bơm 1")
      end
    end

    context "T104 — tổn hao âm (main_meter nhỏ)" do
      it "warning subtotal_exceeds_main từ LossCalculator" do
        sample.main_meter_reading.update!(usage: 1900)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings).to include(
          I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main")
        )
      end
    end

    context "T105 — tất cả công tơ no_loss" do
      it "warning no_loss_bearing_meters" do
        sample.meters.each do |key, meter|
          next if key == :ct_bn1   # giữ bơm nước
          meter.meter_readings.find_by(period: sample.period).update!(no_loss: true)
        end
        # CT-BN1 cũng phải no_loss để B = 0
        sample.meters[:ct_bn1].meter_readings.find_by(period: sample.period).update!(no_loss: true)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings).to include(
          I18n.t("services.loss_calculator.warnings.no_loss_bearing_meters")
        )
      end
    end
  end
end
