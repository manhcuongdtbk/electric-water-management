require "rails_helper"

RSpec.describe ListSortable do
  let(:test_class) do
    Class.new do
      include ListSortable
      attr_reader :params

      def initialize(params = {})
        @params = ActionController::Parameters.new(params)
      end
    end
  end

  let!(:period) { create(:period, closed: false) }
  let!(:zone1) { create(:zone, name: "Khu vực Bắc") }
  let!(:zone2) { create(:zone, name: "Khu vực Nam") }
  let!(:zone3) { create(:zone, name: "100% tải") }

  describe "#apply_search" do
    it "tìm theo 1 cột" do
      obj = test_class.new(q: "Bắc")
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result.pluck(:name)).to contain_exactly("Khu vực Bắc")
    end

    it "tìm theo nhiều cột (OR)" do
      unit = create(:unit, zone: zone1, name: "Tiểu đoàn Alpha")
      obj = test_class.new(q: "Alpha")
      result = obj.send(:apply_search, Unit.joins(:zone), columns: %w[units.name zones.name])
      expect(result.pluck("units.name")).to contain_exactly("Tiểu đoàn Alpha")
    end

    it "q trống → trả toàn bộ" do
      obj = test_class.new(q: "")
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result.count).to eq(3)
    end

    it "q nil → trả toàn bộ" do
      obj = test_class.new
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result.count).to eq(3)
    end

    it "sanitize ký tự % — không match như wildcard" do
      obj = test_class.new(q: "100%")
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result.pluck(:name)).to contain_exactly("100% tải")
    end

    it "sanitize ký tự _ — không match như single-char wildcard" do
      obj = test_class.new(q: "_hu")
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result).to be_empty
    end

    it "strip khoảng trắng đầu cuối" do
      obj = test_class.new(q: "  Bắc  ")
      result = obj.send(:apply_search, Zone.all, columns: "zones.name")
      expect(result.pluck(:name)).to contain_exactly("Khu vực Bắc")
    end
  end
end
