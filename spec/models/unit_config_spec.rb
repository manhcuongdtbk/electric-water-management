require "rails_helper"

RSpec.describe UnitConfig do
  describe "associations" do
    it { is_expected.to belong_to(:unit) }
    it { is_expected.to belong_to(:period) }
  end

  describe "validations" do
    subject { build(:unit_config) }
    it { is_expected.to validate_presence_of(:unit_public_rate) }
    it { is_expected.to validate_numericality_of(:unit_public_rate).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100) }
    it { is_expected.to validate_uniqueness_of(:unit_id).scoped_to(:period_id) }
  end

  describe "#calculation_state_targets" do
    it "returns nil zone_id when unit is nil" do
      config = UnitConfig.new(period_id: 1)
      targets = config.send(:calculation_state_targets)
      expect(targets).to eq([[nil, 1]])
    end
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(UnitConfig.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      config = create(:unit_config)
      copy = UnitConfig.find(config.id)
      config.update!(unit_public_rate: 25)
      expect { copy.update!(unit_public_rate: 30) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end
