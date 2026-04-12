require "rails_helper"

RSpec.describe UnitConfig, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:monthly_period) }
  end

  describe "validations" do
    subject { build(:unit_config) }

    it { is_expected.to validate_uniqueness_of(:organization_id).scoped_to(:monthly_period_id) }

    it "rejects savings_rate >= 1" do
      expect(build(:unit_config, savings_rate: 1.0)).not_to be_valid
      expect(build(:unit_config, savings_rate: 1.5)).not_to be_valid
    end

    it "rejects negative savings_rate" do
      expect(build(:unit_config, savings_rate: -0.01)).not_to be_valid
    end

    it "allows nil rates" do
      config = build(:unit_config, savings_rate: nil, division_public_rate: nil, unit_public_rate: nil)
      expect(config).to be_valid
    end

    it "rejects negative electricity_supply_kw" do
      expect(build(:unit_config, electricity_supply_kw: -1)).not_to be_valid
    end

    it "allows nil electricity_supply_kw" do
      expect(build(:unit_config, electricity_supply_kw: nil)).to be_valid
    end

    it "rejects negative other_deduction_value" do
      expect(build(:unit_config, other_deduction_value: -1)).not_to be_valid
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:other_deduction_type)
        .with_values(fixed_kw: 0, percent: 1)
    }
  end
end
