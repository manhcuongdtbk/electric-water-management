require "rails_helper"

RSpec.describe Billing::RowspanComputer do
  describe ".compute" do
    let(:zone1) { instance_double("Zone", id: 1) }
    let(:zone2) { instance_double("Zone", id: 2) }

    def calc(zone_id:, unit_id:, block_id:, group_id:)
      cp = instance_double("ContactPoint",
                           effective_zone: zone_id ? instance_double("Zone", id: zone_id) : nil,
                           unit_id: unit_id, block_id: block_id, group_id: group_id)
      instance_double("Calculation", contact_point: cp)
    end

    it "gộp các dòng cùng zone+unit+block+group liên tiếp" do
      calcs = [
        calc(zone_id: 1, unit_id: 10, block_id: 100, group_id: 1000),
        calc(zone_id: 1, unit_id: 10, block_id: 100, group_id: 1000),
        calc(zone_id: 1, unit_id: 10, block_id: 100, group_id: 1000)
      ]
      result = described_class.compute(calcs, show_zone: true, show_unit: true)
      expect(result[0]).to eq(zone: 3, unit: 3, block: 3, group: 3)
      expect(result[1]).to eq({})
      expect(result[2]).to eq({})
    end

    it "không gộp block khi parent unit thay đổi" do
      calcs = [
        calc(zone_id: 1, unit_id: 10, block_id: 100, group_id: nil),
        calc(zone_id: 1, unit_id: 20, block_id: 100, group_id: nil)
      ]
      result = described_class.compute(calcs, show_zone: true, show_unit: true)
      expect(result[0][:unit]).to eq(1)
      expect(result[1][:unit]).to eq(1)
      expect(result[0][:block]).to eq(1)
      expect(result[1][:block]).to eq(1)
    end

    it "ẩn cột zone/unit theo flag" do
      calcs = [calc(zone_id: 1, unit_id: 10, block_id: nil, group_id: nil)]
      result = described_class.compute(calcs, show_zone: false, show_unit: false)
      expect(result[0]).not_to have_key(:zone)
      expect(result[0]).not_to have_key(:unit)
      expect(result[0]).to have_key(:block)
    end

    it "handles nil effective_zone gracefully" do
      calcs = [
        calc(zone_id: nil, unit_id: 10, block_id: nil, group_id: nil),
        calc(zone_id: nil, unit_id: 10, block_id: nil, group_id: nil)
      ]
      result = described_class.compute(calcs, show_zone: true, show_unit: true)
      expect(result[0][:zone]).to eq(2)
      expect(result[0][:unit]).to eq(2)
    end

    it "gộp đầu mối zone-residential (unit_id nil) cùng zone" do
      calcs = [
        calc(zone_id: 1, unit_id: nil, block_id: nil, group_id: nil),
        calc(zone_id: 1, unit_id: nil, block_id: nil, group_id: nil)
      ]
      result = described_class.compute(calcs, show_zone: true, show_unit: true)
      expect(result[0][:zone]).to eq(2)
      expect(result[0][:unit]).to eq(2)
    end
  end
end
