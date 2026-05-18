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
        other_period = create(:period, year: 2027, month: 1, closed: true)
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
