require "rails_helper"

RSpec.describe OtherDeduction do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:other_deduction) }
    it { is_expected.to validate_presence_of(:other_type) }
    it { is_expected.to validate_presence_of(:other_value) }
    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:period_id) }
  end

  describe "enum :other_type" do
    it "có giá trị fixed và coefficient" do
      expect(OtherDeduction.other_types.keys).to match_array(%w[fixed coefficient])
    end

    it "tạo method prefix :other" do
      record = build(:other_deduction, other_type: "fixed")
      expect(record.other_fixed?).to be true
      expect(record.other_coefficient?).to be false
    end
  end

  describe "other_value cho phép âm" do
    it "valid với giá trị âm" do
      record = build(:other_deduction, other_value: -100)
      expect(record).to be_valid
    end
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(OtherDeduction.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      deduction = create(:other_deduction)
      copy = OtherDeduction.find(deduction.id)
      deduction.update!(other_value: 100)
      expect { copy.update!(other_value: 200) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
