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
      it "warning subtotal_exceeds_main từ LossCalculator, có tên khu vực" do
        sample.main_meter_reading.update!(usage: 1900)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).to include(sample.zone.name)
          .and include(I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main"))
      end
    end

    context "T105 — tất cả công tơ no_loss" do
      it "warning no_loss_bearing_meters, có tên khu vực" do
        sample.meters.each do |key, meter|
          next if key == :ct_bn1   # giữ bơm nước
          meter.meter_readings.find_by(period: sample.period).update!(no_loss: true)
        end
        # CT-BN1 cũng phải no_loss để B = 0
        sample.meters[:ct_bn1].meter_readings.find_by(period: sample.period).update!(no_loss: true)
        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).to include(sample.zone.name)
          .and include(I18n.t("services.loss_calculator.warnings.no_loss_bearing_meters"))
      end
    end

    context "đầu mối chưa nhập đã bị discard (v2.4.0)" do
      it "không cảnh báo 'chưa nhập chỉ số' cho đầu mối đã discard" do
        cp = sample.contact_points[:ban_tac_huan]
        cp.meters.first.meter_readings.find_by(period: sample.period)
          .update!(reading_end: nil, manual_usage: nil)
        cp.discard

        warnings = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings.join(" ")).not_to include("Ban Tác huấn")
      end
    end

    context "zone đã xóa — không có data cho kỳ" do
      it "không cảnh báo gì cho zone đã xóa không có data" do
        # Tạo zone mới, nhập liệu, xóa, rồi kiểm tra cảnh báo kỳ sau
        extra_zone = Zone.create!(name: "KV Tạm", main_meters_attributes: [{ name: "CT-Tạm" }])
        extra_unit = Unit.create!(name: "ĐV Tạm", zone: extra_zone)
        cp = create(:contact_point, :residential, name: "ĐM Tạm", unit: extra_unit,
                    initial_personnel_counts: { sample.period.ranks.first.id => 1 })
        # Xóa hết rồi xóa zone
        cp.discard
        extra_unit.discard
        extra_zone.discard

        # Mở kỳ mới
        sample.period.update!(closed: true)
        period_2 = PeriodService.new.open_new_period.period

        # Zone đã xóa không có data kỳ 2 → không cảnh báo
        warnings = described_class.new(zone: extra_zone, period: period_2).call
        expect(warnings).to be_empty
      end
    end

    context "zone đã xóa — có data kỳ cũ" do
      it "cảnh báo đúng cho kỳ cũ có data, không cảnh báo cho kỳ mới" do
        # Kỳ 1: zone có data đầy đủ → không cảnh báo
        warnings_p1 = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings_p1).to be_empty

        # Đóng kỳ 1, mở kỳ 2
        sample.period.update!(closed: true)
        period_2 = PeriodService.new.open_new_period.period

        # Xóa 1 đầu mối ở kỳ 2
        kho_vat_tu = sample.contact_points[:kho_vat_tu]
        kho_vat_tu.discard

        # Kỳ 1: vẫn không cảnh báo (data còn đầy đủ)
        warnings_p1_after = described_class.new(zone: sample.zone, period: sample.period).call
        expect(warnings_p1_after).to be_empty

        # Kỳ 2: không cảnh báo cho đầu mối đã xóa (data cleanup)
        # Nhập data kỳ 2 cho các entity còn lại
        sample.meters.each_value do |m|
          next if m.discarded?
          reading = m.meter_readings.find_by(period: period_2)
          reading&.update!(reading_end: reading.reading_start + 100)
        end
        sample.main_meter.main_meter_readings.create!(period: period_2, usage: BigDecimal("2000"))

        warnings_p2 = described_class.new(zone: sample.zone, period: period_2).call
        expect(warnings_p2.join(" ")).not_to include(kho_vat_tu.name)
      end
    end
  end
end
