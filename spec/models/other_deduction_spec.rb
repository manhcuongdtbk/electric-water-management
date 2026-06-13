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
    it "có giá trị fixed, coefficient và unit_coefficient" do
      expect(OtherDeduction.other_types.keys).to match_array(%w[fixed coefficient unit_coefficient])
    end

    it "tạo method prefix :other" do
      record = build(:other_deduction, other_type: "fixed")
      expect(record.other_fixed?).to be true
      expect(record.other_coefficient?).to be false
      expect(record.other_unit_coefficient?).to be false
    end
  end

  describe "unit_coefficient chỉ cho đầu mối thuộc đơn vị" do
    it "valid khi đầu mối thuộc đơn vị" do
      cp = create(:contact_point, :residential) # factory mặc định có unit
      record = build(:other_deduction, contact_point: cp, other_type: "unit_coefficient", other_value: -2)
      expect(record).to be_valid
    end

    it "CHIEU-khac-don-vi-zone-direct: invalid khi đầu mối thuộc khu vực trực tiếp (unit_id null)" do
      cp = create(:contact_point, :zone_residential)
      record = build(:other_deduction, contact_point: cp, other_type: "unit_coefficient", other_value: -2)
      expect(record).not_to be_valid
      expect(record.errors[:other_type]).to be_present
    end

    it "fixed/coefficient vẫn valid cho đầu mối khu vực trực tiếp" do
      cp = create(:contact_point, :zone_residential)
      record = build(:other_deduction, contact_point: cp, other_type: "coefficient", other_value: 2)
      expect(record).to be_valid
    end

    it "persist được với other_type unit_coefficient (chặn lỗi enum DB)" do
      cp = create(:contact_point, :residential)
      record = create(:other_deduction, contact_point: cp, other_type: "unit_coefficient", other_value: -2)
      expect(record.reload.other_type).to eq("unit_coefficient")
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
