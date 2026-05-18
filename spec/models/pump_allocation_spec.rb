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
