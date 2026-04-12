require "rails_helper"

RSpec.describe PumpStation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:meter).optional }
    it { is_expected.to have_many(:pump_station_assignments) }
    it { is_expected.to have_many(:served_organizations).through(:pump_station_assignments).source(:organization) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }

    it "is valid without a meter" do
      expect(build(:pump_station, meter: nil)).to be_valid
    end
  end
end
