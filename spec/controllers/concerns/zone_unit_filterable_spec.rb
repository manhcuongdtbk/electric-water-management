require "rails_helper"

RSpec.describe ZoneUnitFilterable do
  # Test concern bằng class giả lập có params
  let(:test_class) do
    Class.new do
      include ZoneUnitFilterable

      attr_reader :params

      def initialize(params = {})
        @params = ActionController::Parameters.new(params)
      end
    end
  end

  let!(:zone1) { create(:zone, name: "Khu vực 1") }
  let!(:zone2) { create(:zone, name: "Khu vực 2") }
  let!(:unit1) { create(:unit, zone: zone1, name: "Đơn vị 1") }
  let!(:unit2) { create(:unit, zone: zone2, name: "Đơn vị 2") }

  describe "#resolve_zone_unit_filter" do
    it "không chọn gì → zone và unit đều nil" do
      zone, unit = test_class.new.send(:resolve_zone_unit_filter)
      expect(zone).to be_nil
      expect(unit).to be_nil
    end

    it "chọn zone → trả zone, unit nil" do
      zone, unit = test_class.new(zone_id: zone1.id).send(:resolve_zone_unit_filter)
      expect(zone).to eq(zone1)
      expect(unit).to be_nil
    end

    it "chọn unit mà chưa chọn zone → tự chọn zone của unit" do
      zone, unit = test_class.new(unit_id: unit2.id).send(:resolve_zone_unit_filter)
      expect(zone).to eq(zone2)
      expect(unit).to eq(unit2)
    end

    it "chọn cả zone và unit → giữ nguyên cả hai" do
      zone, unit = test_class.new(zone_id: zone1.id, unit_id: unit1.id).send(:resolve_zone_unit_filter)
      expect(zone).to eq(zone1)
      expect(unit).to eq(unit1)
    end

    it "zone_id không tồn tại → zone nil" do
      zone, unit = test_class.new(zone_id: 999999).send(:resolve_zone_unit_filter)
      expect(zone).to be_nil
    end

    it "unit_id không tồn tại → unit nil, zone nil" do
      zone, unit = test_class.new(unit_id: 999999).send(:resolve_zone_unit_filter)
      expect(zone).to be_nil
      expect(unit).to be_nil
    end
  end

  describe "#available_units_for_filter" do
    it "không chọn zone → trả tất cả đơn vị" do
      obj = test_class.new
      units = obj.send(:available_units_for_filter, nil)
      expect(units).to include(unit1, unit2)
    end

    it "chọn zone → chỉ trả đơn vị thuộc zone" do
      obj = test_class.new
      units = obj.send(:available_units_for_filter, zone1)
      expect(units).to include(unit1)
      expect(units).not_to include(unit2)
    end
  end

  describe "#available_zones_for_filter" do
    it "không giới hạn → trả tất cả khu vực kept" do
      obj = test_class.new
      zones = obj.send(:available_zones_for_filter)
      expect(zones).to include(zone1, zone2)
    end

    it "giới hạn zone_ids → chỉ trả khu vực trong danh sách" do
      obj = test_class.new
      zones = obj.send(:available_zones_for_filter, zone_ids: [zone1.id])
      expect(zones).to include(zone1)
      expect(zones).not_to include(zone2)
    end
  end
end
