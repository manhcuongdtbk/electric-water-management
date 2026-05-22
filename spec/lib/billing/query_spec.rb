require "rails_helper"

RSpec.describe Billing::Query do
  let(:sample) { setup_zone_one_full_sample }
  let(:admin_user) { create(:user, :system_admin) }
  let(:ability) { Ability.new(admin_user) }

  before do
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
  end

  describe ".base_scope" do
    it "chỉ lấy residential contact_points của period" do
      scope = described_class.base_scope(sample.period, ability)
      types = scope.map { |c| c.contact_point.contact_point_type }
      expect(types.uniq).to eq(["residential"])
    end

    it "respect accessible_by (system_admin xem hết)" do
      scope = described_class.base_scope(sample.period, ability)
      expect(scope.size).to eq(5)
    end
  end

  describe ".apply_zone_unit_filter" do
    let(:base) { described_class.base_scope(sample.period, ability) }

    it "filter theo unit" do
      scoped = described_class.apply_zone_unit_filter(base, zone: nil, unit: sample.unit_b)
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to contain_exactly("Đại đội 1")
    end

    it "filter theo zone bao gồm cả zone-residential" do
      scoped = described_class.apply_zone_unit_filter(base, zone: sample.zone, unit: nil)
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to include("Chỉ huy khu vực", "Ban Tác huấn", "Đại đội 1")
    end

    it "không filter → trả toàn bộ" do
      scoped = described_class.apply_zone_unit_filter(base, zone: nil, unit: nil)
      expect(scoped.count).to eq(5)
    end
  end

  describe ".apply_search" do
    let(:base) { described_class.base_scope(sample.period, ability) }

    it "filter theo tên đầu mối" do
      scoped = described_class.apply_search(base, q: "Ban")
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to contain_exactly("Ban Tác huấn")
    end

    it "q trống → trả toàn bộ" do
      scoped = described_class.apply_search(base, q: "")
      expect(scoped.count).to eq(5)
    end

    it "q nil → trả toàn bộ" do
      scoped = described_class.apply_search(base, q: nil)
      expect(scoped.count).to eq(5)
    end
  end

  describe ".apply_filters (backward compatible)" do
    let(:base) { described_class.base_scope(sample.period, ability) }

    it "filter theo unit" do
      scoped = described_class.apply_filters(base, zone: nil, unit: sample.unit_b, q: nil)
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to contain_exactly("Đại đội 1")
    end

    it "filter theo zone include zone-residential" do
      scoped = described_class.apply_filters(base, zone: sample.zone, unit: nil, q: nil)
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to include("Chỉ huy khu vực", "Ban Tác huấn", "Đại đội 1")
    end

    it "filter theo q (search by name)" do
      scoped = described_class.apply_filters(base, zone: nil, unit: nil, q: "Ban")
      cp_names = scoped.map { |c| c.contact_point.name }
      expect(cp_names).to contain_exactly("Ban Tác huấn")
    end
  end

  describe ".summary" do
    let(:scope) { described_class.base_scope(sample.period, ability) }

    it "trả về aggregate tổng đúng (T04)" do
      summary = described_class.summary(scope, period: sample.period)
      expect(summary[:total_personnel]).to eq(22)
      expect(summary[:residential_standard]).to eq_display("1644.00")
      expect(summary[:total_usage]).to eq_display("1623.00")
    end

    it "tính trên TOÀN scope, không phụ thuộc limit/offset" do
      ordered = scope.order(Arel.sql(Billing::Query::SORT_ORDER)).limit(2)
      summary = described_class.summary(ordered, period: sample.period)
      # SUM phải tổng cả 5 dòng = 22, không phải 2 dòng pagy
      expect(summary[:total_personnel]).to eq(22)
    end

    it "personnel_by_rank tổng đúng cho mỗi rank" do
      summary = described_class.summary(scope, period: sample.period)
      total = summary[:personnel_by_rank].values.sum
      expect(total).to eq(22)
    end
  end
end
