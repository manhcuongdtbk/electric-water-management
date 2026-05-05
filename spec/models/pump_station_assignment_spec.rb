require "rails_helper"

RSpec.describe PumpStationAssignment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:pump_station) }
    it { is_expected.to belong_to(:organization) }
  end

  it "has paper_trail enabled" do
    expect(PumpStationAssignment).to respond_to(:paper_trail)
    expect(PumpStationAssignment.new).to respond_to(:paper_trail)
  end

  describe "validations" do
    subject { build(:pump_station_assignment) }

    it { is_expected.to validate_uniqueness_of(:pump_station_id).scoped_to(:organization_id) }

    it "prevents duplicate assignment" do
      ps = create(:pump_station)
      org = create(:organization)
      create(:pump_station_assignment, pump_station: ps, organization: org)
      dup = build(:pump_station_assignment, pump_station: ps, organization: org)
      expect(dup).not_to be_valid
    end

    it { is_expected.to validate_numericality_of(:fixed_pump_percentage)
                          .is_greater_than_or_equal_to(0)
                          .is_less_than_or_equal_to(100)
                          .allow_nil }
  end

  describe "#fixed?" do
    it "is false when fixed_pump_percentage is nil" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: nil).fixed?).to be false
    end

    it "is true when fixed_pump_percentage is 0 (explicit fixed share of 0 kW)" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: 0).fixed?).to be true
    end

    it "is true when fixed_pump_percentage is positive" do
      expect(build(:pump_station_assignment, fixed_pump_percentage: 30).fixed?).to be true
    end
  end
end
