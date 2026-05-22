require "rails_helper"

RSpec.describe ZoneUnitFilterable do
  let(:test_class) do
    Class.new do
      include ZoneUnitFilterable

      attr_reader :params
      attr_accessor :current_user_stub, :reopened_old_period_stub

      def initialize(params = {})
        @params = ActionController::Parameters.new(params)
        @reopened_old_period_stub = false
      end

      def current_user
        current_user_stub
      end

      def reopened_old_period?
        reopened_old_period_stub
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
      units = test_class.new.send(:available_units_for_filter, nil)
      expect(units).to include(unit1, unit2)
    end

    it "chọn zone → chỉ trả đơn vị thuộc zone" do
      units = test_class.new.send(:available_units_for_filter, zone1)
      expect(units).to include(unit1)
      expect(units).not_to include(unit2)
    end
  end

  describe "#available_zones_for_filter" do
    it "không giới hạn → trả tất cả khu vực kept" do
      zones = test_class.new.send(:available_zones_for_filter)
      expect(zones).to include(zone1, zone2)
    end

    it "giới hạn zone_ids → chỉ trả khu vực trong danh sách" do
      zones = test_class.new.send(:available_zones_for_filter, zone_ids: [zone1.id])
      expect(zones).to include(zone1)
      expect(zones).not_to include(zone2)
    end
  end

  describe "#zone_filter_scope / #unit_filter_scope" do
    it "kỳ bình thường → dùng .kept" do
      obj = test_class.new
      obj.reopened_old_period_stub = false
      expect(obj.send(:zone_filter_scope)).to eq(Zone.kept)
      expect(obj.send(:unit_filter_scope)).to eq(Unit.kept)
    end

    it "kỳ cũ mở lại → dùng .with_discarded" do
      obj = test_class.new
      obj.reopened_old_period_stub = true
      expect(obj.send(:zone_filter_scope)).to eq(Zone.with_discarded)
      expect(obj.send(:unit_filter_scope)).to eq(Unit.with_discarded)
    end

    it "zone đã xóa hiện trong dropdown khi kỳ cũ mở lại" do
      discarded_zone = Zone.create!(name: "Zone xóa", main_meters_attributes: [{ name: "CT" }])
      discarded_zone.discard
      obj = test_class.new
      obj.reopened_old_period_stub = true
      zones = obj.send(:available_zones_for_filter)
      expect(zones).to include(discarded_zone)
    end

    it "zone đã xóa không hiện trong dropdown khi kỳ mới nhất" do
      discarded_zone = Zone.create!(name: "Zone xóa", main_meters_attributes: [{ name: "CT" }])
      discarded_zone.discard
      obj = test_class.new
      obj.reopened_old_period_stub = false
      zones = obj.send(:available_zones_for_filter)
      expect(zones).not_to include(discarded_zone)
    end
  end

  describe "#set_sa_available_filters_from" do
    let!(:period) { create(:period, closed: false) }
    let!(:alloc1) { PumpAllocation.create!(zone: zone1, period: period, unit: unit1, coefficient: 1) }
    let(:sa) { create(:user, :system_admin) }

    it "SA → set @available_zones và @available_units từ scope" do
      obj = test_class.new
      obj.current_user_stub = sa
      scope = PumpAllocation.where(period: period).joins(:zone).left_joins(:unit)
      obj.send(:set_sa_available_filters_from, scope)
      expect(obj.instance_variable_get(:@available_zones).to_a).to include(zone1)
      expect(obj.instance_variable_get(:@available_zones).to_a).not_to include(zone2)
    end

    it "non-SA → không set gì" do
      ua = create(:user, :unit_admin, unit: unit1)
      obj = test_class.new
      obj.current_user_stub = ua
      scope = PumpAllocation.where(period: period)
      obj.send(:set_sa_available_filters_from, scope)
      expect(obj.instance_variable_get(:@available_zones)).to be_nil
    end
  end
end
