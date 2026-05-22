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

      def current_zone_manager?
        return false unless current_user&.unit_id
        Zone.kept.exists?(manager_unit_id: current_user.unit_id)
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

  describe "#resolve_current_user_zone_unit" do
    it "UA zone-manager → [zone, nil]" do
      zone1.update!(manager_unit_id: unit1.id)
      ua = create(:user, :unit_admin, unit: unit1)
      obj = test_class.new
      obj.current_user_stub = ua
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to eq(zone1)
      expect(unit).to be_nil
    end

    it "UA không phải zone-manager → [zone, unit]" do
      non_manager_unit = create(:unit, zone: zone1, name: "Đơn vị non-manager")
      ua = create(:user, :unit_admin, unit: non_manager_unit)
      obj = test_class.new
      obj.current_user_stub = ua
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to eq(zone1)
      expect(unit).to eq(non_manager_unit)
    end

    it "CMD zone-manager → [zone, nil]" do
      zone1.update!(manager_unit_id: unit1.id)
      cmd = create(:user, :commander, unit: unit1)
      obj = test_class.new
      obj.current_user_stub = cmd
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to eq(zone1)
      expect(unit).to be_nil
    end

    it "CMD không phải zone-manager → [zone, unit]" do
      non_manager_unit = create(:unit, zone: zone1, name: "Đơn vị non-manager CMD")
      cmd = create(:user, :commander, unit: non_manager_unit)
      obj = test_class.new
      obj.current_user_stub = cmd
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to eq(zone1)
      expect(unit).to eq(non_manager_unit)
    end

    it "user không có unit → [nil, nil]" do
      sa = create(:user, :system_admin)
      obj = test_class.new
      obj.current_user_stub = sa
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to be_nil
      expect(unit).to be_nil
    end

    it "zone manager bị gỡ → không phải zone-manager nữa → [zone, unit]" do
      zone1.update!(manager_unit_id: nil)
      ua = create(:user, :unit_admin, unit: unit1)
      obj = test_class.new
      obj.current_user_stub = ua
      zone, unit = obj.send(:resolve_current_user_zone_unit)
      expect(zone).to eq(zone1)
      expect(unit).to eq(unit1)
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

  describe "#apply_sa_zone_unit_filter_with_direct_zone" do
    let!(:period) { create(:period, closed: false) }
    let(:sa) { create(:user, :system_admin) }
    let(:ua) { create(:user, :unit_admin, unit: unit1) }

    let!(:cp_unit1) do
      create(:contact_point, :residential, unit: unit1, name: "CP đơn vị 1").tap do |cp|
        cp.meters.create!(name: "CT1")
      end
    end
    let!(:cp_unit2) do
      create(:contact_point, :residential, unit: unit2, name: "CP đơn vị 2").tap do |cp|
        cp.meters.create!(name: "CT2")
      end
    end
    let!(:cp_zone1) do
      create(:contact_point, :zone_residential, zone: zone1, name: "CP khu vực 1").tap do |cp|
        cp.meters.create!(name: "CT3")
      end
    end

    let(:base_scope) do
      ContactPoint.kept
        .left_joins(:unit, :zone)
        .joins("LEFT JOIN zones unit_zones ON unit_zones.id = units.zone_id")
    end

    it "SA không chọn filter → trả toàn bộ scope, set available zones/units" do
      obj = test_class.new
      obj.current_user_stub = sa
      result = obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      expect(result.to_a).to include(cp_unit1, cp_unit2, cp_zone1)
      expect(obj.instance_variable_get(:@available_zones).to_a).to include(zone1, zone2)
      expect(obj.instance_variable_get(:@available_units).to_a).to include(unit1, unit2)
    end

    it "SA chọn zone → filter OR (zone trực tiếp + qua unit)" do
      obj = test_class.new(zone_id: zone1.id)
      obj.current_user_stub = sa
      result = obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      names = result.map(&:name)
      expect(names).to include("CP đơn vị 1", "CP khu vực 1")
      expect(names).not_to include("CP đơn vị 2")
    end

    it "SA chọn unit → filter theo unit_id" do
      obj = test_class.new(unit_id: unit1.id)
      obj.current_user_stub = sa
      result = obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      names = result.map(&:name)
      expect(names).to include("CP đơn vị 1")
      expect(names).not_to include("CP đơn vị 2", "CP khu vực 1")
    end

    it "SA chọn zone → available_units chỉ hiện đơn vị trong zone đó" do
      obj = test_class.new(zone_id: zone1.id)
      obj.current_user_stub = sa
      obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      available_units = obj.instance_variable_get(:@available_units).to_a
      expect(available_units).to include(unit1)
      expect(available_units).not_to include(unit2)
    end

    it "SA available_zones bao gồm zone từ cả hai đường (trực tiếp + qua unit)" do
      obj = test_class.new
      obj.current_user_stub = sa
      obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      zone_ids = obj.instance_variable_get(:@available_zones).pluck(:id)
      expect(zone_ids).to include(zone1.id, zone2.id)
    end

    it "non-SA → trả scope không đổi, không set @available_zones" do
      obj = test_class.new
      obj.current_user_stub = ua
      result = obj.send(:apply_sa_zone_unit_filter_with_direct_zone, base_scope)
      expect(result.to_a).to include(cp_unit1, cp_unit2, cp_zone1)
      expect(obj.instance_variable_get(:@available_zones)).to be_nil
    end

    it "zone_scope: with_discarded → dropdown hiện zone đã xóa" do
      discarded_zone = Zone.create!(name: "Zone xóa", main_meters_attributes: [{ name: "CT xóa" }])
      create(:unit, zone: discarded_zone, name: "Unit xóa").tap do |u|
        create(:contact_point, :residential, unit: u, name: "CP xóa").tap do |cp|
          cp.meters.create!(name: "CT4")
        end
      end
      discarded_zone.discard

      obj = test_class.new
      obj.current_user_stub = sa
      scope = ContactPoint.with_discarded
                .left_joins(:unit, :zone)
                .joins("LEFT JOIN zones unit_zones ON unit_zones.id = units.zone_id")
      obj.send(:apply_sa_zone_unit_filter_with_direct_zone, scope,
               zone_scope: Zone.with_discarded, unit_scope: Unit.with_discarded)
      zone_names = obj.instance_variable_get(:@available_zones).pluck(:name)
      expect(zone_names).to include("Zone xóa")
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
