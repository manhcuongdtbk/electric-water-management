require "rails_helper"

RSpec.describe ZoneQuery do
  let(:sample) { setup_zone_one_full_sample }
  let(:query) { described_class.new(zone: sample.zone, period: sample.period) }

  describe "#contact_points" do
    it "trả về đầu mối kept trong zone (qua unit + zone trực tiếp)" do
      result = query.contact_points
      sample.contact_points.each_value do |cp|
        expect(result).to include(cp)
      end
    end

    it "vẫn bao gồm đầu mối đã discard (v2.3.0 — engine tính toán lại kỳ cũ)" do
      sample.contact_points[:ban_tac_huan].discard
      expect(query.contact_points).to include(sample.contact_points[:ban_tac_huan])
    end
  end

  describe "#meters" do
    it "trả về tất cả công tơ kept trong zone" do
      result = query.meters
      sample.meters.each_value do |meter|
        expect(result).to include(meter)
      end
    end
  end

  describe "#meter_readings" do
    it "trả về readings của zone trong period" do
      readings = query.meter_readings
      expect(readings.count).to eq(sample.meters.size)
    end
  end

  describe "#meter_usages" do
    it "trả về hash meter_id => BigDecimal(usage)" do
      usages = query.meter_usages
      expect(usages[sample.meters[:ct_a1].id]).to eq(BigDecimal("250"))
      expect(usages[sample.meters[:ct_a2].id]).to eq(BigDecimal("180"))
      expect(usages[sample.meters[:ct_a3].id]).to eq(BigDecimal("110"))
      expect(usages[sample.meters[:ct_bn1].id]).to eq(BigDecimal("300"))
    end

    it "trả về 0 khi reading_end null" do
      reading = sample.meters[:ct_a1].meter_readings.find_by(period: sample.period)
      reading.update!(reading_end: nil)
      expect(query.meter_usages[sample.meters[:ct_a1].id]).to eq(BigDecimal("0"))
    end
  end

  describe "#pump_meters" do
    it "trả về chỉ công tơ bơm nước" do
      expect(query.pump_meters).to contain_exactly(sample.meters[:ct_bn1])
    end
  end

  describe "#main_meter_total_usage" do
    it "trả về tổng usage main_meter trong zone+period" do
      expect(query.main_meter_total_usage).to eq(BigDecimal("2100"))
    end
  end

  describe "#residential_contact_points" do
    it "trả về 5 đầu mối sinh hoạt theo mục 1.4" do
      result = query.residential_contact_points
      expect(result.count).to eq(5)
      expect(result.map(&:name)).to contain_exactly(
        "Ban Tác huấn", "Văn thư", "Kho vật tư", "Đại đội 1", "Chỉ huy khu vực"
      )
    end
  end
end
