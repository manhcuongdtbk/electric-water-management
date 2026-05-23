require "rails_helper"

RSpec.describe PumpAllocation do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to belong_to(:period) }
    it { is_expected.to belong_to(:unit).optional }
    it { is_expected.to belong_to(:contact_point).optional }
  end

  describe "validations" do
    subject { build(:pump_allocation) }

    it { is_expected.to validate_presence_of(:coefficient) }
    it { is_expected.to validate_numericality_of(:coefficient).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:fixed_percentage).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100).allow_nil }

    it "cho phép coefficient = 0 (T112)" do
      allocation = build(:pump_allocation, coefficient: 0)
      expect(allocation).to be_valid
    end

    describe "XOR unit/contact_point" do
      it "hợp lệ với unit và không có contact_point" do
        allocation = build(:pump_allocation)
        expect(allocation).to be_valid
      end

      it "hợp lệ với contact_point và không có unit" do
        allocation = build(:pump_allocation, :for_contact_point)
        expect(allocation).to be_valid
      end

      it "không hợp lệ khi có cả unit và contact_point" do
        allocation = build(:pump_allocation, contact_point: create(:contact_point, :residential))
        expect(allocation).not_to be_valid
      end

      it "không hợp lệ khi cả unit và contact_point đều null" do
        allocation = build(:pump_allocation, unit: nil, contact_point: nil)
        expect(allocation).not_to be_valid
      end
    end

    describe "tổng fixed_percentage trong cùng zone+period không vượt quá 100" do
      let(:zone) { create(:zone) }
      let(:period) { create(:period, closed: true) }
      let(:unit_one) { create(:unit, zone: zone) }
      let(:unit_two) { create(:unit, zone: zone) }
      let(:unit_three) { create(:unit, zone: zone) }

      it "hợp lệ khi tổng = 100" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 60)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: 40)
        expect(allocation).to be_valid
      end

      it "không hợp lệ khi tổng > 100" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 60)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: 41)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base])
          .to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.fixed_percentage_sum_exceeds_one_hundred"))
      end

      it "không tính chính bản ghi đang update" do
        allocation = create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 70)
        allocation.fixed_percentage = 80
        expect(allocation).to be_valid
      end

      it "không ảnh hưởng giữa các zone khác nhau" do
        other_zone = create(:zone)
        other_unit = create(:unit, zone: other_zone)
        create(:pump_allocation, zone: other_zone, period: period, unit: other_unit, fixed_percentage: 90)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 90)
        expect(allocation).to be_valid
      end

      it "không ảnh hưởng giữa các period khác nhau" do
        # Dùng năm xa để tránh đụng sequence của :period factory.
        other_period = create(:period, year: 2099, month: 12, closed: true)
        create(:pump_allocation, zone: zone, period: other_period, unit: unit_one, fixed_percentage: 90)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 90)
        expect(allocation).to be_valid
      end

      it "không cấm khi fixed_percentage = nil" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 100)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: nil, coefficient: 2)
        expect(allocation).to be_valid
      end
    end
  end

  describe "validate_contact_point_must_be_zone_level (I4)" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let(:period) { create(:period, closed: false) }

    it "chặn phân bổ cho CP thuộc đơn vị (phải zone-level)" do
      unit_cp = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, contact_point: unit_cp, unit: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:contact_point_id]).to be_present
    end

    it "cho phép CP thuộc khu vực (zone-level)" do
      zone_cp = create(:contact_point, :zone_residential, zone: zone)
      alloc = build(:pump_allocation, zone: zone, period: period, contact_point: zone_cp, unit: nil)
      expect(alloc).to be_valid
    end
  end

  describe "validate_target_belongs_to_zone (I5)" do
    let(:zone_a) { create(:zone) }
    let(:zone_b) { create(:zone) }
    let(:unit_a) { create(:unit, zone: zone_a) }
    let(:period) { create(:period, closed: false) }

    it "chặn unit thuộc zone khác" do
      unit_b = create(:unit, zone: zone_b)
      alloc = build(:pump_allocation, zone: zone_a, period: period, unit: unit_b, contact_point: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:unit_id]).to be_present
    end

    it "chặn CP thuộc zone khác" do
      cp_b = create(:contact_point, :zone_residential, zone: zone_b)
      alloc = build(:pump_allocation, zone: zone_a, period: period, contact_point: cp_b, unit: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:contact_point_id]).to be_present
    end
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(PumpAllocation.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      allocation = create(:pump_allocation)
      copy = PumpAllocation.find(allocation.id)
      allocation.update!(coefficient: 2)
      expect { copy.update!(coefficient: 3) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
