require "rails_helper"

RSpec.describe ContactPointOtherDeduction, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:contact_point) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "enums" do
    it do
      is_expected.to define_enum_for(:other_type)
        .with_values(fixed_kw: 0, factor_per_person: 1)
    end
  end

  describe "validations" do
    subject { build(:contact_point_other_deduction) }

    it { is_expected.to validate_uniqueness_of(:contact_point_id).scoped_to(:monthly_period_id) }
    it { is_expected.to validate_numericality_of(:other_value) }
  end
end
